library(GenomicRanges)
library(GenomicAlignments)
library(Biostrings)
library(Rsamtools)
library(rtracklayer)
library(BiocParallel)
library(stringr)

bamfn <- raer_example("SRR5564269_Aligned.sortedByCoord.out.md.bam")
bam2fn <- raer_example("SRR5564277_Aligned.sortedByCoord.out.md.bam")
fafn <- raer_example("human.fasta")
bedfn <- raer_example("regions.bed")

nts <- c("A", "T", "G", "C")
nt_clmns <- paste0("n", nts)

res <- get_pileup(bamfn, fafn, bedfn)

test_that("pileup works", {
  expect_equal(length(res$Ref), 182)
  expect_equal(ncol(as.data.frame(res)), 15)
})

test_that("filtering for variants in pileup works", {
  vars <- res[res$Var != "-"]
  res_all_vars <- get_pileup(bamfn, fafn, bedfn,
    filterParam = FilterParam(only_keep_variants = TRUE)
  )
  expect_equal(length(res_all_vars), 2)
  expect_equal(vars, res_all_vars)

  res_2_vars <- get_pileup(bamfn, fafn, bedfn,
                             filterParam = FilterParam(min_variant_reads = 2))
  expect_equal(length(res_2_vars), 1)
  expect_equal(vars[vars$nVar >= 2], res_2_vars)

})

test_that("n-bam pileup works", {
  res <- get_pileup(c(bamfn, bamfn), fafn, bedfn,
    filterParam = FilterParam(library_type = c(
      "fr-first-strand",
      "fr-first-strand"
    ))
  )
  expect_true(identical(res[[1]], res[[2]]))
  expect_equal(length(res[[1]]$Ref), 182)
  expect_equal(ncol(as.data.frame(res[[1]])), 15)

  res <- get_pileup(c(bamfn, bam2fn), fafn, bedfn)
  expect_equal(length(res[[1]]$Ref), 182)
  expect_false(identical(res[[1]], res[[2]]))

  res <- get_pileup(c(bamfn, bamfn), fafn, bedfn,
    filterParam = FilterParam(library_type = c(
      "fr-first-strand",
      "genomic-unstranded"
    ))
  )
  expect_equal(length(res[[1]]$Ref), 214)
  expect_equal(length(res[[1]]$Ref), length(res[[2]]$Ref))

  res <- get_pileup(c(bamfn, bam2fn), fafn, bedfn,
    filterParam = FilterParam(
      library_type = "fr-first-strand",
      only_keep_variants = TRUE
    ),
  )
  # same sites reported in both files
  expect_true(all(start(res[[1]]) == start(res[[2]])))
  # sites are variant in at least 1 file
  expect_true(all(res[[1]]$Var != "-" | res[[2]]$Var != "-"))

  res <- get_pileup(rep(bamfn, 4), fafn, bedfn,
    filterParam = FilterParam(library_type = "fr-first-strand")
  )
  expect_true(length(res) == 4)

  # all sites in first bam are variant
  res <- get_pileup(c(bamfn, bam2fn), fafn, bedfn,
    filterParam = FilterParam(
      library_type = "fr-first-strand",
      only_keep_variants = c(TRUE, FALSE)
    )
  )
  expect_true(all(res[[1]]$Var != "-"))

  # all sites in first bam are variant
  res <- get_pileup(c(bamfn, bam2fn), fafn, bedfn,
    filterParam = FilterParam(
      library_type = "fr-first-strand",
      only_keep_variants = c(FALSE, TRUE)
    )
  )
  expect_true(all(res[[2]]$Var != "-"))
})

test_that("pileup regional query works", {
  res <- get_pileup(bamfn, fafn, region = "SSR3:203-205")
  expect_equal(length(res$Ref), 3)
  expect_equal(start(res), c(203, 204, 205))
  expect_equal(end(res), c(203, 204, 205))

  # chr1 does not exist
  expect_error(suppressWarnings(get_pileup(bamfn, fafn, region = "chr1")))

  res <- get_pileup(bamfn, fafn, bedfile = NULL, chrom = "SSR3")
  expect_equal(length(res$Ref), 529)
})

test_that("incorrect regional query is caught", {
  # will produce warning that chrHello is not in bamfile and an error
  expect_error(suppressWarnings(get_pileup(bamfn, fafn, region = "chrHello")))
})

test_that("missing files are caught", {
  expect_error(get_pileup(bamfile = "hello.bam", fafn, bedfn))
  expect_error(get_pileup(bamfn, fafile = "hello.fasta", bedfn))
  expect_error(get_pileup(bamfn, fafn, bedfile = "hello.bed"))
})

