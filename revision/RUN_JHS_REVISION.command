#!/bin/bash
# Runs the JHS revision analyses locally. The Gallup data never leave this Mac.
cd "$(dirname "$0")"
export GALLUP_PARQUET="$HOME/Documents/1 - LSE/Tesis (Capstone MY498)/Bienestar (Gallup)/data/Gallup/gallup_synthetic.parquet"
export WB_PANEL="$HOME/Documents/1 - LSE/Tesis (Capstone MY498)/LSE Capstone/Capstone Datasets/Datasets/wb_panel.rds"
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
echo "Listo. Puedes cerrar esta ventana."
