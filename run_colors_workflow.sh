#!/bin/bash

set -eu -o pipefail


usage() {
    echo "Usage: run_colors_workflow.sh -i <input_vcf> -o <output_dir> [-m <min_sv_length>]"
    echo
    echo "Required arguments:"
    echo "  -i <input_vcf>         Input VCF (should be .gz and have .tbi index)."
    echo "  -o <output_dir>        Output directory."
    echo
    echo "Optional arguments:"
    echo "  -m <min_sv_length>    Filter out SVs smaller than set threshold. (default: 15)."

}

# Check if no arguments were passed
if [ "$#" -eq 0 ]; then
    usage
    exit 1
fi

# Default values
export MIN_SV_LENGTH=15

while getopts "i:o:m:h" FLAG; do
    case ${FLAG} in
        i) INPUTFILE=${OPTARG};;
        o) OUTDIR=${OPTARG};;
        m) MIN_SV_LENGTH=${OPTARG};;
        h) 
            usage
            exit 0
            ;;
        *) 
            echo "Invalid or missing arguments."
            usage
            exit 1
            ;;
    esac
done

### modifiable variables
export OVERSIZED_THRESHOLD=100000
export UW1KG_STRICTNESS="relaxed" ## strict or relaxed VCF
###

export COLORS_WORKFLOW_ROOT="$(dirname "$(readlink -f "${BASH_SOURCE}")")"
export COLORS_WORKFLOW_RESOURCES="${COLORS_WORKFLOW_ROOT}/resources"
export COLORS_WORKFLOW_SINGULARITY="${COLORS_WORKFLOW_ROOT}/singularity"

export REF="${COLORS_WORKFLOW_RESOURCES}/GRCh38_no_alt_analysis_set.fasta"
export COLORSDBVCF="${COLORS_WORKFLOW_RESOURCES}/CoLoRSdb.GRCh38.v1.2.0.pbsv.jasmine.fixed_format.vcf.gz"
export UWONTVCF="${COLORS_WORKFLOW_RESOURCES}/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_${UW1KG_STRICTNESS}.fixed_format.vcf.gz"

export BCFTOOLSCMD="${COLORS_WORKFLOW_SINGULARITY}/bcftools_1.19.sif"
export TRUVARICMD="${COLORS_WORKFLOW_SINGULARITY}/truvari_5.3.0.sif"
export HTSLIBCMD="${COLORS_WORKFLOW_SINGULARITY}/htslib_1.19.sif"

OUTDIR="${OUTDIR%/}"
[ ! -d "${OUTDIR}" ] && mkdir "${OUTDIR}"
mkdir -p ${OUTDIR}/debug

export INPUTDIR=$(dirname ${INPUTFILE})
export PREFIX=$(basename ${INPUTFILE})
PREFIX="${PREFIX%.gz}"
PREFIX="${PREFIX%.*}"

export SINGULARITY_BINDPATH="${COLORS_WORKFLOW_ROOT},${INPUTDIR}"
if [[ "${OUTDIR}" != "${INPUTDIR}" ]]; then
    export SINGULARITY_BINDPATH="${COLORS_WORKFLOW_ROOT},${INPUTDIR},${OUTDIR}"
fi

echo "Input file = ${INPUTFILE}"
echo "Output directory = ${OUTDIR}"
echo "Minimum SV Length = ${MIN_SV_LENGTH}"
echo "Starting variant count: " $(zcat ${INPUTFILE} | grep -v '^#' | wc -l)

echo '==' $(date) '==' Preprocess input VCF to filter for PASS and chr1-22,X,Y,M variants
${BCFTOOLSCMD} bcftools view -f PASS -i "INFO/SVLEN>${MIN_SV_LENGTH} || INFO/SVLEN<-${MIN_SV_LENGTH}" \
-r chr1,chr2,chr3,chr4,chr5,chr6,chr7,chr8,chr9,chr10,chr11,chr12,chr13,chr14,chr15,chr16,chr17,chr18,chr19,chr20,chr21,chr22,chrX,chrY,chrM \
-Oz -o ${OUTDIR}/${PREFIX}.preprocessed.vcf.gz ${INPUTFILE}
${BCFTOOLSCMD} bcftools index --tbi ${OUTDIR}/${PREFIX}.preprocessed.vcf.gz

