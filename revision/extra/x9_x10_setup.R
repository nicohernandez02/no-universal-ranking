source("extra/common.R")
add_items <- function(d0, added) {
  A <- copy(ctx$CY_ALL)[, iso3 := as.character(iso3)]
  ext <- merge(d0[, .(iso3, year)], A[, c("iso3", "year", added), with = FALSE], by = c("iso3", "year"), all.x = TRUE)
  ext <- ctx$impute_country_mean(ext, added); ext <- ctx$decompose(ext, added)
  for (v in added) ext[!iso3 %in% ctx$WITHIN, (paste0(v, "_w")) := 0]
  keepc <- intersect(c("iso3","year", paste0(added,"_w"), paste0(added,"_b"), paste0(added,"_miss")), names(ext))
  merge(d0, ext[, ..keepc], by = c("iso3","year"))
}
ADD9 <- c("WP111","EMP_FTEMP_POP","WP60","WP23","WP117","WP10248","WP27")
cat("in CY_ALL:", intersect(ADD9, names(ctx$CY_ALL)), "\n")
D9 <- add_items(P, intersect(ADD9, names(ctx$CY_ALL))); V9 <- c(VARS, intersect(ADD9, names(ctx$CY_ALL)))
# WHR-style: GDP, social support (WP27), freedom (WP134), generosity (WP108), perceived corruption (mean of WP145, WP146)
A <- copy(ctx$CY_ALL)[, iso3 := as.character(iso3)][, CORR := rowMeans(cbind(WP145, WP146), na.rm = TRUE)]
ctx$CY_ALL <- A
D10 <- add_items(P, c("WP27","CORR")); V10 <- c("ln_gdp","WP27","WP134","WP108","CORR")
saveRDS(list(D9=D9, V9=V9, D10=D10, V10=V10), file.path(OUT, "d910.rds"))
cat("ok", ncol(D9), ncol(D10), "\n"); print(summary(D10$CORR_w)); print(summary(D10$WP27_b))
