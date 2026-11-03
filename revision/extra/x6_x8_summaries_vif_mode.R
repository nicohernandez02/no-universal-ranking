source("extra/common.R")
base <- fit_cre(P, VARS)
bt <- rbindlist(lapply(list.files(OUT, "^boot_", full.names=TRUE), readRDS))
cat("reps:", uniqueN(bt$rep), "\n")
s <- bt[, .(se_boot = sd(est), lo = quantile(est, .025), hi = quantile(est, .975)), by=.(code, level)]
X6 <- merge(base, s, by=c("code","level"))
X6[, `:=`(p_boot = 2*pnorm(-abs(est/se_boot)))][, q_boot := p.adjust(p_boot, "BH"), by=level][, sig_boot := q_boot < .05]
X6[, label := LAB[code]]
fwrite(X6, file.path(OUT, "X6_cre_country_bootstrap.csv"))
cat("\n== X6 bootstrap: established\n"); print(X6[, .(model_based=sum(sig), bootstrap=sum(sig_boot)), by=level])
print(X6[sig | sig_boot, .(level, label, est=round(est,3), se=round(se,3), se_boot=round(se_boot,3), q_boot=signif(q_boot,2), sig, sig_boot)][order(level,-abs(est))])
# ---- X7 VIFs (within and between design, net of year FE) and bivariate slopes
d <- P[complete.cases(P[, c(wv, bv), with=FALSE])]
vif <- function(cols) sapply(cols, function(v) { f <- as.formula(paste(v, "~", paste(c(setdiff(c(wv,bv), v), "factor(yearf)"), collapse="+"))); r2 <- summary(lm(f, data=d))$r.squared; 1/(1-r2) })
V <- data.table(term = c(wv, bv), vif = vif(c(wv, bv)))
V[, `:=`(code = sub("_(w|b)$","",term), level = fifelse(grepl("_w$",term),"within","between"))]
bi <- rbindlist(lapply(VARS, function(v) { o <- fit_ols_cl(P, "cantril", c(paste0(v,"_w"), paste0(v,"_b")), fe="yearf"); o[, code := v] }))
bi[, level := fifelse(grepl("_w$", term), "within", "between")][, q := p.adjust(p, "BH"), by=level]
cl <- fit_ols_cl(P, "cantril", c(wv, bv, MV), fe="yearf"); cl[, `:=`(code=sub("_(w|b)$","",term), level=fifelse(grepl("_w$",term),"within","between"))]
X7 <- merge(merge(V[, .(code, level, vif)], bi[, .(code, level, bi_est=est, bi_se=se, bi_q=q)], by=c("code","level")), cl[, .(code, level, cond_est=est)], by=c("code","level"))
X7[, `:=`(label = LAB[code], sign_change = sign(bi_est) != sign(cond_est))]
fwrite(X7, file.path(OUT, "X7_vif_bivariate.csv"))
cat("\n== X7 VIF summary\n"); print(X7[, .(median=round(median(vif),2), max=round(max(vif),2), n_over5=sum(vif>5), n_over10=sum(vif>10)), by=level])
print(X7[vif > 5, .(level, label, vif=round(vif,1))])
cat("bivariate established:\n"); print(X7[, .(n_bi_sig = sum(bi_q < .05), sign_changes = sum(sign_change)), by=level])
print(X7[sign_change & bi_q < .05, .(level, label, bi=round(bi_est,3), cond=round(cond_est,3))])
# condition number of standardized design
Z <- scale(as.matrix(d[, c(wv, bv), with=FALSE])); ev <- eigen(crossprod(Z)/nrow(Z), only.values=TRUE)$values
cat("condition number:", round(sqrt(max(ev)/min(ev)),1), "\n")
# ---- X8 mode proxy: drop 2020-2021 (pandemic-era telephone interviewing)
P8 <- P[!year %in% c(2020, 2021)]
c8 <- fit_ols_cl(P8, "cantril", c(wv, bv, MV), fe="yearf"); c8[, `:=`(code=sub("_(w|b)$","",term), level=fifelse(grepl("_w$",term),"within","between"))]
c8[, q := p.adjust(p, "BH"), by=level]
m8 <- fit_cre(P8, VARS)
X8 <- merge(c8[, .(code, level, cl_est=est, cl_se=se, cl_q=q)], m8[, .(code, level, mb_est=est, mb_q=p_fdr)], by=c("code","level"))
X8[, label := LAB[code]]
fwrite(X8, file.path(OUT, "X8_drop_2020_2021.csv"))
cat("\n== X8 rows:", nrow(P8), "\n"); print(X8[, .(clustered=sum(cl_q<.05), model_based=sum(mb_q<.05)), by=level])
print(X8[code %in% c("WP31","WP40","WP2319","WP92","ln_gdp","WP141") , .(level,label,cl=round(cl_est,3),cl_q=signif(cl_q,2),mb=round(mb_est,3),mb_q=signif(mb_q,2))][order(level)])
