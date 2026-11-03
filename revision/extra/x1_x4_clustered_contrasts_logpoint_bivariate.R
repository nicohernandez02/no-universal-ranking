suppressPackageStartupMessages({library(data.table); library(lme4)})
setwd(Sys.getenv("REVISION_DIR", "."))  # run from the revision/ folder
for (f in list.files("R", full.names=TRUE)) source(f)
ctx <- readRDS("_targets/objects/panel")
out <- normalizePath(Sys.getenv("X_OUT", "../outputs/revision"), mustWork = FALSE)
P <- copy(ctx$P); VARS <- ctx$VARS; LAB <- ctx$LABEL
wv <- paste0(VARS,"_w"); bv <- paste0(VARS,"_b")
MV <- intersect(paste0(setdiff(VARS,"ln_gdp"),"_miss"), names(P)); MV <- MV[sapply(MV,function(m) uniqueN(P[[m]])>1)]
cat("N cy", nrow(P), " countries", uniqueN(P$iso3), "\n")
# ---- X1 clustered CRE (Mundlak OLS, year FE, CR1 by country)
A <- fit_ols_cl(P, "cantril", c(wv,bv,MV), fe="yearf")
A <- A[term %in% c(wv,bv)][, `:=`(level=ifelse(grepl("_w$",term),"within","between"), code=sub("_(w|b)$","",term))]
A[, p_fdr:=p.adjust(p,"BH"), by=level][, sig:=p_fdr<.05][, label:=LAB[code]]
R0 <- fread(file.path(out,"R0_baseline_collapsed_cre.csv"))
X1 <- merge(R0[,.(code,level,base_est=est,base_se=se,base_sig=sig)], A[,.(code,level,label,cl_est=est,cl_se=se,cl_p=p,cl_q=p_fdr,cl_sig=sig)], by=c("code","level"))
fwrite(X1, file.path(out,"X1_cre_clustered.csv"))
cat("\n== X1 clustered CRE: sig counts\n"); print(X1[,.(base=sum(base_sig), clustered=sum(cl_sig)),by=level])
print(X1[cl_sig==TRUE | base_sig==TRUE, .(level,label,base_est=round(base_est,3),cl_est=round(cl_est,3),base_sig,cl_sig,q=round(cl_q,3))][order(level,-abs(base_est))])
# ---- X2 Mundlak contrasts in common (pooled-SD) units
for (v in VARS) { x <- as.numeric(P[[v]]); cm <- ave(x, P$iso3, FUN=function(z) if (all(is.na(z))) NA_real_ else mean(z,na.rm=TRUE)); x <- ifelse(is.na(x),cm,x); x[is.na(x)] <- mean(x,na.rm=TRUE); x <- (x-mean(x))/sd(x); set(P, j=paste0(v,"_raw"), value=x); set(P, j=paste0(v,"_cm"), value=ave(x,P$iso3,FUN=mean)) }
RV <- paste0(VARS,"_raw"); CM <- paste0(VARS,"_cm")
B <- fit_ols_cl(P, "cantril", c(RV,CM,MV), fe="yearf")
bw <- B[term %in% RV, .(code=sub("_raw$","",term), w_est=est, w_se=se)]
ct <- B[term %in% CM, .(code=sub("_cm$","",term), contrast=est, c_se=se, c_p=p)]
X2 <- merge(bw, ct, by="code")[, `:=`(b_est=w_est+contrast, c_q=p.adjust(c_p,"BH"), label=LAB[code])]
fwrite(X2, file.path(out,"X2_mundlak_contrasts.csv"))
cat("\n== X2 contrasts (pooled SD units): n q<.05 =", X2[c_q<.05,.N], "of", nrow(X2), "\n")
print(X2[order(c_p), .(label, w=round(w_est,3), b=round(b_est,3), contrast=round(contrast,3), q=signif(c_q,2))][1:12])
# ---- X3 GDP per log point
g <- as.numeric(P$ln_gdp); P[, gdp_cm := ave(g, iso3, FUN=function(z) mean(z,na.rm=TRUE))]; P[, gdp_dev := g - gdp_cm]
cat("\nGDP raw: sd within", sd(P$gdp_dev,na.rm=T), " sd between(country means)", sd(unique(P[,.(iso3,gdp_cm)])$gdp_cm,na.rm=T), " NA", sum(is.na(g)), "\n")
g1 <- fit_ols_cl(P[!is.na(gdp_dev)], "cantril", c("gdp_dev","gdp_cm"), fe="yearf")
oth <- setdiff(c(wv,bv), c("ln_gdp_w","ln_gdp_b"))
g2 <- fit_ols_cl(P[!is.na(gdp_dev)], "cantril", c("gdp_dev","gdp_cm",oth,MV), fe="yearf")
X3 <- rbind(g1[term %in% c("gdp_dev","gdp_cm")][,model:="GDP only"], g2[term %in% c("gdp_dev","gdp_cm")][,model:="Full (28 other predictors)"])
fwrite(X3, file.path(out,"X3_gdp_per_logpoint.csv")); cat("== X3\n"); print(X3)
# ---- X4 bivariate within for counter-directional items
neg <- names(LAB)[LAB %in% c("Enough money for shelter","Confidence in financial institutions","Quality of air satisfaction","Educational system satisfaction")]
X4 <- rbindlist(lapply(neg, function(v){ o <- fit_ols_cl(P, "cantril", c(paste0(v,"_w"),paste0(v,"_b")), fe="yearf"); o[,code:=v]; o }))[grepl("_w$",term)][,label:=LAB[code]]
fwrite(X4, file.path(out,"X4_bivariate_negative_items.csv")); cat("== X4\n"); print(X4[,.(label,est=round(est,3),se=round(se,3),p=signif(p,2))])
# ---- X5 binding coverage thresholds (lmer, as baseline) + clustered
R1 <- fread(file.path(out,"R1_coverage_audit.csv"))
keep90 <- intersect(VARS, R1[share_cy_observed >= .90, code])
cat("\nkept at >=90%:", length(keep90), "dropped:", paste(setdiff(VARS,keep90), collapse=", "), "\n")
f90 <- fit_cre(ctx$P, keep90)
m <- merge(R0[,.(code,level,base_sig,base_est=est)], f90[,.(code,level,est,sig)], by=c("code","level"))
cat("X5 >=90%: baseline-sig retained:", m[base_sig & sig & sign(est)==sign(base_est), .N], "of", m[base_sig==TRUE,.N], " (baseline sig present in model)\n")
mvcols <- intersect(paste0(VARS,"_miss"), names(ctx$P))
cc <- ctx$P[rowSums(ctx$P[, ..mvcols]==1, na.rm=TRUE)==0]
cat("complete-case country-years:", nrow(cc), " countries:", uniqueN(cc$iso3), "\n")
fcc <- tryCatch(fit_cre(cc, VARS, mflags=FALSE), error=function(e) {cat("cc error", conditionMessage(e), "\n"); NULL})
if (!is.null(fcc)) { m2 <- merge(R0[,.(code,level,base_sig,base_est=est)], fcc[,.(code,level,est,sig)], by=c("code","level")); cat("X5 complete-case retained:", m2[base_sig & sig & sign(est)==sign(base_est), .N], "of", m2[base_sig==TRUE,.N], "\n"); fwrite(m2, file.path(out,"X5_complete_case.csv")) }
fwrite(m, file.path(out,"X5_coverage90.csv"))
