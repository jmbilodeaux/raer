#ifndef raer_pileup_H
#define raer_pileup_H

int run_cpileup(const char** cbampath,
                int n,
                char* fapath,
                char* cregion,
                char* outfn,
                char* bedfn,
                int* min_reads,
                int max_depth,
                int min_baseQ,
                int* min_mapQ,
                int* libtype,
                int* b_flags,
                int n_align,
                char* n_align_tag,
                int* event_filters,
                int only_keep_variants,
                char* outbam,
                SEXP ext);

#endif
