# Tune Hyperparameters for Isolation Forest

Internal function to automatically tune isotree hyperparameters using
grid search, random search, or Bayesian optimization.

## Usage

``` r
tune_parameters(
  data,
  method = c("grid", "random", "bayesian"),
  contamination = 0.1,
  parallel = TRUE,
  verbose = TRUE
)
```

## Arguments

- data:

  Preprocessed data frame

- method:

  Character. Tuning method: "grid", "random", or "bayesian"

- contamination:

  Expected proportion of outliers

- parallel:

  Logical. Use parallel processing?

- verbose:

  Logical. Print progress?

## Value

List of optimal hyperparameters
