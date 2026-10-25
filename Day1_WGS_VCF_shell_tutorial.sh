#!/usr/bin/env bash
# GenART Day 1 - WGS: from reads (FASTQ) to a checked VCF, all in shell commands.
#
#   bash Day1_WGS_VCF_shell_tutorial.sh
#
# Plain shell: every command is printed in green with a "$" and then run; all output is shown. Explanations are in cyan.
# Runs on Linux (Colab terminal, or in a Colab cell:  !bash Day1_WGS_VCF_shell_tutorial.sh ). Needs internet for the first run.
# Everything is made in ./Day1_WGS (change with  WORK=/some/folder ). The tools are installed to ~/genart-lab (change with LAB=...).
# If a data/ folder sits next to this script (the cloned repository), it is used; otherwise the repository is cloned from GitHub.

set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${WORK:-$PWD/Day1_WGS}"
LAB="${LAB:-$HOME/genart-lab}"
mkdir -p "$WORK" "$LAB/bin"
cd "$WORK"
export PATH="$LAB/env/bin:$LAB/bin:$PATH"
export MAMBA_ROOT_PREFIX="$LAB/mamba"
exec 2>&1
C=$'\033[36m'; B=$'\033[1m'; N=$'\033[0m'
PS4=$'\n\033[1;32m$ \033[0m'
set -x

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
GenART Day 1 - WGS: from reads (FASTQ) to a checked VCF, all in shell commands

Every cell below is plain shell commands (no scripts hidden behind them). Each command is printed in green with a $ in front,
and then its complete output follows, live, in the same cell. Nothing is hidden.

How to run: Connect (top right), then run the cells from top to bottom with the play button (or *Runtime > Run all*).
Setup takes about 3-4 minutes, the analysis itself about 1 minute.

The data: REAL reads of a Holstein calf (dna_A) and its two parents (dna_B, dna_C) from the European Nucleotide Archive (PRJEB53518).
The original files are 11 GB each; here only the reads from three windows of the cattle genome (around the genes ALB, DGAT1, UMOD) were kept
(about 3 MB per animal), so every step takes seconds.

| Part | Steps |
|---|---|
| 0 Setup | get the data, install the tools |
| A Look at the files | 1 FASTQ (reads) - 2 FASTA (reference) - 3 VCF (what we want to make) |
| B Reads to VCF | 4 FastQC - 5 fastp trim - 6 FastQC again - 7 BWA index - 8 BWA-MEM align - 9 call variants - 10 filter - 11 read your VCF - 12 view in the reads - 13 is it good? - 14 what we made |
EOF
printf '%s\n' "$N"; set -x

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
0. Setup
0a. Settings (this one is Python: it only sets the working folder and makes the shell cells print every command).
EOF
printf '%s\n' "$N"; set -x

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
0b. Get the data. The reads, the reference and the published VCF are in the GitHub repository of this tutorial. We use the data folder next to this script, or clone the repository.
EOF
printf '%s\n' "$N"; set -x

if [ -d "$HERE/data" ]; then
  cp -r "$HERE/data" data
else
  git clone --depth 1 https://github.com/pratikpathade/GenART-Day1-WGS.git repo
  cp -r repo/data data
fi
ls -lh data/reads data/ref data/session3

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
0c. Install the tools (2-3 minutes, once per session). We use *micromamba* (a fast installer) to get FastQC, MultiQC, fastp, BWA, samtools and bcftools
with the same versions we tested. The long output is the download and install.
EOF
printf '%s\n' "$N"; set -x

[ -x "$LAB/bin/micromamba" ] || {
  curl -fsSL -o "$LAB/bin/micromamba" https://github.com/mamba-org/micromamba-releases/releases/download/2.9.0-0/micromamba-linux-64
  chmod +x "$LAB/bin/micromamba"
}
micromamba --version

