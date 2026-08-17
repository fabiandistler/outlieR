# outlieR Package State — Research Findings

Ticket: #6 (wayfinder:research) — assessed 2026-08-17 on branch `research/package-state`.

## Summary

outlieR v0.1.0 is in good shape for an early release: **tests pass (64/64), R CMD check is clean apart from 1 trivial NOTE, docs/CI/pkgdown are all in place**. It is not yet ready for unguarded use by a team at work: the **default grid tuning takes ~7 minutes on a 2k×11 dataset (1350 isotree fits)**, the **final model ignores the tuned split-probability parameters** (hardcoded `prob_pick_* = 0/0/1/0`, producing degenerate deterministic forests when `ndim = 1`), and **parallel tuning is not reproducible** (worker RNG never seeded). Missing-value handling, categorical encoding, and diagnostics are functional but have edge-case gaps.

Environment note: the test suite and check could not run out of the box — `isotree` and `patchwork` were not installed in the R library and had to be installed first.

## Check results

### Tests (`devtools::test()`)

```
[ FAIL 0 | WARN 33 | SKIP 0 | PASS 64 ]
```

- 64 passing, 0 failing, 0 skipped.
- **33 warnings**, all emitted by isotree:
  - ~30× *"Passed parameters for deterministic single-variable splits with no sub-sampling. Every tree fitted will end up doing exactly the same splits"* — every test calling `detect_outliers(..., tune = FALSE)` triggers this (mtcars, iris, etc.). Root cause: `detect_outliers()` hardcodes `prob_pick_pooled_gain = 0`, `prob_pick_avg_gain = 0`, `prob_pick_full_gain = 1`, `prob_pick_dens = 0` (R/detect_outliers.R:103-106). With the default `ndim = 1`, all trees are identical — the "forest" is effectively one tree. This is a real model-quality problem, not just noise.
  - 3× *"Split type probabilities sum to more than 1, will standardize them"* — during random/grid search, `prob_pick_avg_gain` and `prob_pick_pooled_gain` are sampled independently (R/tuning.R:27-28, 124-125), so combinations exceeding 1 are standardized by isotree — those evaluations are wasted, and the two parameters are coupled but tuned as if independent.

### R CMD check (`devtools::check(args = "--no-manual", cran = FALSE)`)

```
0 errors | 0 warnings | 1 note
```

Ran in ~5 min with `--no-manual` (full manual check would exceed the 15-min budget; nothing else was skipped). Only NOTE:

```
❯ checking R code for possible problems ... NOTE
  get_outlier_summary: no visible global function definition for '.'
  plot_feature_importance: no visible global function definition for '.'
  plot_outlier_distribution: no visible binding for global variable 'type'
```

- `.` comes from data.table's list shorthand `.(...)` used in `get_outlier_summary` (R/detect_outliers.R:189) and `plot_feature_importance` (R/visualization.R:159) — `.` is not in the `importFrom(data.table, ...)` list (NAMESPACE lines 8-15).
- `type` is a column name created in `plot_outlier_distribution` (R/visualization.R:192) but not declared in `utils::globalVariables()`.
- Fix is one-line each: add `.` to the roxygen `@importFrom data.table` block and `"type"` to `globalVariables` (R/utils.R:2-6).

`cran-comments.md` already claims exactly "0 errors | 0 warnings | 1 note" — consistent with reality.

### lintr (`lintr::lint_package()`)

- **139 findings: 91 warnings, 48 style** (package installed before linting; without it there are 3 extra false positives).
- ~120 are `object_usage_linter` false positives inherent to data.table NSE: no visible binding for `:=`, `.SD`, `score`, `is_outlier`, `feature`, `row_id`, `anomaly_score`, `n_outlier_features`, `.N`, `top_outlier_features`, `PC1`, `PC2` — most are already in `globalVariables()` (R/utils.R) or `importFrom`'d; lintr still flags them because they are used inside `data.table` expressions it cannot see into. `:=` and `.` ARE flagged even though imported, which lintr resolves by scanning the installed package namespace.
- Genuine findings:
  - `line_length_linter` (80 cols): ~25 violations, concentrated in R/visualization.R.
  - `return_linter` (explicit `return()`): 4 in R/preprocessing.R:269, R/tuning.R:104/174, and R/preprocessing.R:150.
  - 2× `tests/spelling.R` style.
