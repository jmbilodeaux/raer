#' Download GSE99249 BAM files and related data
#'
#' @description  This function will download ~ 250 MB of data.
#'
#' @param path path to directory to download data
#' @returns A named list with paths to BAM files, a FASTA file and a bed
#' file of known editing sites from hg38 chromosome 18.
#'
#' @rdname download_data
#'
#' @examples
#' \dontrun{
#' td <- tempdir()
#' download_GSE99249(td)
#' }
#' @export
download_GSE99249 <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  options(timeout = max(1000, getOption("timeout")))
  baseURL <- "https://raer-test-data.s3.us-west-2.amazonaws.com/GSE99249/"

  bam_fns <- c(
    "SRR5564260_dedup_sorted.bam",
    "SRR5564261_dedup_sorted.bam",
    "SRR5564269_dedup_sorted.bam",
    "SRR5564270_dedup_sorted.bam",
    "SRR5564271_dedup_sorted.bam",
    "SRR5564277_dedup_sorted.bam"
  )
  GSE99249_files <- list(
    bams = bam_fns,
    bai = paste0(bam_fns, ".bai"),
    fasta = "chr18.fasta.bgz",
    bed = "rediportal_hg38_chr18.bed.gz"
  )

  fids <- list()
  for (i in seq_along(GSE99249_files)) {
    fns <- GSE99249_files[[i]]
    ftype <- names(GSE99249_files)[i]
    out_fns <- unlist(lapply(fns, function(x) {
      fn <- file.path(path, x)
      if (!file.exists(fn)) {
        # wb  necessary to avoid windows mangling line endings...
        download.file(paste0(baseURL, x), fn, mode = "wb")
      }
      fn
    }))
    names(out_fns) <- fns
    fids[[ftype]] <- out_fns
  }
  fids
}

#' Download NA12878 BAM files and related data
#'
#' @description This function will download ~ 5 GB of data.
#' @param path path to directory to download data
#'
#' @returns A named list with paths to an RNA-seq and WGS BAM file, and a FASTA file
#' from hg38 chromosome 4.
#'
#' @rdname download_data
#' @examples
#' \dontrun{
#' td <- tempdir()
#' download_NA12878(td)
#' }
#' @export
download_NA12878 <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  baseURL <- "https://raer-test-data.s3.us-west-2.amazonaws.com/NA12878/"

  bam_fns <- c(
    "ERR262996_dedup_chr4_sub.bam",
    "SRR1258218_Aligned.sorted.dedup_sub.bam"
  )
  NA12878_files <- list(
    bams = bam_fns,
    bai = paste0(bam_fns, ".bai"),
    fasta = "hg38_chr4.fa.bgz",
    snps = "chr4snps.bed.gz",
    rmsk = "rmsk_hg38.tsv.gz"
  )

  options(timeout = max(5000, getOption("timeout")))

  fids <- list()
  for (i in seq_along(NA12878_files)) {
    fns <- NA12878_files[[i]]
    ftype <- names(NA12878_files)[i]
    out_fns <- unlist(lapply(fns, function(x) {
      fn <- file.path(path, x)
      if (!file.exists(fn)) {
        # wb  necessary to avoid windows mangling line endings...
        download.file(paste0(baseURL, x), fn, mode = "wb")
      }
      fn
    }))
    names(out_fns) <- fns
    fids[[ftype]] <- out_fns
  }
  fids
}



#' Download 10x PMBC bam file and related data
#'
#' @description This function will download < 1 GB of data.
#' @param path path to directory to download data
#'
#' @returns A named list with paths to bam file, fasta file,
#' bed file of editing_sites, and an .rds file with a
#' SingleCellExperiment
#' @rdname download_data
#' @examples
#' \dontrun{
#' td <- tempdir()
#' download_human_pbmc(td)
#' }
#' @export
download_human_pbmc <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  baseURL <- "https://raer-test-data.s3.us-west-2.amazonaws.com/10x_human_pbmc/"

  bam_fn <- c("10k_PBMC_3p_nextgem_Chromium_X_intron_cbsorted_genome_rediportal_xf25_chr16.bam")
  pbmc_files <- list(
    bams = bam_fn,
    fasta = "hg38_chr16.fasta.bgz",
    edit_sites = "rediportal_sites.bed.gz",
    sce = "sce.rds"
  )

  options(timeout = max(5000, getOption("timeout")))

  fids <- list()
  for (i in seq_along(pbmc_files)) {
    fns <- pbmc_files[[i]]
    ftype <- names(pbmc_files)[i]
    out_fns <- unlist(lapply(fns, function(x) {
      fn <- file.path(path, x)
      if (!file.exists(fn)) {
        # wbnecessary to avoid windows mangling line endings...
        download.file(paste0(baseURL, x), fn, mode = "wb")
      }
      fn
    }))
    names(out_fns) <- fns
    fids[[ftype]] <- out_fns
  }
  fids
}
