#!/bin/bash

## Only need to run this script once for set up of singularity files and reference file downloads

set -eu -o pipefail

export COLORS_WORKFLOW_ROOT="$(dirname "$(readlink -f "${BASH_SOURCE}")")"
export COLORS_WORKFLOW_RESOURCES="${COLORS_WORKFLOW_ROOT}/resources"
export COLORS_WORKFLOW_SINGULARITY="${COLORS_WORKFLOW_ROOT}/singularity"
export SINGULARITY_BINDPATH="${COLORS_WORKFLOW_ROOT}"

mkdir -p ${COLORS_WORKFLOW_SINGULARITY}
mkdir -p ${COLORS_WORKFLOW_RESOURCES}

export BCFTOOLSCMD="${COLORS_WORKFLOW_SINGULARITY}/bcftools_1.19.sif"
export TRUVARICMD="${COLORS_WORKFLOW_SINGULARITY}/truvari_5.3.0.sif"

echo $(date) - Downloading sif files to singularity subfolder..
curl -o ${BCFTOOLSCMD} https://depot.galaxyproject.org/singularity/bcftools%3A1.19--h8b25389_1 -C -
curl -o ${TRUVARICMD} https://depot.galaxyproject.org/singularity/truvari%3A5.3.0--pyhdfd78af_0 -C -
echo $(date) - End of download.

echo $(date) - Set up sif execution permission..
chmod a+rx ${COLORS_WORKFLOW_SINGULARITY}
chmod a+rx ${COLORS_WORKFLOW_SINGULARITY}/*.sif
echo $(date) - End of permission set up.

echo $(date) - Downloading hg38 ref to resources subfolder...
FTPDIR=ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids
curl ${FTPDIR}/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz | gunzip > ${COLORS_WORKFLOW_RESOURCES}/GRCh38_no_alt_analysis_set.fasta
curl ${FTPDIR}/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.fai > ${COLORS_WORKFLOW_RESOURCES}/GRCh38_no_alt_analysis_set.fasta.fai
echo $(date) - End of download.

echo $(date) - Downloading ColorsDB SV dataset to resources subfolder..
curl -o ${COLORS_WORKFLOW_RESOURCES}/CoLoRSdb.GRCh38.v1.2.0.pbsv.jasmine.vcf.gz https://zenodo.org/records/14814308/files/CoLoRSdb.GRCh38.v1.2.0.pbsv.jasmine.vcf.gz
echo $(date) - End of download.

echo $(date) - Formatting ColorsDB vcf by filling IDs and addding SAMPLE column.
${BCFTOOLSCMD} bcftools annotate --set-id +'colors\_%CHROM\_%POS\_%INFO/SVTYPE\_%INFO/SVLEN' \
-Oz -o ${COLORS_WORKFLOW_RESOURCES}/CoLoRSdb.GRCh38.v1.2.0.pbsv.jasmine.setid.vcf.gz ${COLORS_WORKFLOW_RESOURCES}/CoLoRSdb.GRCh38.v1.2.0.pbsv.jasmine.vcf.gz
${BCFTOOLSCMD} bcftools index --tbi ${COLORS_WORKFLOW_RESOURCES}/CoLoRSdb.GRCh38.v1.2.0.pbsv.jasmine.setid.vcf.gz
echo $(date) - End of ColorsDB VCF formatting.

echo $(date) - Downloading 1000gONT SV dataset to resources subfolder..
curl -o ${COLORS_WORKFLOW_RESOURCES}/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_relaxed.vcf https://s3.amazonaws.com/1000g-ont/needLR/custom_analyses/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_relaxed.vcf
curl -o ${COLORS_WORKFLOW_RESOURCES}/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_strict.vcf https://s3.amazonaws.com/1000g-ont/needLR/custom_analyses/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_strict.vcf
echo $(date) - End of download.

echo $(date) - Formatting strict 1000gONT vcf by filling IDs and addding SAMPLE column. 
${BCFTOOLSCMD} bcftools annotate --set-id +'1000gONT\_%CHROM\_%POS\_%INFO/SVTYPE\_%INFO/SVLEN' \
-Oz -o ${COLORS_WORKFLOW_RESOURCES}/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_strict.setid.vcf.gz ${COLORS_WORKFLOW_RESOURCES}/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_strict.vcf 
${BCFTOOLSCMD} bcftools index --tbi ${COLORS_WORKFLOW_RESOURCES}/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_strict.setid.vcf.gz
echo $(date) - End of 1000gONT VCF formatting.

echo $(date) - Formatting relaxed 1000gONT vcf by filling IDs and addding SAMPLE column. 
${BCFTOOLSCMD} bcftools annotate --set-id +'1000gONT\_%CHROM\_%POS\_%INFO/SVTYPE\_%INFO/SVLEN' \
-Oz -o ${COLORS_WORKFLOW_RESOURCES}/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_relaxed.setid.vcf.gz ${COLORS_WORKFLOW_RESOURCES}/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_relaxed.vcf 
${BCFTOOLSCMD} bcftools index --tbi ${COLORS_WORKFLOW_RESOURCES}/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_relaxed.setid.vcf.gz
echo $(date) - End of 1000gONT VCF formatting.

echo $(date) - Set up resource permissions..
chmod a+rx ${COLORS_WORKFLOW_RESOURCES}
chmod a+rx ${COLORS_WORKFLOW_RESOURCES}/*
echo $(date) - End of permission set up.

echo $(date) - Set up complete.



