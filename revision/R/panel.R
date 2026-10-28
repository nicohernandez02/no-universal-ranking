# Builds the revision panel by running the `cfg` (and `preflight`, if present)
# and `clean` chunks of the MAIN pipeline .qmd, unchanged, in a private
# environment. The response-style hook is injected automatically just before
# `rm(DT)`, so the .qmd itself is never edited.

# ---- read one chunk's code from the .qmd, by label -------------------------
extract_chunk <- function(qmd, label) {
  l <- readLines(qmd, encoding = "UTF-8", warn = FALSE)
  open  <- grep("^```\\{r", l)
  close <- grep("^```\\s*$", l)
  for (i in open) {
    j <- min(close[close > i])
    hdr <- l[i]; body <- if (j > i + 1) l[(i + 1):(j - 1)] else character(0)
    lab_hdr <- sub("^```\\{r[ ,]*([A-Za-z0-9_.-]*).*$", "\\1", hdr)
    lab_opt <- sub("^#\\|\\s*label:\\s*", "", grep("^#\\|\\s*label:", body, value = TRUE))
    if (identical(lab_hdr, label) || label %in% trimws(lab_opt)) return(body)
  }
  NULL
}

# The code that defines the panel. A target of its own: if these chunks do not
# change, editing anything else in the .qmd (figures, prose) re-runs nothing.
panel_code <- function(qmd) {
  chunks <- c("cfg", "preflight", "clean")
  code <- lapply(chunks, function(lb) extract_chunk(qmd, lb))
  names(code) <- chunks
  if (is.null(code$cfg) || is.null(code$clean))
    stop("Could not find chunks labelled `cfg` and `clean` in ", qmd)
  code <- code[!vapply(code, is.null, logical(1))]
  # inject the hook immediately before the line that deletes DT
  cl <- code$clean
  k <- grep("^\\s*rm\\(DT\\)", cl)
  if (!length(k)) stop("`rm(DT)` not found in the clean chunk; cannot inject the hook.")
  code$clean <- append(cl, ".REV_HOOK_OUT <- revision_hook(environment())", after = k[1] - 1)
  code
}

build_panel <- function(code, qmd_dir) {
  e <- new.env(parent = globalenv())
  old <- setwd(qmd_dir); on.exit(setwd(old), add = TRUE)
  for (nm in names(code)) {
    message("Running main-pipeline chunk `", nm, "` ...")
    eval(parse(text = code[[nm]], encoding = "UTF-8"), envir = e)
  }
  ctx <- panel_from_env(e)
  ctx$CFG$outdir <- normalizePath(file.path(qmd_dir, ctx$CFG$outdir), mustWork = FALSE)
  ctx
}

# ---- response-style and all-item country-year tables (needs DT) ------------
revision_hook <- function(env) {
  DT <- env$DT; CAT <- env$CAT; OUTCOME <- env$OUTCOME
  excl <- c(OUTCOME, env$AFFECT_P, env$AFFECT_N, env$HIGH_PROX)
  cand_all <- setdiff(intersect(CAT$code, names(DT)), excl)
  wm <- function(v, w) { ok <- !is.na(v) & !is.na(w)
    if (!any(ok)) NA_real_ else sum(v[ok] * w[ok]) / sum(w[ok]) }

  CY_ALL <- DT[, c(lapply(.SD, wm, w = wt), .(n_resp = .N)),
               by = .(iso3, year), .SDcols = cand_all]

  RS <- DT[, {
    y <- get(OUTCOME); ok <- !is.na(y); w <- wt[ok]; v <- y[ok]
    m <- sum(v * w) / sum(w)
    .(cantril_mean = m, cantril_sd = sqrt(sum(w * (v - m)^2) / sum(w)),
      share_0 = sum(w * (v == 0)) / sum(w), share_10 = sum(w * (v == 10)) / sum(w),
      share_5 = sum(w * (v == 5)) / sum(w))
  }, by = .(iso3, year)]

  # Balanced yes-rate (acquiescence proxy). After cleaning, higher = favourable.
  # Raw "Yes" is the HIGH code for items whose Yes is favourable (direction -1,
  # reversed in cleaning) and the LOW code for items whose Yes is adverse (+1).
  bin <- CAT[code %in% cand_all & (vmax - vmin) == 1]
  yes_rate <- function(codes, end) {
    if (!length(codes)) return(NULL)
    lv <- setNames(if (end == "high") bin[match(codes, code), vmax]
                   else bin[match(codes, code), vmin], codes)
    out <- DT[, lapply(setNames(codes, codes), function(cc) wm(as.numeric(get(cc) == lv[[cc]]), wt)),
              by = .(iso3, year)]
    out[, .(iso3, year, r = rowMeans(.SD, na.rm = TRUE)), .SDcols = codes]
  }
  yf <- yes_rate(bin[direction == -1, code], "high")
  ya <- yes_rate(bin[direction ==  1, code], "low")
  if (!is.null(yf) && !is.null(ya)) {
    yy <- merge(yf[, .(iso3, year, yes_fav = r)], ya[, .(iso3, year, yes_adv = r)],
                by = c("iso3", "year"))
    yy[, yes_balanced := (yes_fav + yes_adv) / 2]
    RS <- merge(RS, yy, by = c("iso3", "year"), all.x = TRUE)
  }
  message(sprintf("Revision hook: %d item means, response style for %d country-years.",
                  length(cand_all), nrow(RS)))
  list(CY_ALL = CY_ALL, RS = RS)
}

