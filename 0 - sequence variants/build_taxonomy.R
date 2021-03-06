#!/usr/bin/env Rscript

# Copyright 2016 Christian Diener <mail[at]cdiener.com>
#
# Apache license 2.0.

library(mbtools)
library(stringr)
library(data.table)

#' Walk through the folders for each sequencing run and assemble a data table
#' containing the meta info for each file.
#'
#' @param path The root path in which to look for runs.
#' @return A data table with the columns run, sample, forward and reverse that
#'  contains the run ID, sample ID and file names for forward and reverse
#'  reads.
annotate_files <- function(path) {
    fwd <- list.files(path, pattern = "R1.+\\.fastq.gz", full.names = TRUE,
                      recursive = TRUE)
    ids_fwd <- str_match(fwd, "run_(\\d+)/(.+)_S")
    bwd <- list.files(path, pattern = "R2.+\\.fastq.gz", full.names = TRUE,
                      recursive = TRUE)
    ids_rev <- str_match(bwd, "run_(\\d+)/(.+)_S")
    files_fwd <- data.table(run = ids_fwd[, 2],
                            sample = ids_fwd[, 3], forward = fwd)
    files_rev <- data.table(run = ids_rev[, 2],
                            sample = ids_rev[, 3], reverse = bwd)
    files <- files_fwd[files_rev, on = .(run, sample)]

    return(files)
}

#' Learn the experiment-specific error rates for a set of samples.
#'
#' @param samples A data frame or table as returned by
#'  \code{\link{annotate_files}}.
#' @return A list containing the error rates for forward and reverse reads.
dada_errors <- function(samples) {
    fwd_err <- learnErrors(samples$forward, nreads = 2e6,
                           multithread = TRUE, randomize = TRUE)
    rev_err <- learnErrors(samples$reverse, nreads = 2e6,
                           multithread = TRUE, randomize = TRUE)

    return(list(forward = list(fwd_err), reverse = list(rev_err)))
}

# Perform trimming and quality filtering on the reads.
if (!file.exists("../data/filtered")) {
    cat("Preprocessing reads...\n")
    raw <- annotate_files("../data")
    filtered <- copy(raw)
    filtered[, forward := file.path("../data/filtered", forward)]
    filtered[, reverse := file.path("../data/filtered", reverse)]
    metrics <- filterAndTrim(raw$forward, filtered$forward,
                             raw$reverse, filtered$reverse,
                             trimLeft = 10, truncLen = c(240, 200),
                             maxEE = 2, multithread = TRUE)
    fwrite(data.table(metrics), "preprocessing.csv")
}
samples <- annotate_files("filtered")

# Estimate per-run error rates.
if (!file.exists("errors.rds")) {
    err <- samples[, dada_errors(.SD), by = "run"]
    saveRDS(err, "errors.rds")
} else {
    err <- readRDS("errors.rds")
}
setkey(err, run)

# Obtain the sequence variants for each run
for(r in unique(samples$run)) {
    cat("Processing run", r, "...\n")
    filename <- paste0("merged_", r, ".rds")
    if (file.exists(filename)) next
    s <- samples[run == r]
    derep_fwd <- derepFastq(s$forward)
    derep_rev <- derepFastq(s$reverse)
    dd_fwd <- dada(derep_fwd, err = err[r, forward][[1]], multithread = TRUE)
    dd_rev <- dada(derep_rev, err = err[r, reverse][[1]], multithread = TRUE)
    merged <- mergePairs(dd_fwd, derep_fwd, dd_rev, derep_rev)
    saveRDS(merged, filename)
}

# merge variant tables and remove bimeras
merged <- lapply(list.files(pattern = "merged_"),
                 function(path) makeSequenceTable(readRDS(path)))
seqtab <- do.call(mergeSequenceTables, merged)
seqtab <- removeBimeraDenovo(seqtab, multithread = TRUE)
saveRDS(seqtab, "seqtab.rds")

# Assign the taxonomy for the samples and save as a phloseq object
taxa <- assignTaxonomy(seqtab, "silva_nr_v128_train_set.fa.gz",
                       multithread = TRUE)
taxa <- addSpecies(taxa, "silva_species_assignment_v128.fa.gz",
                    verbose = TRUE)
ps <- phyloseq(otu_table(seqtab, taxa_are_rows = FALSE),
               tax_table(taxa))
fwrite(seqtab, "../data/variants.csv")
fwrite(taxa, "../taxa.csv")
saveRDS(ps, "../data/taxonomy.rds")
