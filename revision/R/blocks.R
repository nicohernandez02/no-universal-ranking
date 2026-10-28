# Revision blocks R0-R7. Each takes the panel context (and, where needed, the
# R0 baseline), writes its tables to <outdir>/revision/ and returns
# list(<tables>, sentences = list(<tag> = "...")).

# ============================================================================
# R0  Country-year CRE baseline + agreement with the published model
# ============================================================================
block_r0 <- function(ctx) {
  base <- fit_cre(ctx$P, ctx$VARS)
  write_tab(base, "R0_baseline_collapsed_cre.csv", ctx)
  s <- "Published T03_main_coefficients.csv not found; agreement check skipped."
  agr <- NULL
  if (!is.null(ctx$T03)) {
    agr <- merge(base[, .(code, level, est)],
                 ctx$T03[, .(code, level, pub_est = estimate)], by = c("code", "level"))
    r_w <- agr[level == "within",  cor(est, pub_est)]
    r_b <- agr[level == "between", cor(est, pub_est)]
    write_tab(agr, "R0_agreement_with_published.csv", ctx)
    s <- sprintf(
      "Robustness variants are estimated on the weighted country-year panel, each against its own baseline on the same frame. That baseline %s the published respondent-level coefficients (correlation %.3f within and %.3f between countries; median absolute difference %.3f Cantril points).",
      if (min(r_w, r_b) >= .9) "closely reproduces"
      else "only partly reproduces [CHECK: agreement below .90 -- inspect R0_agreement_with_published.csv]",
      r_w, r_b, agr[, median(abs(est - pub_est))])
  }
  list(base = base, agreement = agr, sentences = list(R0 = s))
}

# ============================================================================
# R1  Coverage audit (C3)
# ============================================================================
block_r1 <- function(ctx) {
  P <- ctx$P; nP <- nrow(P); nC <- uniqueN(P$iso3)
  tab <- rbindlist(lapply(ctx$VARS, function(v) {
    mf <- paste0(v, "_miss"); obs <- P[[mf]] == 0
    w3 <- P[obs, .N, by = iso3][N >= ctx$min_waves, iso3]
    ever <- P[, .(any_obs = any(get(mf) == 0)), by = iso3]
    P2 <- merge(P[, .(iso3, m = get(mf))], ever, by = "iso3")
    data.table(code = v, label = ctx$LABEL[v], proximity = ctx$PROX[v],
               cy_observed = sum(obs), share_cy_observed = mean(obs),
               countries_observed = P[obs, uniqueN(iso3)],
               share_countries_observed = P[obs, uniqueN(iso3)] / nC,
               countries_3plus_observed_waves = length(w3),
               cy_identifying_within = P[obs & iso3 %in% w3, .N],
               share_cy_intermittent_fill = P2[m == 1 & any_obs == TRUE, .N] / nP,
               share_cy_never_fielded = P2[m == 1 & any_obs == FALSE, .N] / nP)
  }))
  setorder(tab, share_cy_observed)
  write_tab(tab, "R1_coverage_audit.csv", ctx)
  lo <- tab[share_cy_observed < .5]
  s <- sprintf(
    "Across the %d national predictors, the share of the %d panel country-years that are genuinely observed ranges from %.0f%% to %.0f%% (median %.0f%%), and the number of countries with an observed value ranges from %d to %d of %d. %d predictors are observed in fewer than half of the country-years; for these, intermittent country-mean fill accounts for a median %.0f%% and never-fielded fallback for a median %.0f%% of country-years.",
    nrow(tab), nP, 100 * min(tab$share_cy_observed), 100 * max(tab$share_cy_observed),
    100 * median(tab$share_cy_observed), min(tab$countries_observed),
    max(tab$countries_observed), nC, nrow(lo),
    100 * med(lo$share_cy_intermittent_fill), 100 * med(lo$share_cy_never_fielded))
  list(coverage = tab, sentences = list(R1 = s))
}

