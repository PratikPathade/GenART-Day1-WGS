#!/usr/bin/env bash
# GenART Day 1 - WGS: from reads (FASTQ) to a checked VCF, all in shell commands.
#
#   bash Day1_WGS_VCF_shell_tutorial.sh
#
# Plain shell: every command is printed in green with a "$" and then run; all output is shown. Explanations are in cyan.
# Runs on Linux (Colab terminal, or in a Colab cell:  !bash Day1_WGS_VCF_shell_tutorial.sh ). Needs internet for the first run.
# Figures (matplotlib) are saved as PNG files in results/wgs/figures/
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

[ -x "$LAB/env/bin/bcftools" ] || micromamba create -y -p $LAB/env -c conda-forge -c bioconda python=3.11 numpy matplotlib-base fastqc=0.13.0 multiqc=1.35 fastp=1.4.0 bwa=0.7.19 samtools=1.24 bcftools=1.24
"$LAB/env/bin/python" -c 'import matplotlib' 2>/dev/null || micromamba install -y -p "$LAB/env" -c conda-forge numpy matplotlib-base

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

MPLBACKEND=Agg python - <<'PY'
import os
import numpy as np
import matplotlib.pyplot as plt
os.makedirs("results/wgs/figures", exist_ok=True)

def fastqc_module(path, name):
    """the rows of one FastQC module (FastQC writes them as a text table)"""
    rows, on = [], False
    for line in open(path):
        if line.startswith(">>" + name):
            on = True
        elif on and line.startswith(">>END_MODULE"):
            break
        elif on and not line.startswith("#"):
            rows.append(line.rstrip("\n").split("\t"))
    return rows

fig, ax = plt.subplots(1, 2, figsize=(11, 3.8))
for label, folder, col in [("raw reads", "qc_raw", "tab:red"), ("trimmed reads", "qc_clean", "tab:blue")]:
    path = f"results/wgs/{folder}/dna_A_R1_fastqc/fastqc_data.txt"
    q = fastqc_module(path, "Per base sequence quality")
    n = fastqc_module(path, "Per base N content")
    ax[0].plot([float(r[0].split("-")[0]) for r in q], [float(r[1]) for r in q], color=col, label=label)
    ax[1].plot([float(r[0].split("-")[0]) for r in n], [float(r[1]) for r in n], color=col, label=label)
ax[0].axhline(30, ls="--", c="grey", lw=1)
ax[0].text(2, 30.5, "Q30 = 1 error in 1,000 bases", fontsize=8, color="grey")
ax[0].set(title="Mean base quality along the read (dna_A, R1)", xlabel="position in read", ylabel="Phred quality")
ax[1].set(title="Share of N bases along the read", xlabel="position in read", ylabel="% of reads with N")
ax[0].legend(loc="lower left"); ax[1].legend()
plt.tight_layout()
plt.savefig("results/wgs/figures/A1_read_quality.png", dpi=120, bbox_inches="tight")
PY

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Figure: base quality and N bases, raw reads against trimmed reads (dna_A, R1).
Left: the quality falls towards the end of the read (normal for Illumina); after trimming the whole curve lies higher because the poor tails are gone.
Right: the raw reads have about 22 % N at the very last position, the trimmed reads none. This is the "Per base N content" problem that FastQC flagged, and the reason for trimming.
EOF
printf '%s\n' "$N"; set -x


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

for s in dna_A dna_B dna_C; do samtools depth -a results/wgs/dna/$s.bam | awk -v s=$s -v OFS='\t' '{b=int(($2-1)/5000); k=$1 "\t" b; sum[k]+=$3; n[k]++} END {for (k in sum) {split(k,a,"\t"); print s, a[1], a[2]*5000, sum[k]/n[k]}}'; done | sort -k1,1 -k2,2 -k3,3n > results/wgs/dna/depth_5kb.tsv
for s in dna_A dna_B dna_C; do samtools stats results/wgs/dna/$s.bam | grep '^IS' | cut -f2,3 | sed "s/^/$s\t/"; done > results/wgs/dna/insert_sizes.tsv
head -n 3 results/wgs/dna/depth_5kb.tsv
head -n 3 results/wgs/dna/insert_sizes.tsv

MPLBACKEND=Agg python - <<'PY'
import os
import numpy as np
import matplotlib.pyplot as plt
os.makedirs("results/wgs/figures", exist_ok=True)
import csv, collections
depth = collections.defaultdict(lambda: collections.defaultdict(list))
for s, contig, pos, d in csv.reader(open("results/wgs/dna/depth_5kb.tsv"), delimiter="\t"):
    depth[contig][s].append((int(pos) / 1000, float(d)))
colors = {"dna_A": "tab:red", "dna_B": "tab:blue", "dna_C": "tab:green"}
fig, ax = plt.subplots(2, 2, figsize=(11, 6.5))
for a, contig in zip(ax.flat, sorted(depth)):
    for s in colors:
        xs, ys = zip(*sorted(depth[contig][s]))
        a.plot(xs, ys, color=colors[s], lw=1, label=s)
    a.set(title=contig, xlabel="position on the contig (kb)", ylabel="mean depth per 5 kb")
ax[0, 0].legend()
a = ax[1, 1]
ins = collections.defaultdict(dict)
for s, size, n in csv.reader(open("results/wgs/dna/insert_sizes.tsv"), delimiter="\t"):
    ins[s][int(size)] = int(n)