- Distribution: R/visualization.R 63, R/preprocessing.R 26, R/detect_outliers.R 21, R/tuning.R 20, tests/spelling.R 2.

### styler (`styler::style_pkg(dry = "on")`)

- 14 of 15 files already compliant. **Only `tests/spelling.R` would be reformatted** (function call braces). No styler work needed in `R/`.

## Code quality

- Structure is clean: one concern per file (detect_outliers API, preprocessing, tuning, visualization, utils), roxygen2 fully covering all exported functions, `@noRd`/`@keywords internal` on internals, no `:::`, no base-pipe issues (R >= 4.1 `|>` matches `Depends: R (>= 4.1.0)`).
- NAMESPACE is minimal and hygienic (6 exports, importFrom data.table only; cli/ggplot2/etc. accessed via `::`).
- Error handling: `validate_inputs()` (R/preprocessing.R:121-151) checks data type, min 10 rows, target_cols type/emptiness, contamination range. **Gaps:** `n_trees`, `sample_size`, `max_depth`, `seed`, `parallel`, `verbose` are never validated (a character `n_trees` passes through to isotree); target_cols existence is checked only in `prepare_data`, so invalid columns error mid-pipeline rather than up front.
- `evaluate_params()` swallows all errors into `score = -Inf` (R/tuning.R:260-263) — good for robustness, but the grid search can silently return "best" parameters where every combination failed.
- Categorical handling: one-hot encoding drops the first level and loops `for (i in 2:length(levels))` with per-column `:=` — functionally correct, but (a) **no cap on cardinality** (a 500-level column becomes 499 columns), (b) level names are not `make.names()`-sanitized (a level `"a b"` produces a column `cat_a b`), (c) logical and Date columns are silently excluded from the usable-column scan (R/preprocessing.R:19-21).
- Missing values: only numeric columns are median-imputed (R/preprocessing.R:87-92); categorical NAs are *indirectly* handled because one-hot columns are numeric and get median-imputed too. Edge cases: an **all-NA column stays NA** (median of NA is NA) and will break isotree at fit time with an unclear error; imputation happens **after** encoding, so the encoded representation is "median one-hot vector" rather than "most common category".

## Performance

Measured on a 2000×11 dataset (10 numeric + 1 five-level categorical), serial, 8-core laptop:

| Configuration | Time |
|---|---|
| Default (`tune = TRUE`, grid) | **433.9 s** — 1350 parameter combinations |
| Random search (20 evals) | 7.5 s |
| No tuning (`tune = FALSE`) | 0.63 s |

- **The default is grid tuning with 1350 fits** (3 ndim × 3 ntrees × 5 × 5 split probs × 3 ntry × 2 sample_size). On mtcars it's 675 combinations; on team-sized data (10k–100k rows) this is hours serial. Parallel helps linearly with cores but is capped at `n_cores - 1` (R/utils.R:31) and not reproducible (see below). **Recommendation: make `tune = FALSE` the default, or default `tune_method = "random"`** (20 evals ≈ 1.7% of grid cost).
- `generate_outlier_details()` (R/preprocessing.R:162-270) has the only row-wise loops in the package: a `for (i in seq_along(outlier_indices))` with an inner `sapply` over features, and `by = row_id` group-bys for `n_outlier_features`/`top_outlier_features` (lines 229-252). It also allocates a full `n_obs × n_features` NA matrix (lines 195-200) even though only outlier rows are filled. Cost is O(outliers × features) with heavy per-row R overhead — acceptable at ≤10k rows, slow at 100k+ rows. Could be vectorized: compute the MAD z-score matrix for all rows in one step, then `n_outlier_features <- rowSums(z > 3)`.
- `prepare_data()` copies the target data (`data.table::copy`, R/preprocessing.R:46) — unnecessary (the one-hot loop could modify in place) but not a hotspot.
- Everything else is vectorized data.table/isotree. No `data.frame`-row iteration, no `apply` misuse elsewhere.

