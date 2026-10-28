# Settings for the revision analyses. Each block reads only its own setting,
# so changing one value re-runs only that block when you call tar_make().

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x

SET_ALPHA <- 0.05                                   # FDR level (all blocks)

SET_R3 <- list(cov_shares    = c(0.25, 0.50),       # share of country-years observed
               cov_countries = c(60, 100))          # minimum countries observed

SET_R4 <- list(sd_thresholds = c(0.03, 0.04, 0.05, 0.06, 0.075, 0.10))

SET_R7 <- list(reps     = 10,      # repeated country holdouts per design
               holdout  = 0.25,    # share of countries held out
               n_max    = NULL,    # NULL = all respondents; e.g. 1e6 to speed up
               enet     = TRUE,    # elastic net on the sets below
               enet_sets = c("F5 Pooled (undecomposed)", "F6 Full CRE (within+between)"),
               seed     = 20260724)