[ -x "$LAB/env/bin/bcftools" ] || micromamba create -y -p $LAB/env -c conda-forge -c bioconda python=3.11 fastqc=0.13.0 multiqc=1.35 fastp=1.4.0 bwa=0.7.19 samtools=1.24 bcftools=1.24

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
0d. Check the tools - a version number for each means they are ready.
EOF
printf '%s\n' "$N"; set -x

fastqc --version
multiqc --version
fastp --version
bwa 2>&1 | grep Version
samtools --version | head -n 1
bcftools --version | head -n 1

mkdir -p results/wgs/qc_raw results/wgs/trim results/wgs/qc_clean results/wgs/index results/wgs/dna
ls results/wgs

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
PART A - Look at the files

Step 1 of 14: FASTQ - the raw reads
Every read is 4 lines:
* line 1 @name - read name
* line 2 - the bases (A C G T; N = the sequencer could not tell)
* line 3 + - separator
* line 4 - one quality character per base. Phred score = ASCII code - 33; Q30 = 1 error in 1,000 bases

Look at the last base of the two reads below: both end with an N. Remember it - FastQC will find it.
EOF
printf '%s\n' "$N"; set -x

zcat data/reads/dna_A_R1.fastq.gz | head -n 8

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Paired-end sequencing reads both ends of every DNA fragment. R2 has the same read names as R1 (ending in 2:N:0:1 = second read of the pair).
EOF
printf '%s\n' "$N"; set -x

zcat data/reads/dna_A_R2.fastq.gz | head -n 1
echo $(( $(zcat data/reads/dna_A_R1.fastq.gz | wc -l) / 4 )) read pairs in dna_A
zcat data/reads/dna_A_R1.fastq.gz | awk 'NR%4==2 {print length($0)}' | sort | uniq -c

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
The quality line of one read, turned into numbers (high at the start, lower at the end - normal for Illumina):
EOF
printf '%s\n' "$N"; set -x

zcat data/reads/dna_A_R1.fastq.gz | sed -n 4p | python -c "import sys; q=[ord(c)-33 for c in sys.stdin.readline().strip()]; print('first 12:', *q[:12]); print('last  12:', *q[-12:]); print('length', len(q), 'mean quality', round(sum(q)/len(q),1))"

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Step 2 of 14: FASTA - the reference genome
FASTA = names and sequences. A line starting with > is a name; the lines below are its bases. Our reference has 3 contigs: windows of about 400 kb cut
from the real cattle genome (ARS-UCD2.0) around three genes. regions.tsv says where they really are (ALB = chr 6, DGAT1 = chr 14, UMOD = chr 25).
EOF
printf '%s\n' "$N"; set -x

head -n 3 data/ref/mini.fa
grep '>' data/ref/mini.fa
column -t data/ref/regions.tsv
cat data/reads/animals.tsv

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Step 3 of 14: VCF - the file we want to make (here a published one)
A VCF is a table of differences from the reference: one line per variant.
* lines starting ## = header (what the fields mean); the #CHROM line = column names
* columns: CHROM POS ID REF ALT QUAL FILTER INFO FORMAT, then one column per animal
* REF = base in the reference, ALT = the other base seen in the animals
* genotype 0/0 = like the reference on both chromosomes, 0/1 = heterozygous, 1/1 = the other base on both

This file has 132 Holstein (our calf and its parents are among them) and only genotypes (GT).
EOF
printf '%s\n' "$N"; set -x

bcftools head data/session3/damona132_chr14_0-10Mb.vcf.gz | grep -v '^##contig' | cut -c1-100
bcftools view -H data/session3/damona132_chr14_0-10Mb.vcf.gz | head -n 3 | cut -f1-12
bcftools view -H data/session3/damona132_chr14_0-10Mb.vcf.gz | head -n 1 | tr '\t' '\n' | head -n 12 | nl

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
PART B - From the reads to a checked VCF

