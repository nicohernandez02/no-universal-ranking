# X11: full 0.04 model without the two finance items closest to the ladder (WP2319, WP31)
# X12: WHR-style model adding household-finance items one at a time (clustered errors)
source("extra/common.R"); z <- readRDS(file.path(OUT, "d910.rds"))
clus <- function(d, vars) { wv <- paste0(vars,"_w"); bv <- paste0(vars,"_b")
  mv <- intersect(paste0(setdiff(vars,"ln_gdp"),"_miss"), names(d)); mv <- mv[sapply(mv, function(m) uniqueN(d[[m]])>1)]
  o <- fit_ols_cl(d, "cantril", c(wv,bv,mv), fe="yearf")[term %in% c(wv,bv)]
  o[, `:=`(code=sub("_(w|b)$","",term), level=fifelse(grepl("_w$",term),"within","between"))][, q := p.adjust(p,"BH"), by=level][] }
WHR <- c("ln_gdp","WP27","WP134","WP108","WP145","WP146","CORR")
# X11
v11 <- setdiff(z$V9, c("WP2319","WP31"))
mb <- fit_cre(z$D9, v11); cl <- clus(z$D9, v11)
x11 <- merge(mb[, .(code, level, mb_est=est, mb_se=se, mb_q=p_fdr)], cl[, .(code, level, cl_est=est, cl_se=se, cl_q=q)], by=c("code","level"))
fwrite(x11, file.path(OUT, "X11_full_without_wp2319_wp31.csv"))
cat("X11 established (mb, cl):\n"); print(x11[, .(mb=sum(mb_q<.05), cl=sum(cl_q<.05)), by=level])
print(x11[mb_q<.05 | cl_q<.05 | code %in% WHR, .(level, code, mb=round(mb_est,3), mb_q=signif(mb_q,2), cl=round(cl_est,3), cl_q=signif(cl_q,2))][order(level, -abs(cl))])
# X12
FIN <- list(none=character(0), food="WP40", shelter="WP43", income_feel="WP2319", living_better="WP31", hh_income="ln_income_h",
            all=c("WP40","WP43","WP2319","WP31","ln_income_h"))
x12 <- rbindlist(lapply(names(FIN), function(n) { v <- c(z$V10, FIN[[n]]); o <- clus(z$D10, v); o[, added := n][] }))
x12 <- x12[, .(added, code, level, est, se, q)]
fwrite(x12, file.path(OUT, "X12_whr_plus_finance.csv"))
cat("\nX12 within, clustered est (q):\n")
w <- x12[level=="within" & code %in% c("ln_gdp","WP27","WP134","WP108","CORR")]
print(dcast(w, code ~ added, value.var="est", fun.aggregate=function(x) round(x,3)))
print(dcast(w, code ~ added, value.var="q", fun.aggregate=function(x) signif(x,2)))
b <- x12[level=="between" & code %in% c("ln_gdp","WP27","WP134","WP108","CORR")]
cat("between q:\n"); print(dcast(b, code ~ added, value.var="q", fun.aggregate=function(x) signif(x,2)))
cat("finance items within (est,q):\n"); print(x12[level=="within" & !code %in% z$V10, .(added, code, est=round(est,3), q=signif(q,2))])
