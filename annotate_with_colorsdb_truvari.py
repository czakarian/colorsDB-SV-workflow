#!/usr/bin/env python

"""This script takes the output vcfs from truvari bench between a sample vcf and the colorsDB pbsv VCF and appends the colorsDB annotations to
the appropriate variant records that had a match in the merge using MatchIDs. It will add empty annotations for variants without a match in colorsDB."""

#1. parse tp-base (colors version of matches) to get MatchID per record as key and colors AC/AF info as value
#2 parse tp-comp, identify MatchID in colors dict and append to INFO field + header should be written here as well
#3 parse fp, append empty colors INFO fields


import argparse
import gzip

def get_args():
    parser = argparse.ArgumentParser(description="Append INFO tags from one vcf to another post-truvari merge.")
    parser.add_argument("-i", "--indir", help="Directory path of truvari bench output.", required=True)
    parser.add_argument("-o", "--output_vcf", help="Path to updated output vcf.", required=True)
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

colorsdb_variant_dict = {}
colorsdb_header_lines = []
## there is also END (inc in header but not pulled per record)
colors_info_fields_to_keep= ['SVTYPE', 'SVLEN', 'AC', 'AN', 'NS', 'AF', 'AC_Het', 'AC_Hom', 'AC_Hemi', 'HWE', 'ExcHet', 'nhomalt']

with gzip.open(tp_base_file, 'rt') as fr:
    for line in fr:
        ## pull header lines for colors INFO fields to add to final vcf
        if line.startswith("##INFO"):
            line = line.strip()
            line = line.replace('ID=', 'ID=COLORS_', 1)
            colorsdb_header_lines.append(line)

        ## store MatchID (key) and colors INFO fields (value)
        elif not line.startswith("#"):
            fields = line.strip().split('\t')
            info_dict = string_to_dict(input_string=fields[7], item_delim=";", key_value_delim="=")
            matchid = info_dict['MatchId']
            info_list = ['COLORS_' + key + '=' + info_dict[key] for key in colors_info_fields_to_keep]
            info_string = ";".join(info_list)
            colorsdb_variant_dict[matchid] = info_string

## keep only colors relevant header lines (truvari header lines will already be present)
colorsdb_header_lines = colorsdb_header_lines[0:13]

with gzip.open(tp_comp_file, 'rt') as fr:
    for line in fr:
        info_field_dict = {} 

        ## copy over header lines
        if line.startswith("##"):
            fw.write(line)
        
        ## append colors header lines followed by column name line
        elif line.startswith("#CHROM"):
            fw.write('\n'.join(colorsdb_header_lines))
            fw.write('\n' + line)
        
        ## parse variant rows
        else:
            fields = line.strip().split('\t')
            info_fields = fields[7].split(';')
            info_dict = string_to_dict(input_string=fields[7], item_delim=";", key_value_delim="=")
            matchid = info_dict['MatchId']
            colorsdb_info_string = colorsdb_variant_dict[matchid]
            fields[7] = ';'.join(info_fields) + ";" + colorsdb_info_string
            updated_row = '\t'.join(fields)
            fw.write(updated_row + '\n')

with gzip.open(fp_file, 'rt') as fr:
    for line in fr:
        info_field_dict = {} 

        if not line.startswith("#"):
            fields = line.strip().split('\t')
            no_match_string="COLORS_AC=0;COLORS_AN=0;COLORS_NS=0;COLORS_AF=0;COLORS_AC_Het=0;COLORS_AC_Hom=0;COLORS_AC_Hemi=0;COLORS_HWE=0;COLORS_ExcHet=0;COLORS_nhomalt=0"
            fields[7] = fields[7] + ";" + no_match_string
            updated_row = '\t'.join(fields)
            fw.write(updated_row + '\n')