test_that("library types are respected", {
  res <- get_pileup(bamfn, fafn,
    filterParam = FilterParam(library_type = "fr-first-strand")
  )
  expect_true(table(strand(res))["+"] == 619)
  expect_true(table(strand(res))["-"] == 1047)
  expect_true(all(strand(res[seqnames(res) == "DHFR"]) == "-"))
  expect_true(all(strand(res[seqnames(res) == "SPCS3"]) == "+"))

  res <- get_pileup(bamfn, fafn,
    filterParam = FilterParam(library_type = "fr-second-strand")
  )
  expect_true(table(strand(res))["+"] == 1047)
  expect_true(table(strand(res))["-"] == 619)
  expect_true(all(strand(res[seqnames(res) == "DHFR"]) == "+"))
  expect_true(all(strand(res[seqnames(res) == "SPCS3"]) == "-"))

  res <- get_pileup(bamfn, fafn,
    filterParam = FilterParam(library_type = "genomic-unstranded")
  )
  expect_true(all(strand(res) == "+"))

  res <- get_pileup(bamfn, fafn,
    filterParam = FilterParam(library_type = "unstranded")
  )
  expect_true(all(strand(res) %in% c("+", "-")))

  expect_error(get_pileup(bamfn, fafn, bedfn,
    filterParam = FilterParam(library_type = "unknown-string")
  ))
})

test_that("pileup chrom start end args", {
  res <- get_pileup(
    bamfn, fafn,
    chrom = "DHFR"
  )
  expect_true(all(seqnames(res) == "DHFR"))
})

test_that("pileup depth lims", {
  unflt <- get_pileup(bamfn, fafn)
  unflt <- as.data.frame(unflt)
  unflt$seqnames <- as.character(unflt$seqnames)

  rsums <- unflt[nt_clmns]
  rsums <- rowSums(rsums) >= 30

  expected_df <- unflt[rsums, ]
  rownames(expected_df) <- NULL

  res <- get_pileup(bamfn, fafn,
    filterParam = FilterParam(min_nucleotide_depth = 30)
  )
  res <- as.data.frame(res, row.names = NULL)
  res$seqnames <- as.character(res$seqnames)

  expect_equal(expected_df, res)
})

check_nRef_calc <- function(input, nts_in = nts) {
  res <- as.data.frame(input)

  for (nt in nts_in) {
    clmn <- paste0("n", nt)
    dat <- res[res$Ref == nt, ]

    expect_identical(dat[, clmn], dat$nRef)

    other_clmns <- nts_in[nts_in != nt]
    other_clmns <- paste0("n", other_clmns)
    var_sums <- rowSums(dat[, other_clmns])

    expect_identical(as.integer(var_sums), as.integer(dat$nVar))
  }
}

test_that("pileup check nRef and nVar", {
  # strds <- c("unstranded", "fr-first-strand", "fr-second-strand")
  strds <- c("fr-first-strand", "fr-second-strand")

  for (strd in strds) {
    res <- get_pileup(bamfn, fafn, filterParam = FilterParam(library_type = strd))

    check_nRef_calc(res)
  }
})

bout <- tempfile(fileext = ".bam")

test_that("pileup check mapq filter", {
  bout <- filterBam(bamfn,
    param = ScanBamParam(mapqFilter = 255),
    destination = bout,
    indexDestination = TRUE
  )
  a <- get_pileup(bamfn, fafn, filterParam = FilterParam(min_mapq = 255))
  b <- get_pileup(bout, fafn)
  expect_true(identical(a, b))
})

test_that("pileup check flag filtering", {
  bout <- filterBam(bamfn,
    param = ScanBamParam(flag = scanBamFlag(isMinusStrand = F)),
    destination = bout,
    indexDestination = TRUE
  )
  a <- get_pileup(bamfn, fafn, bedfn, bam_flags = scanBamFlag(isMinusStrand = F))
  b <- get_pileup(bout, fafn, bedfn)
  expect_true(identical(a, b))

  bout <- filterBam(bamfn,
    param = ScanBamParam(flag = scanBamFlag(isMinusStrand = T)),
    destination = bout,
    indexDestination = TRUE
  )
  a <- get_pileup(bamfn, fafn, bedfn, bam_flags = scanBamFlag(isMinusStrand = T))
  b <- get_pileup(bout, fafn, bedfn)
  expect_true(identical(a, b))
})

