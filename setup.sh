#!/bin/bash

## Only need to run this script once for set up of singularity files and reference file downloads

set -eu -o pipefail

export COLORS_WORKFLOW_ROOT="$(dirname "$(readlink -f "${BASH_SOURCE}")")"
export COLORS_WORKFLOW_RESOURCES="${COLORS_WORKFLOW_ROOT}/resources"
export COLORS_WORKFLOW_SINGULARITY="${COLORS_WORKFLOW_ROOT}/singularity"
export SINGULARITY_BINDPATH="${COLORS_WORKFLOW_ROOT}"

mkdir -p ${COLORS_WORKFLOW_SINGULARITY}
mkdir -p ${COLORS_WORKFLOW_RESOURCES}

echo $(date) - Downloading sif files to singularity subfolder..
#curl -o ${COLORS_WORKFLOW_SINGULARITY}/pbsv_2.9.0.sif https://depot.galaxyproject.org/singularity/pbsv%3A2.9.0--h9ee0642_0 -C -
curl -o ${COLORS_WORKFLOW_SINGULARITY}/jasminesv_1.1.5.sif https://depot.galaxyproject.org/singularity/jasminesv%3A1.1.5--hdfd78af_0 -C -
#curl -o ${COLORS_WORKFLOW_SINGULARITY}/truvari_5.2.0.sif https://depot.galaxyproject.org/singularity/truvari%3A5.2.0--pyhdfd78af_0 -C -
curl -o ${COLORS_WORKFLOW_SINGULARITY}/bcftools_1.19.sif https://depot.galaxyproject.org/singularity/bcftools%3A1.19--h8b25389_1 -C -
echo $(date) - End of download.

echo $(date) - Set up sif execution permission..
chmod a+rx ${COLORS_WORKFLOW_SINGULARITY}
chmod a+rx ${COLORS_WORKFLOW_SINGULARITY}/*.sif
echo $(date) - End of permission set up.

echo $(date) - Downloading ColorsDB SV dataset to resources subfolder..
curl -o ${COLORS_WORKFLOW_RESOURCES}/CoLoRSdb.GRCh38.v1.2.0.pbsv.jasmine.vcf.gz https://zenodo.org/records/14814308/files/CoLoRSdb.GRCh38.v1.2.0.pbsv.jasmine.vcf.gz

echo $(date) - Setting missing IDs in ColorsDB SV vcf..
${COLORS_WORKFLOW_SINGULARITY}/bcftools_1.19.sif bcftools annotate --set-id +'colors\_%CHROM\_%POS\_%INFO/SVTYPE\_%INFO/SVLEN' \
${COLORS_WORKFLOW_RESOURCES}/CoLoRSdb.GRCh38.v1.2.0.pbsv.jasmine.vcf.gz > ${COLORS_WORKFLOW_RESOURCES}/CoLoRSdb.GRCh38.v1.2.0.pbsv.jasmine.setid.vcf
echo $(date) - End of setting missing IDs.

echo $(date) - Downloading hg38 ref to resources subfolder...
FTPDIR=ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids
curl ${FTPDIR}/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz | gunzip > ${COLORS_WORKFLOW_RESOURCES}/GRCh38_no_alt_analysis_set.fasta
curl ${FTPDIR}/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.fai > ${COLORS_WORKFLOW_RESOURCES}/GRCh38_no_alt_analysis_set.fasta.fai
echo $(date) - End of download.