# ============================================================================
# R2  Observed-only re-estimation, predictor by predictor (C3)
#     Two scales: published (per pooled within-SD incl. filled zeros) and per
#     SD of the observed within deviations (attenuation-free).
# ============================================================================
block_r2 <- function(ctx, r0) {
  base <- r0$base
  fits <- rbindlist(lapply(ctx$VARS, function(v) {
    d  <- ctx$P[get(paste0(v, "_miss")) == 0]
    ok <- d[, .N, by = iso3][N >= ctx$min_waves, iso3]
    d[!iso3 %in% ok, (paste0(v, "_w")) := 0]
    if (uniqueN(d$iso3) < 20 || nrow(d) < 200) return(NULL)
    f <- tryCatch(fit_cre(d, ctx$VARS), error = function(e) NULL)
    if (is.null(f)) return(NULL)
    s_obs <- d[iso3 %in% ok, sd(get(paste0(v, "_w")))]
    f <- f[code == v]
    f[level == "within", `:=`(est_obs_sd = est * s_obs, se_obs_sd = se * s_obs)]
    f[, `:=`(n_cy = nrow(d), n_countries = uniqueN(d$iso3), n_within_countries = length(ok))]
    f
  }), fill = TRUE)
  fits[, p_fdr := p.adjust(p, "BH"), by = level][, sig := p_fdr < SET_ALPHA]
  tab <- compare_to_base(fits, base, "observed_only", ctx$LABEL)
  tab <- merge(tab, fits[, .(code, level, est_obs_sd, se_obs_sd, n_cy, n_countries,
                             n_within_countries)], by = c("code", "level"))
  write_tab(tab, "R2_observed_only.csv", ctx)
  w <- tab[level == "within"]; mr <- w[base_sig == TRUE, med(ratio)]
  s <- sprintf(
    "Re-estimating each predictor on its genuinely observed country-years only, %d of the %d within-country associations that are FDR-significant in the baseline remain significant with the same sign, %d lose significance and %d change sign; %d become significant. The median ratio of observed-only to baseline within coefficients is %.2f, %s. Between-country conclusions are unchanged for %d of %d predictors.",
    w[status == "retained", .N], w[base_sig == TRUE, .N], w[status == "lost", .N],
    w[sign_flip & base_sig, .N], w[status == "gained", .N], mr,
    if (is.na(mr)) "(no baseline-significant within associations)"
    else if (mr >= 1) "so filled country-years do not inflate the within estimates"
    else "indicating mild attenuation rather than inflation from filled country-years",
    tab[level == "between", sum(sig == base_sig & !sign_flip)], tab[level == "between", .N])
  list(observed_only = tab, sentences = list(R2 = s))
}

# ============================================================================
# R3  Stricter coverage thresholds (C3)
# ============================================================================
block_r3 <- function(ctx, r0, r1) {
  nP <- nrow(ctx$P)
  specs <- CJ(share = c(ctx$CFG$min_cyears_item / nP, SET_R3$cov_shares), min_ctry = SET_R3$cov_countries)
  tab <- rbindlist(lapply(seq_len(nrow(specs)), function(i) {
    sh <- specs$share[i]; mc <- specs$min_ctry[i]
    keep <- r1$coverage[share_cy_observed >= sh & countries_observed >= mc, code]
    keep <- union(intersect(keep, ctx$VARS), "ln_gdp")
    out <- compare_to_base(fit_cre(ctx$P, keep), r0$base,
                           sprintf("cov>=%.0f%%_cy & >=%d countries", 100 * sh, mc), ctx$LABEL)
    out[, n_predictors := length(keep)]
  }))
  sm <- tab[level == "within", .(n_pred = n_predictors[1], kept_sig = sum(status == "retained"),
                                 base_sig_present = sum(base_sig), lost = sum(status == "lost"),
                                 flips = sum(sign_flip & base_sig)), by = spec]
  write_tab(tab, "R3_coverage_thresholds.csv", ctx); write_tab(sm, "R3_summary.csv", ctx)
  st <- sm[spec == sprintf("cov>=50%%_cy & >=%d countries", min(SET_R3$cov_countries))]
  if (!nrow(st)) st <- sm[which.min(n_pred)]
  s <- sprintf(
    "Requiring each predictor to be observed in at least %s retains %d predictors; of the baseline FDR-significant within associations still in the model, %d of %d keep sign and significance (%d lost, %d sign changes). All threshold combinations are in Table R3.",
    sub("cov>=", "", sub("_cy", " of country-years", st$spec)), st$n_pred, st$kept_sig,
    st$base_sig_present, st$lost, st$flips)
  list(thresholds = tab, summary = sm, sentences = list(R3 = s))
}