for s in colors:
    tot = sum(ins[s].values())
    bins = np.arange(0, 1001, 10)                      # 10-base bins make the curve smooth
    counts = [sum(v for k, v in ins[s].items() if lo <= k < lo + 10) for lo in bins[:-1]]
    a.plot(bins[:-1] + 5, [100 * c / tot for c in counts], color=colors[s], lw=1.3, label=s)
a.set(title="Insert size (distance between the two reads of a pair)", xlabel="bases", ylabel="% of read pairs per 10 bases", xlim=(0, 1000))
plt.tight_layout()
plt.savefig("results/wgs/figures/B1_coverage_and_insert_size.png", dpi=120, bbox_inches="tight")
PY

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Figure: depth along the three reference windows and the insert size.
Depth is about 3-5x along the windows, with gaps where it falls to 0: repeat sequence, whose reads were left out when the data were cut. All three animals follow the same ups and downs, because depth depends on the genome (repeats, GC) more than on the animal.
Bottom right: the insert size (distance between the two reads of a pair) peaks at about 550-600 bases, as expected for this library.
EOF
printf '%s\n' "$N"; set -x


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

bcftools query -f '%CHROM\t%POS\t%QUAL\t%INFO/DP[\t%DP]\n' results/wgs/dna/calls.vcf.gz > results/wgs/dna/calls_table.tsv
head -n 3 results/wgs/dna/calls_table.tsv
wc -l results/wgs/dna/calls_table.tsv

MPLBACKEND=Agg python - <<'PY'
import os
import numpy as np
import matplotlib.pyplot as plt
os.makedirs("results/wgs/figures", exist_ok=True)
rows = [l.rstrip("\n").split("\t") for l in open("results/wgs/dna/calls_table.tsv")]
qual = np.array([float(r[2]) for r in rows])
mindp = np.array([min(float(x) if x != "." else 0 for x in r[4:7]) for r in rows])
keep = (qual >= 30) & (mindp >= 4)
fig, ax = plt.subplots(1, 3, figsize=(13, 3.8))
ax[0].hist(np.clip(qual, 0, 225), bins=45, color="tab:grey")
ax[0].axvline(30, color="tab:red", ls="--"); ax[0].set(title="Call quality (QUAL)", xlabel="QUAL (values above 225 shown at 225)", ylabel="variants")
ax[1].hist(np.clip(mindp, 0, 20), bins=np.arange(-0.5, 21.5, 1), color="tab:grey")
ax[1].axvline(3.5, color="tab:red", ls="--"); ax[1].set(title="Fewest reads in any animal (MIN DP)", xlabel="reads (values above 20 shown at 20)", ylabel="variants")
ax[2].scatter(np.clip(mindp, 0, 20) + np.random.default_rng(1).uniform(-0.3, 0.3, len(qual)), np.clip(qual, 0, 225), c=np.where(keep, "tab:green", "tab:red"), s=6, alpha=0.5)
ax[2].axvline(3.5, color="grey", ls="--", lw=1); ax[2].axhline(30, color="grey", ls="--", lw=1)
ax[2].set(title=f"Kept (green) {keep.sum()} of {len(keep)}", xlabel="MIN DP", ylabel="QUAL")
plt.tight_layout()
plt.savefig("results/wgs/figures/B2_call_quality_and_filter.png", dpi=120, bbox_inches="tight")
PY

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Figure: quality of the variant calls and what the filter keeps.
Left: many calls have a low QUAL; the pile at the right are the sure calls (QUAL above 225). Middle: for most variants at least one animal has only 0-3 reads: with three animals at about 3x we cannot trust those calls.
Right: every dot is a variant. Green = kept by the filter (QUAL >= 30 and at least 4 reads in every animal), red = removed. Both thresholds matter.
EOF
printf '%s\n' "$N"; set -x


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
: > results/wgs/dna/filters.tsv
printf '%-34s %7s %7s   %s\n' "filter" "calls" "Ts/Tv" "Mendel errors"
for f in "QUAL>=0" "QUAL>=30" "QUAL>=30 && INFO/DP>=10" "QUAL>=30 && MIN(FMT/DP)>=4" "QUAL>=30 && MIN(FMT/DP)>=6"; do
  calls=$(bcftools view -H -i "$f" results/wgs/dna/calls.vcf.gz 2>/dev/null | wc -l)
  tstv=$(bcftools stats -i "$f" results/wgs/dna/calls.vcf.gz 2>/dev/null | grep '^TSTV' | cut -f5)
  mend=$(bcftools +mendelian2 results/wgs/dna/calls.vcf.gz -i "$f" -p dna_A,dna_B,dna_C 2>/dev/null | awk '/^ngood\t/ {g=$2} /^nmerr\t/ {e=$2} END {printf "%d of %d", e, g+e}')
  printf '%-34s %7s %7s   %s\n' "$f" "$calls" "$tstv" "$mend"
  printf '%s\t%s\t%s\t%s\n' "$f" "$calls" "$tstv" "$mend" >> results/wgs/dna/filters.tsv
done

