# No Universal Ranking

**Does any ranking of the correlates of life evaluation survive once within-country change, between-country difference and respondent-level position are no longer averaged together?**

A single-pipeline analysis of the Gallup World Poll's Cantril ladder (life
evaluation, 0–10) against a catalogue of up to 37 candidate country-year
predictors across ten domains — material conditions, income, health, social
support, institutions, safety, freedom, civic behaviour, public services and
employment. The question is not which predictors are "significant" in one
pooled regression; it is whether an association holds *within* a country over
time, *between* countries at a point in time, at the individual respondent's
position, or not at all — and how much of a pooled-model ranking evaporates
once those three questions are kept separate.

## What was done

Every respondent row is decomposed, country-year by country-year, into a
within-country deviation and a between-country mean (the Mundlak
decomposition), then entered into a correlated random-effects (CRE) mixed
model with country and country-year random intercepts. The pipeline does not
assume this decomposition is necessary — it tests it: a formal likelihood-
ratio test compares the plain random-effects model against the CRE model, and
only proceeds with separate within/between coefficients because that test
rejects the simpler specification. Skipping this is what lets a predictor that
merely distinguishes rich countries from poor ones masquerade as a
within-country effect in a pooled regression; the LRT is the pipeline's
argument for why the added complexity is not optional.

Four further checks sit on top of the CRE-Mundlak coefficients, each answering
something a single regression table cannot:

**Is a "significant" predictor a multiple-testing artefact?** With dozens of
candidate predictors tested at both levels, unadjusted p-values manufacture
findings. Benjamini-Hochberg FDR correction is applied within two families
declared *before* estimation, not chosen after seeing results: the within-
country main-effect family and the between-country main-effect family
(`fdr_alpha = 0.05`). A separate, larger 87-test family covers the
predictor-by-moderator heterogeneity screen (does an association differ by
development level, world region or historical period) — mixing that pool with
the two-dozen main-effect tests would either over- or under-correct both.

**Would an unmeasured confounder erase this coefficient?** Gallup does not
field a personality measure, so nothing in the data can rule out a stable
unobserved trait driving both a predictor and life evaluation. Oster bounds
(`delta = 1.0`, `Rmax` multiplier `1.3`) quantify, per predictor and per level,
how much selection on unobservables — as strong as the selection already
visible from adding controls — would be needed to move the identified
coefficient through zero. A coefficient can clear the FDR threshold and still
fail this: the two diagnostics are answering different questions, and the
pipeline's evidence grade only awards "Strong" when a predictor clears both,
plus a third, independent check —

**Does a flexible, non-parametric model actually rely on this predictor?**
Elastic net (`alpha = 0.5`, cross-validated penalty) and single-threaded,
early-stopped XGBoost are fit as validation models, not as the estimator of
interest, and compared to the linear CRE specification on four held-out
designs: a random split (an optimistic upper bound, reported for
completeness), a country-block holdout (transfer to unseen countries), a
temporal split (train on earlier waves, predict later ones) and a
development-tier holdout (transfer across income groups). A predictor with
zero permutation importance in the boosted model, even if linearly
"significant," does not earn the top evidence grade. Out-of-sample R² on the
country-block and development holdouts is allowed to go negative — the
pipeline treats that as a real finding about transportability, not a bug, and
decomposes it into a level-shift (bias) component versus a residual component
so a poor score isn't automatically read as "the predictors carry no signal."

**Does the result depend on one influential country?** For the predictors that
do clear the grading bar, a leave-one-country-out (LOCO) sweep reports the
maximum single-country deviation in the coefficient and whether dropping any
one country flips its sign — read from a companion checkpoint file rather than
refit inline, alongside two further sensitivity checks (country-sample-
weighting perturbations and MICE-based multiple imputation against the
country-mean-fill default used elsewhere).

