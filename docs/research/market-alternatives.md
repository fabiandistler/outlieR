# Market & alternatives for automatic data-error detection

Research ticket: [fabiandistler/outlieR#5](https://github.com/fabiandistler/outlieR/issues/5)
Date: 2026-08-17
Scope: tools that cover automatic data-error detection in tabular data, compared against outlieR's feature set (single API `detect_outliers()`, automatic hyperparameter tuning, per-feature diagnostics, visualizations, data.table-based).

## Summary

The market splits into three camps, and none of them combines what outlieR does:

1. **Rule-based data-quality tools** (R: `pointblank`, `validate`, `dataMaid`, `dlookr`; Python: Great Expectations, pandera, Soda Core) — powerful and established, but require a human to *declare* every check. They detect *known* problems (missingness, ranges, duplicates, schema) and have no unsupervised multivariate anomaly detection.
2. **Anomaly-detection algorithm toolboxes** (R: `isotree`, `outlierensembles`, `HDoutliers`, `DDoutlier`, `mvoutlier`, `Rlof`; Python: PyOD) — rich algorithm collections, but engine-level: no auto-tuning, no per-feature explainability, no reports, no threshold determination.
3. **Enterprise data-quality platforms** (Anomalo, Monte Carlo, Soda Cloud) — automated, ML-driven anomaly detection plus observability, but closed SaaS aimed at warehouses, with weekly learning periods and per-table minimum volumes; not applicable to in-process R analysis.

R's dedicated anomaly detection is dominated by **time-series** tools (`anomalize`/`timetk`); multivariate *tabular* anomaly detection in R is otherwise a collection of low-level research packages. The two most feature-overlapping tools are `outForest` (per-cell outlier scores + replacement, but numeric-only, no tuning, no visuals) and `cleanlab` (per-row issue scores, but requires a trained model / labels and is Python-only).

outlieR's credible niche: **the zero-configuration, explainable, multivariate anomaly detector for R + data.table teams** — automatic (no rules to write), non-parametric (isolation forest via `isotree`), per-feature explainable (MAD-based robust z-scores), visual (ggplot2 suite), and fast on large tables (data.table). Its gap: no built-in *standard quality checks* (missingness, duplicates, ranges) and no report artifact — combining those with the anomaly detection in one call is the open opportunity.

## Landscape table

| Tool | Ecosystem | What it does | Feature overlap with outlieR | Gap vs. outlieR |
|---|---|---|---|---|
| `pointblank` | R (Posit) | Agent-based rule validation; 6 workflows incl. DQ reporting; in-database validation (Postgres, MySQL, SQL Server, BigQuery, DuckDB, SQLite, Spark); gt reports, YAML agents, multiagent history | None on detection; strong reporting UX that outlieR lacks | Rule-declared checks only; no automatic anomaly detection |
| `validate` | R (data-cleaning) | Declarative validation-rule DSL + quality indicators; record-wise/cross-record/cross-dataset rules; functional dependencies; SDMX import | None on detection; rule-as-first-class-citizen design | Manual rules; no unsupervised detection; no visuals beyond violation plots |
| `dataMaid` | R | Auto-generated data screening reports (makeDataReport); per-type checks (missing, outliers Tukey-style, loners, case issues, whitespace, key) | Univariate outlier check; report artifact | Supervised screening for human review; univariate only; no model |
| `dlookr` | R | Data diagnosis/EDA/transformation; `diagnose_outlier()` (IQR-based, univariate); web/paged reports; DBMS support; imputation | Outlier counts/ratios per column; reports | Univariate IQR outliers only; no multivariate detection, no model |
| `anomalize` (→ `timetk`) | R (tidyverse) | Tidy time-series anomaly detection: STL/Twitter decomposition + IQR/GESD; plots; `clean_anomalies()` | Anomaly detection + plots | Time series only, univariate; superceded by `timetk`; no tuning, no per-feature diagnostics |
| `isotree` (engine outlieR wraps) | R/Python/C++ | Fast multi-threaded isolation forest + EIF, SCiForest, FCF, RRCF; categoricals, missing-data heuristics, imputation, distances | Same underlying algorithm; categorical support | Engine-level: ~40 manual hyperparameters, no auto-tuning, no threshold, no per-feature diagnostics, no visuals |
| `outForest` | R | Multivariate per-cell outlier scores (RF regression on all other vars, scaled OOB residual); replacement via PMM; `predict()` on new data; plot/summary | Per-feature (per-cell) outlier diagnostics; replacement ideas | Numeric-only; no auto-tuning; no categoricals; sparse visuals; no row-level flagging |
| `outlierensembles` | R | Ensembles of outlier scores (IRT, greedy, ICWA, max, threshold, average) from any detectors | Ensemble scoring concept | Scores as input; no model fitting, no tuning, no diagnostics, no visuals |
| `HDoutliers`, `DDoutlier`, `mvoutlier`, `Rlof` | R | Single-algorithm outlier detectors (HDoutliers, 60+ via DDoutlier, robust Mahalanobis, parallel LOF) | Algorithm coverage | Research-style APIs; no tuning, no diagnostics, no reports |
| Great Expectations (GX Core) | Python | Expectations = unit tests for data; suites, Data Docs (auto docs), validation definitions, orchestrator integration (Airflow et al.); GX Cloud | Validation automation; documentation rendering | Rule-declared expectations only; no unsupervised detection |
| pandera | Python (Union.ai) | DataFrame schema/type validation + Checks + statistical Hypothesis tests (t-tests, normality); pandas/polars/pyspark/ibis; lazy error reports; decorators | Statistical checks | Declared schemas only; hypothesis tests are user-specified; no anomaly scoring |
| cleanlab | Python | Data-centric AI: Datalab finds label errors, outliers (OOD), near-duplicates, non-IID, class imbalance, nulls; per-row issue scores; CleanLearning robust training; Cleanlab Studio | Per-row issue scores incl. outliers; "find issues automatically" | Needs model `pred_probs`/embeddings or labels; ML-pipeline focus; Python-only |
| PyOD | Python | 60+ anomaly detectors (tabular, time series, graph, text); uniform fit/predict API; ADBench-backed detector routing; model combination | Broad algorithm coverage; single API per detector | No auto-tuning; no per-feature diagnostics; no reports; pandas/numpy only |
| Soda Core | Python (OSS) + Soda Cloud | Data-contract engine; YAML contracts; 50+ built-in checks; scans over 18+ sources; anomaly monitoring in paid Soda Cloud | Contract/check automation | Declared checks only; anomaly detection requires SaaS tier |
| Anomalo | Enterprise SaaS | Unsupervised ML anomaly detection per table + observability (freshness/volume/schema) + validation rules + root cause analysis + lineage; no-code UI | Automatic (unsupervised) anomaly detection; root-cause-ish diagnostics | Warehouse-bound SaaS; needs ~2 weeks learning, ≥100 rows/day; no R API, no local use |
| Monte Carlo | Enterprise SaaS | Data observability; ML auto-thresholds on freshness/volume/schema/metric monitors; validation templates/SQL; 6 DQ dimensions; root-cause analysis | ML thresholds for anomalies; validation | Cloud SaaS; monitoring-focused (time series of table health), not row-level analysis |

## Where outlieR stands

**Feature set (from repo, R/detect_outliers.R):** one call `detect_outliers(data, contamination, tune, tune_method, ...)` → trained `isotree` model, anomaly scores, quantile-based threshold, per-row/per-feature outlier details (MAD-based robust z-scores, `feat_score_*`, `n_outlier_features`, `top_outlier_features`), grid/random/Bayesian hyperparameter tuning with Cohen's d evaluation, parallel tuning, ggplot2 visualizations (score/features/distribution/PCA/heatmap), one-hot encoding for categoricals, median imputation, data.table internals.

**Positioning:**
- *vs. rule-based tools* (pointblank, validate, dataMaid, dlookr, GX, pandera, Soda): outlieR is the only automatic, unsupervised, zero-config option — no rules, no schemas, no expectations to declare. It finds "unknown unknowns"; they verify "known expectations". Complementary, not competing.
- *vs. algorithm toolboxes* (isotree, outlierensembles, DDoutlier, PyOD): outlieR is the only one that adds automatic hyperparameter tuning, automatic thresholding, per-feature explainability, and a visualization suite on top of a production-grade engine. In R this combination is unique (PyOD comes closest but is Python and still lacks tuning + diagnostics).
- *vs. cleanlab*: both do "automatic per-row issue scores", but cleanlab requires a model/labels (supervised, ML-centric); outlieR is fully unsupervised and needs no model outputs.
- *vs. enterprise platforms* (Anomalo, Monte Carlo): outlieR is free, open-source, local, in-process R — the platform's warehouse-monitoring value (lineage, alerting, orchestration) is out of scope by design, but so is their requirement of weeks of history and SaaS infrastructure.

**Gaps (opportunities):**
1. **No standard quality checks** in the same call — missingness, duplicates, out-of-range values, cardinality/type checks (pointblank/validate/dataMaid/GX/pandera all have these). A `detect_outliers()` that also returns a rule-based quality report would directly match the ticket's "combined with standard quality checks" framing.
2. **No report artifact** — pointblank agents, dataMaid reports, GX Data Docs render shareable HTML; outlieR only returns an object + plots.
3. **No out-of-sample scoring** — `outForest` and `isotree::predict` support new data; outlieR does not expose a predict path.
4. **No time-series awareness** — `anomalize`/`timetk` territory, deliberately out of scope for tabular data.

## Credible niche

> **The automatic, explainable, multivariate anomaly detector for R + data.table teams: one call on any tabular data.frame/data.table returns scores, thresholds, per-feature diagnostics, and plots — no rules to write, no hyperparameters to choose, no Python stack.**

Concretely:
- **Primary users:** R-native data teams (data.table shops, pharma/stats/finance analysts, data engineers doing R-based ETL) who today hand-code isolation forests via `isotree` (or misuse `anomalize` on non-time-series data) and get no explainability out of it.
- **Differentiators to lean into:** automatic tuning (unique), per-feature explainability with robust statistics (unique in R), built-in visualization suite (unique), data.table performance + data.frame compatibility, single-function API (unique).
- **Wedge vs. rule-based tools:** position as the *automatic first pass* that flags suspicious rows/features which analysts then verify with pointblank/validate rules — and close the loop by absorbing standard quality checks (missingness, duplicates, ranges) into the same call.
- **Wedge vs. Python:** teams that already live in R + data.table should not need PyOD/cleanlab for row-level anomaly scoring; outlieR is the R-native equivalent with explainability Python lacks out of the box.
- **Recommended roadmap for the niche:** (1) add standard quality checks (missing/duplicate/range/type) as a parallel report section; (2) add `predict()`/`score_new()` for out-of-sample data; (3) optional HTML report export à la pointblank; (4) document the rule-based complement (pointblank/validate) explicitly.

## Sources

Primary sources (official docs / CRAN / package repos), retrieved 2026-08-17:

- anomalize — https://cran.r-project.org/web/packages/anomalize/ , https://business-science.github.io/anomalize/ (README notes functionality superceded by timetk)
- pointblank — https://cran.r-project.org/web/packages/pointblank/ , https://rstudio.github.io/pointblank/articles/validation_workflows.html
- validate — https://cran.r-project.org/web/packages/validate/ , https://data-cleaning.github.io/validate/ , Van der Loo & De Jonge (2021) JSS 97(10) https://doi.org/10.18637/jss.v097.i10
- dataMaid — https://cran.r-project.org/package=dataMaid , https://ekstroem.github.io/dataMaid/ , Petersen & Ekstrøm (2019) JSS 90(6) https://doi.org/10.18637/jss.v090.i06
- dlookr — https://cran.r-project.org/package=dlookr , https://choonghyunryu.github.io/dlookr/articles/diagonosis.html
- outlierensembles — https://cran.r-project.org/package=outlierensembles , https://sevvandi.github.io/outlierensembles/
- isotree — https://cran.r-project.org/package=isotree , https://github.com/david-cortes/isotree
- outForest — https://cran.r-project.org/package=outForest , https://mayer79.github.io/outForest/
- CRAN Task View AnomalyDetection (index of R anomaly packages) — https://cran.r-project.org/web/views/AnomalyDetection.html
- Great Expectations — https://docs.greatexpectations.io/ , https://github.com/great-expectations/great_expectations
- pandera — https://pandera.readthedocs.io/ , https://github.com/unionai-oss/pandera
- cleanlab — https://docs.cleanlab.ai/ , https://github.com/cleanlab/cleanlab
- PyOD — https://pyod.readthedocs.io/ , https://github.com/yzhao062/pyod
- Soda Core — https://github.com/sodadata/soda-core , https://docs.soda.io/
- Anomalo — https://www.anomalo.com/product-overview/ , https://www.anomalo.com/anomaly-detection-software/
- Monte Carlo — https://docs.getmontecarlo.com/docs/anomaly-detection-overview , https://montecarlo.ai/platform/data-quality/
- outlieR (baseline feature set) — https://github.com/fabiandistler/outlieR (R/detect_outliers.R, R/preprocessing.R, R/tuning.R, R/visualization.R)