# ============================================================================
# R4  Within-SD screening threshold (minor 4)
# ============================================================================
block_r4 <- function(ctx, r0) {
  ci <- ctx$cov_item
  sd_col <- intersect(c("within_sd_weighted", "within_sd"), names(ci))[1]
  scr <- ci[, .(code, label, within_sd = get(sd_col), n_cyears, n_countries)]
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

# ============================================================================
# R5  Country trends, first differences, placebo leads (C4)
# ============================================================================
block_r5 <- function(ctx) {
  P <- ctx$P; VARS <- ctx$VARS
  WV <- paste0(VARS, "_w")
  MV <- intersect(paste0(ctx$INCLUDED, "_miss"), names(P))
  MV <- MV[vapply(MV, function(m) uniqueN(P[[m]]) > 1, logical(1))]
  PW <- P[iso3 %in% ctx$WITHIN]
  tag <- function(d, spec) d[, .(spec, code = gsub("^d_|_w$", "", term), est, se, p)]

  a <- tag(fit_ols_cl(PW, "cantril", c(WV, MV)), "TWFE")
  b <- tag(fit_ols_cl(PW, "cantril", c(WV, MV), trend = TRUE), "TWFE + country trends")

  FD <- copy(PW); FD[, gap := year - shift(year), by = iso3]
  dc <- c("cantril", WV, MV)
  FD[, (paste0("d_", dc)) := lapply(.SD, function(x) x - shift(x)), by = iso3, .SDcols = dc]
  FD[, w_fd := 1 / (1 / w + 1 / shift(w)), by = iso3]
  fx <- paste0("d_", c(WV, MV))
  c1 <- tag(fit_ols_cl(FD[gap == 1], "d_cantril", fx, fe = "yearf", weights = "w_fd"),
            "First differences (consecutive waves)")
  c2 <- tag(fit_ols_cl(FD[!is.na(gap)], "d_cantril", c(fx, "gap"), fe = "yearf",
                       weights = "w_fd"), "First differences (all gaps)")[code != "gap"]

  LD <- copy(PW); LD[, next_gap := shift(year, type = "lead") - year, by = iso3]
  dl <- rbindlist(lapply(VARS, function(v) {
    lv <- paste0(v, "_w_lead")
    d <- copy(LD)[, (lv) := shift(get(paste0(v, "_w")), type = "lead"), by = iso3][next_gap == 1]
    o <- tryCatch(fit_ols_cl(d, "cantril", c(WV, MV, lv)), error = function(e) NULL)
    if (is.null(o) || !lv %in% o$term)
      return(data.table(spec = "Placebo lead", code = v, est = NA_real_, se = NA_real_, p = NA_real_))
    data.table(spec = "Placebo lead", code = v, est = o[term == lv, est], se = o[term == lv, se],
               p = o[term == lv, p], contemp_with_lead = o[term == paste0(v, "_w"), est],
               contemp_p_with_lead = o[term == paste0(v, "_w"), p])
  }), fill = TRUE)

  tab <- rbindlist(list(a, b, c1, c2, dl), fill = TRUE)[code %in% VARS]
  tab[, p_fdr := p.adjust(p, "BH"), by = spec][, sig := !is.na(p_fdr) & p_fdr < SET_ALPHA]
  tab[, label := ctx$LABEL[code]]
  wide <- dcast(tab[spec != "Placebo lead"], code + label ~ spec, value.var = c("est", "sig"))
  write_tab(tab, "R5_trends_fd_leads_long.csv", ctx); write_tab(wide, "R5_trends_fd_wide.csv", ctx)

  ll <- ""
  if (!is.null(ctx$T10)) {
    write_tab(ctx$T10, "R5_T10_lead_lag_AIC.csv", ctx)
    ll <- sprintf(" In the AIC comparison already produced by the pipeline (Table R5c), the lead specification fits materially better than the contemporaneous one (AIC difference > 2) for %d of %d predictors.",
                  sum(ctx$T10$order_ambiguous, na.rm = TRUE), nrow(ctx$T10))
  }
  sig0 <- tab[spec == "TWFE" & sig == TRUE, code]
  kept <- function(sp) {
    m <- merge(tab[spec == "TWFE", .(code, b0 = est)], tab[spec == sp, .(code, b1 = est, s1 = sig)],
               by = "code")[code %in% sig0]
    c(same_sign = m[, sum(sign(b0) == sign(b1), na.rm = TRUE)], sig = m[, sum(s1)])
  }
  kt <- kept("TWFE + country trends"); kf <- kept("First differences (consecutive waves)")
  s <- sprintf(
    "Of the %d within-country associations that are FDR-significant in the two-way fixed-effects baseline, %d keep their sign and %d remain significant after adding country-specific linear trends; under first differences across consecutive waves, %d keep their sign and %d remain significant. Placebo leads (next-wave predictor values entered alongside current values) are FDR-significant for %d of %d estimable predictors.%s",
    length(sig0), kt[["same_sign"]], kt[["sig"]], kf[["same_sign"]], kf[["sig"]],
    tab[spec == "Placebo lead", sum(sig)], tab[spec == "Placebo lead" & !is.na(est), .N], ll)
  list(long = tab, wide = wide, sentences = list(R5 = s))
}

# ============================================================================
# R6  Measurement comparability (C5)
# ============================================================================
block_r6 <- function(ctx, r0) {
  PROX <- ctx$PROX; VARS <- ctx$VARS
  sv <- union(VARS[PROX[VARS] == "structural"], "ln_gdp")
  a <- compare_to_base(fit_cre(ctx$P, sv), r0$base, "structural predictors only", ctx$LABEL)
  write_tab(a, "R6a_perceptual_excluded.csv", ctx)
  sents <- list(R6a = sprintf(
    "Dropping all %d perceptual predictors leaves %d structural predictors; their between-country coefficients change by a median %.0f%% and %d of %d keep their significance status and sign (within-country: %d of %d).",
    sum(PROX[VARS] == "perceptual"), length(sv), 100 * a[level == "between", med(abs(ratio - 1))],
    a[level == "between", sum(sig == base_sig & !sign_flip)], a[level == "between", .N],
    a[level == "within", sum(sig == base_sig & !sign_flip)], a[level == "within", .N]))
  out <- list(perceptual_excluded = a)

  if (!is.null(ctx$RS)) {
    RS <- copy(ctx$RS)[, iso3 := as.character(iso3)]
    RS[, heaping := share_0 + share_10]
    RS[, region := if (requireNamespace("countrycode", quietly = TRUE))
      countrycode::countrycode(iso3, "iso3c", "region", warn = FALSE) else NA_character_]
    rv <- intersect(c("yes_balanced", "heaping"), names(RS))
    desc <- RS[, .(countries = uniqueN(iso3), cantril_mean = mean(cantril_mean),
                   cantril_sd = mean(cantril_sd), share_0 = mean(share_0),
                   share_10 = mean(share_10), share_5 = mean(share_5),
                   yes_balanced = if ("yes_balanced" %in% names(RS)) mean(yes_balanced, na.rm = TRUE) else NA_real_),
               by = region][order(region)]
    byc <- RS[, lapply(.SD, mean, na.rm = TRUE), by = iso3, .SDcols = rv]
    write_tab(desc, "R6b_response_distributions_by_region.csv", ctx)
    write_tab(byc, "R6b_response_style_by_country.csv", ctx)

    d <- merge(ctx$P, RS[, c("iso3", "year", rv), with = FALSE], by = c("iso3", "year"), all.x = TRUE)
    d <- ctx$impute_country_mean(d, rv); d <- ctx$decompose(d, rv)
    for (v in rv) d[!iso3 %in% ctx$WITHIN, (paste0(v, "_w")) := 0]
    b1 <- compare_to_base(fit_cre(d, VARS, extra = c(paste0(rv, "_w"), paste0(rv, "_b"))),
                          r0$base, "controlling response style", ctx$LABEL)
    hi <- byc[, lapply(.SD, function(x) x >= quantile(x, .9, na.rm = TRUE)), .SDcols = rv]
    drop_c <- byc$iso3[apply(as.matrix(hi), 1, any)]
    b2 <- compare_to_base(fit_cre(ctx$P[!iso3 %in% drop_c], VARS), r0$base,
                          sprintf("excluding %d high response-style countries", length(drop_c)), ctx$LABEL)
    b <- rbind(b1, b2); write_tab(b, "R6b_response_style_models.csv", ctx)
    pb <- b[level == "between" & PROX[code] == "perceptual"]
    sents$R6b <- sprintf(
      "Response distributions differ across regions (Table R6b): the mean share of Cantril answers at 0 or 10 ranges from %.1f%% to %.1f%% and the balanced yes-rate from %.2f to %.2f. Controlling for acquiescence and Cantril heaping (decomposed within and between) changes the between-country coefficients of perceptual items by a median %.0f%%, and excluding the %d countries with the most extreme response styles leaves %d of %d perceptual between-country conclusions unchanged.",
      100 * min(desc$share_0 + desc$share_10), 100 * max(desc$share_0 + desc$share_10),
      min(desc$yes_balanced, na.rm = TRUE), max(desc$yes_balanced, na.rm = TRUE),
      100 * pb[spec == "controlling response style", med(abs(ratio - 1))], length(drop_c),
      pb[spec != "controlling response style", sum(sig == base_sig & !sign_flip)],
      pb[spec != "controlling response style", .N])
    out <- c(out, list(regions = desc, by_country = byc, response_style = b))
  } else sents$R6b <- "Response-style tables missing (hook did not run); R6b skipped."
  c(out, list(sentences = sents))
}

# ============================================================================
# R7  Predictive baselines (C6). Same learner and splits, different features.
# ============================================================================
block_r7 <- function(ctx, ML) {
  V <- ctx$VARS; L <- paste0(V, "_lvl"); names(L) <- V
  if (!is.null(SET_R7$n_max) && nrow(ML) > SET_R7$n_max) {
    set.seed(SET_R7$seed)
    ML <- ML[ML[, .I[sample(.N, max(min(.N, 30), round(.N * SET_R7$n_max / nrow(ML))))],
                by = .(iso3, year)]$V1]
  }
  FS <- list(
    "F1 GDP only"                  = L["ln_gdp"],
    "F2 GDP within + between"      = c("ln_gdp_w", "ln_gdp_b"),
    "F3 Country means only"        = c(ctx$B_VARS, ctx$M_VARS),
    "F4 Within only"               = c(ctx$W_VARS, ctx$M_VARS),
    "F5 Pooled (undecomposed)"     = c(L, ctx$M_VARS),
    "F6 Full CRE (within+between)" = c(ctx$W_VARS, ctx$B_VARS, ctx$M_VARS))
  r2 <- function(y, yh, w = rep(1, length(y))) 1 - sum(w * (y - yh)^2) / sum(w * (y - weighted.mean(y, w))^2)
  ev <- function(tr, te, design, rep) rbindlist(lapply(names(FS), function(fs) {
    X <- as.matrix(ML[tr, FS[[fs]], with = FALSE]); Xt <- as.matrix(ML[te, FS[[fs]], with = FALSE])
    y <- ML$cantril[tr]; yt <- ML$cantril[te]
    k <- apply(X, 2, function(z) sd(z) > 0); X <- X[, k, drop = FALSE]; Xt <- Xt[, k, drop = FALSE]
    b <- lm.fit(cbind(1, X), y)$coefficients; b[is.na(b)] <- 0
    pr <- list(lin = as.numeric(cbind(1, Xt) %*% b))
    if (SET_R7$enet && fs %in% SET_R7$enet_sets && requireNamespace("glmnet", quietly = TRUE)) {
      set.seed(SET_R7$seed)
      cv <- glmnet::cv.glmnet(X, y, alpha = 0.5, nfolds = 5)
      pr$enet <- as.numeric(predict(cv, Xt, s = "lambda.min"))
    }
    rbindlist(lapply(names(pr), function(mod) {
      ag <- data.table(cy = paste(ML$iso3[te], ML$year[te]), y = yt, yh = pr[[mod]], w = ML$wt[te])[
        , .(y = weighted.mean(y, w), yh = weighted.mean(yh, w), w = sum(w)), by = cy]
      data.table(design = design, rep = rep, features = fs, model = mod,
                 r2_respondent = r2(yt, pr[[mod]]), r2_country_year = r2(ag$y, ag$yh, ag$w),
                 n_test = length(te), n_test_cy = nrow(ag))
    }))
  }))
  set.seed(SET_R7$seed)
  ct <- unique(ML[, .(iso3, dev)]); res <- list()
  for (r in seq_len(SET_R7$reps)) {
    ho <- sample(ct$iso3, ceiling(SET_R7$holdout * nrow(ct)))
    res[[length(res) + 1]] <- ev(which(!ML$iso3 %in% ho), which(ML$iso3 %in% ho), "Country holdout", r)
    hs <- ct[, .(iso3 = iso3[sample.int(.N, ceiling(SET_R7$holdout * .N))]), by = dev]$iso3
    res[[length(res) + 1]] <- ev(which(!ML$iso3 %in% hs), which(ML$iso3 %in% hs),
                                 "Development-stratified country holdout", r)
  }
  cy <- quantile(ML$year, .75)
  res[[length(res) + 1]] <- ev(which(ML$year <= cy), which(ML$year > cy), "Temporal split", 1)
  all <- rbindlist(res)
  sm <- all[, .(r2_respondent = mean(r2_respondent), r2_respondent_sd = sd(r2_respondent),
                r2_country_year = mean(r2_country_year), reps = .N),
            by = .(design, model, features)][order(design, model, features)]
  write_tab(all, "R7_predictive_baselines_all_reps.csv", ctx)
  write_tab(sm, "R7_predictive_baselines_summary.csv", ctx)
  g <- function(fs, col = "r2_respondent")
    sm[design == "Development-stratified country holdout" & features == fs & model == "lin", get(col)]
  f <- names(FS)[c(1, 3, 4, 5, 6)]
  s <- sprintf(
    "Against simpler specifications on identical development-stratified country holdouts (linear learner), out-of-sample respondent-level R-squared is %.3f for GDP alone, %.3f for country means only, %.3f for within components only, %.3f for the pooled undecomposed predictors and %.3f for the full level-separated specification. At the country-year level the corresponding values are %.3f, %.3f, %.3f, %.3f and %.3f. R-squared in the main text is computed at the respondent level, unweighted; the country-year version weights each country-year by its summed survey weight.",
    g(f[1]), g(f[2]), g(f[3]), g(f[4]), g(f[5]),
    g(f[1], "r2_country_year"), g(f[2], "r2_country_year"), g(f[3], "r2_country_year"),
    g(f[4], "r2_country_year"), g(f[5], "r2_country_year"))
  list(all = all, summary = sm, sentences = list(R7 = s))
}

# ============================================================================
# R8  Conventional specifications vs the CRE decomposition (C2)
#     Same country-year panel, same predictors, same missingness flags.
#     Each raw predictor is filled like the main pipeline (country mean for
#     intermittent gaps, panel mean where never fielded) and scaled by its
#     pooled SD, so the pooled / RE / FE slopes are per pooled SD.
# ============================================================================
block_r8 <- function(ctx, r0) {
  P <- copy(ctx$P); VARS <- ctx$VARS
  MV <- intersect(paste0(setdiff(VARS, "ln_gdp"), "_miss"), names(P))
  MV <- MV[vapply(MV, function(m) uniqueN(P[[m]]) > 1, logical(1))]
  RV <- paste0(VARS, "_raw")
  for (v in VARS) {
    x <- as.numeric(P[[v]])
    cm <- ave(x, P$iso3, FUN = function(z) if (all(is.na(z))) NA_real_ else mean(z, na.rm = TRUE))
    x <- ifelse(is.na(x), cm, x); x[is.na(x)] <- mean(x, na.rm = TRUE)
    set(P, j = paste0(v, "_raw"), value = (x - mean(x)) / sd(x))
  }
  fix <- function(o, spec) {
    o <- o[term %in% RV]
    o[, `:=`(spec = spec, code = sub("_raw$", "", term))]
    o[, p_fdr := p.adjust(p, "BH")][, sig := p_fdr < SET_ALPHA]
    o[, .(spec, code, est, se, p, p_fdr, sig)]
  }
  pooled <- fix(fit_ols_cl(P, "cantril", c(RV, MV), fe = "yearf"), "Pooled OLS (year FE)")
  fe     <- fix(fit_ols_cl(P, "cantril", c(RV, MV)), "Country FE (two-way)")
  d <- copy(P)[, `:=`(yearf = droplevels(factor(yearf)), iso3f = droplevels(factor(iso3f)))]
  fitter <- if (requireNamespace("lmerTest", quietly = TRUE)) lmerTest::lmer else lme4::lmer
  m <- suppressMessages(suppressWarnings(fitter(
    as.formula(paste("cantril ~", paste(c(RV, MV, "yearf"), collapse = " + "), "+ (1|iso3f)")),
    data = d, weights = w, REML = TRUE,
    control = lme4::lmerControl(optimizer = "bobyqa", calc.derivs = FALSE))))
  cf <- as.data.table(coef(summary(m)), keep.rownames = "term")
  setnames(cf, c("Estimate", "Std. Error"), c("est", "se"))
  pcol <- grep("^Pr\\(", names(cf), value = TRUE)
  cf[, p := if (length(pcol)) get(pcol) else 2 * pnorm(-abs(est / se))]
  re <- fix(cf, "Random effects (no Mundlak means)")

  conv <- rbindlist(list(pooled, re, fe))
  cre  <- r0$base[, .(spec = paste0("CRE ", level), code, est, se, p, p_fdr, sig)]
  long <- rbindlist(list(conv, cre))[, label := ctx$LABEL[code]]
  wide <- dcast(long, code + label ~ spec, value.var = c("est", "sig"))
  write_tab(long, "R8_conventional_vs_cre_long.csv", ctx)
  write_tab(wide, "R8_conventional_vs_cre_wide.csv", ctx)

  # where does each conventional estimator put the evidence?
  W <- cre[spec == "CRE within", .(code, w_sig = sig, w_est = est)]
  B <- cre[spec == "CRE between", .(code, b_sig = sig, b_est = est)]
  X <- merge(merge(W, B, by = "code"), pooled[, .(code, pl_sig = sig, pl_est = est)], by = "code")
  X <- merge(X, fe[, .(code, fe_sig = sig)], by = "code")
  only_b  <- X[b_sig & !w_sig, .N]; only_w <- X[w_sig & !b_sig, .N]
  pl_hide <- X[(w_sig | b_sig) & !pl_sig, .N]
  pl_mix  <- X[pl_sig & w_sig & b_sig & sign(w_est) != sign(b_est), .N]
  fe_miss <- X[b_sig & !w_sig & !fe_sig, .N]
  g <- function(sp) long[spec == sp & code == "ln_gdp", est]
  s <- sprintf(paste(
    "On the same country-year panel, a pooled specification gives GDP per capita a single slope of %.3f per pooled SD,",
    "a random-effects model without Mundlak means %.3f and two-way country fixed effects %.3f, against %.3f between and %.3f within countries under CRE.",
    "Across the catalogue, %d predictors are established only between countries and %d only within; country fixed effects, which discard the between comparison,",
    "leave %d of the between-only associations undetected, and the pooled model fails to establish %d of the associations that CRE establishes at one level or the other."),
    g("Pooled OLS (year FE)"), g("Random effects (no Mundlak means)"), g("Country FE (two-way)"),
    g("CRE between"), g("CRE within"), only_b, only_w, fe_miss, pl_hide)
  list(long = long, wide = wide, sentences = list(R8 = s))
}
