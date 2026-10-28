# Same analyses as _targets.R, run top to bottom without {targets}
# (fallback if targets is not installed). Re-runs everything each time.
suppressPackageStartupMessages({library(data.table); library(lme4)})
for (f in list.files("R", full.names = TRUE)) source(f)
MAIN_QMD <- Sys.getenv("MAIN_QMD", "../no-universal-ranking.qmd")
code  <- panel_code(MAIN_QMD)
state <- build_panel(code, dirname(normalizePath(MAIN_QMD)))
panel <- state[setdiff(names(state), "ML")]
r0 <- block_r0(panel); r1 <- block_r1(panel); r2 <- block_r2(panel, r0)
r3 <- block_r3(panel, r0, r1); r4 <- block_r4(panel, r0); r5 <- block_r5(panel)
r6 <- block_r6(panel, r0); r7 <- block_r7(panel, state$ML); r8 <- block_r8(panel, r0)
f <- write_sentences(panel, list(r0, r1, r2, r3, r4, r5, r6, r7, r8))
message("Done. Sentences in ", f)
