# No Universal Ranking

**Which correlates of life evaluation hold, and how far do they travel?**

Cross-national analysis of subjective wellbeing using the Gallup World Poll
Cantril ladder, 2006–2025. The question is not *what predicts life
evaluation* — plenty of things do — but **whether any ranking of those
predictors survives once you take between-country differences seriously.**

## Method

- **CRE-Mundlak estimation.** Correlated random effects separate within-country
  variation from between-country variation, so a correlate that only reflects
  rich countries differing from poor ones does not masquerade as an effect.
- **Robustness architecture.** Leave-one-country-out, sample weighting
  sensitivity, and MICE-based sensitivity to missingness — each run as a
  systematic sweep rather than a spot check.
- **Multiplicity adjustment.** With many candidate correlates tested at once,
  unadjusted p-values manufacture findings; the analysis corrects for it.
- **Predictive validation.** Gradient boosting used as a check on whether the
  specification generalises, not as the estimator of interest.

## This repository is not reproducible, on purpose

The Gallup World Poll microdata are licensed and cannot be redistributed.
Nothing in this repository will run end to end without them.

What it does offer is **the full specification**: every model, every robustness
sweep, every adjustment, in the order they were run. If you have institutional
access to the World Poll, the code documents exactly what was done. If you do
not, it still shows the analytical decisions — which is what a reader assessing
the work actually needs.

## Layout

```
no-universal-ranking.qmd   the complete analysis, 5,810 lines, code folded
```

Dependencies resolve through `renv.lock` when present; the notebook checks for
it at startup. Core stack: `fixest`, `data.table`, `ggplot2`, `gt`,
`countrycode`.

## Context

MSc Applied Social Data Science capstone, London School of Economics,
submitted August 2026.
