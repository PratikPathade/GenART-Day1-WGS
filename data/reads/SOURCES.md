# Reads: sources and what was changed

## DNA: `dna_A`, `dna_B`, `dna_C` - real reads of a Holstein calf and its two parents

| Sample | Role | Animal (ENA sample alias) | ENA run | Whole-genome depth | Read pairs in the kit | File size (R1 + R2) |
|---|---|---|---|---|---|---|
| `dna_A` | calf | Damona-GIGA-ULiège-18 | ERR11839901 | 6.1x | 21,246 | 1.40 + 1.38 MB |
| `dna_B` | parent | Damona-GIGA-ULiège-14 | ERR11839564 | 6.2x | 20,006 | 1.34 + 1.30 MB |
| `dna_C` | parent | Damona-GIGA-ULiège-17 | ERR11839588 | 5.8x | 19,522 | 1.25 + 1.21 MB |

**Source.** European Nucleotide Archive, project PRJEB53518 "IVF impacts rate of de novo structural variants" (GIGA, University of Liège). Illumina HiSeq 2000, paired-end 2 x 101 bp, nominal insert size about 800 bp (the archive's metadata; measured from the alignments it is about 550 bp, see the BWA output). Public data. The three animals are among the 132 Holstein of the VCF of Session 3b (`data/session3/damona132_chr14_0-10Mb.vcf.gz`, same sample names), so what you call from the reads can be compared with their published genotypes.

**Why these three.** In the published genotypes (41,151 SNPs) the calf follows Mendel's rules with the other two as parents: 0 impossible genotypes; with any other assignment of the three roles there are thousands. They were also the cheapest family in the 132 animals with about 6x depth and one sequencing run each (33 GB of raw FASTQ to read once).

**What was done to the reads** (instructor script `scripts/trim_real_reads.sh`, which is not in the participants' kit):

1. Each animal's two raw FASTQ files (about 11 GB) were streamed through BWA-MEM against a **repeat-masked** copy of the three windows of `data/ref/mini.fa` (Ensembl soft-masking, repeats turned into N). Without the mask, reads from repeat copies elsewhere in the genome pile up on the few copies in the windows: in a test, 30 % of all reads aligned and the depth was hundreds of times the true one.
2. Every read pair with at least one mate aligned at MAPQ >= 20 was kept: **both mates, exactly as the sequencer wrote them** (sequence, base qualities, orientation). The partner of an aligned read is kept even if it does not align itself.
3. Nothing else was changed: no trimming, no error correction, no subsampling. (The read names keep the run accession and the read number.)

**What this means for the data** (say it openly in class):

* About half of each window is repeat sequence (ALB 54 %, DGAT1 31 %, UMOD 68 %). Reads inside repeats were not kept unless their partner lies in unique sequence, so repeats look under-covered. The mean depth in the windows is therefore about 3-4x (about 5-6x in the unique parts), not the 6x of the whole genome.
* Reads that cannot be aligned to unique sequence (adapter read-through, very poor quality) are missing, so the files look a little cleaner than the original ones.
* Three animals at this depth are a small data set: variants that no read shows cannot be called, and a heterozygous site with only one or two alternative reads is often called homozygous. This is what low-coverage sequencing looks like.

**Please cite** the ENA project above and Oget-Ebrad C, Kadri NK, Moreira GCM, Karim L, Coppieters W, Georges M, Druet T (2022) Benchmarking phasing software with a whole-genome sequenced cattle pedigree. BMC Genomics 23:130 (how the pedigree was sequenced).

## RNA and bisulfite reads: `rna_*`, `bs_*` - simulated

Made with `scripts/make_reads.py` from the transcripts of the same three windows (fixed random seed). They carry problems planted on purpose (adapter read-through in `rna_liver2`, a contaminant in `rna_kidney2`, incomplete conversion in `bs_2`); the answers are in `data/teacher_only/`, which is removed before the kit is handed out.