test_that("pileup read trimming filter works", {
  a <- get_pileup(bamfn, fafn, region = "SSR3:440-450")
  b <- get_pileup(bamfn, fafn, filterParam = FilterParam(trim_5p = 6), region = "SSR3:440-450")
  d <- get_pileup(bamfn, fafn, filterParam = FilterParam(trim_5p = 6, trim_3p = 6), region = "SSR3:440-450")
  e <- get_pileup(bamfn, fafn, filterParam = FilterParam(trim_3p = 6), region = "SSR3:440-450")
  ex1 <- c(0L, 0L, 0L, 1L, 1L, 1L, 1L, 1L, 1L, 0L, 0L)
  ex2 <- c(1L, 1L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L)

  expect_equal(a$nRef - b$nRef, ex1)
  expect_equal(b$nRef - d$nRef, ex2)
  expect_equal(a$nRef - e$nRef, ex2)

  a <- get_pileup(bamfn, fafn, region = "SSR3:128-130")
  b <- get_pileup(bamfn, fafn, filterParam = FilterParam(trim_5p = 6), region = "SSR3:128-130")
  d <- get_pileup(bamfn, fafn, filterParam = FilterParam(trim_5p = 6, trim_3p = 6), region = "SSR3:128-130")
  e <- get_pileup(bamfn, fafn, filterParam = FilterParam(trim_3p = 6), region = "SSR3:128-130")
  ex1 <- c(3L, 4L, 2L)
  ex2 <- c(3L, 2L, 0L)
  expect_equal(a$nRef - b$nRef, ex1)
  expect_equal(b$nRef - d$nRef, ex2)
  expect_equal(a$nRef - e$nRef, ex2)
})

fa <- scanFa(fafn)
hp_matches <- vmatchPattern(strrep("A", 6), fa) |> as("GRanges")

test_that("pileup check homopolymer filter", {
  a <- get_pileup(bamfn, fafn, filterParam = FilterParam(homopolymer_len = 6))
  b <- get_pileup(bamfn, fafn)
  expect_false(identical(a, b))

  expect_equal(length(queryHits(findOverlaps(hp_matches, a))), 0)
  expect_equal(length(queryHits(findOverlaps(hp_matches, b))), 120)
})

test_that("filtering for splicing events works", {
  # get sites near splicing events
  splices <- GRanges(coverage(junctions(GenomicAlignments::readGAlignmentPairs(bamfn))))
  splices <- splices[splices$score > 0]
  plp <- get_pileup(bamfn, fafn)
  plp <- plp[plp$Var != "-"]

  # 3 sites, 1 is from all non-spliced reds, 2 sites are all from spliced reads,
  # (SPCS3  227, 347, 348)
  sites_near_splices <- plp[queryHits(findOverlaps(plp, splices, maxgap = 4))]

  plp_b <- get_pileup(bamfn, fafn, filterParam = FilterParam(splice_dist = 5))
  plp_b <- plp_b[plp_b$Var != "-"]
  bsites_near_splices <- plp_b[queryHits(findOverlaps(plp_b,
    splices,
    maxgap = 4
  ))]
  expect_equal(length(sites_near_splices$Ref), 3)
  expect_equal(length(bsites_near_splices$Ref), 1)
})


test_that("filtering for indel events works", {
  # get sites near splicing events
  reads <- GenomicAlignments::readGAlignments(bamfn, use.names = T)
  cig_ops <- cigarRangesAlongReferenceSpace(cigar(reads), ops = "D", pos = start(reads))
  refs <- seqnames(reads)[elementNROWS(cig_ops) > 0]
  cig_ops <- cig_ops[elementNROWS(cig_ops) > 0]
  names(cig_ops) <- refs
  cig_pos <- unique(GRanges(cig_ops))

  plp <- get_pileup(bamfn, fafn, filterParam = FilterParam(min_base_quality = 1))

  plp <- plp[plp$Var != "-"]

  # SSR3 387 variant has 1 read with variant with indel 4 bp away
  # SRR3 388 variant has 1 read with variant 3bp away from indel
  sites_near_indels <- plp[queryHits(findOverlaps(plp, cig_pos))]

  plp_b <- get_pileup(bamfn, fafn, filterParam = FilterParam(
    min_base_quality = 1,
    indel_dist = 5
  ))
  plp_b <- plp_b[plp_b$Var != "-"]
  bsites <- plp_b[queryHits(findOverlaps(
    plp_b,
    cig_pos
  ))]

  expect_equal(length(sites_near_indels$Ref), 3)
  # lose SSR3 387 site after filtering
  expect_equal(length(bsites$Ref), 2)
  # lose 1 read from SSR3 388 site after filtering
  expect_equal(sites_near_indels$nVar[2] - bsites$nVar[1], 1)
})

