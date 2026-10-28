# R9  Lead-lag AIC comparison (Reviewer comment 4: "report the lead-lag
#     diagnostics mentioned in the manuscript"). Same logic as Section 10 of
#     the main pipeline (Tier 2, collapsed country-year panel): for each
#     predictor, contemporaneous, lagged and lead within-country terms are fitted
#     on IDENTICAL rows, and the predictor is flagged order-ambiguous only when
#     the lead model's AIC is more than 2 below the contemporaneous model's.
block_r9 <- function(ctx) {
  P <- copy(ctx$P); setorder(P, iso3, year)
  out <- rbindlist(lapply(ctx$VARS, function(v) {
    wv <- paste0(v, "_w"); bv <- paste0(v, "_b")
    if (!all(c(wv, bv) %in% names(P))) return(NULL)
    d <- copy(P)
    d[, lagv  := shift(get(wv), 1, type = "lag"),  by = iso3]
    d[, leadv := shift(get(wv), 1, type = "lead"), by = iso3]
    d <- d[!is.na(get(wv)) & !is.na(lagv) & !is.na(leadv)]
    d[, `:=`(yearf = droplevels(factor(yearf)), iso3f = droplevels(factor(iso3)))]
    fitr <- function(term) {
      f <- as.formula(sprintf("cantril ~ %s + %s + yearf + (1|iso3f)", term, bv))
      m <- tryCatch(suppressMessages(suppressWarnings(lme4::lmer(
             f, data = d, weights = w, REML = FALSE,
             control = lme4::lmerControl(optimizer = "bobyqa", calc.derivs = FALSE)))),
             error = function(e) NULL)
      if (is.null(m)) return(c(NA_real_, NA_real_))
      c(lme4::fixef(m)[term], AIC(m))
    }
    con <- fitr(wv); lag <- fitr("lagv"); led <- fitr("leadv")
    data.table(code = v, label = ctx$LABEL[v], n_obs = nrow(d),
               beta_contemp = con[1], aic_contemp = con[2],
               beta_lag = lag[1], aic_lag = lag[2],
               beta_lead = led[1], aic_lead = led[2],
               aic_lead_minus_contemp = led[2] - con[2],
               aic_lag_minus_contemp  = lag[2] - con[2],
               order_ambiguous = !is.na(led[2]) & !is.na(con[2]) & (led[2] < con[2] - 2))
  }), fill = TRUE)
  write_tab(out, "R9_lead_lag_AIC.csv", ctx)
  s <- sprintf("In the AIC comparison on identical rows, the lead specification fits materially better than the contemporaneous one (AIC lower by more than 2) for %d of %d predictors; the median AIC difference (lead minus contemporaneous) is %.1f.",
               sum(out$order_ambiguous, na.rm = TRUE), nrow(out), median(out$aic_lead_minus_contemp, na.rm = TRUE))
  writeLines(s, file.path(ctx$CFG$outdir, "revision", "R9_sentence.txt"))
  list(tab = out, sentences = list(R9 = s))
}