Every predictor that survives is finally placed on an **evidence map**: graded
Strong / Moderate / Not established at each level (Strong requires FDR
significance *and* a robust Oster bound *and* nonzero permutation importance;
Moderate requires FDR significance alone), and classified as holding at both
levels, only within countries ("dynamic"), only between countries
("structural"), or not established at either. As a code comment in the
pipeline puts it, "the typology is the deliverable — not a shortlist of what
'matters'." A `causality` note generated alongside the map states the
project's own scope plainly: *"No claim in this dissertation is causal... The
contribution is evidence location, not effect estimation."*

None of the above can be re-run here — the Gallup World Poll microdata are
licensed and are not included in this repository (see below) — so no output
numbers from an actual execution are reproduced in this README. A handful of
figures *are* hardcoded into the pipeline's own plot captions and code
comments, marked in-line as verified against the submitted dissertation, and
are reproduced here for that reason rather than invented:

- The respondent-level model adds sociodemographic composition, then income
  and employment, then a quadratic income term, reporting the *incremental*
  (not cumulative) within-country-year R² at each step: **+3.17 pp**
  (demographic composition), **+1.76 pp** (income/employment), **+0.59 pp**
  (income non-linearity) — a cumulative 5.52% of within-country-year variance
  in life evaluation explained at the individual level.
- Exactly three predictor × moderator pairs survive the 87-test heterogeneity
  FDR family: *Enough money for shelter* × development tier (stratum slopes
  −0.055 / −0.044 / +0.043), *Freedom in your life* × world region (q = .002),
  and *Freedom in your life* × historical period (q = .036).
- The pipeline is written to expect exactly **14** within-country predictors
  reaching the "Strong"/"Moderate" evidence grade (`stopifnot(length(established)
  == 14L)`); the single largest leave-one-out influence among them belongs to
  GDP per capita (max deviation 0.0197, attributable to India).

## This repository is not reproducible, on purpose — with one gap

The Gallup World Poll microdata are licensed and cannot be redistributed;
nothing here runs end to end without an extract obtained under your own
licence. What the repository offers instead is the complete, heavily
commented specification — every model, every robustness sweep, every
adjustment, in the order it was run, plus (per its own reproducibility
contract) a fixed random seed, pinned RNG algorithm, single-threaded boosting,
and SHA-256 verification of both required inputs before anything expensive
runs.

One piece of that contract is not actually present in this repository:
`renv.lock` is referenced repeatedly as "shipped in this repository," but no
lockfile is committed, so exact package versions are not currently pinned.
See **Hygiene notes** below.

## Layout

```
no-universal-ranking.qmd   the complete analysis: ~5,813 lines, 10 named
                            code sections (config/catalogue, preflight,
                            load+clean, CRE-Mundlak estimation, robustness,
                            predictive validation, individual-level battery,
                            evidence-map figures, generated prose, plus an
                            appended `candidate_figures` chunk producing
                            three additional main-text figures — see
                            Hygiene notes; this block now sits inside a
                            proper code fence)
README.md                  this file
.gitignore                 excludes licensed data, generated output, R/Quarto artefacts
```

Running it end to end (not possible here without licensed data) would also
produce, but does not currently commit:

- `data/gallup_extract.parquet`, `data/wb_panel.rds` — the two licensed/
  derived inputs, and `data/downstream_checkpoints/` — three small,
  aggregated CSV checkpoints (leave-one-country-out, sample-weighting
  sensitivity, MICE sensitivity) the pipeline's own comments say *are*
  meant to be committed, since they contain no microdata (see Hygiene notes).
- `outputs_v26_one_shot_final/{fig,tab}/` — roughly 46 figures and 55+ tables
  (`F01`…`F46`, `T00`…`T34`), plus `GENERATED_THESIS_PROSE.md`, in which every
  narrative sentence citing a number is generated from the fitted objects
  rather than transcribed by hand, "so text and results cannot diverge."
- `MAPPING.md`, referenced in the document's own instructions as the full
  output-to-thesis-exhibit correspondence table — not present in this
  repository (see Hygiene notes).