fout <- tempfile(fileext = ".fa")
test_that("writing reads with mismatches works", {
  plp <- get_pileup(bamfn, fafn, reads = fout)
  plp <- plp[plp$Var != "-"]
  seqs <- Rsamtools::scanFa(fout)
  expect_false(any(duplicated(names(seqs))))
})


seqs <- Rsamtools::scanFa(fout)
ids <- unlist(lapply(str_split(names(seqs), "_"), function(x) paste0(x[1], "_", x[2])))
writeLines(ids, fout)
test_that("excluding reads with mismatches works", {
  plp <- get_pileup(bamfn, fafn, region = "DHFR:513-513")
  plp2 <- get_pileup(bamfn, fafn,
    region = "DHFR:513-513",
    bad_reads = fout
  )
  expect_true(length(plp) == 1)
  expect_true(length(plp2) == 1)
  expect_true(plp2$nVar == 0)

  plp <- get_pileup(bamfn, fafn)
  plp2 <- get_pileup(bamfn, fafn, bad_reads = fout)
  expect_true(length(plp2) > 0)
  expect_true(sum(plp$nVar) - sum(plp2$nVar) > 0)
})

test_that("filtering for read-level mismatches works", {
  plp <- get_pileup(bamfn, fafn,
    filterParam = FilterParam(
      min_base_quality = 10,
      only_keep_variants = TRUE
    ),
    region = "SSR3:244-247"
  )
  expect_equal(length(plp), 2)

  plp <- get_pileup(bamfn, fafn,
    region = "SSR3:244-247",
    filterParam = FilterParam(
      min_base_quality = 10,
      only_keep_variants = TRUE,
      max_mismatch_type = c(1, 1)
    )
  )
  expect_equal(length(plp), 0)
  expect_s4_class(plp, "GRanges")

  plp <- get_pileup(bamfn, fafn,
    region = "SSR3:244-247",
    filterParam = FilterParam(
      min_base_quality = 10,
      only_keep_variants = TRUE,
      max_mismatch_type = c(0, 10)
    )
  )
  expect_equal(length(plp), 2)

  plp <- get_pileup(bamfn, fafn,
    region = "SSR3:244-247",
    filterParam = FilterParam(
      min_base_quality = 10,
      only_keep_variants = TRUE,
      max_mismatch_type = c(0, 1)
    )
  )
  expect_equal(length(plp), 0)
  expect_s4_class(plp, "GRanges")

  plp <- get_pileup(bamfn, fafn,
    region = "SSR3:244-247",
    filterParam = FilterParam(
      min_base_quality = 10,
      only_keep_variants = TRUE,
      max_mismatch_type = c(8, 0)
    )
  )
  expect_equal(length(plp), 2)

  plp <- get_pileup(bamfn, fafn,
    region = "SSR3:244-247",
    filterParam = FilterParam(
      min_base_quality = 10,
      only_keep_variants = TRUE,
      max_mismatch_type = c(1, 0)
    )
  )
  expect_equal(length(plp), 0)
  expect_s4_class(plp, "GRanges")
})


test_that("parallel processing works", {
  plp <- get_pileup(bamfn, fafn)
  plp_serial <- get_pileup(bamfn, fafn, BPPARAM = SerialParam())
  expect_equal(plp_serial$Ref, plp$Ref)

  if (.Platform$OS.type != "windows") {
    plp_mc <- get_pileup(bamfn, fafn, BPPARAM = MulticoreParam(workers = 2))
    expect_equal(plp_mc$Ref, plp$Ref)
  } else {
    plp_sp <- get_pileup(bamfn, fafn, BPPARAM = SnowParam(workers = 2))
    expect_equal(plp_sp$Ref, plp$Ref)
  }

  # note that there is a difference in counts in SPCS3, which
  # happens when single chromosomes or regions are queried.
  # this may have something to do with the overlapping mate quality score
  # tweaking.
})


test_that("limiting chromosomes works", {
  chroms_to_query <- names(scanBamHeader(bamfn)[[1]]$targets)
  plp <- get_pileup(bamfn, fafn)
  plp_2 <- get_pileup(bamfn, fafn, chroms = chroms_to_query)
  expect_true(identical(plp_2, plp))

  plp_2 <- get_pileup(bamfn, fafn, chroms = chroms_to_query[1])
  plp <- plp[seqnames(plp) == chroms_to_query[1]]
  expect_true(identical(plp_2$nRef, plp$nRef))

  if (.Platform$OS.type != "windows") {
    plp_mc <- get_pileup(bamfn, fafn,
      chroms = chroms_to_query[1:2],
      BPPARAM = MulticoreParam(workers = 2)
    )
    expect_true(all(unique(seqnames(plp_mc)) == chroms_to_query[1:2]))
  }
})