MPLBACKEND=Agg python - <<'PY'
import os
import numpy as np
import matplotlib.pyplot as plt
os.makedirs("results/wgs/figures", exist_ok=True)
rows = [l.rstrip("\n").split("\t") for l in open("results/wgs/dna/filters.tsv")]
names = [r[0].replace(" && ", "\n& ") for r in rows]
calls = [int(r[1]) for r in rows]
err = [100 * int(r[3].split()[0]) / int(r[3].split()[2]) for r in rows]
fig, ax = plt.subplots(figsize=(10, 4.2))
ax.bar(range(len(rows)), calls, color="tab:grey")
ax.set_xticks(range(len(rows))); ax.set_xticklabels(names, fontsize=8)
ax.set(ylabel="variants kept", title="Stricter filter: fewer variants, fewer Mendelian errors")
ax2 = ax.twinx()
ax2.plot(range(len(rows)), err, "o-", color="tab:red")
ax2.set_ylabel("Mendelian errors (% of checked genotypes)", color="tab:red")
plt.tight_layout()
plt.savefig("results/wgs/figures/B3_filter_tradeoff.png", dpi=120, bbox_inches="tight")
PY

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Figure: the price of a stricter filter.
Bars: variants kept. Red line: Mendelian errors in the calf-and-parents check. Each stricter filter removes more variants and more errors: from about 20 % wrong genotypes without a filter to about 3 % with at least 6 reads in every animal, but only 490 variants are left. Low depth costs.
EOF
printf '%s\n' "$N"; set -x


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

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
PART C - QA/QC of a complete VCF (132 Holstein, whole-genome sequence)

Part B made a VCF from three animals. Here we take a finished, complete VCF and do what you do with every VCF you receive: audit it before using it.
The file data/session3/damona132_chr14_0-10Mb.vcf.gz holds the genotypes of 132 Holstein (whole-genome sequence, chromosome 14, first 10 Mb, 41,151 SNPs); the calf and parents of Part B are among them.
Source: Druet T, Forneris NS (2026), Zenodo doi:10.5281/zenodo.23011638 (CC BY 4.0). The authors had already filtered and refined it, so this QC is an audit:
check what the authors say they did, and check what the file does not tell you.

| Step | Question |
|---|---|
| C1 | What is in the file? (header, animals, variants) |
| C2 | What kind of variants, and how many? (Ts/Tv) |
| C3 | Add QC tags to every variant (allele frequency, MAF, Hardy-Weinberg, missingness) |
| C4 | How complete is it? (missing genotypes) |
| C5 | Allele-frequency spectrum (MAF) |
| C6 | Hardy-Weinberg equilibrium |
| C7 | Which animals look odd? (heterozygosity, duplicates) |
| C8 | Is it on the right genome build? (REF alleles against the genome) |
| C9 | Filter for analysis |
| C10 | Everyday VCF commands (region, animals, genotypes, Mendel check, density) |
| C11 | Final checks (PASS / FAIL) |

Part C only needs the setup cells (0a-0d), not Parts A and B.
EOF
printf '%s\n' "$N"; set -x

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Start: a folder for the results of Part C.
EOF
printf '%s\n' "$N"; set -x

