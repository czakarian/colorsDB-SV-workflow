#!/usr/bin/env python

"""This script takes the output vcfs from truvari bench between a sample vcf and either the 1000g ONT merged VCF or the Colors SV merged VCF and appends the AF annotations to
the appropriate variant records that had a match in the merge using MatchIDs. It will add empty annotations for variants without a match."""

#1 parse tp-base to get MatchID per record as key and AC/AF/etc annotations as value
#2 parse tp-comp, identify MatchID in #1 dict and append to INFO field + header should be written here as well
#3 parse fp, append empty INFO fields

import argparse
import gzip

def get_args():
    parser = argparse.ArgumentParser(description="Append INFO tags from one vcf to another post-truvari merge.")
    parser.add_argument("-i", "--indir", help="Directory path of truvari bench output.", required=True)
    parser.add_argument("-o", "--output_vcf", help="Path to updated output vcf.", required=True)
    parser.add_argument("-r", "--reference_db", help="Specify name of reference SV set: COLORS or UW1KG", required=True)
    return parser.parse_args()
args = get_args()

def string_to_dict(input_string, item_delim, key_value_delim):
    """
    Converts a string with 2 sets of delimiters to a dictionary.

    Args:
        input_string (str): The string to convert.
        item_delimiter (str): The delimiter separating key-value pairs.
        key_value_delimiter (str): The delimiter separating keys and values.

    Returns:
        dict: A dictionary created from the string.
    """
    result_dict = {}
    items = input_string.split(item_delim)
    for item in items:
        if len(item.split(key_value_delim, 1)) == 2: 
            key, value = item.split(key_value_delim, 1)
            result_dict[key] = value
        ## if item doesn't have '=value' like 'PRECISE/IMPRECISE' fields set empty
        else:
            result_dict[item] = ''
    return result_dict

## add / to indir if not there
if args.indir[-1] != '/':
    args.indir += '/'

tp_base_file=args.indir + "tp-base.vcf.gz"
tp_comp_file=args.indir + "tp-comp.vcf.gz"
fn_file=args.indir + "fn.vcf.gz"
fp_file=args.indir + "fp.vcf.gz"

fw = open(args.output_vcf, 'wt')

variant_dict = {}
header_lines = []

## there is also END (inc in header but not pulled per record)
if args.reference_db == 'COLORS':
    info_fields_to_keep= ['SVTYPE', 'SVLEN', 'AC', 'AN', 'NS', 'AF', 'AC_Het', 'AC_Hom', 'AC_Hemi', 'HWE', 'ExcHet', 'nhomalt']
elif args.reference_db == 'UW1KG':
    info_fields_to_keep= ['SVTYPE', 'SVLEN', 'Allele_Freq_ALL', 'Pop_Count_ALL', 'Pop_Freq_ALL', 'OMIM', 'Exonic', 'Centromeric', 'Pericentromeric', 'Telomeric', 'STR', 'VNTR', 'Segdup', 'Repeat', 'Gap', 'HiConf']
else:
    exit("Value given to argument --reference_db was invalid. Should be either COLORS or UW1KG")

with gzip.open(tp_base_file, 'rt') as fr:

    if args.reference_db == 'COLORS':
        prepend_names_with = 'COLORS_'
    elif args.reference_db == 'UW1KG':
        prepend_names_with = 'UW1KG_'

    for line in fr:
        ## pull header lines for INFO fields to add to final vcf
        if line.startswith("##INFO"):
            line = line.strip()
            line = line.replace('ID=', 'ID=' + prepend_names_with, 1)
            header_lines.append(line)

        ## store MatchID (key) and INFO fields (value)
        elif not line.startswith("#"):
            fields = line.strip().split('\t')
            info_dict = string_to_dict(input_string=fields[7], item_delim=";", key_value_delim="=")
            matchid = info_dict['MatchId']
            info_list = [prepend_names_with + key + '=' + info_dict[key] for key in info_fields_to_keep]
            info_string = ";".join(info_list)
            variant_dict[matchid] = info_string

## keep only relevant header lines (truvari header lines will already be present)
header_lines = header_lines[0:-10]

with gzip.open(tp_comp_file, 'rt') as fr:
    for line in fr:
        info_field_dict = {} 

        ## copy over header lines
        if line.startswith("##"):
            fw.write(line)
        
        ## append header lines followed by column name line
        elif line.startswith("#CHROM"):
            fw.write('\n'.join(header_lines))
            fw.write('\n' + line)
        
        ## parse variant rows
        else:
            fields = line.strip().split('\t')
            info_fields = fields[7].split(';')
            info_dict = string_to_dict(input_string=fields[7], item_delim=";", key_value_delim="=")
            matchid = info_dict['MatchId']
            info_string = variant_dict[matchid]
            fields[7] = ';'.join(info_fields) + ";" + info_string
            updated_row = '\t'.join(fields)
            fw.write(updated_row + '\n')

if args.reference_db == 'COLORS':
    no_match_string="COLORS_AC=0;COLORS_AN=0;COLORS_NS=0;COLORS_AF=0;COLORS_AC_Het=0;COLORS_AC_Hom=0;COLORS_AC_Hemi=0;COLORS_HWE=0;COLORS_ExcHet=0;COLORS_nhomalt=0"
elif args.reference_db == 'UW1KG':
    no_match_string="UW1KG_Allele_Freq_ALL=0;UW1KG_Pop_Count_ALL=0;UW1KG_Pop_Freq_ALL=0"

with gzip.open(fp_file, 'rt') as fr:
    for line in fr:
        info_field_dict = {} 

        if not line.startswith("#"):
            fields = line.strip().split('\t')
            fields[7] = fields[7] + ";" + no_match_string
            updated_row = '\t'.join(fields)
            fw.write(updated_row + '\n')
