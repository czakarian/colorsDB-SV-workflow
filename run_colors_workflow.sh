#!/bin/bash

set -eu -o pipefail

## input should be a pbsv joint called vcf (or single sample if a single sample)
INPUTFILE=$1
OUTDIR=$2

export COLORS_WORKFLOW_ROOT="$(dirname "$(readlink -f "${BASH_SOURCE}")")"
export COLORS_WORKFLOW_RESOURCES="${COLORS_WORKFLOW_ROOT}/resources"
export COLORS_WORKFLOW_SINGULARITY="${COLORS_WORKFLOW_ROOT}/singularity"

export REF="${COLORS_WORKFLOW_RESOURCES}/GRCh38_no_alt_analysis_set.fasta"
export COLORSDBVCF="${COLORS_WORKFLOW_RESOURCES}/CoLoRSdb.GRCh38.v1.2.0.pbsv.jasmine.setid.vcf"

export JASMINECMD="${COLORS_WORKFLOW_SINGULARITY}/jasminesv_1.1.5.sif jasmine"
export BCFTOOLSCMD="${COLORS_WORKFLOW_SINGULARITY}/bcftools_1.19.sif bcftools"

export THREADS=16

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

echo '==' $(date) '==' Jasmine merge START 
${JASMINECMD} file_list=${INPUTFILE},${COLORSDBVCF} out_file=${OUTDIR}/${PREFIX}.colorMerge.vcf \
genome_file=${REF} threads=${THREADS} --comma_filelist --require_first_sample --dup_to_ins 
echo '==' $(date) '==' Jasmine merge END

echo '==' $(date) '==' Append ColorsDB annotions START 
python ${COLORS_WORKFLOW_ROOT}/annotate_with_colorsdb.py \
-m ${OUTDIR}/${PREFIX}.colorMerge.vcf \
-c ${COLORSDBVCF} \
-o ${OUTDIR}/${PREFIX}.colorAnno.vcf
echo '==' $(date) '==' Append ColorsDB annotions  END

echo '==' $(date) '==' Sort final vcf and add AC,AN,AF tags START 
${BCFTOOLSCMD} sort ${OUTDIR}/${PREFIX}.colorAnno.vcf | ${BCFTOOLSCMD} +fill-tags -- -t AC,AN,AF > ${OUTDIR}/${PREFIX}.colorAnno.sorted.vcf
echo '==' $(date) '==' Sort final vcf and add AC,AN,AF tags END
