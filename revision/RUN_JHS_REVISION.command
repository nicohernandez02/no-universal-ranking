#!/bin/bash
# Runs the revision analyses locally. The licensed Gallup data are read from GALLUP_PARQUET and never leave the machine.
cd "$(dirname "$0")"
export GALLUP_PARQUET="${GALLUP_PARQUET:?Set GALLUP_PARQUET to the path of the licensed Gallup World Poll extract}"
export WB_PANEL="${WB_PANEL:?Set WB_PANEL to the path of the World Bank GDP panel (.rds)}"
export MAIN_QMD="../no-universal-ranking.qmd"
RS=""
for c in "$(command -v Rscript)" /usr/local/bin/Rscript /opt/homebrew/bin/Rscript /Library/Frameworks/R.framework/Resources/bin/Rscript; do
  [ -x "$c" ] && RS="$c" && break
done
LOG="run_log.txt"
echo "START $(date)" > "$LOG"
if [ -z "$RS" ]; then echo "ERROR: Rscript not found" | tee -a "$LOG"; exit 1; fi
echo "Rscript: $RS" >> "$LOG"
"$RS" -e 'for (p in c("targets","lmerTest","data.table","lme4","arrow","glmnet","xgboost","mice")) if (!requireNamespace(p, quietly=TRUE)) install.packages(p, repos="https://cloud.r-project.org")' >> "$LOG" 2>&1
"$RS" -e 'targets::tar_make(reporter = "timestamp")' >> "$LOG" 2>&1
echo "EXIT $? $(date)" >> "$LOG"
echo "Done. You can close this window."
