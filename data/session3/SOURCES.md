# Session 3 data: sources, licences, what was changed

| File | What it is | Source | Licence |
|---|---|---|---|
| `snp50_world.bed/.bim/.fam` | Illumina BovineSNP50 genotypes, 198 animals of 10 breeds, 43,042 SNPs, UMD3.1 positions | Decker et al. 2014, Dryad doi:10.5061/dryad.th092 (same files: Zenodo record 4961186) | CC0 |
| `breeds.tsv` | breed codes of the file with their names | Table S1 of Decker et al. (arXiv:1309.5118) | - |
| `damona132_chr14_0-10Mb.vcf.gz` (+ `.tbi`) | whole-genome-sequence genotypes of 132 Holstein, chromosome 14, first 10 Mb, 41,151 SNPs | Druet T, Forneris NS (2026) Zenodo doi:10.5281/zenodo.23011638, file `DAMONA132_CEPE_refined.vcf.gz` | CC BY 4.0 |
| `../reads/dna_*` | REAL reads of a Holstein calf and its two parents (animals of the 132-animal VCF above), cut to three 400-kb windows | ENA project PRJEB53518; how they were cut: `../reads/SOURCES.md` | public data |
| `../ref/*` | a 1.25 Mb reference made of three real ARS-UCD2.0 windows | Ensembl, via GenART Lab `scripts/fetch_reference.py` | - |

## What was changed (be open about this with participants)

**`snp50_world`** - real genotypes, with these changes made by the instructor:
* 10 of the 134 breeds kept (HO, JER, AN, HFD, BSW, GIR, SAHW, NEL, NDAM, SGT; 17-21 animals each).
* The one SNP assigned to "chromosome 0" was removed (43,043 -> 43,042 SNPs). 25 SNP names that occur twice in the original file were made unique (`_2`).
* The family ID is the breed code; animals are sorted by it.
* **Four sample problems were planted** so that QC has something to find: a duplicate animal, a mislabelled animal (a Nelore recorded as Holstein), an animal with 20 % of its calls removed, and a "contaminated" animal (Holstein DNA mixed with Gir DNA). The answers are in `data/teacher_only/planted_snp_problems.tsv` - remove that folder before handing the kit to participants. Everything else, including the animals that QC flags besides these four, is real.
* The authors had already removed animals with more than 10 % missing genotypes and SNPs with more than 10 % missing or MAF < 0.0005 (paper, Methods). So the real animals are unusually complete; that is why the planted low-call-rate animal stands out.

**`damona132_chr14_0-10Mb`** - cut out of the 199 MB file with `bcftools view -r chr14:1-10000000` over HTTP (only the needed blocks of the file were downloaded; header otherwise unchanged except for the `--no-version` option). According to the depositors the refined file holds genotypes after Beagle 4.1 refinement and removal of Mendelian inconsistencies, at positions kept after filtering on minor allele frequency, Hardy-Weinberg equilibrium and Mendelian inconsistencies. The raw reads are at ENA PRJEB53518.

## Please cite

* Decker JE, McKay SD, Rolf MM, Kim J, Molina Alcala A, Sonstegard TS, Hanotte O, Gotherstrom A, Seabury CM, Praharani L, Babar ME, Correia de Almeida Regitano L, Yildiz MA, Heaton MP, Liu W-S, Lei C-Z, Reecy JM, Saif-Ur-Rehman M, Schnabel RD, Taylor JF (2014) Worldwide patterns of ancestry, divergence, and admixture in domesticated cattle. PLoS Genetics 10(3): e1004254. https://doi.org/10.1371/journal.pgen.1004254
* Forneris N, Wragg D, Fischer D, Schoenebeck JJ, Clements DN, Iso-Touru T, Gautier M, Druet T (2026) Comparing whole-genome sequencing and cost-effective genotyping strategies for estimating homozygosity-by-descent. Submitted to Heredity. (the paper the VCF was made for)
* Oget-Ebrad C, Kadri NK, Moreira GCM, Karim L, Coppieters W, Georges M, Druet T (2022) Benchmarking phasing software with a whole-genome sequenced cattle pedigree. BMC Genomics 23:130. https://doi.org/10.1186/s12864-022-08354-6 (how the sequence data were generated)