### Parallel code path (R/tuning.R:61-87, 130-147)

- `parallel::makeCluster` + `clusterExport` copies the **entire data frame to every worker** on each tuning call.
- **No RNG seeding in workers** → results of parallel tuning are non-reproducible even with `seed = 123` (the existing "seed produces reproducible results" test only covers `tune = FALSE`). `withr::local_seed` in `detect_outliers` (R/detect_outliers.R:65) affects only the master process.
- No progress reporting in the parallel branch (the `i %% 5` progress is serial-only).
- `get_n_cores()` respects `_R_CHECK_LIMIT_CORES_` — good CRAN hygiene.

## CRAN-readiness

Largely ready; the ONE check NOTE is the only blocker.

| Item | Status |
|---|---|
| DESCRIPTION | Complete: Title, Description, Authors@R (aut+cre), MIT + file LICENSE, URL/BugReports, Imports/Suggests, `Config/testthat/edition: 3`, Encoding, Language, RoxygenNote | 
| NAMESPACE | Minimal, generated by roxygen2, matches R/outlieR-package.R imports |
| man/ | 24 .Rd files covering every exported function + internal helpers; `checking Rd files`/`code/documentation mismatches` all OK |
| NEWS.md | Present but minimal (4 bullets) — fine for a first release |
| cran-comments.md | Present and accurate ("0 errors, 0 warnings, 1 note; new release") |
| LICENSE | Standard MIT template, correct YEAR/holder |
| Vignettes | `getting-started.Rmd` builds cleanly in check (vignette re-build OK) |
| CITATION | inst/CITATION present |
| CI | R-CMD-check (macos/windows/ubuntu × devel/release/oldrel-1), pkgdown.yaml, test-coverage.yaml (codecov, informational status) |
| pkgdown | `_pkgdown.yml` complete (reference index, navbar, footer); `gh-pages` branch exists (site deployed) |
| Spelling | `spelling` in Suggests, inst/WORDLIST + tests/spelling.R present, passes |
| Todo | `.Rbuildignore` covers Rproj, LICENSE.md, README.Rmd, dev/, CLAUDE.md, .github, codecov.yml, docs |

The `.(...)`/`type` NOTE is the only thing that would need fixing for a CRAN submission; everything else would just be recommendations.

## Gaps for team use

1. **Slow by default.** `detect_outliers(data)` on real data triggers 1350 isotree fits (measured 434 s at 2k rows; hours at 100k rows). Teams will either wait or discover `tune = FALSE`/`random` by accident.
2. **Degenerate forest when `tune = FALSE` (and sometimes when tuned).** Hardcoded `prob_pick_*` parameters (R/detect_outliers.R:103-106) make every tree identical at `ndim = 1`; isotree warns about it in every run. The tuned `prob_pick_avg_gain`/`prob_pick_pooled_gain` values are **never used** in the final model — a correctness gap between tuning and final fit.
3. **Non-reproducible parallel tuning.** No worker RNG seeding; `seed` param has no effect on tuned results in parallel mode. A team running the same code twice gets different results.
4. **Silent, edge-case-prone missing-value handling.** Median imputation only; all-NA columns crash isotree with an opaque error; no imputation method choice.
5. **Categorical encoding limits.** No high-cardinality guard (column explosion), no name sanitization, logical/Date columns silently dropped without warning.
6. **No new-data prediction helper.** `detect_outliers()` returns a model, but there is no `predict.outlier_detector()` — teams must reach into `result$model` and reproduce preprocessing by hand to score new rows.
7. **Diagnostics cost.** Per-row loop + full-matrix allocation in `generate_outlier_details()` slows large datasets; PCA plot silently unavailable above 10k rows (data not stored) with only a placeholder message.
8. **Warnings in normal operation.** 33 warnings per test-suite run degrade signal in CI; teams will start ignoring output.
9. **Input validation gaps.** `n_trees`/`sample_size`/`max_depth`/`seed`/`parallel`/`verbose` unvalidated; invalid `target_cols` fails after preprocessing already ran.

