# Copyright 2017 Christian Diener <mail[at]cdiener.com>
#
# Apache license 2.0. See LICENSE for more information.

# Scripts for running association tests on the genus level

library(mbtools)

ps <- readRDS("../data/taxonomy_clean.rds")
ps <- subset_samples(ps, diabetes_status < 6 & metformin == 0)
variables <- names(sample_data(ps))
exclude <- variables %in% c("id", "metformin")

tests <- association(ps, variables = variables[!exclude],
                     confounders = c("gender"))
fwrite(tests[order(padj, variable)], "../data/tests_genus.csv")

# Get post-hoc tests for status
sample_data(ps)$diabetes_status <- factor(sample_data(ps)$diabetes_status)
multi <- combinatorial_association(ps, "diabetes_status")
