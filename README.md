# Level-specific correlates of life evaluation

Code for the paper *Level-Specific Correlates of Life Evaluation: Within- and
Between-Country Evidence from the Gallup World Poll, 2006–2025*.

The analysis relates the Cantril ladder (0–10) to 29 national conditions in
2,670 country-years across 168 countries. Each condition is split into a
within-country deviation and a country mean (correlated random effects, or
Mundlak, decomposition), so that change within countries and differences
between countries get separate coefficients. A separate respondent-level model
with country-year fixed effects estimates the association with household income
relative to compatriots.

## Contents

| Path | What it does |
|---|---|
| `no-universal-ranking.qmd` | Main pipeline: data preparation, screening of candidate items, the decomposition models, multiple-testing correction (Benjamini–Hochberg), Oster bounds, heterogeneity tests and out-of-sample validation (linear model, elastic net, XGBoost). |
| `revision/` | Analyses added during peer review, run with `{targets}` on the country-year panel built by the main pipeline. |
| `revision/R/` | Model helpers (`helpers.R`), panel construction (`panel.R`), settings and the individual robustness blocks. |
| `revision/_targets.R` | Pipeline definition for the revision analyses (R0–R9). |
| `revision/run_without_targets.R` | The same analyses run sequentially, without `{targets}`. |

### Revision analyses

| Output | Content |
|---|---|
| R0 | Country-year baseline that reproduces the main coefficients |
| R1–R3 | Observed coverage by predictor, observed-only estimation, stricter coverage thresholds |
| R4 | Sensitivity to the within-country variation threshold |
| R5–R6 | Country-specific trends, first differences, placebo leads; response-style controls and models without perceptual items |
| R7 | Predictive baselines (GDP only, country means, within-country deviations, undecomposed predictors) |
| R8 | Pooled, random-effects and two-way fixed-effects comparisons |
| R9 | Lead–lag AIC comparison |

## Running the code

The Gallup World Poll microdata are licensed and cannot be redistributed. To
reproduce the results, obtain the World Poll extract from Gallup, place it
where the `cfg` chunk of `no-universal-ranking.qmd` expects it (or set the
`GALLUP_PARQUET` environment variable), and supply the World Bank GDP panel
through `WB_PANEL`. Then:

```bash
quarto render no-universal-ranking.qmd     # main pipeline (several hours with QUICK = FALSE)
cd revision && Rscript -e 'targets::tar_make()'
```

`CFG$QUICK = TRUE` in the `cfg` chunk runs a fast check on a subsample. Seeds
are fixed, and every reported number is written from saved model objects.
