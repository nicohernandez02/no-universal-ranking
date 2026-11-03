args <- commandArgs(TRUE); chunk <- as.integer(args[1]); B <- as.integer(args[2])
source("extra/common.R")
set.seed(20261103 + chunk)
cs <- unique(P$iso3)
res <- vector("list", B)
for (b in seq_len(B)) {
  s <- sample(cs, length(cs), replace = TRUE)
  d <- rbindlist(lapply(seq_along(s), function(k) { x <- P[iso3 == s[k]]; x[, `:=`(iso3 = paste0(s[k], "_", k), iso3f = paste0(s[k], "_", k))]; x }))
  r <- tryCatch(fit_cre(d, VARS), error = function(e) NULL)
  if (!is.null(r)) res[[b]] <- r[, .(code, level, est)][, rep := (chunk - 1) * B + b]
}
saveRDS(rbindlist(res), sprintf("%s/boot_%02d.rds", OUT, chunk)); cat("done", chunk, "\n")
