#!/bin/bash

set -eu -o pipefail


usage() {
    echo "Usage: run_colors_workflow.sh -i <input_vcf> -o <output_dir> [-t <threads>]"
    echo
    echo "Required arguments:"
    echo "  -i <input_vcf>         Input VCF (should be .gz and have .tbi index)."
    echo "  -o <output_dir>        Output directory."
    echo
    echo "Optional arguments:"
    echo "  -t <threads>          Number of threads to use (default: 4)."

}

# Check if no arguments were passed
if [ "$#" -eq 0 ]; then
    usage
    exit 1
fi

# Default values
export THREADS=4  

while getopts "i:o:t:h" FLAG; do
    case ${FLAG} in
        i) INPUTFILE=${OPTARG};;
        o) OUTDIR=${OPTARG};;
        t) THREADS=${OPTARG};;
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

export COLORS_WORKFLOW_ROOT="$(dirname "$(readlink -f "${BASH_SOURCE}")")"
export COLORS_WORKFLOW_RESOURCES="${COLORS_WORKFLOW_ROOT}/resources"
export COLORS_WORKFLOW_SINGULARITY="${COLORS_WORKFLOW_ROOT}/singularity"

export REF="${COLORS_WORKFLOW_RESOURCES}/GRCh38_no_alt_analysis_set.fasta"
export COLORSDBVCF="${COLORS_WORKFLOW_RESOURCES}/CoLoRSdb.GRCh38.v1.2.0.pbsv.jasmine.fixed_format.vcf.gz"

#export JASMINECMD="${COLORS_WORKFLOW_SINGULARITY}/jasminesv_1.1.5.sif"
export BCFTOOLSCMD="${COLORS_WORKFLOW_SINGULARITY}/bcftools_1.19.sif"
export TRUVARICMD="${COLORS_WORKFLOW_SINGULARITY}/truvari_5.2.0.sif"
export HTSLIBCMD="${COLORS_WORKFLOW_SINGULARITY}/htslib_1.19.sif"

OUTDIR="${OUTDIR%/}"
[ ! -d "${OUTDIR}" ] && mkdir "${OUTDIR}"

export INPUTDIR=$(dirname ${INPUTFILE})
export PREFIX=$(basename ${INPUTFILE})
PREFIX="${PREFIX%.gz}"
PREFIX="${PREFIX%.*}"

export SINGULARITY_BINDPATH="${COLORS_WORKFLOW_ROOT},${INPUTDIR}"
if [[ "${OUTDIR}" != "${INPUTDIR}" ]]; then
    export SINGULARITY_BINDPATH="${COLORS_WORKFLOW_ROOT},${INPUTDIR},${OUTDIR}"
fi

# echo '==' $(date) '==' Jasmine merge START 
# ${JASMINECMD} jasmine file_list=${INPUTFILE},${COLORSDBVCF} out_file=${OUTDIR}/${PREFIX}.colorMerge.vcf \
# genome_file=${REF} threads=${THREADS} out_dir=${OUTDIR} --comma_filelist --require_first_sample --dup_to_ins 
# echo '==' $(date) '==' Jasmine merge END


### might need to add sizemax for long variants that make truvari hang
### test stricter match? 0.9 instead of 0.7?

echo '==' $(date) '==' Truvari bench START 
${TRUVARICMD} truvari bench -b ${COLORSDBVCF} -c ${INPUTFILE} \
-f ${REF} -o ${OUTDIR}/truvari_bench --sizemin 15 --sizemax 100000 --dup-to-ins --write-resolved
echo '==' $(date) '==' Truvari bench END

# echo '==' $(date) '==' Append ColorsDB annotions START 
# python ${COLORS_WORKFLOW_ROOT}/annotate_with_colorsdb.py \
# -m ${OUTDIR}/${PREFIX}.colorMerge.vcf \
# -c ${COLORSDBVCF} \
# -o ${OUTDIR}/${PREFIX}.colorAnno.vcf
# echo '==' $(date) '==' Append ColorsDB annotions  END

echo '==' $(date) '==' Append ColorsDB annotions START 
python ${COLORS_WORKFLOW_ROOT}/annotate_with_colorsdb_truvari.py \
-i ${OUTDIR}/truvari_bench \
-o ${OUTDIR}/${PREFIX}.colorAnno.vcf
echo '==' $(date) '==' Append ColorsDB annotions  END


echo '==' $(date) '==' Sort final vcf and add AC,AN,AF tags START 
${BCFTOOLSCMD} bcftools sort ${OUTDIR}/${PREFIX}.colorAnno.vcf | ${BCFTOOLSCMD} bcftools +fill-tags -- -t AC,AN,AF > ${OUTDIR}/${PREFIX}.colorAnno.sorted.vcf
echo '==' $(date) '==' Sort final vcf and add AC,AN,AF tags END

${HTSLIBCMD} bgzip ${OUTDIR}/${PREFIX}.colorAnno.sorted.vcf
${HTSLIBCMD} tabix -p vcf ${OUTDIR}/${PREFIX}.colorAnno.sorted.vcf.gz

rm ${OUTDIR}/${PREFIX}.colorAnno.vcf


### keep track of variants filtered out by truvari
#/net/nwgc/vol1/home/czaka/tools/colorsDB-SV-workflow/check_missing_variants.py