Step 4 of 14: FastQC - check the raw reads
FastQC reads a FASTQ file, runs many tests and writes a report. -t 2 = two files at the same time, --extract = unpack the report so we can read it here.
EOF
printf '%s\n' "$N"; set -x

fastqc -t 2 --extract --outdir results/wgs/qc_raw data/reads/dna_A_R1.fastq.gz data/reads/dna_A_R2.fastq.gz

fastqc -t 2 --extract --outdir results/wgs/qc_raw data/reads/dna_B_R1.fastq.gz data/reads/dna_B_R2.fastq.gz

fastqc -t 2 --extract --outdir results/wgs/qc_raw data/reads/dna_C_R1.fastq.gz data/reads/dna_C_R2.fastq.gz

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
MultiQC puts the reports of all six files on one page (results/wgs/qc_raw/multiqc_report.html).
EOF
printf '%s\n' "$N"; set -x

multiqc -f --outdir results/wgs/qc_raw results/wgs/qc_raw

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
One line per test: PASS / WARN / FAIL. Three FAILs - is the data bad? Look at the one that matters:
EOF
printf '%s\n' "$N"; set -x

cat results/wgs/qc_raw/dna_A_R1_fastqc/summary.txt
sed -n '/>>Per base N content/,/>>END_MODULE/p' results/wgs/qc_raw/dna_A_R1_fastqc/fastqc_data.txt | tail -n 6

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Per base N content: in the last two positions (100-101) about 22 % of the reads have an N - the sequencer could not call its last cycle.
A real problem of this run; we cut it away in the next step. The other two FAILs (base content, GC content) are common in real data and here also an
effect of the three small windows (FastQC compares with a whole genome). They do not stop us from calling variants.
EOF
printf '%s\n' "$N"; set -x

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Step 5 of 14: fastp - trim the reads
Trimming removes what would disturb the alignment: adapters, bad read ends, bad or too short reads.
* --detect_adapter_for_pe find the adapter sequence by itself (paired-end)
* -q 20 a base with Phred quality below 20 is "bad"; -u 30 drop a read if more than 30 % of its bases are bad; -l 30 drop a read shorter than 30 bases
* --cut_tail ... cut the bad end: a window of 4 bases slides in from the 3' end while its mean quality is below 20
* -j / -h write a JSON and an HTML report
EOF
printf '%s\n' "$N"; set -x

fastp -i data/reads/dna_A_R1.fastq.gz -I data/reads/dna_A_R2.fastq.gz -o results/wgs/trim/dna_A_R1.fastq.gz -O results/wgs/trim/dna_A_R2.fastq.gz --detect_adapter_for_pe -q 20 -u 30 -l 30 --cut_tail --cut_tail_window_size 4 --cut_tail_mean_quality 20 -j results/wgs/trim/dna_A.json -h results/wgs/trim/dna_A.html -R dna_A

fastp -i data/reads/dna_B_R1.fastq.gz -I data/reads/dna_B_R2.fastq.gz -o results/wgs/trim/dna_B_R1.fastq.gz -O results/wgs/trim/dna_B_R2.fastq.gz --detect_adapter_for_pe -q 20 -u 30 -l 30 --cut_tail --cut_tail_window_size 4 --cut_tail_mean_quality 20 -j results/wgs/trim/dna_B.json -h results/wgs/trim/dna_B.html -R dna_B

fastp -i data/reads/dna_C_R1.fastq.gz -I data/reads/dna_C_R2.fastq.gz -o results/wgs/trim/dna_C_R1.fastq.gz -O results/wgs/trim/dna_C_R2.fastq.gz --detect_adapter_for_pe -q 20 -u 30 -l 30 --cut_tail --cut_tail_window_size 4 --cut_tail_mean_quality 20 -j results/wgs/trim/dna_C.json -h results/wgs/trim/dna_C.html -R dna_C

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
One read that was cut: the last 60 bases and their qualities, raw (first two lines) and trimmed (last two lines).
EOF
printf '%s\n' "$N"; set -x

