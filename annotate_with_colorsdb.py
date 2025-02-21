#!/usr/bin/env python

"""This script takes the output vcf from a jasmine merge between a sample vcf and the colorsDB pbsv VCF and appends the colorsDB annotations to
the appropriate variant records that had a match in the merge. It will add empty annotations for variants without a match in colorsDB."""

import argparse

def get_args():
    parser = argparse.ArgumentParser(description="Append INFO tags from one vcf to another post-jasmine merge.")
    parser.add_argument("-m", "--merged_vcf", help="File path to jasmine merged vcf output between colorsdb vcf and sample vcf.", required=True)
    parser.add_argument("-c", "--colorsdb_vcf", help="File path to the colorsdb VCF used in jasmine merge.", required=True)
    parser.add_argument("-o", "--output_vcf", help="Path to updated output vcf.", required=True)
    return parser.parse_args()
args = get_args()


colorsdb_variant_dict = {}
colorsdb_header_lines = []
info_field_dict = {} 

with open(args.colorsdb_vcf, 'rt') as fr:
    for line in fr:
        if line.startswith("##INFO"):
            line = line.strip()
            line = line.replace('ID=', 'ID=COLORS_', 1)
            colorsdb_header_lines.append(line)
        elif not line.startswith("#"):
            fields = line.strip().split('\t')
            id_field = fields[2]
            info_fields = fields[7].split(";")
            colors_prepended = ["COLORS_" + x for x in info_fields]
            selected_info_fields = ";".join(colors_prepended)
            colorsdb_variant_dict[id_field] = selected_info_fields


with open(args.merged_vcf, 'rt') as fr, open(args.output_vcf, 'wt') as fw:
    for line in fr:
        info_field_dict = {} 
        if line.startswith("##"):
            fw.write(line)
        elif line.startswith("#CHROM"):
            fw.write('\n'.join(colorsdb_header_lines))
            fw.write('\n' + line)
        else:
            fields = line.strip().split('\t')
            info_fields = fields[7].split(";")
            for info_field in info_fields:
                if len(info_field.split('=')) == 2: 
                    info_key, info_value = info_field.split('=')
                    info_field_dict[info_key] = info_value
                else:
                    info_field_dict[info_field] = ''
            supp_vec = info_field_dict['SUPP_VEC']
            idlist = info_field_dict['IDLIST'].split(',')

            if supp_vec == '11':
                colorsdb_id = idlist[1]
                colorsdb_info_string = colorsdb_variant_dict[colorsdb_id]
                updated_info_field = ';'.join(info_fields) + ";" + colorsdb_info_string

                fields[7] = updated_info_field
                updated_row = '\t'.join(fields)
                fw.write(updated_row + '\n')

            elif supp_vec == '10':
                no_match_string="COLORS_AC=0;COLORS_AN=0;COLORS_NS=0;COLORS_AF=0;COLORS_AC_Het=0;COLORS_AC_Hom=0;COLORS_AC_Hemi=0;COLORS_HWE=0;COLORS_ExcHet=0;COLORS_nhomalt=0"
                updated_info_field = ';'.join(info_fields) + ";" + no_match_string

                fields[7] = updated_info_field
                updated_row = '\t'.join(fields)
                fw.write(updated_row + '\n')
