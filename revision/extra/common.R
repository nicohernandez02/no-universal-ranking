suppressPackageStartupMessages({library(data.table); library(lme4)})
setwd(Sys.getenv("REVISION_DIR", "."))  # run from the revision/ folder
for (f in list.files("R", full.names=TRUE)) source(f)
ctx <- readRDS("_targets/objects/panel")
P <- copy(ctx$P); VARS <- ctx$VARS; LAB <- ctx$LABEL
wv <- paste0(VARS,"_w"); bv <- paste0(VARS,"_b")
MV <- intersect(paste0(setdiff(VARS,"ln_gdp"),"_miss"), names(P)); MV <- MV[sapply(MV,function(m) uniqueN(P[[m]])>1)]
OUT <- Sys.getenv("X_OUT", "../outputs/revision")