name=$(zcat results/wgs/trim/dna_A_R1.fastq.gz | awk 'NR%4==1 {h=substr($1,2)} NR%4==2 && length($0)<=90 {print h; exit}')
echo "read: $name"
zcat data/reads/dna_A_R1.fastq.gz | grep -A3 -m1 -F "@$name " | sed -n '2p;4p' | cut -c41-
zcat results/wgs/trim/dna_A_R1.fastq.gz | grep -A3 -m1 -F "@$name " | sed -n '2p;4p' | cut -c41-

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
The trimmed read is shorter: its poor tail is gone. A trimmed FASTQ is still just a FASTQ.
EOF
printf '%s\n' "$N"; set -x

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Step 6 of 14: FastQC - check again after trimming
EOF
printf '%s\n' "$N"; set -x

fastqc -t 2 --extract --outdir results/wgs/qc_clean results/wgs/trim/dna_A_R1.fastq.gz results/wgs/trim/dna_A_R2.fastq.gz
fastqc -t 2 --extract --outdir results/wgs/qc_clean results/wgs/trim/dna_B_R1.fastq.gz results/wgs/trim/dna_B_R2.fastq.gz
fastqc -t 2 --extract --outdir results/wgs/qc_clean results/wgs/trim/dna_C_R1.fastq.gz results/wgs/trim/dna_C_R2.fastq.gz

cat results/wgs/qc_clean/dna_A_R1_fastqc/summary.txt

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Per base N content is PASS now (the N bases are gone). Sequence Length Distribution is WARN: the reads no longer all have the same length - expected.
EOF
printf '%s\n' "$N"; set -x

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Step 7 of 14: BWA - index the reference
An aligner cannot search a plain FASTA quickly. bwa index builds a search index (5 files); samtools faidx builds a .fai file
(contig name, length, where it starts in the file) so tools can jump to any position.
EOF
printf '%s\n' "$N"; set -x

cp data/ref/mini.fa results/wgs/index/mini.fa
bwa index results/wgs/index/mini.fa
samtools faidx results/wgs/index/mini.fa
cat results/wgs/index/mini.fa.fai
ls -lh results/wgs/index

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Step 8 of 14: BWA-MEM - align the reads to the reference
bwa mem finds, for every read pair, the place on the reference where it comes from, and writes SAM text (one line per read).
samtools sort puts the lines in order along the genome and writes a compressed BAM file; samtools index makes the .bai index.
-t 4 = 4 threads; -R = the read group, which names the sample inside the BAM file. bwa prints its progress and how it estimated the distance between the two reads of a pair.
EOF
printf '%s\n' "$N"; set -x

bwa mem -t 4 -R '@RG\tID:dna_A\tSM:dna_A' results/wgs/index/mini.fa results/wgs/trim/dna_A_R1.fastq.gz results/wgs/trim/dna_A_R2.fastq.gz | samtools sort -o results/wgs/dna/dna_A.bam -
samtools index results/wgs/dna/dna_A.bam

bwa mem -t 4 -R '@RG\tID:dna_B\tSM:dna_B' results/wgs/index/mini.fa results/wgs/trim/dna_B_R1.fastq.gz results/wgs/trim/dna_B_R2.fastq.gz | samtools sort -o results/wgs/dna/dna_B.bam -
samtools index results/wgs/dna/dna_B.bam

bwa mem -t 4 -R '@RG\tID:dna_C\tSM:dna_C' results/wgs/index/mini.fa results/wgs/trim/dna_C_R1.fastq.gz results/wgs/trim/dna_C_R2.fastq.gz | samtools sort -o results/wgs/dna/dna_C.bam -
samtools index results/wgs/dna/dna_C.bam

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Inside a BAM file
The header: @HD = format and sort order, @SQ = contigs and lengths, @RG = read group, @PG = programs that made the file.
EOF
printf '%s\n' "$N"; set -x

