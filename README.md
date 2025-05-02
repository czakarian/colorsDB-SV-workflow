# SV filtration and population AF annotation

## Overview

The purpose of this command line workflow is to assist in SV filtration by annotating SVs based on population AF frequencies. The workflow uses truvari to perform SV merging and annotates input SVs using the colorsDB SV dataset and the 1000G ONT 450-sample SV dataset. Both single sample vcfs and multisample vcfs can be processed.

### Steps involved

1. Preprocess input vcf (FILTER=PASS, chr1-22,X,Y,M)
2. Run Truvari merge using the input vcf and the colorsDB dataset and then separately again using the input vcf and the 1000G ONT dataset
3. Append population dataset annotations from colorsDB and 1000G as new INFO fields in input VCF (INFO/COLORS_AF, INFO/COLORS_AC, etc)
4. Run similar iteration of steps 2-3 for oversized SVs (>100k) (helps speed up initial truvari merge to process on their own)

## Setup 
```
git clone https://github.com/czakarian/colorsDB-SV-workflow
chmod +x colorsDB-SV-workflow/*
cd colorsDB-SV-workflow/
./setup.sh
```

## Example run
```
Usage: run_colors_workflow.sh -i <input_vcf> -o <output_dir> [-m <min_sv_length>]

Required arguments:
  -i <input_vcf>         Input VCF (should be .gz and have .tbi index).
  -o <output_dir>        Output directory.

Optional arguments:
  -m <min_sv_length>    Filter out SVs smaller than set threshold. (default: 15).
```

`./run_colors_workflow.sh -i input.vcf -o example_dir`

## Added INFO fields

The final vcf will generated in the given output directory and named as `{SAMPLE}.colorAnno.1000gAnno.final.vcf.gz`. Intermediate files will be stored in a directory named `debug`.

Annotations will be added as new INFO fields -- those from the colorsDB dataset will be prepended with `COLORS_` and those from the 1000G ONT dataset will be prepended with `UW1KG_`. SVs that were not detected in either population dataset will be annotated with empty INFO fields (ex. COLORS_AF=0, COLORS_AC=0, UW1KG_Pop_Count_ALL=0, etc).




 