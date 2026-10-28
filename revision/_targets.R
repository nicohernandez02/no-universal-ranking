# Revision pipeline (JHS, Reviewer 1).  Run with:  targets::tar_make()
# Only what changed is re-run: edit a setting in R/settings.R and only the
# affected blocks run again; the main pipeline's `cfg`/`clean` chunks re-run
# only if their code (or the .qmd path) changes.
library(targets)
tar_option_set(packages = c("data.table", "lme4"), memory = "transient",
               garbage_collection = TRUE)
tar_source("R")

# Path to the MAIN pipeline .qmd, relative to this folder (edit if needed,
# or set the environment variable MAIN_QMD).
MAIN_QMD <- Sys.getenv("MAIN_QMD", "../no-universal-ranking.qmd")

list(
  tar_target(qmd_file, MAIN_QMD, format = "file"),
  tar_target(code,  panel_code(qmd_file)),                                # chunk text only
  tar_target(qmd_dir, dirname(normalizePath(MAIN_QMD))),
  tar_target(state, build_panel(code, qmd_dir)),                          # heavy: runs cfg + clean
  tar_target(panel, state[setdiff(names(state), "ML")]),                  # small copy for R0-R6
  tar_target(r0, block_r0(panel)),
  tar_target(r1, block_r1(panel)),
  tar_target(r2, block_r2(panel, r0)),
  tar_target(r3, block_r3(panel, r0, r1)),
  tar_target(r4, block_r4(panel, r0)),
  tar_target(r5, block_r5(panel)),
  tar_target(r6, block_r6(panel, r0)),
  tar_target(r7, block_r7(panel, state$ML)),
  tar_target(r8, block_r8(panel, r0)),
  tar_target(sentences, write_sentences(panel, list(r0, r1, r2, r3, r4, r5, r6, r7, r8)),
             format = "file")
)