## Concrete fix list

Priority-ordered:

1. **Default-safety (P0, behavior change):** default `tune = FALSE` (or `tune_method = "random"`); keep `tune = TRUE` opt-in. Update DESCRIPTION/README/vignette wording accordingly.
2. **Honor tuned parameters (P0, bug):** pass tuned `prob_pick_avg_gain`/`prob_pick_pooled_gain` (and `prob_pick_dens`) into the final `isolation.forest` call instead of hardcoding 0/0/1/0; ensure the sum of split probabilities ≤ 1 in the search space (sample them jointly).
3. **Reproducible parallel tuning (P1):** seed workers via `parallel::clusterSetRNGStream` when `seed` is given; document that parallel tuning is seeded.
4. **R CMD check NOTE (P1, CRAN blocker):** add `.` to `@importFrom data.table` and `"type"` to `globalVariables()` in R/utils.R; regenerate NAMESPACE with `devtools::document()`.
5. **Imputation hardening (P1):** reject or handle all-NA columns up front (clear error), offer `median`/`mean`/`mode`/`none` methods, impute before one-hot encoding for categoricals.
6. **Categorical guards (P2):** cap one-hot expansion (e.g. max 50 levels, else ordinal/frequency encoding), `make.names()` on levels, include logical columns or warn on silent exclusion.
7. **Vectorize diagnostics (P2):** replace the per-outlier loop in `generate_outlier_details()` with a single vectorized MAD z-score matrix + `rowSums`; avoid the full-N matrix allocation.
8. **Validation (P2):** extend `validate_inputs()` to all remaining args; move target_cols existence check there.
9. **Quiet by default (P2):** reduce isotree warnings to at most one user-facing message (e.g. when the model is degenerate); this also cleans up CI logs.
10. **Predict helper (P3):** add `predict.outlier_detector()` that re-applies `preprocessing$info` encoding/imputation to new data.
11. **Lint cleanup (P3):** add `.lintr` config (e.g. `line_length_linter(100)`), fix the 4 explicit `return()`s, and consider `object_usage_linter` suppression for data.table expressions; run `styler` on `tests/spelling.R`.
12. **Benchmark/limits doc (P3):** document expected runtime and 10k-row PCA caveat in README/vignette.

## Method

- Tests: `Rscript -e 'devtools::test()'` (installed missing `isotree`/`patchwork` first).
- Check: `Rscript -e 'devtools::check(args = "--no-manual", cran = FALSE)'` — 0 errors, 0 warnings, 1 NOTE (~5 min; `--no-manual` used per ticket budget).
- Lint: `lintr::lint_package()` — 139 findings (91 warnings / 48 style).
- Style: `styler::style_pkg(dry = "on")` — only `tests/spelling.R` would change.
- Benchmark: `detect_outliers()` on 2000×11 synthetic data, serial, with a stopwatch (values above).
- Sources: R/detect_outliers.R, R/preprocessing.R, R/tuning.R, R/visualization.R, R/utils.R, R/outlieR-package.R, NAMESPACE, DESCRIPTION, tests/testthat/*.R, README.md, _pkgdown.yml, .github/workflows/*, inst/CITATION, cran-comments.md, NEWS.md.
