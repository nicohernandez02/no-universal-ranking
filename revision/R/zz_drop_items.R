# Items the submitted paper excludes but the repository's unweighted coverage
# screen still admits. The paper's weighted within-country SD screen drops the
# Gallup per-capita income quintile (weighted mean within SD .0047 < .05).
SET_DROP <- c("INCOME_5")

# Remove dropped items from every name list the blocks use, so the revision
# panel has exactly the 29 predictors of the submitted paper.
drop_items <- function(ctx, drop = SET_DROP) {
  drop <- intersect(drop, ctx$INCLUDED)
  if (!length(drop)) return(ctx)
  pat <- paste0("^(", paste(drop, collapse = "|"), ")(_w|_b|_miss|_lvl)?$")
  ctx$INCLUDED <- setdiff(ctx$INCLUDED, drop)
  ctx$VARS     <- setdiff(ctx$VARS, drop)
  for (n in c("W_VARS", "B_VARS", "M_VARS")) ctx[[n]] <- ctx[[n]][!grepl(pat, ctx[[n]])]
  ctx$LABEL <- ctx$LABEL[ctx$VARS]; ctx$PROX <- ctx$PROX[ctx$VARS]
  ctx$P <- ctx$P[, names(ctx$P)[!grepl(pat, names(ctx$P))], with = FALSE]
  message("Revision panel: dropped ", paste(drop, collapse = ", "), "; ",
          length(ctx$VARS), " predictors remain.")
  ctx
}
