# GenART Day 1 - WGS: from reads to a checked VCF (shell commands)

Hands-on tutorial for the GenART workshop (TANUVAS, Chennai): real whole-genome reads of a Holstein calf and its two parents go through
FastQC, fastp, BWA-MEM and bcftools to a quality-checked VCF. Every step is a plain shell command; each command is printed and its full output is shown.

## Run it in Google Colab (nothing to install)

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/pratikpathade/GenART-Day1-WGS/blob/main/Day1_WGS_VCF_shell_tutorial.ipynb)

1. Click the badge, then **Connect** (top right).
2. Run the cells from top to bottom (play button, or *Runtime > Run all*). Setup takes about 3-4 minutes, the analysis about 1 minute.

## Run it as a script (Linux / Colab terminal)

```bash
git clone https://github.com/pratikpathade/GenART-Day1-WGS.git
cd GenART-Day1-WGS
bash Day1_WGS_VCF_shell_tutorial.sh
```

Everything is made in `./Day1_WGS`; the tools are installed to `~/genart-lab` (micromamba: FastQC, MultiQC, fastp, BWA, samtools, bcftools).

## Data (`data/`, about 9 MB)

| Files | What |
|---|---|
| `data/reads/dna_A, dna_B, dna_C` (R1/R2 FASTQ) | Real reads of a Holstein calf (A) and its parents (B, C), cut to three 400-kb windows (genes ALB, DGAT1, UMOD) so that every step takes seconds |
| `data/ref/mini.fa`, `regions.tsv` | The 3-contig reference (windows of cattle genome ARS-UCD2.0) and where they come from |
| `data/session3/damona132_chr14_0-10Mb.vcf.gz` | A published VCF of 132 Holstein (genotypes), used in step 3 to show what a VCF looks like |

Sources and what was changed: `data/reads/SOURCES.md`, `data/session3/SOURCES.md`.

**Please cite** the European Nucleotide Archive project PRJEB53518 and Oget-Ebrad C, Kadri NK, Moreira GCM, Karim L, Coppieters W, Georges M, Druet T (2022) Benchmarking phasing software with a whole-genome sequenced cattle pedigree. BMC Genomics 23:130.
