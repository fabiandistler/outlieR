# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

## Overview

**outlieR** is an R package for automatic outlier detection using
Isolation Forests (via the `isotree` package). It provides a simple API
with automatic hyperparameter tuning, detailed feature-level
diagnostics, and comprehensive visualizations.

**Key features:** - Single main function
([`detect_outliers()`](https://fabiandistler.github.io/outlieR/reference/detect_outliers.md))
for most use cases - Automatic hyperparameter tuning (grid, random, or
Bayesian search) - Per-feature outlier analysis using robust
statistics - Rich visualization suite (score plots, PCA, feature
importance, heatmaps) - `data.table` design for efficient data
processing - Support for numeric and categorical variables with
automatic one-hot encoding

## Package Structure

### Core Modules

1.  **R/detect_outliers.R** - Main API and user-facing functions
    - [`detect_outliers()`](https://fabiandistler.github.io/outlieR/reference/detect_outliers.md):
      Primary function for outlier detection
    - [`get_outlier_summary()`](https://fabiandistler.github.io/outlieR/reference/get_outlier_summary.md):
      Extract outlier information
    - S3 methods:
      [`print.outlier_detector()`](https://fabiandistler.github.io/outlieR/reference/print.outlier_detector.md),
      [`summary.outlier_detector()`](https://fabiandistler.github.io/outlieR/reference/summary.outlier_detector.md)
    - Returns `outlier_detector` S3 class containing model, scores,
      outliers, diagnostics
2.  **R/preprocessing.R** - Data preparation pipeline
    - [`prepare_data()`](https://fabiandistler.github.io/outlieR/reference/prepare_data.md):
      Handles column selection, type detection, one-hot encoding
    - [`validate_inputs()`](https://fabiandistler.github.io/outlieR/reference/validate_inputs.md):
      Input validation
    - [`generate_outlier_details()`](https://fabiandistler.github.io/outlieR/reference/generate_outlier_details.md):
      Creates per-observation feature-level analysis using robust
      z-scores (MAD-based)
    - Automatic median imputation for missing values
3.  **R/tuning.R** - Hyperparameter optimization
    - [`tune_parameters()`](https://fabiandistler.github.io/outlieR/reference/tune_parameters.md):
      Main tuning dispatcher
    - [`tune_grid_search()`](https://fabiandistler.github.io/outlieR/reference/tune_grid_search.md):
      Grid search over parameter combinations
    - [`tune_random_search()`](https://fabiandistler.github.io/outlieR/reference/tune_random_search.md):
      Random sampling of hyperparameters
    - [`tune_bayesian_optimization()`](https://fabiandistler.github.io/outlieR/reference/tune_bayesian_optimization.md):
      Placeholder (currently falls back to random search)
    - [`evaluate_params()`](https://fabiandistler.github.io/outlieR/reference/evaluate_params.md):
      Uses Cohen’s d effect size to measure outlier separation quality
    - Supports parallel processing via `parallel` package
4.  **R/visualization.R** - Plotting functionality
    - S3 method:
      [`plot.outlier_detector()`](https://fabiandistler.github.io/outlieR/reference/plot.outlier_detector.md)
    - Plot types: “score”, “features”, “distribution”, “pca”, “heatmap”,
      “all”
    - Uses `ggplot2` for individual plots, `patchwork` for combining
      multiple plots
    - PCA plotting requires stored original data (only for datasets
      ≤10,000 rows)
5.  **R/outlieR-package.R** - Package documentation

### Testing

- Uses `testthat` framework
- Test files mirror R/ structure: `test-detect_outliers.R`,
  `test-preprocessing.R`, `test-tuning.R`, `test-visualization.R`
- Tests use `tune = FALSE` by default for speed
- Located in `tests/testthat/`

## Development Commands

### Build and Check

``` r
# Load package during development
devtools::load_all()

# Run tests
devtools::test()

# Run a single test file
testthat::test_file("tests/testthat/test-detect_outliers.R")

# Check package (full CRAN checks)
devtools::check()

# Build package
devtools::build()

# Install locally
devtools::install()
```

### Documentation

``` r
# Generate documentation from roxygen2 comments
devtools::document()

# Preview README
rmarkdown::render("README.Rmd")
```

### Code Quality

``` r
# Style code (tidyverse style guide)
styler::style_pkg()

# Lint code
lintr::lint_package()
```

### Before Pushing

``` bash
# From R console:
devtools::document()    # Update documentation
devtools::test()        # Run all tests
devtools::check()       # Run R CMD check
styler::style_pkg()     # Format code
```

## Architecture Notes

### Outlier Detection Workflow

1.  **Input validation**
    ([`validate_inputs()`](https://fabiandistler.github.io/outlieR/reference/validate_inputs.md)) -
    checks data types, dimensions, parameter ranges
2.  **Preprocessing**
    ([`prepare_data()`](https://fabiandistler.github.io/outlieR/reference/prepare_data.md)) -
    selects columns, encodes categoricals, imputes missing values
3.  **Tuning** (optional) - evaluates parameter combinations using
    parallel processing, ranks by Cohen’s d
4.  **Model training** - builds
    [`isotree::isolation.forest`](https://rdrr.io/pkg/isotree/man/isolation.forest.html)
    with optimized/specified parameters
5.  **Scoring** - computes anomaly scores (average path depth)
6.  **Threshold determination** - uses contamination parameter with
    quantile-based threshold
7.  **Detailed analysis** - generates per-observation, per-feature
    diagnostics using MAD-based robust z-scores

### Diagnostics Generation

The package computes detailed outlier information in
[`generate_outlier_details()`](https://fabiandistler.github.io/outlieR/reference/generate_outlier_details.md): -
For each observation, calculates robust z-scores for each feature using
MAD (Median Absolute Deviation) - Identifies features with z-score \> 3
as outlier features - Stores feature scores as
`feat_score_<feature_name>` columns - Computes `n_outlier_features` and
`top_outlier_features` for each outlier - Returns comprehensive
`data.table` for flexible downstream analysis

### Key Design Decisions

- **data.table internally**: Efficient operations, especially for
  feature-level analysis
- **data.frame compatibility**: Accepts and works with both data.frame
  and data.table inputs
- **Minimal storage**: Original data only stored for datasets ≤10,000
  rows (affects PCA plotting)
- **Parallel by default**: Tuning uses parallel processing unless
  disabled
- **Contamination-based thresholding**: Uses quantile approach rather
  than fixed threshold

## Common Workflows

### Adding New Tuning Methods

To add a new tuning algorithm: 1. Add function `tune_<method>_search()`
in `R/tuning.R` 2. Update
[`tune_parameters()`](https://fabiandistler.github.io/outlieR/reference/tune_parameters.md)
switch statement 3. Update
[`detect_outliers()`](https://fabiandistler.github.io/outlieR/reference/detect_outliers.md)
parameter documentation 4. Add tests in `tests/testthat/test-tuning.R`

### Adding New Visualizations

To add a new plot type: 1. Create `plot_<type>()` helper function in
`R/visualization.R` 2. Add case to
[`plot.outlier_detector()`](https://fabiandistler.github.io/outlieR/reference/plot.outlier_detector.md)
switch statement 3. Update documentation and examples 4. Add tests in
`tests/testthat/test-visualization.R`

### Modifying Outlier Diagnostics

Feature-level analysis is centralized in
[`generate_outlier_details()`](https://fabiandistler.github.io/outlieR/reference/generate_outlier_details.md): -
Uses MAD-based robust z-scores (less sensitive to outliers than standard
deviation) - Z-score \> 3 threshold for identifying outlier features -
Modify this function to change diagnostic logic package-wide

## Dependencies

**Core dependencies:** - `isotree`: Isolation forest implementation -
`data.table`: Efficient data manipulation - `cli`: User-friendly console
output - `ggplot2`: Visualization - `parallel`: Parallel processing for
tuning - `patchwork`: Combining multiple plots

**Suggested:** - `testthat`: Testing framework

## Important Constraints

- Minimum 10 rows required for analysis
- Contamination must be between 0 and 1 (exclusive)
- PCA plots require original data storage (datasets ≤10,000 rows)
- Bayesian optimization not yet implemented (falls back to random
  search)
- Categorical variables must be convertible to factors for encoding
- Missing values imputed with median (numeric only)
