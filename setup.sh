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
export HTSLIBCMD="${COLORS_WORKFLOW_SINGULARITY}/htslib_1.19.sif"

echo $(date) - Downloading sif files to singularity subfolder..
curl -o ${BCFTOOLSCMD} https://depot.galaxyproject.org/singularity/bcftools%3A1.19--h8b25389_1 -C -
curl -o ${TRUVARICMD} https://depot.galaxyproject.org/singularity/truvari%3A5.3.0--pyhdfd78af_0 -C -
curl -o ${HTSLIBCMD} https://depot.galaxyproject.org/singularity/htslib%3A1.19--h81da01d_0 -C -
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
${COLORS_WORKFLOW_RESOURCES}/CoLoRSdb.GRCh38.v1.2.0.pbsv.jasmine.vcf.gz > ${COLORS_WORKFLOW_RESOURCES}/CoLoRSdb.GRCh38.v1.2.0.pbsv.jasmine.setid.vcf

## truvari v5.3.0 doesn't require sample column // can probs remove this if want to?
${COLORS_WORKFLOW_ROOT}/add_sample_columns.py \
-i ${COLORS_WORKFLOW_RESOURCES}/CoLoRSdb.GRCh38.v1.2.0.pbsv.jasmine.setid.vcf \
-o ${COLORS_WORKFLOW_RESOURCES}/CoLoRSdb.GRCh38.v1.2.0.pbsv.jasmine.setid.setSampleCol.vcf

mv ${COLORS_WORKFLOW_RESOURCES}/CoLoRSdb.GRCh38.v1.2.0.pbsv.jasmine.setid.setSampleCol.vcf ${COLORS_WORKFLOW_RESOURCES}/CoLoRSdb.GRCh38.v1.2.0.pbsv.jasmine.fixed_format.vcf
rm ${COLORS_WORKFLOW_RESOURCES}/CoLoRSdb.GRCh38.v1.2.0.pbsv.jasmine.setid.vcf

${HTSLIBCMD} bgzip ${COLORS_WORKFLOW_RESOURCES}/CoLoRSdb.GRCh38.v1.2.0.pbsv.jasmine.fixed_format.vcf
${HTSLIBCMD} tabix -p vcf ${COLORS_WORKFLOW_RESOURCES}/CoLoRSdb.GRCh38.v1.2.0.pbsv.jasmine.fixed_format.vcf.gz
echo $(date) - End of ColorsDB VCF formatting.

echo $(date) - Downloading 1000gONT SV dataset to resources subfolder..
curl -o ${COLORS_WORKFLOW_RESOURCES}/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_relaxed.vcf https://s3.amazonaws.com/1000g-ont/needLR/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_relaxed.vcf
curl -o ${COLORS_WORKFLOW_RESOURCES}/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_strict.vcf https://s3.amazonaws.com/1000g-ont/needLR/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_strict.vcf
echo $(date) - End of download.

echo $(date) - Formatting 1000gONT vcf by filling IDs and addding SAMPLE column.
${BCFTOOLSCMD} bcftools annotate --set-id +'1000gONT\_%CHROM\_%POS\_%INFO/SVTYPE\_%INFO/SVLEN' \
${COLORS_WORKFLOW_RESOURCES}/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_strict.vcf > ${COLORS_WORKFLOW_RESOURCES}/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_strict.setid.vcf

${COLORS_WORKFLOW_ROOT}/add_sample_columns.py \
-i ${COLORS_WORKFLOW_RESOURCES}/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_strict.setid.vcf \
-o ${COLORS_WORKFLOW_RESOURCES}/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_strict.setid.setSampleCol.vcf

mv ${COLORS_WORKFLOW_RESOURCES}/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_strict.setid.setSampleCol.vcf ${COLORS_WORKFLOW_RESOURCES}/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_strict.fixed_format.vcf
rm ${COLORS_WORKFLOW_RESOURCES}/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_strict.setid.vcf 

${HTSLIBCMD} bgzip ${COLORS_WORKFLOW_RESOURCES}/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_strict.fixed_format.vcf
${HTSLIBCMD} tabix -p vcf ${COLORS_WORKFLOW_RESOURCES}/UWONT_450_sniffles_2.5.2_cohort_merge_annotate_strict.fixed_format.vcf.gz
echo $(date) - End of 1000gONT VCF formatting.



echo $(date) - Set up resource permissions..
chmod a+rx ${COLORS_WORKFLOW_RESOURCES}
chmod a+rx ${COLORS_WORKFLOW_RESOURCES}/*
echo $(date) - End of permission set up.

echo $(date) - Set up complete.



