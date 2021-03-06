## Data files

Contains various input and intermediate output files.

|File                            |                                  Description|
|--------------------------------|---------------------------------------------|
|preprocessing.csv               | Number of reads that pass quality filter.   |
|taxonomy_clean.rds              | Variant table in phyloseq format.           |
|variants.csv                    | Sequence variants and abundances in samples.|
|taxa.csv                        | Taxonomy assignment for each variant.       |
|genera.csv                      | Genus-level abundances for all samples.     |
|tests_genus.csv                 | Association tests for genera x clinical.    |
|tests_variants.csv              | Association tests for variant x clinical.   |
|tests_who_genus.csv             | Association tests for WHO classification.   |
|counts_norm_genus.csv           | DESeq2 normalized and filtered genus counts.|
|counts_norm_variant.csv         | DESeq2 normalized and filt. variant counts. |