mkdir -p results/wgs/vcf132
ls -lh data/session3/damona132_chr14_0-10Mb.vcf.gz data/session3/damona132_chr14_0-10Mb.vcf.gz.tbi

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
C1: What is in the file?
A VCF has a header (## lines), one #CHROM line with the column names, then one line per variant with one column per animal.
QUAL and FILTER are . here because depth and quality were used up-stream and are not kept in this file; INFO holds AC (alternative alleles counted) and AN (alleles with a genotype).
Genotype GT: 0/0 two reference alleles, 0/1 heterozygous, 1/1 two alternative alleles, ./. missing. | instead of / means the genotype is phased.
EOF
printf '%s\n' "$N"; set -x

bcftools head data/session3/damona132_chr14_0-10Mb.vcf.gz | grep -v '^##contig' | cut -c1-110
bcftools view -H data/session3/damona132_chr14_0-10Mb.vcf.gz | head -n 3 | cut -f1-12
bcftools query -l data/session3/damona132_chr14_0-10Mb.vcf.gz | head -n 3
bcftools query -l data/session3/damona132_chr14_0-10Mb.vcf.gz | wc -l
bcftools index -s data/session3/damona132_chr14_0-10Mb.vcf.gz

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
bcftools index -s shows the contigs of the index and the number of variants on each: one contig (chr14) with 41,151 variants.
EOF
printf '%s\n' "$N"; set -x

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
C2: What kind of variants, and how many?
bcftools stats counts everything: records, SNPs, indels, multiallelic sites, and the transition/transversion ratio.
Ts/Tv: transitions (A<->G, C<->T) are about twice as common as transversions in real cattle SNPs (about 2.0-2.5 genome-wide); random errors give about 0.5. A low Ts/Tv warns of false positives.
EOF
printf '%s\n' "$N"; set -x

bcftools stats data/session3/damona132_chr14_0-10Mb.vcf.gz > results/wgs/vcf132/stats.txt
grep '^SN' results/wgs/vcf132/stats.txt | cut -f3-
grep '^TSTV' results/wgs/vcf132/stats.txt | cut -f3-5

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
All 41,151 records are biallelic SNPs (no indels, no multiallelic sites), and Ts/Tv = 2.67: these look like real variants.
EOF
printf '%s\n' "$N"; set -x

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
C3: Add QC tags to every variant
bcftools +fill-tags (a *plugin*) calculates new INFO fields from the genotypes: AF allele frequency, MAF minor allele frequency, HWE Hardy-Weinberg p-value,
ExcHet excess-heterozygosity p-value, F_MISSING fraction of animals with a missing genotype. We write a new VCF, then one table with one line per variant.
Columns: chromosome, position, REF, ALT, AF, MAF, HWE, F_MISSING.
EOF
printf '%s\n' "$N"; set -x

bcftools +fill-tags data/session3/damona132_chr14_0-10Mb.vcf.gz -Oz -o results/wgs/vcf132/tagged.vcf.gz -- -t AF,MAF,HWE,ExcHet,F_MISSING
bcftools index -t -f results/wgs/vcf132/tagged.vcf.gz
bcftools query -f '%CHROM\t%POS\t%REF\t%ALT\t%INFO/AF\t%INFO/MAF\t%INFO/HWE\t%INFO/F_MISSING\n' results/wgs/vcf132/tagged.vcf.gz > results/wgs/vcf132/sites.tsv
head -n 5 results/wgs/vcf132/sites.tsv
wc -l results/wgs/vcf132/sites.tsv

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
From here on we simply read the table sites.tsv with awk and sort: one line per variant.
EOF
printf '%s\n' "$N"; set -x

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
C4: How complete is it?
Missing genotypes (./.) per variant (column 8 of the table) and per animal (nMissing in the per-sample statistics of bcftools stats -s -).
EOF
printf '%s\n' "$N"; set -x

awk '$8>0' results/wgs/vcf132/sites.tsv | wc -l
bcftools stats -s - data/session3/damona132_chr14_0-10Mb.vcf.gz | grep '^PSC' | awk '{m+=$14} END {print m, "missing genotype calls in total"}'
bcftools stats -s - data/session3/damona132_chr14_0-10Mb.vcf.gz | grep '^PSC' | awk '$14>0 {print $3, $14}' | sort -k2,2nr | head -n 5

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Only 104 of 41,151 variants have a missing genotype and 141 calls are missing out of 5.4 million (132 animals x 41,151 variants): the file is almost complete, because the authors imputed and refined it (Beagle).
EOF
printf '%s\n' "$N"; set -x

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
C5: Allele-frequency spectrum (MAF)
How many variants are rare, how many common? A text histogram, one # per 400 variants. Real data: many rare variants and fewer common ones.
Then the number of variants with MAF below 1 % and below 5 %.
EOF
printf '%s\n' "$N"; set -x

awk '{b=($6>=0.5)?9:int($6/0.05); n[b]++} END {for(i=0;i<=9;i++) {s=sprintf("%*s", n[i]/400, ""); gsub(/ /,"#",s); printf "MAF %.2f-%.2f %6d %s\n", i*0.05, (i+1)*0.05, n[i], s}}' results/wgs/vcf132/sites.tsv
awk '$6<0.01' results/wgs/vcf132/sites.tsv | wc -l
awk '$6<0.05' results/wgs/vcf132/sites.tsv | wc -l

MPLBACKEND=Agg python - <<'PY'
import os
import numpy as np
import matplotlib.pyplot as plt
os.makedirs("results/wgs/figures", exist_ok=True)
rows = [l.rstrip("\n").split("\t") for l in open("results/wgs/vcf132/sites.tsv")]
af = np.array([float(r[4]) for r in rows]); maf = np.array([float(r[5]) for r in rows])
fig, ax = plt.subplots(1, 2, figsize=(11, 3.8))
ax[0].hist(maf, bins=np.arange(0, 0.5001, 0.025), color="tab:blue", edgecolor="white")
ax[0].axvline(0.01, color="tab:red", ls="--", lw=1); ax[0].axvline(0.05, color="tab:orange", ls="--", lw=1)
ax[0].set(title="Minor allele frequency (MAF)", xlabel="MAF (red 1 %, orange 5 %)", ylabel="variants")
ax[1].hist(af, bins=np.arange(0, 1.0001, 0.05), color="tab:purple", edgecolor="white")
ax[1].set(title="Frequency of the ALT allele", xlabel="ALT allele frequency", ylabel="variants")
plt.tight_layout()
plt.savefig("results/wgs/figures/C1_allele_frequency.png", dpi=120, bbox_inches="tight")
PY

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Figure: allele-frequency spectrum.
Left: MAF (the frequency of the rarer allele). Most variants are rare and fewer are common, as expected in real data. The dashed lines are the 1 % and 5 % thresholds.
Right: the frequency of the ALT allele. It is skewed towards low values: the reference genome carries the common allele at most positions.
EOF
printf '%s\n' "$N"; set -x


{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
The first bar is the highest: the commonest class are the rare variants (MAF below 5 %: 8,161 variants; below 1 %: 1,133). A flat spectrum would be suspicious.
EOF
printf '%s\n' "$N"; set -x

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
C6: Hardy-Weinberg equilibrium
In a randomly mating population the genotype counts follow the allele frequency (p^2, 2pq, q^2). A variant that clearly breaks this often is a genotyping or calling error.
With 41,151 tests, about 41 variants would have p < 0.001 by chance alone. We count the variants below 0.001 and list the five smallest p-values (columns: chromosome, position, REF, ALT, MAF, HWE p).
EOF
printf '%s\n' "$N"; set -x

awk '$7<0.001' results/wgs/vcf132/sites.tsv | wc -l
sort -g -k7,7 results/wgs/vcf132/sites.tsv | head -n 5 | cut -f1-4,6,7

MPLBACKEND=Agg python - <<'PY'
import os
import numpy as np
import matplotlib.pyplot as plt
os.makedirs("results/wgs/figures", exist_ok=True)
rows = [l.rstrip("\n").split("\t") for l in open("results/wgs/vcf132/sites.tsv")]
p = np.sort(np.array([float(r[6]) for r in rows]))
n = len(p)
obs = -np.log10(np.clip(p, 1e-300, 1))
exp = -np.log10((np.arange(1, n + 1) - 0.5) / n)
fig, ax = plt.subplots(1, 2, figsize=(11, 4))
ax[0].plot([0, exp.max()], [0, exp.max()], c="grey", lw=1)
ax[0].plot(exp[::-1], obs[::-1], ".", ms=3, color="tab:blue")
ax[0].axhline(3, color="tab:red", ls="--", lw=1)
ax[0].set(title="Hardy-Weinberg: observed against expected -log10(p)", xlabel="expected -log10(p)", ylabel="observed -log10(p)")
ax[1].hist(p, bins=20, color="tab:blue", edgecolor="white")
ax[1].set(title="Hardy-Weinberg p-values", xlabel="p-value", ylabel="variants")
plt.tight_layout()
plt.savefig("results/wgs/figures/C2_hardy_weinberg.png", dpi=120, bbox_inches="tight")
PY

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Figure: Hardy-Weinberg.
Left: a QQ plot. If nothing is wrong the points follow the grey diagonal; here they stay on or below it and stop at about 3 (p about 0.0007): no variant is more extreme than that. A real data set would shoot far above the diagonal; here the authors have already removed the variants that broke Hardy-Weinberg.
Right: the p-values are spread evenly; the tall bar at 1 are rare variants, which always agree with Hardy-Weinberg.
EOF
printf '%s\n' "$N"; set -x


{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Only 4 variants, and none below 0.0005, instead of about 40: a Hardy-Weinberg filter has been applied, exactly as the authors say. In raw sequence data you would see many more.
EOF
printf '%s\n' "$N"; set -x

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
C7: Which animals look odd?
Per animal, from bcftools stats -s - (PSC lines): columns are animal, homozygous reference, homozygous alternative, heterozygous, and the heterozygosity (heterozygous / all called).
Very low heterozygosity over 10 Mb = long runs of homozygosity (inbreeding, or a sample problem); very high = possible contamination.
EOF
printf '%s\n' "$N"; set -x

bcftools stats -s - data/session3/damona132_chr14_0-10Mb.vcf.gz | grep '^PSC' | awk '{printf "%s\t%d\t%d\t%d\t%.3f\n", $3, $4, $5, $6, $6/($4+$5+$6)}' > results/wgs/vcf132/animals.tsv
sort -g -k5,5 results/wgs/vcf132/animals.tsv | head -n 5
sort -g -k5,5 results/wgs/vcf132/animals.tsv | tail -n 3
awk '{s+=$5; n++} END {printf "mean heterozygosity %.3f over %d animals\n", s/n, n}' results/wgs/vcf132/animals.tsv

MPLBACKEND=Agg python - <<'PY'
import os
import numpy as np
import matplotlib.pyplot as plt
os.makedirs("results/wgs/figures", exist_ok=True)
rows = [l.rstrip("\n").split("\t") for l in open("results/wgs/vcf132/animals.tsv")]
rows.sort(key=lambda r: float(r[4]))
het = np.array([float(r[4]) for r in rows])
fig, ax = plt.subplots(figsize=(11, 3.8))
ax.scatter(range(len(het)), het, s=26, color=np.where(het < 0.05, "tab:red", "tab:blue"))
ax.axhline(het.mean(), color="grey", ls="--", lw=1)
ax.text(1, het.mean() + 0.008, f"mean {het.mean():.3f}", fontsize=9, color="grey")
ax.set(title="Heterozygosity of each animal over these 10 Mb (red: below 0.05)", xlabel="132 animals, sorted", ylabel="heterozygous / called genotypes", xticks=[])
ax.set_ylim(-0.02, 0.42)
plt.tight_layout()
plt.savefig("results/wgs/figures/C3_heterozygosity_per_animal.png", dpi=120, bbox_inches="tight")
PY

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Figure: heterozygosity of every animal.
Each dot is one animal. Most are between 0.07 and 0.38 (mean 0.288). Five animals (red) are below 0.05 and three of them are exactly 0: no heterozygous genotype in 10 Mb. Long runs of homozygosity (inbreeding) or a sample problem: worth a look in a real project.
EOF
printf '%s\n' "$N"; set -x


{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
The mean heterozygosity is 0.288 and the highest 0.38, but three animals are almost completely homozygous (heterozygosity 0.000) over the whole 10 Mb, and two more have only about 0.02: long runs of homozygosity (inbreeding) or a sample problem, worth a look in a real project.

Are any two animals the same? bcftools gtcheck compares every animal with every other animal. Columns: animal 1, animal 2, discordance (0 = identical), average -log P(HWE) of the matching sites, sites compared, matching genotypes.
Identical genotypes at thousands of sites would mean a duplicated sample or a clone, but if the matches are mostly common genotypes (a low value in column 4) the animals may just be homozygous for the same common haplotype - so read both columns.
EOF
printf '%s\n' "$N"; set -x

bcftools gtcheck data/session3/damona132_chr14_0-10Mb.vcf.gz 2>/dev/null > results/wgs/vcf132/gtcheck.txt
grep -c '^DCv2' results/wgs/vcf132/gtcheck.txt
grep '^DCv2' results/wgs/vcf132/gtcheck.txt | sort -g -k4,4 | head -n 5 | cut -f2-7

bcftools query -l results/wgs/vcf132/tagged.vcf.gz > results/wgs/vcf132/samples.txt
bcftools view -i 'MAF>=0.05' results/wgs/vcf132/tagged.vcf.gz -Ou | bcftools query -f '[%GT\t]\n' | awk 'NR%4==0' > results/wgs/vcf132/gt_matrix.tsv
wc -l results/wgs/vcf132/samples.txt results/wgs/vcf132/gt_matrix.tsv

MPLBACKEND=Agg python - <<'PY'
import os
import numpy as np
import matplotlib.pyplot as plt
os.makedirs("results/wgs/figures", exist_ok=True)
# --- 1. how different are two animals? (every pair of the 132 animals, from bcftools gtcheck)
pairs = [l.rstrip("\n").split("\t") for l in open("results/wgs/vcf132/gtcheck.txt") if l.startswith("DCv2")]
diff = np.array([100 * (1 - float(r[6]) / float(r[5])) for r in pairs])

# --- 2. PCA of the genotypes: every animal becomes one point; similar animals lie close together
names = [l.strip() for l in open("results/wgs/vcf132/samples.txt")]
code = {"0/0": 0, "0|0": 0, "0/1": 1, "1/0": 1, "0|1": 1, "1|0": 1, "1/1": 2, "1|1": 2}
G = np.array([[code.get(x, np.nan) for x in line.rstrip("\n").split("\t")[:len(names)]] for line in open("results/wgs/vcf132/gt_matrix.tsv")], float)
m = np.nanmean(G, axis=1, keepdims=True)
G = np.where(np.isnan(G), m, G) - m
sd = G.std(axis=1, keepdims=True)
G = G / np.where(sd == 0, 1, sd)
U, S, Vt = np.linalg.svd(G, full_matrices=False)
pc = Vt.T * S
var = 100 * S ** 2 / (S ** 2).sum()

het = {r[0]: float(r[4]) for r in (l.rstrip("\n").split("\t") for l in open("results/wgs/vcf132/animals.tsv"))}
trio = {"Damona-GIGA-ULiege-18": "calf", "Damona-GIGA-ULiege-14": "parent", "Damona-GIGA-ULiege-17": "parent"}
fig, ax = plt.subplots(1, 3, figsize=(15, 4.3), gridspec_kw={"width_ratios": [1, 1.5, 0.8]})
ax[0].hist(diff, bins=60, color="tab:grey")
ax[0].set(title="Pairs of animals", xlabel="% of sites with different genotypes", ylabel="pairs of animals")
low = np.array([het[n] < 0.05 for n in names])
ax[1].scatter(pc[:, 0], pc[:, 1], s=22, color="tab:blue", alpha=0.7, label="animals")
ax[1].scatter(pc[low, 0], pc[low, 1], s=40, color="tab:red", label="almost completely homozygous")
for i, n in enumerate(names):
    if n in trio:
        ax[1].scatter(pc[i, 0], pc[i, 1], s=90, facecolors="none", edgecolors="black", linewidths=1.6)
        ax[1].annotate(trio[n] + " " + n.split("-")[-1], (pc[i, 0], pc[i, 1]), textcoords="offset points", xytext=(6, 6), fontsize=8)
ax[1].set(title="PCA of the 132 animals", xlabel=f"PC1 ({var[0]:.1f} %)", ylabel=f"PC2 ({var[1]:.1f} %)")
ax[1].legend(fontsize=8)
ax[2].bar(range(1, 11), var[:10], color="tab:blue")
ax[2].set(title="Variance explained", xlabel="principal component", ylabel="%", xticks=range(1, 11))
plt.tight_layout()
plt.savefig("results/wgs/figures/C4_pairs_and_pca.png", dpi=120, bbox_inches="tight")
PY

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Figure: how similar are the animals?
Left: every pair of animals, as the share of sites where they differ. Most pairs differ at 30-50 % of the sites. The small group at the far left are pairs that differ at less than 10 %: nearly identical animals (duplicates, clones, or animals homozygous for the same haplotype).
Middle: a PCA, which puts every animal on a map: animals with similar genotypes lie close together. The nearly homozygous animals (red) are outliers; the calf and its two parents (circled) are among the other animals.
Right: how much of the variation each principal component explains.
EOF
printf '%s\n' "$N"; set -x


{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
There are 8,646 pairs (132 x 131 / 2). The best-matching pairs differ at only 0-2 of about 41,150 sites, yet their column 4 is low (0.5-0.9): most of their matches are common genotypes, not rare ones. One of these pairs, animals 6 and 240, consists of two of the three nearly homozygous animals above. A good example of why one number is not enough.
EOF
printf '%s\n' "$N"; set -x

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
C8: Is it on the right genome build?
Positions only mean something on the genome build they were made on. A VCF on the wrong build looks perfectly fine and gives wrong results. The test: do the REF alleles of the VCF agree with the genome at those positions?

Our reference data/ref/mini.fa holds 410 kb of chromosome 14 (ARS-UCD2.0, around the DGAT1 gene). We put it back at its real position (it starts at chr14:403,035) by padding it with N, then ask bcftools norm -c w to warn (REF_MISMATCH) wherever a REF allele disagrees with the genome.
EOF
printf '%s\n' "$N"; set -x

{ echo ">chr14"; head -c 403034 /dev/zero | tr '\0' N; samtools faidx data/ref/mini.fa DGAT1_region | grep -v '>' | tr -d '\n'; echo; } | fold -w 60 > results/wgs/vcf132/chr14_window.fa
samtools faidx results/wgs/vcf132/chr14_window.fa
bcftools view -H -r chr14:403035-812781 data/session3/damona132_chr14_0-10Mb.vcf.gz | wc -l
bcftools norm -c w -f results/wgs/vcf132/chr14_window.fa -r chr14:403035-812781 data/session3/damona132_chr14_0-10Mb.vcf.gz -Ou -o /dev/null 2>&1 | grep -c REF_MISMATCH | tee results/wgs/vcf132/mismatch_right.txt || true

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
491 variants lie in the window and 0 REF alleles disagree: the file is on ARS-UCD2.0. Now the control: the same genome moved by one base (a stand-in for the wrong assembly):
EOF
printf '%s\n' "$N"; set -x

{ echo ">chr14"; head -c 403035 /dev/zero | tr '\0' N; samtools faidx data/ref/mini.fa DGAT1_region | grep -v '>' | tr -d '\n'; echo; } | fold -w 60 > results/wgs/vcf132/chr14_window_shifted.fa
samtools faidx results/wgs/vcf132/chr14_window_shifted.fa
bcftools norm -c w -f results/wgs/vcf132/chr14_window_shifted.fa -r chr14:403035-812781 data/session3/damona132_chr14_0-10Mb.vcf.gz -Ou -o /dev/null 2>&1 | grep -c REF_MISMATCH | tee results/wgs/vcf132/mismatch_shifted.txt || true

MPLBACKEND=Agg python - <<'PY'
import os
import numpy as np
import matplotlib.pyplot as plt
os.makedirs("results/wgs/figures", exist_ok=True)
right = int(open("results/wgs/vcf132/mismatch_right.txt").read())
shifted = int(open("results/wgs/vcf132/mismatch_shifted.txt").read())
fig, ax = plt.subplots(figsize=(6, 3.8))
bars = ax.bar(["right genome\n(ARS-UCD2.0)", "genome shifted\nby one base"], [right, shifted], color=["tab:green", "tab:red"])
for b, v in zip(bars, [right, shifted]):
    ax.text(b.get_x() + b.get_width() / 2, v, f"{v} of 491", ha="center", va="bottom")
ax.set(title="REF alleles that disagree with the genome", ylabel="variants")
ax.set_ylim(0, 491)
plt.tight_layout()
plt.savefig("results/wgs/figures/C5_genome_build_check.png", dpi=120, bbox_inches="tight")
PY

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Figure: the genome-build check.
With the right genome no REF allele disagrees (0 of 491). Shift the genome by one base and about three in four disagree (377 of 491). One wrong base is enough to see it.
EOF
printf '%s\n' "$N"; set -x


{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
377 of 491 (about three in four) disagree: that is what a wrong build looks like. Do not trust the header alone. This header lists chr14 with length=82253933, but ARS-UCD2.0 chr14 is 82,403,003 bp; the alleles are the real test.
EOF
printf '%s\n' "$N"; set -x

bcftools head data/session3/damona132_chr14_0-10Mb.vcf.gz | grep -E 'ID=(chr)?14[,>]'

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
C9: Filter for analysis
Keep variants with minor allele frequency >= 1 % (rare variants carry little information and are often errors) and fewer than 5 % missing calls. We use the tags from C3 (MAF, F_MISSING) and check the result.
EOF
printf '%s\n' "$N"; set -x

bcftools view -i 'MAF>=0.01 && F_MISSING<0.05' -Oz -o results/wgs/vcf132/qc.vcf.gz results/wgs/vcf132/tagged.vcf.gz
bcftools index -t -f results/wgs/vcf132/qc.vcf.gz
bcftools view -H results/wgs/vcf132/tagged.vcf.gz | wc -l
bcftools view -H results/wgs/vcf132/qc.vcf.gz | wc -l

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
41,151 variants before, 40,018 after: exactly the 1,133 variants with MAF below 1 % are removed (no variant has more than 5 % missing calls). This qc.vcf.gz is the file you hand over to the analysis (GWAS, relatedness, PCA ...).
EOF
printf '%s\n' "$N"; set -x

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
C10: Everyday VCF commands
One region. -r uses the index to jump straight to a region: how many variants in 100 kb?
Some animals. -s keeps only the animals you name: here the calf and its two parents of Parts A-B (their names in this VCF are in data/reads/animals.tsv).
Genotypes as a table with bcftools query: one line per variant, one column per animal.
EOF
printf '%s\n' "$N"; set -x

bcftools view -H -r chr14:5000000-5100000 results/wgs/vcf132/qc.vcf.gz | wc -l
bcftools view -s Damona-GIGA-ULiege-18,Damona-GIGA-ULiege-14,Damona-GIGA-ULiege-17 results/wgs/vcf132/qc.vcf.gz -Oz -o results/wgs/vcf132/trio.vcf.gz
bcftools query -l results/wgs/vcf132/trio.vcf.gz
bcftools query -f '%CHROM\t%POS\t%REF\t%ALT[\t%GT]\n' results/wgs/vcf132/trio.vcf.gz | head -n 5

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Genotype counts of the three animals over all variants, and the family check from Part B, now on the published genotypes: the calf (first) must follow Mendel's rules with the other two as parents.
EOF
printf '%s\n' "$N"; set -x

bcftools query -f '[%GT\n]' results/wgs/vcf132/trio.vcf.gz | sort | uniq -c
bcftools +mendelian2 results/wgs/vcf132/trio.vcf.gz -p Damona-GIGA-ULiege-18,Damona-GIGA-ULiege-14,Damona-GIGA-ULiege-17 | grep -E '^(ngood|nmerr)'

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
0 Mendelian errors in 40,016 checked genotypes: the published genotypes are consistent. (Our own calls from Part B had 57 errors in 852 calls with the strict filter - the difference between 6x reads and a refined, imputed file.)
EOF
printf '%s\n' "$N"; set -x

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Variant density along the region (one # per 150 variants): variants are not evenly spread; the most are found at 4-5 Mb. (The DGAT1 gene, the milk-fat gene of Parts A-B, lies at about 0.6 Mb, in the first, sparse bin.)
EOF
printf '%s\n' "$N"; set -x

bcftools query -f '%POS\n' data/session3/damona132_chr14_0-10Mb.vcf.gz | awk '{n[int($1/1000000)]++} END {for(i=0;i<10;i++) {s=sprintf("%*s", n[i]/150, ""); gsub(/ /,"#",s); printf "%2d-%2d Mb %5d %s\n", i, i+1, n[i], s}}'

MPLBACKEND=Agg python - <<'PY'
import os
import numpy as np
import matplotlib.pyplot as plt
os.makedirs("results/wgs/figures", exist_ok=True)
rows = [l.rstrip("\n").split("\t") for l in open("results/wgs/vcf132/sites.tsv")]
pos = np.array([int(r[1]) for r in rows]) / 1e6
maf = np.array([float(r[5]) for r in rows])
edges = np.arange(0, 10.0001, 0.1)
idx = np.clip(np.digitize(pos, edges) - 1, 0, len(edges) - 2)
count = np.bincount(idx, minlength=len(edges) - 1)
mean_maf = np.array([maf[idx == i].mean() if (idx == i).any() else np.nan for i in range(len(edges) - 1)])
fig, ax = plt.subplots(2, 1, figsize=(11, 5.5), sharex=True)
ax[0].bar(edges[:-1], count, width=0.1, align="edge", color="tab:blue")
ax[0].set(ylabel="variants per 100 kb", title="Variant density and diversity along chromosome 14 (first 10 Mb)")
ax[1].plot(edges[:-1] + 0.05, mean_maf, color="tab:purple")
ax[1].set(ylabel="mean MAF per 100 kb", xlabel="position on chromosome 14 (Mb)")
for a in ax:
    a.axvspan(0.603, 0.613, color="tab:orange", alpha=0.5)
ax[0].text(0.62, count.max() * 0.9, "DGAT1", color="tab:orange", fontsize=9)
plt.tight_layout()
plt.savefig("results/wgs/figures/C6_density_along_chr14.png", dpi=120, bbox_inches="tight")
PY

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
Figure: variants along the region.
Top: the number of variants per 100 kb; there are most between 4 and 5 Mb and few at the start. Bottom: the mean MAF per 100 kb, a simple measure of diversity. The orange line is the DGAT1 gene (about 0.6 Mb), the gene of Parts A-B.
EOF
printf '%s\n' "$N"; set -x


{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
C11: Final checks
The four checks of an audit, each PASS or FAIL: the right number of animals, only biallelic SNPs, REF alleles agree with the genome, Ts/Tv like real variants.
EOF
printf '%s\n' "$N"; set -x

n_samp=$(bcftools query -l data/session3/damona132_chr14_0-10Mb.vcf.gz | wc -l)
n_snp=$(grep '^SN' results/wgs/vcf132/stats.txt | grep 'number of SNPs' | cut -f4)
n_site=$(grep '^SN' results/wgs/vcf132/stats.txt | grep 'number of records' | cut -f4)
n_multi=$(grep '^SN' results/wgs/vcf132/stats.txt | grep 'multiallelic sites' | head -n 1 | cut -f4)
mism=$(bcftools norm -c w -f results/wgs/vcf132/chr14_window.fa -r chr14:403035-812781 data/session3/damona132_chr14_0-10Mb.vcf.gz -Ou -o /dev/null 2>&1 | grep -c REF_MISMATCH || true)
tstv=$(grep '^TSTV' results/wgs/vcf132/stats.txt | cut -f5)
[ "$n_samp" = 132 ] && echo "PASS  132 animals in the file ($n_samp)" || echo "FAIL  animals: $n_samp"
[ "$n_snp" = "$n_site" ] && [ "$n_multi" = 0 ] && echo "PASS  only biallelic SNPs ($n_snp SNPs of $n_site records)" || echo "FAIL  not only biallelic SNPs"
[ "$mism" = 0 ] && echo "PASS  REF alleles agree with ARS-UCD2.0 ($mism mismatches)" || echo "FAIL  REF mismatches: $mism"
awk -v t="$tstv" 'BEGIN { if (t>=2.0 && t<=3.0) print "PASS  Ts/Tv looks like real variants (" t ")"; else print "FAIL  Ts/Tv " t }'

{ set +x; } 2>/dev/null
printf '\n%s=====================================================================%s\n' "$B" "$N"
printf '%s' "$C"; cat <<'EOF'
The audit of a VCF, in short: how many animals and variants - what kind (Ts/Tv) - how complete - allele-frequency spectrum - Hardy-Weinberg - odd or identical animals - right genome build - filter - Mendel check when you have families.
Then the VCF is ready for analysis. The files are in results/wgs/vcf132/: qc.vcf.gz (the filtered VCF), tagged.vcf.gz, sites.tsv, animals.tsv, gtcheck.txt, stats.txt.
EOF
printf '%s\n' "$N"; set -x