echo "Remaining variant count: " $(zcat ${OUTDIR}/${PREFIX}.preprocessed.vcf.gz | grep -v '^#' | wc -l)

echo '==' $(date) '==' Truvari bench with ColorsDB 
${TRUVARICMD} truvari bench -b ${COLORSDBVCF} -c ${OUTDIR}/${PREFIX}.preprocessed.vcf.gz -f ${REF} -o ${OUTDIR}/debug/truvari_bench_colors \
--sizemin ${MIN_SV_LENGTH} --sizemax ${OVERSIZED_THRESHOLD} --dup-to-ins --write-resolved --refdist 500 --pctseq 0.90 --pctsize 0.90

echo '==' $(date) '==' Append ColorsDB annotations 
python ${COLORS_WORKFLOW_ROOT}/annotate_with_truvari_output.py \
-i ${OUTDIR}/debug/truvari_bench_colors \
-o ${OUTDIR}/debug/${PREFIX}.colorAnno.vcf \
-r COLORS

${BCFTOOLSCMD} bcftools sort ${OUTDIR}/debug/${PREFIX}.colorAnno.vcf -Oz -o ${OUTDIR}/debug/${PREFIX}.colorAnno.vcf.gz
${BCFTOOLSCMD} bcftools index --tbi ${OUTDIR}/debug/${PREFIX}.colorAnno.vcf.gz

echo "Remaining variant count: " $(zcat ${OUTDIR}/debug/${PREFIX}.colorAnno.vcf.gz | grep -v '^#' | wc -l)

echo '==' $(date) '==' Truvari bench with 1000gONT 
${TRUVARICMD} truvari bench -b ${UWONTVCF} -c ${OUTDIR}/debug/${PREFIX}.colorAnno.vcf.gz -f ${REF} -o ${OUTDIR}/debug/truvari_bench_1000g \
--sizemin ${MIN_SV_LENGTH} --sizemax ${OVERSIZED_THRESHOLD} --dup-to-ins --write-resolved --refdist 500 --pctseq 0.90 --pctsize 0.90

echo '==' $(date) '==' Append 1000gONT annotations 
python ${COLORS_WORKFLOW_ROOT}/annotate_with_truvari_output.py \
-i ${OUTDIR}/debug/truvari_bench_1000g \
-o ${OUTDIR}/debug/${PREFIX}.colorAnno.1000gAnno.vcf \
-r UW1KG

${BCFTOOLSCMD} bcftools sort ${OUTDIR}/debug/${PREFIX}.colorAnno.1000gAnno.vcf -Oz -o ${OUTDIR}/debug/${PREFIX}.colorAnno.1000gAnno.vcf.gz
${BCFTOOLSCMD} bcftools index --tbi ${OUTDIR}/debug/${PREFIX}.colorAnno.1000gAnno.vcf.gz 

echo "Remaining variant count: " $(zcat ${OUTDIR}/debug/${PREFIX}.colorAnno.1000gAnno.vcf.gz  | grep -v '^#' | wc -l)

echo '==' $(date) '==' Oversized SV iteration - Run truvari merge + annotate steps for oversized SVs filtered during first iteration of workflow
echo '==' $(date) '==' "Pull oversized SVs from preprocessed VCF (SVLEN>${OVERSIZED_THRESHOLD})"
${BCFTOOLSCMD} bcftools view -i "(INFO/SVLEN > ${OVERSIZED_THRESHOLD} || INFO/SVLEN < -${OVERSIZED_THRESHOLD})" \
-Oz -o ${OUTDIR}/debug/${PREFIX}.oversizedSVs.vcf.gz ${OUTDIR}/${PREFIX}.preprocessed.vcf.gz
${BCFTOOLSCMD} bcftools index --tbi ${OUTDIR}/debug/${PREFIX}.oversizedSVs.vcf.gz

echo "Oversized SV count: " $(zcat ${OUTDIR}/debug/${PREFIX}.oversizedSVs.vcf.gz | grep -v '^#' | wc -l)

