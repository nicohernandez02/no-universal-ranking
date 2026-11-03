source("extra/common.R"); z <- readRDS(file.path(OUT, "d910.rds"))
clus <- function(d, vars) { wv <- paste0(vars,"_w"); bv <- paste0(vars,"_b")
  mv <- intersect(paste0(setdiff(vars,"ln_gdp"),"_miss"), names(d)); mv <- mv[sapply(mv, function(m) uniqueN(d[[m]])>1)]
  o <- fit_ols_cl(d, "cantril", c(wv,bv,mv), fe="yearf")[term %in% c(wv,bv)]
  o[, `:=`(code=sub("_(w|b)$","",term), level=fifelse(grepl("_w$",term),"within","between"))][, q := p.adjust(p,"BH"), by=level][] }
for (k in c("9","10")) {
  d <- z[[paste0("D",k)]]; v <- z[[paste0("V",k)]]
  mb <- fit_cre(d, v); cl <- clus(d, v)
  out <- merge(mb[, .(code, level, mb_est=est, mb_se=se, mb_q=p_fdr)], cl[, .(code, level, cl_est=est, cl_se=se, cl_q=q)], by=c("code","level"))
  saveRDS(out, file.path(OUT, sprintf("fit_%s.rds", k)))
  cat("\n== X", k, "\n"); print(out[, .(mb=sum(mb_q<.05), cl=sum(cl_q<.05)), by=level])
  print(out[mb_q<.05 | cl_q<.05 | !code %in% VARS, .(level, code, mb=round(mb_est,3), mb_q=signif(mb_q,2), cl=round(cl_est,3), cl_q=signif(cl_q,2))][order(level, code)])
}
lab <- c(LAB, WP111 = "Voiced opinion to an official", EMP_FTEMP_POP = "In payroll employment", WP60 = "Felt well-rested yesterday",
         WP23 = "No health problems", WP117 = "No money or property stolen", WP10248 = "Good place to make friends",
         WP27 = "Someone to count on", CORR = "Low perceived corruption (mean of business and government)")
for (k in c("9", "10")) { o <- readRDS(file.path(OUT, sprintf("fit_%s.rds", k))); o[, label := lab[code]]
  fwrite(o, file.path(OUT, c("9" = "X9_threshold004_clustered.csv", "10" = "X10_whr_style_model.csv")[k])) }
