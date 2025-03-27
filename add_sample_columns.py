#!/usr/bin/env python

# Python script to add a blank SAMPLE column to a VCF file without one (also add appropriate header line)

import argparse

def get_args():
    parser = argparse.ArgumentParser(description="Add blank SAMPLE column if missing in VCF.")
    parser.add_argument("-i", "--input", help="Input file path.", required=True)
    parser.add_argument("-o", "--output", help="Output file path.", required=True)
    return parser.parse_args()
args = get_args()

with open(args.input, 'r') as infile, open(args.output, 'w') as outfile:
    for line in infile:
        if line.startswith("#CHROM"):
            # Add SAMPLE to the header
            outfile.write("##FORMAT=<ID=GT,Number=1,Type=String,Description=\"Genotype\">\n")
            line = line.strip() + "\tFORMAT\tSAMPLE\n"
        elif not line.startswith("#"):
            line = line.strip() + "\tGT\t./.\n"
        outfile.write(line)
