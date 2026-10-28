# Estimation helpers shared by the revision blocks.

med <- function(x) if (length(x) && any(!is.na(x))) median(x, na.rm = TRUE) else NA_real_

# Write one block table to <outdir>/revision/<name>
write_tab <- function(x, name, ctx) {
  d <- file.path(ctx$CFG$outdir, "revision"); dir.create(d, FALSE, TRUE)
  fwrite(x, file.path(d, name)); invisible(x)
}

# CRE on the country-year panel (pipeline Tier-2 form): country random
# intercept, year fixed effects, weights = respondents per country-year.
fit_cre <- function(d, vars, extra = NULL, mflags = TRUE, alpha = SET_ALPHA) {
  d <- copy(d)[, `:=`(yearf = droplevels(factor(yearf)), iso3f = droplevels(factor(iso3f)))]
  wv <- paste0(vars, "_w"); bv <- paste0(vars, "_b")
  mv <- if (mflags) intersect(paste0(setdiff(vars, "ln_gdp"), "_miss"), names(d)) else NULL
  mv <- mv[vapply(mv, function(m) uniqueN(d[[m]]) > 1, logical(1))]
  f <- as.formula(paste("cantril ~", paste(c(wv, bv, mv, extra, "yearf"), collapse = " + "),
                        "+ (1|iso3f)"))
  fitter <- if (requireNamespace("lmerTest", quietly = TRUE)) lmerTest::lmer else lme4::lmer
  m <- suppressMessages(suppressWarnings(
    fitter(f, data = d, weights = w, REML = TRUE,
           control = lme4::lmerControl(optimizer = "bobyqa", calc.derivs = FALSE))))
  cf <- as.data.table(coef(summary(m)), keep.rownames = "term")
  setnames(cf, c("Estimate", "Std. Error"), c("est", "se"))
  pcol <- grep("^Pr\\(", names(cf), value = TRUE)
  cf[, p := if (length(pcol)) get(pcol) else 2 * pnorm(-abs(est / se))]
  cf <- cf[grepl("_(w|b)$", term)]
  cf[, `:=`(level = fifelse(grepl("_w$", term), "within", "between"),
            code  = sub("_(w|b)$", "", term))]
  cf[, p_fdr := p.adjust(p, "BH"), by = level][, sig := p_fdr < alpha]
  cf[, .(code, level, est, se, p, p_fdr, sig)]
}

# Weighted OLS with country/year dummies (optional country-specific linear
# trends) and CR1 standard errors clustered by country. Base R only.
fit_ols_cl <- function(d, y, xs, fe = c("iso3f", "yearf"), trend = FALSE,
                       weights = "w", cluster = "iso3") {
  d <- d[complete.cases(d[, c(y, xs, weights), with = FALSE])]
  d[, `:=`(yearf = droplevels(factor(yearf)), iso3f = droplevels(factor(iso3f)))]
  if (trend) d[, trend := year - mean(year), by = iso3]
  f <- as.formula(paste(y, "~", paste(c(xs, fe, if (trend) "iso3f:trend"), collapse = " + ")))
  m <- lm(f, data = d, weights = d[[weights]])
  keep <- !is.na(coef(m)); X <- model.matrix(m)[, keep, drop = FALSE]; b <- coef(m)[keep]
  sw <- sqrt(d[[weights]]); Xw <- X * sw; ew <- residuals(m) * sw
  bread <- tryCatch(solve(crossprod(Xw)), error = function(err) MASS::ginv(crossprod(Xw)))
  sc <- rowsum(Xw * ew, d[[cluster]]); G <- nrow(sc); N <- nrow(X); K <- ncol(X)
  V <- bread %*% crossprod(sc) %*% bread * (G / (G - 1)) * ((N - 1) / (N - K))
  out <- data.table(term = names(b), est = b, se = sqrt(diag(V)))[term %in% xs]
  out[, p := 2 * pt(-abs(est / se), df = G - 1)]
  out
}

compare_to_base <- function(alt, base, spec, labels) {
  x <- merge(base[, .(code, level, base_est = est, base_se = se,
                      base_p_fdr = p_fdr, base_sig = sig)],
             alt[, .(code, level, est, se, p_fdr, sig)], by = c("code", "level"))
  x[, `:=`(spec = spec, ratio = est / base_est,
           sign_flip = sign(est) != sign(base_est),
           status = fifelse(base_sig & sig & sign(est) == sign(base_est), "retained",
                    fifelse(base_sig & !sig, "lost",
                    fifelse(!base_sig & sig, "gained", "unchanged (n.s.)"))))]
  x[, label := labels[code]]
  setcolorder(x, c("spec", "code", "label", "level"))
  x[]
}

# Collect every block's sentence into one markdown file.
write_sentences <- function(ctx, blocks) {
  d <- file.path(ctx$CFG$outdir, "revision"); dir.create(d, FALSE, TRUE)
  f <- file.path(d, "REVISION_SENTENCES.md")
  txt <- c("# Generated sentences for the revision (paste, do not retype)", "",
           unlist(lapply(blocks, function(b)
             unlist(lapply(names(b$sentences), function(n)
               c(sprintf("**%s.** %s", n, b$sentences[[n]]), ""))))))
  writeLines(txt, f, useBytes = TRUE)
  f
}
