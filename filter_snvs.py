#!/usr/bin/env python

"""Filter a SNV vcf file according to whether variants are present in another vcf."""

#/net/nwgc/vol1/mendelian_projects/mendelian_analysis/references/ColorsDB-v1.2.0/CoLoRSdb.GRCh38.v1.2.0.deepvariant.glnexus.AFgt005.vcf.gz

import argparse
import gzip

def get_args():
    parser = argparse.ArgumentParser(description="Append INFO tags from one vcf to another post-truvari merge.")
    parser.add_argument("-i", "--input_vcf", help="File path of vcf to filter.", required=True)
    parser.add_argument("-o", "--output_vcf", help="File path to filtered vcf.gz.", required=True)
    parser.add_argument("-c", "--colors", help="File path to colors SNV vcf (AF>0.05) to use for filtering or other vcf.", required=True)
    return parser.parse_args()
args = get_args()

colorsdb_variants = set()

kept_variants = 0
filtered_variants = 0

with gzip.open(args.colors, 'rt') as fr:
    for line in fr:
        if not line.startswith("#"):
            fields = line.strip().split('\t')
            chrom = fields[0]
            pos = fields[1]
            ref = fields[3]
            alt = fields[4]
            match_string = chrom + "_" + pos + "_" + ref + "_" + alt
            colorsdb_variants.add(match_string)


with gzip.open(args.input_vcf, 'rt') as fr, gzip.open(args.output_vcf, 'wt') as fw:
    for line in fr:
        ## copy over header lines
        if line.startswith("#"):
            fw.write(line)

        ## parse variant rows
        else:
            fields = line.strip().split('\t')
            chrom = fields[0]
            pos = fields[1]
            ref = fields[3]
            alt = fields[4]
            match_string = chrom + "_" + pos + "_" + ref + "_" + alt
            if match_string not in colorsdb_variants:
                fw.write(line)
                kept_variants += 1
            else:
                filtered_variants +=1


print("Kept variants: ", kept_variants)
print("Filtered variants: ", filtered_variants)