samtools view -H results/wgs/dna/dna_A.bam | head -n 8

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Below the header: one line per read. One typical read - properly paired (-f 2), unique (-q 60), between positions 10,000 and 20,000 of ALB_region
(the .bai index lets samtools jump straight there). Its fields, one per line:

| # | field | # | field |
|---|---|---|---|
| 1 | QNAME read name | 7 | RNEXT contig of the mate |
| 2 | FLAG kind of alignment | 8 | PNEXT position of the mate |
| 3 | RNAME contig | 9 | TLEN length of the whole DNA fragment |
| 4 | POS leftmost base (from 1) | 10 | SEQ the bases |
| 5 | MAPQ 60 = unique, 0 = could be anywhere | 11 | QUAL the qualities |
| 6 | CIGAR 101M = 101 bases match, 5S96M = 5 clipped, 2I insertion, 3D deletion | 12+ | tags: NM mismatches, AS alignment score, RG read group |
EOF
printf '%s\n' "$N"; set -x

samtools view -f 2 -F 2304 -q 60 results/wgs/dna/dna_A.bam ALB_region:10000-20000 | head -n 1 | tr '\t' '\n' | nl
samtools view -f 2 -F 2304 -q 60 results/wgs/dna/dna_A.bam ALB_region:10000-20000 | head -n 1 | cut -f2 | xargs samtools flags

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
FLAG is a sum of yes/no bits: 1 = paired, 2 = properly paired, 16 = this read is reversed, 32 = its mate is reversed, 64 = first of the pair, 128 = second. samtools flags writes the number in words.
EOF
printf '%s\n' "$N"; set -x

samtools flagstat results/wgs/dna/dna_A.bam

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Almost all reads (99 %) aligned and about 97.5 % are *properly paired*: both reads aligned, facing each other, at a sensible distance. *singletons* = one read aligned and its mate did not.
EOF
printf '%s\n' "$N"; set -x

samtools coverage results/wgs/dna/dna_A.bam | cut -f1,4,6,7
samtools coverage results/wgs/dna/dna_B.bam | cut -f1,4,6,7
samtools coverage results/wgs/dna/dna_C.bam | cut -f1,4,6,7

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
numreads = reads on the contig, coverage = % of bases covered by at least one read, meandepth = reads per base. Depth is only about 3x here (about half of every window is repeat sequence, whose reads were left out). Low depth matters - remember it when we look at genotypes.
EOF
printf '%s\n' "$N"; set -x

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Step 9 of 14: bcftools - call the variants
At every position, compare what the reads show with the reference and decide which bases each animal carries.
* mpileup stacks the reads of all three animals over each position (a "pileup") and counts the bases. -q 20 / -Q 20 = ignore reads with mapping quality below 20 and bases with quality below 20. -a FORMAT/AD,FORMAT/DP = also write reads per base (AD) and depth (DP) for every animal
* call decides. -m = multi-allele model, -v = write only variable positions, -Oz = compressed VCF
EOF
printf '%s\n' "$N"; set -x

bcftools mpileup -f results/wgs/index/mini.fa -q 20 -Q 20 -a FORMAT/AD,FORMAT/DP -Ou results/wgs/dna/dna_A.bam results/wgs/dna/dna_B.bam results/wgs/dna/dna_C.bam | bcftools call -mv -Oz -o results/wgs/dna/calls.vcf.gz
bcftools index -f results/wgs/dna/calls.vcf.gz
bcftools view -H results/wgs/dna/calls.vcf.gz | wc -l

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
That last number is the count of variable positions found in the three animals - before any filtering.
EOF
printf '%s\n' "$N"; set -x

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Step 10 of 14: Filter the calls
Not every call is right. Keep a call only if
* QUAL >= 30 - the caller is at least 99.9 % sure the site really varies
* MIN(FMT/DP) >= 4 - every animal has at least 4 reads there (a sum over animals would let one deep animal hide two shallow ones)
EOF
printf '%s\n' "$N"; set -x