## Reproducing

There is no `install.R`, `renv.lock`, or `DESCRIPTION` in this repository yet.
The document declares its own dependencies at the top of the `cfg` chunk; to
install them manually:

```r
install.packages(c(
  "data.table","arrow","lme4","lmerTest","fixest","broom.mixed",
  "ggplot2","patchwork","scales","ggrepel","viridis",
  "glmnet","xgboost","mice","psych","GPArotation","dplyr","parallel",
  "countrycode","gt","digest"
))
```

You will also need R, [Quarto](https://quarto.org), and (to actually run it)
a licensed Gallup World Poll extract and a World Bank GDP-per-capita panel:

1. Place the Gallup extract at `data/gallup_extract.parquet` (or set the
   `GALLUP_PARQUET` environment variable) and the World Bank panel at
   `data/wb_panel.rds` (or `WB_PANEL`). The preflight section verifies each
   against a pinned SHA-256 before anything expensive runs.
2. Render:
   ```bash
   quarto render no-universal-ranking.qmd
   ```
   (the document's own render instruction previously pointed at a stale
   filename, `CAPSTONE_PIPELINE_V29_REPRODUCIBLE.qmd` — see Hygiene notes;
   this has been corrected in the source to `no-universal-ranking.qmd`.)
3. `CFG$QUICK` in the `cfg` chunk is frozen at `FALSE` — the configuration
   that, per the document, produced every number in the dissertation. Flip it
   to `TRUE` first for a several-minutes structural validation pass on a
   stratified respondent subsample before committing to the multi-hour full
   run.

## Hygiene notes

- **`.gitignore` gaps.** The committed `.gitignore` ignores `output/`, but
  the pipeline actually writes to `outputs_v26_one_shot_final/`; a real run
  would not have been excluded. It also has no entries for `renv`'s own
  local library, which the document's reproducibility contract depends on.
  Both are now added.
- **`data/` is a blanket ignore, but the code expects part of it committed.**
  `CFG$downstream_dir` (`data/downstream_checkpoints/`) is described in-code
  as containing only small, aggregated, license-free CSVs that *should* ship
  with the repository — but the current `.gitignore` excludes all of `data/`
  indiscriminately, and no such folder exists yet in this clone. Added a
  narrow negation so that path can be committed without exposing the
  microdata paths beside it.
- **`renv.lock` is referenced but absent.** The reproducibility contract
  (top of the document) and a runtime check in the `cfg` chunk both assume
  `renv.lock` is shipped; it is not present anywhere in this repository. This
  can't be fabricated without running `renv::snapshot()` against a real
  library, so it is flagged here rather than invented — see "Anything I
  couldn't verify" below.
- **Stale filename in the render instructions — fixed.** Step 3 of the
  reproducibility contract told a reader to `quarto render
  CAPSTONE_PIPELINE_V29_REPRODUCIBLE.qmd`, a file that does not exist in this
  repository (the actual file is `no-universal-ranking.qmd`, evidently
  renamed for publication without updating this line). Corrected directly in
  the source (line 31) to `quarto render no-universal-ranking.qmd`.
- **`MAPPING.md` is referenced but absent.** The document tells readers to
  consult it before citing any output as "the thesis figure/table." It is not
  in this repository. Not fabricated here — flagged for the author to add or
  the reference to be removed.
- **~740 lines of R at the end of the file sat outside any code fence — fixed.**
  The document's last ` ```{r synth}` chunk closed at line 5066; everything
  from the `CANDIDATE MAIN-TEXT FIGURES` header (line ~5068) to the end of
  the file — the code producing three of the "final" thesis figures the
  document's own recovery notes point to — was plain body text, not inside a
  ` ```{r} ` fence. As previously committed, Quarto would have rendered this
  block as literal text in the output document rather than executed it. Not
  a small formatting slip: it was the block that produces the figures the
  recovery notes say supersede the earlier drafts. Now wrapped in a proper
  ` ```{r candidate_figures}` / `#| cache: false` chunk, matching the
  labelling and chunk-option convention used by the document's other nine
  code chunks — no R code inside the block was changed, only the fence added
  around it. Verified with `knitr::purl()`, which now extracts this chunk as
  chunk 20 of 20, and with a base-R `parse()` of the purled output, which
  completes without error.
- **Candidate exam number redacted.** One R comment in the `synth` section
  (verifying the leave-one-out/sensitivity table against the submitted
  thesis) left a specific candidate exam number in cleartext —
  `MY498_73280` — despite the YAML author field being anonymised to
  "Candidate XXXXX." Redacted in the source to `MY498_XXXXX`.
- **No LICENSE file.** Not requested, noting for completeness.
- No stray `.DS_Store`, `.ipynb_checkpoints`, `__pycache__`, or empty
  placeholder files were found in the tracked tree.

### Exact diff made to `.gitignore`

```diff
 # Data — licensed, never committed
 data/
 *.parquet
 *.csv
 *.sav
 *.dta
 
+# Exception: small, aggregated, license-free stability-diagnostic checkpoints
+# that CFG$downstream_dir in no-universal-ranking.qmd expects to find
+# committed (leave-one-country-out, sample-weighting sensitivity, MICE
+# sensitivity summaries feeding Table 7 / Figure 15). No microdata here.
+!data/downstream_checkpoints/
+!data/downstream_checkpoints/*.csv
+
 # Generated output
 output/
+outputs_v26_one_shot_final/
+outputs*/
+
+# renv (renv.lock IS meant to be committed; its local library is not)
+renv/library/
+renv/local/
+renv/cellar/
+renv/lock/
+renv/python/
+renv/sandbox/
+renv/staging/
+
+# Quarto/knitr stray artefacts
+.ipynb_checkpoints/
+__pycache__/
```

The negation is ordered *after* the `*.csv` blanket rule (git evaluates
`.gitignore` patterns in file order, last match wins), and the directory is
un-excluded before the file pattern inside it, so both are needed for the
checkpoint CSVs to actually be committable.

## Anything I'm unsure about / couldn't verify

- The `data/downstream_checkpoints/` negation assumes only the three named
  checkpoint CSVs (and nothing large or licensed) would ever land in that
  folder. If other files end up there, the folder-level negation would
  expose them too — worth a second look before actually committing anything
  into it.
- The GitHub description states "168 countries." I could not verify an exact
  country count from this repository's content — that number is a property
  of the licensed extract, which isn't present, and the code computes it at
  runtime (`uniqueN(ANA$iso3)`) rather than hardcoding it anywhere I found.
- The institution/programme. The document refers throughout to "the
  dissertation," "the thesis," "the candidate" and "the supervisor," and one
  comment ties a verification pass to a submitted document under a module
  code (`MY498`); a specific candidate number that had been left in cleartext
  in that comment (the YAML author field was otherwise anonymised to
  "Candidate XXXXX") has now been redacted to `MY498_XXXXX` — see Hygiene
  notes. Nothing inside this repository names an institution. The module-code
  format and phrasing match the same
  author's `MY474` (household-burden-classifier) repository, which does name
  LSE — I have treated that as a reasonable but unconfirmed inference, not
  stated it as fact.
- I could not confirm renv.lock's absence is accidental rather than
  deliberate (e.g., omitted because it's large or machine-specific); I did
  not attempt to generate one, since doing so meaningfully requires actually
  restoring the described library.

## Context

Published, per the commit history, as "the submitted capstone analysis" in
August 2026. The document's own YAML front matter lists the author as
"Candidate XXXXX" (anonymised), and its text repeatedly refers to itself as a
dissertation/thesis produced for a named supervisor — consistent with a
Master's capstone submission, though this repository does not itself state
the institution or programme.