unlink(c(bout, fout))


####### Other bam files

cbbam <- system.file("extdata", "5k_neuron_mouse_xf25_1pct_cbsort.bam", package = "raer")
tmp <- tempfile()
sort_cbbam <- sortBam(cbbam, tmp)
idx <- indexBam(sort_cbbam)

cbfa <- system.file("extdata", "mouse_tiny.fasta", package = "raer")

test_that("unsorted bam file fails", {
  expect_error(get_pileup(cbbam, cbfa))
})

test_that("single end libary types are respected", {
  fp <- FilterParam(library_type = "genomic-unstranded")
  plp <- get_pileup(sort_cbbam, cbfa, filterParam = fp)
  expect_true(all(strand(plp) == "+"))
})

test_that("poor quality reads get excluded with min_read_bqual", {
  res_no_filter <- get_pileup(bamfn, fafn,
    filterParam = FilterParam(
      min_base_quality = 0L,
      library_type = c("genomic-unstranded")
    )
  )

  bqual_cutoff <- c(0.25, 20.0)
  bam_recs <- readGAlignments(bamfn,
    param = ScanBamParam(what = c("qname", "qual"))
  )
  strand(bam_recs) <- "+"
  bad_reads <- lapply(
    as(mcols(bam_recs)$qual, "IntegerList"),
    function(x) (sum(x < bqual_cutoff[2]) / length(x)) >= bqual_cutoff[1]
  )
  bad_reads <- bam_recs[unlist(bad_reads)]
  bad_reads <- subsetByOverlaps(bad_reads, res_no_filter)

  res <- get_pileup(bamfn, fafn,
    filterParam = FilterParam(
      min_read_bqual = bqual_cutoff,
      min_base_quality = 0L,
      library_type = c("genomic-unstranded")
    )
  )

  res_no_filter <- subsetByOverlaps(res_no_filter, bad_reads)
  res <- subsetByOverlaps(res, bad_reads)

  n_diff <- (res_no_filter$nRef + res_no_filter$nVar) - (res$nRef + res$nVar)

  # we don't count deletions as coverage
  cov <- coverage(bad_reads, drop.D.ranges = TRUE)
  cov <- cov[cov != 0]
  cov <- as.integer(unlist(cov))

  expect_equal(n_diff, cov)
})

test_that("sites within short splice overhangs can be excluded", {
  # 5 spliced reads, 2 unspliced
  fp <- FilterParam(
    library_type = "genomic-unstranded",
    min_splice_overhang = 0,
    min_base_quality = 0
  )
  res <- get_pileup(bamfn, fafn, filterParam = fp, region = "SPCS3:220-220")
  expect_equal(length(res), 1)
  expect_equal(res$nRef, 7)

  # excludes 1 read 5' of splice site (SRR5564269.2688337, cigar 51M120N100M)
  fp <- FilterParam(
    library_type = "genomic-unstranded",
    min_splice_overhang = 52,
    min_base_quality = 0
  )
  res <- get_pileup(bamfn, fafn, filterParam = fp, region = "SPCS3:220-220")
  expect_equal(length(res), 1)
  expect_equal(res$nRef, 6)

  fp <- FilterParam(
    library_type = "genomic-unstranded",
    min_splice_overhang = 0,
    min_base_quality = 0
  )
  res <- get_pileup(bamfn, fafn, filterParam = fp, region = "SPCS3:350-350")
  expect_equal(length(res), 1)
  expect_equal(res$nRef, 5)

  # excludes 1 read 3' of splice site (SRR5564269.224850, cigar 73M120N78M)
  fp <- FilterParam(
    library_type = "genomic-unstranded",
    min_splice_overhang = 79,
    min_base_quality = 0
  )
  res <- get_pileup(bamfn, fafn, filterParam = fp, region = "SPCS3:350-350")
  expect_equal(length(res), 1)
  expect_equal(res$nRef, 4)

  # excludes all 5 spliced reads
  fp <- FilterParam(
    library_type = "genomic-unstranded",
    min_splice_overhang = 101,
    min_base_quality = 0
  )
  res <- get_pileup(bamfn, fafn, filterParam = fp, region = "SPCS3:350-350")
  expect_equal(length(res), 0)
})
unlink(c(tmp, sort_cbbam, idx))

test_that("chroms missing from fasta file will not be processed", {
  mfafn <- raer_example("mouse_tiny.fasta")
  expect_error(expect_warning(get_pileup(bamfn, mfafn, bedfn)))
})