bcftools view -i 'QUAL>=30 && MIN(FMT/DP)>=4' -Oz -o results/wgs/dna/calls.filtered.vcf.gz results/wgs/dna/calls.vcf.gz
bcftools index -f results/wgs/dna/calls.filtered.vcf.gz
bcftools view -H results/wgs/dna/calls.filtered.vcf.gz | wc -l

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Step 11 of 14: Read your own VCF
The header remembers how the file was made (the ##bcftools...Command lines).
EOF
printf '%s\n' "$N"; set -x

bcftools head results/wgs/dna/calls.filtered.vcf.gz | grep -v '^##contig' | cut -c1-110

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Now a variant that is nice to look at: the calf is heterozygous, one parent has the new base and the other parent does not. We save its position in a file for the next steps.
EOF
printf '%s\n' "$N"; set -x

bcftools query -i 'TYPE="snp" && GT[0]="het" && ((GT[1]="het" && GT[2]="RR") || (GT[1]="RR" && GT[2]="het"))' -f '%CHROM\t%POS\n' results/wgs/dna/calls.filtered.vcf.gz | head -n 1 > results/wgs/dna/site.tsv
cat results/wgs/dna/site.tsv

read chrom pos < results/wgs/dna/site.tsv
bcftools view -H -r $chrom:$pos results/wgs/dna/calls.filtered.vcf.gz | tr '\t' '\n' | nl

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Fields 1-9: CHROM, POS, ID, REF, ALT, QUAL (confidence), FILTER, INFO (facts about the site), FORMAT. Fields 10, 11, 12 = the calf (dna_A), parent 1 (dna_B), parent 2 (dna_C).

FORMAT = GT:PL:DP:AD, so each animal column holds four values separated by colons:
* GT genotype (0/0 like the reference, 0/1 heterozygous, 1/1 new base on both chromosomes)
* PL how unlikely each genotype is (Phred scale; the 0 is the genotype the caller chose)
* DP depth = number of reads; AD reads per base: first the reference base, then the new one

The calf is 0/1 with AD about half and half; one parent is 0/0 with no new base; the other is 0/1.
EOF
printf '%s\n' "$N"; set -x

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Step 12 of 14: Look at the variant in the reads
samtools tview is a small genome browser for the terminal. Top: positions, then the reference, then the consensus of the reads (a letter like Y = C or T means the reads disagree).
Each row below is one read: . or , = same as the reference, a letter = a different base (upper case = forward read, lower case = reverse read).
Same position in the calf and both parents - which parent gave the calf the new base?
EOF
printf '%s\n' "$N"; set -x

read chrom pos < results/wgs/dna/site.tsv
echo "----- dna_A -----"
COLUMNS=100 samtools tview -d T -p $chrom:$((pos-12)) results/wgs/dna/dna_A.bam results/wgs/index/mini.fa | head -n 14

read chrom pos < results/wgs/dna/site.tsv
echo "----- dna_B -----"
COLUMNS=100 samtools tview -d T -p $chrom:$((pos-12)) results/wgs/dna/dna_B.bam results/wgs/index/mini.fa | head -n 14

read chrom pos < results/wgs/dna/site.tsv
echo "----- dna_C -----"
COLUMNS=100 samtools tview -d T -p $chrom:$((pos-12)) results/wgs/dna/dna_C.bam results/wgs/index/mini.fa | head -n 14

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Heterozygous = about half of the reads show the new base. A new base on one read only would be a sequencing error.
EOF
printf '%s\n' "$N"; set -x

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Step 13 of 14: Is the call set any good?
EOF
printf '%s\n' "$N"; set -x

bcftools stats -s - results/wgs/dna/calls.filtered.vcf.gz > results/wgs/dna/calls.stats.txt
grep '^SN' results/wgs/dna/calls.stats.txt | cut -f3-
grep '^TSTV' results/wgs/dna/calls.stats.txt | cut -f3-5

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Ts/Tv: transitions are A<->G and C<->T; transversions are all other changes. Real variants in cattle give a Ts/Tv of about 2 or more; random sequencing errors would give about 0.5.
A Ts/Tv of 2 or more says: these are mostly real variants.

*(A line [W::bcf_hdr_check_sanity] MQ should be declared as Type=Float may appear below. It is a harmless warning about a header detail of the VCF.)*

Per animal: sample, homozygous reference, homozygous new base, heterozygous, mean depth:
EOF
printf '%s\n' "$N"; set -x

grep '^PSC' results/wgs/dna/calls.stats.txt | cut -f3-6,10

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
The family check. A calf gets one allele from each parent, so some genotype combinations are IMPOSSIBLE (for example a calf 1/1 when one parent is 0/0).
Every impossible genotype is a mistake - found without any truth set. ngood = genotypes that follow Mendel's rules, nmerr = Mendelian errors.
EOF
printf '%s\n' "$N"; set -x

bcftools +mendelian2 results/wgs/dna/calls.filtered.vcf.gz -p dna_A,dna_B,dna_C | grep -E '^(ngood|nmerr)'

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
How strict should the filter be? The same checks for different filters (QUAL>=0 = no filter at all). Columns: calls kept, Ts/Tv, Mendelian errors of all checked genotypes.
EOF
printf '%s\n' "$N"; set -x

{ set +x; } 2>/dev/null     # no command echo inside this loop, so that the table stays readable
printf '%-34s %7s %7s   %s\n' "filter" "calls" "Ts/Tv" "Mendel errors"
for f in "QUAL>=0" "QUAL>=30" "QUAL>=30 && INFO/DP>=10" "QUAL>=30 && MIN(FMT/DP)>=4" "QUAL>=30 && MIN(FMT/DP)>=6"; do
  calls=$(bcftools view -H -i "$f" results/wgs/dna/calls.vcf.gz 2>/dev/null | wc -l)
  tstv=$(bcftools stats -i "$f" results/wgs/dna/calls.vcf.gz 2>/dev/null | grep '^TSTV' | cut -f5)
  mend=$(bcftools +mendelian2 results/wgs/dna/calls.vcf.gz -i "$f" -p dna_A,dna_B,dna_C 2>/dev/null | awk '/^ngood\t/ {g=$2} /^nmerr\t/ {e=$2} END {printf "%d of %d", e, g+e}')
  printf '%-34s %7s %7s   %s\n' "$f" "$calls" "$tstv" "$mend"
done

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
A total depth >= 10 (sum over animals) still leaves many errors because one deep animal can hide two shallow ones. At least 4 or 6 reads in every animal removes most errors - but also most calls: low depth costs. Stricter = cleaner but fewer variants; this is why real projects sequence 20-30x.
EOF
printf '%s\n' "$N"; set -x

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Step 14 of 14: What we made
EOF
printf '%s\n' "$N"; set -x

ls -lh results/wgs/trim results/wgs/dna | grep -v html

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
| file | what |
|---|---|
| .fastq.gz | reads (raw and trimmed) |
| _fastqc/ | the FastQC reports |
| .json / .html | the fastp reports |
| .bam / .bai | the reads aligned to the genome, and the BAM index |
| .vcf.gz / .csi | the variants (calls = all, calls.filtered = the ones we trust) and the VCF index |
| calls.stats.txt | the statistics of the VCF |

The whole pipeline: FASTQ --FastQC--> --fastp--> --FastQC--> --BWA-MEM--> BAM --bcftools--> VCF --filter--> --checks--> a VCF we can use.
EOF
printf '%s\n' "$N"; set -x