echo '==' $(date) '==' OVERSIZED - Truvari bench with ColorsDB
${TRUVARICMD} truvari bench -b ${COLORSDBVCF} -c ${OUTDIR}/debug/${PREFIX}.oversizedSVs.vcf.gz -f ${REF} -o ${OUTDIR}/debug/truvari_bench_colors_oversized \
--sizemin ${OVERSIZED_THRESHOLD} --sizemax -1 --dup-to-ins --refdist 500 --pctseq 0.90 --pctsize 0.90

echo '==' $(date) '==' OVERSIZED - Append ColorsDB annotations 
python ${COLORS_WORKFLOW_ROOT}/annotate_with_truvari_output.py \
-i ${OUTDIR}/debug/truvari_bench_colors_oversized \
-o ${OUTDIR}/debug/${PREFIX}.colorAnno.1000gAnno.withColorsOversized.vcf \
-r COLORS

${BCFTOOLSCMD} bcftools sort ${OUTDIR}/debug/${PREFIX}.colorAnno.1000gAnno.withColorsOversized.vcf -Oz -o ${OUTDIR}/debug/${PREFIX}.colorAnno.1000gAnno.withColorsOversized.vcf.gz
${BCFTOOLSCMD} bcftools index --tbi ${OUTDIR}/debug/${PREFIX}.colorAnno.1000gAnno.withColorsOversized.vcf.gz

echo '==' $(date) '==' OVERSIZED - Truvari bench with 1000g
${TRUVARICMD} truvari bench -b ${UWONTVCF} -c ${OUTDIR}/debug/${PREFIX}.colorAnno.1000gAnno.withColorsOversized.vcf.gz -f ${REF} -o ${OUTDIR}/debug/truvari_bench_1000g_oversized \
--sizemin ${OVERSIZED_THRESHOLD} --sizemax -1 --dup-to-ins --refdist 500 --pctseq 0.90 --pctsize 0.90

echo '==' $(date) '==' OVERSIZED - Append 1000g annotations 
python ${COLORS_WORKFLOW_ROOT}/annotate_with_truvari_output.py \
-i ${OUTDIR}/debug/truvari_bench_1000g_oversized \
-o ${OUTDIR}/debug/${PREFIX}.colorAnno.1000gAnno.withColorsOversized.with1000gOversized.vcf \
-r UW1KG

${BCFTOOLSCMD} bcftools sort ${OUTDIR}/debug/${PREFIX}.colorAnno.1000gAnno.withColorsOversized.with1000gOversized.vcf -Oz -o ${OUTDIR}/debug/${PREFIX}.colorAnno.1000gAnno.withColorsOversized.with1000gOversized.vcf.gz
${BCFTOOLSCMD} bcftools index --tbi ${OUTDIR}/debug/${PREFIX}.colorAnno.1000gAnno.withColorsOversized.with1000gOversized.vcf.gz

echo '==' $(date) '==' Add annotated oversized SVs to final VCF
${BCFTOOLSCMD} bcftools concat -a ${OUTDIR}/debug/${PREFIX}.colorAnno.1000gAnno.vcf.gz ${OUTDIR}/debug/${PREFIX}.colorAnno.1000gAnno.withColorsOversized.with1000gOversized.vcf.gz \
-Oz -o ${OUTDIR}/debug/${PREFIX}.colorAnno.1000gAnno.combined.vcf.gz
${BCFTOOLSCMD} bcftools index --tbi ${OUTDIR}/debug/${PREFIX}.colorAnno.1000gAnno.combined.vcf.gz

echo '==' $(date) '==' Add bcftools fill-tags for AC,AN,AF tags 
${BCFTOOLSCMD} bcftools +fill-tags ${OUTDIR}/debug/${PREFIX}.colorAnno.1000gAnno.combined.vcf.gz -- -t AC,AN,AF \
| ${BCFTOOLSCMD} bcftools sort -Oz -o ${OUTDIR}/${PREFIX}.colorAnno.1000gAnno.final.vcf.gz
${BCFTOOLSCMD} bcftools index --tbi ${OUTDIR}/${PREFIX}.colorAnno.1000gAnno.final.vcf.gz

echo '==' $(date) '==' Clean up temp files
rm ${OUTDIR}/debug/${PREFIX}*.vcf

echo "Final SV count: " $(zcat ${OUTDIR}/${PREFIX}.colorAnno.1000gAnno.final.vcf.gz | grep -v '^#' | wc -l)
