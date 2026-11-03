suppressPackageStartupMessages({library(data.table); library(lme4)})
setwd(Sys.getenv("REVISION_DIR", "."))  # run from the revision/ folder
for (f in list.files("R", full.names=TRUE)) source(f)
ctx <- readRDS("_targets/objects/panel")
out <- normalizePath(Sys.getenv("X_OUT", "../outputs/revision"), mustWork = FALSE)
P <- copy(ctx$P); VARS <- ctx$VARS; LAB <- ctx$LABEL
wv <- paste0(VARS,"_w"); bv <- paste0(VARS,"_b")
MV <- intersect(paste0(setdiff(VARS,"ln_gdp"),"_miss"), names(P)); MV <- MV[sapply(MV,function(m) uniqueN(P[[m]])>1)]
cat("N cy", nrow(P), " countries", uniqueN(P$iso3), "\n")
R0 <- fread(file.path(out,'R0_baseline_collapsed_cre.csv'))
# ---- X5 binding coverage thresholds (lmer, as baseline) + clustered
R1 <- fread(file.path(out,"R1_coverage_audit.csv"))
keep90 <- intersect(VARS, R1[share_cy_observed >= .90, code])
cat("\nkept at >=90%:", length(keep90), "dropped:", paste(setdiff(VARS,keep90), collapse=", "), "\n")
f90 <- fit_cre(ctx$P, keep90)
m <- merge(R0[,.(code,level,base_sig=sig,base_est=est)], f90[,.(code,level,est,sig)], by=c("code","level"))
cat("X5 >=90%: baseline-sig retained:", m[base_sig & sig & sign(est)==sign(base_est), .N], "of", m[base_sig==TRUE,.N], " (baseline sig present in model)\n")
mvcols <- intersect(paste0(VARS,"_miss"), names(ctx$P))
cc <- ctx$P[rowSums(ctx$P[, ..mvcols]==1, na.rm=TRUE)==0]
cat("complete-case country-years:", nrow(cc), " countries:", uniqueN(cc$iso3), "\n")
fcc <- tryCatch(fit_cre(cc, VARS, mflags=FALSE), error=function(e) {cat("cc error", conditionMessage(e), "\n"); NULL})
if (!is.null(fcc)) { m2 <- merge(R0[,.(code,level,base_sig=sig,base_est=est)], fcc[,.(code,level,est,sig)], by=c("code","level")); cat("X5 complete-case retained:", m2[base_sig & sig & sign(est)==sign(base_est), .N], "of", m2[base_sig==TRUE,.N], "\n"); fwrite(m2, file.path(out,"X5_complete_case.csv")) }
fwrite(m, file.path(out,"X5_coverage90.csv"))
