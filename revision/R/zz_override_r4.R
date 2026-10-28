# Override of block_r4: same logic, but the within-SD screen is recomputed on
# survey-weighted country-year means, as in the submitted paper.
block_r4 <- function(ctx, r0) {
  ci <- ctx$cov_item
  sd_col <- intersect(c("within_sd_weighted", "within_sd"), names(ci))[1]
  scr <- ci[, .(code, label, within_sd = get(sd_col), n_cyears, n_countries)]
  # The submitted paper screens on the WEIGHTED within-country SD of country-year
  # means. CY_ALL holds survey-weighted country-year means for every candidate,
  # so recompute the screen statistic from it (the repository's cov_item is unweighted).
  if (!is.null(ctx$CY_ALL)) {
    A <- copy(ctx$CY_ALL)
    wsd <- rbindlist(lapply(intersect(scr$code, names(A)), function(cc) {
      s <- A[!is.na(get(cc)), .(sdw = if (.N > 1) sd(get(cc)) else NA_real_), by = iso3]
      data.table(code = cc, within_sd_w = mean(s$sdw, na.rm = TRUE))
    }))
    scr <- merge(scr, wsd, by = "code", all.x = TRUE)
    scr[!is.na(within_sd_w), within_sd := within_sd_w][, within_sd_w := NULL]
  }
  scr[, cov_ok := n_cyears >= ctx$CFG$min_cyears_item & n_countries >= ctx$CFG$min_countries_item]
  labels <- ctx$LABEL
  res <- list(); sm <- list()
  for (th in SET_R4$sd_thresholds) {
    keep <- scr[cov_ok & within_sd >= th, code]
    added <- setdiff(keep, ctx$INCLUDED); removed <- setdiff(ctx$INCLUDED, keep)
    d <- ctx$P; vars <- union(intersect(keep, ctx$INCLUDED), "ln_gdp")
    if (length(added)) {
      if (is.null(ctx$CY_ALL)) {
        sm[[length(sm) + 1]] <- data.table(threshold = th, n_predictors = NA_integer_,
          added = paste(added, collapse = "; "), removed = paste(removed, collapse = "; "),
          note = "hook output missing: cannot estimate added items")
        next
      }
      A <- copy(ctx$CY_ALL)[, iso3 := as.character(iso3)]
      ext <- merge(ctx$P[, .(iso3, year)], A[, c("iso3", "year", added), with = FALSE],
                   by = c("iso3", "year"), all.x = TRUE)
      ext <- ctx$impute_country_mean(ext, added); ext <- ctx$decompose(ext, added)
      for (v in added) ext[!iso3 %in% ctx$WITHIN, (paste0(v, "_w")) := 0]
      d <- merge(ctx$P, ext[, c("iso3", "year", paste0(added, "_w"), paste0(added, "_b"),
                                 paste0(added, "_miss")), with = FALSE], by = c("iso3", "year"))
      vars <- c(vars, added)
      labels[added] <- ctx$CAT[match(added, code), label]
    }
    sp <- sprintf("within_sd>=%.3f", th)
    fit <- fit_cre(d, vars)
    out <- compare_to_base(fit, r0$base, sp, labels)
    new <- fit[!code %in% r0$base$code]
    if (nrow(new)) out <- rbind(out, new[, .(spec = sp, code, label = labels[code], level,
      est, se, p_fdr, sig, status = fifelse(sig, "new item, significant", "new item, n.s."))],
      fill = TRUE)
    res[[length(res) + 1]] <- out
    sm[[length(sm) + 1]] <- data.table(threshold = th, n_predictors = length(vars),
      added = paste(added, collapse = "; "), removed = paste(removed, collapse = "; "),
      n_sig_within = fit[level == "within", sum(sig)],
      n_sig_between = fit[level == "between", sum(sig)],
      base_sig_within_retained = out[level == "within" & status == "retained", .N], note = "")
  }
  tab <- rbindlist(res, fill = TRUE); sm <- rbindlist(sm, fill = TRUE)
  near <- scr[cov_ok & within_sd >= min(SET_R4$sd_thresholds) & within_sd <= max(SET_R4$sd_thresholds)][order(within_sd)]
  write_tab(tab, "R4_within_sd_threshold.csv", ctx); write_tab(sm, "R4_summary.csv", ctx)
  write_tab(near, "R4_items_near_threshold.csv", ctx)
  base_sig_w <- r0$base[level == "within" & sig, code]
  stable <- tab[level == "within" & code %in% base_sig_w,
                .(ok = all(status == "retained")), by = code][, sum(ok)]
  s <- sprintf(
    "Moving the .05 within-country SD screen between %.2f and %.2f yields between %s national predictors (baseline %d); across these thresholds the number of FDR-significant within-country associations ranges from %s, and %d of the %d baseline within-country findings retain sign and significance at every threshold at which they are estimated.",
    min(SET_R4$sd_thresholds), max(SET_R4$sd_thresholds),
    paste(range(sm$n_predictors, na.rm = TRUE), collapse = " and "), length(ctx$VARS),
    paste(range(sm$n_sig_within, na.rm = TRUE), collapse = " to "), stable, length(base_sig_w))
  list(by_threshold = tab, summary = sm, near = near, sentences = list(R4 = s))
}