# A function defined inside the pipeline environment carries that whole
# environment (ANA, CY, ...) when saved. Re-home it so only its code is stored.
detach_fun <- function(f) { environment(f) <- globalenv(); f }

# ---- collect what the blocks need from the pipeline environment ------------
panel_from_env <- function(e) {
  need <- c("CFG", "CAT", "CY", "AGG", "ANA", "wave_tab", "cov_item",
            "INCLUDED", "W_VARS", "B_VARS", "M_VARS")
  miss <- need[!vapply(need, exists, logical(1), envir = e, inherits = FALSE)]
  if (length(miss)) stop("Pipeline objects missing after `clean`: ", paste(miss, collapse = ", "))
  g <- function(n) get(n, envir = e, inherits = FALSE)
  CFG <- g("CFG"); CAT <- g("CAT"); CY <- copy(g("CY")); INCLUDED <- g("INCLUDED")
  VARS  <- c(INCLUDED, "ln_gdp")
  LABEL <- setNames(c(CAT[match(INCLUDED, code), label], "GDP per capita (log)"), VARS)
  PROX  <- setNames(c(CAT[match(INCLUDED, code), proximity], "structural"), VARS)
  WITHIN <- g("wave_tab")[contributes_within == TRUE, as.character(iso3)]

  # country-year panel: AGG + raw levels and flags from CY
  P <- copy(g("AGG")); P[, iso3 := as.character(iso3)]
  CY[, iso3 := as.character(iso3)]
  extra <- setdiff(intersect(c(VARS, paste0(VARS, "_miss")), names(CY)), names(P))
  P <- merge(P, CY[, c("iso3", "year", extra), with = FALSE], by = c("iso3", "year"), all.x = TRUE)
  if (!"ln_gdp_miss" %in% names(P)) P[, ln_gdp_miss := as.integer(is.na(ln_gdp))]
  P[, `:=`(yearf = factor(year), iso3f = factor(iso3), w = n_resp)]
  setorder(P, iso3, year)

  # respondent frame for R7 (only the columns R7 uses)
  ANA <- g("ANA")
  ML <- ANA[, c("cantril", "wt", "iso3", "year", g("W_VARS"), g("B_VARS"), g("M_VARS")), with = FALSE]
  ML[, iso3 := as.character(iso3)]
  LV <- CY[, c("iso3", "year", VARS), with = FALSE]
  setnames(LV, VARS, paste0(VARS, "_lvl"))
  ML <- merge(ML, LV, by = c("iso3", "year"))
  gt <- CY[, .(g = mean(ln_gdp, na.rm = TRUE)), by = iso3][is.finite(g)]
  qs <- unique(quantile(gt$g, c(0, 1/3, 2/3, 1), na.rm = TRUE))
  gt[, dev := cut(g, qs, labels = c("Low", "Middle", "High")[seq_len(length(qs) - 1)],
                  include.lowest = TRUE)]
  ML <- merge(ML, gt[, .(iso3, dev)], by = "iso3")
  ML <- ML[complete.cases(ML)]

  tabdir <- file.path(CFG$outdir, "tab")
  rd <- function(f) { p <- file.path(tabdir, f); if (file.exists(p)) fread(p) else NULL }
  hook <- if (exists(".REV_HOOK_OUT", envir = e, inherits = FALSE)) g(".REV_HOOK_OUT") else NULL

  list(CFG = CFG, CAT = CAT, CY = CY, P = P, ML = ML,
       wave_tab = g("wave_tab"), cov_item = g("cov_item"), INCLUDED = INCLUDED,
       W_VARS = g("W_VARS"), B_VARS = g("B_VARS"), M_VARS = g("M_VARS"),
       VARS = VARS, LABEL = LABEL, PROX = PROX, WITHIN = WITHIN,
       impute_country_mean = detach_fun(g("impute_country_mean")),
       decompose = detach_fun(g("decompose")),
       CY_ALL = hook$CY_ALL, RS = hook$RS,
       T03 = rd("T03_main_coefficients.csv"), T10 = rd("T10_lead_lag.csv"),
       min_waves = CFG$min_waves_within %||% 3)
}
