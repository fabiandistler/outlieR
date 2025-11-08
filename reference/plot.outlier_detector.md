# Plot Outlier Detection Results

Create comprehensive visualizations of outlier detection results.

## Usage

``` r
# S3 method for class 'outlier_detector'
plot(
  x,
  type = c("score", "features", "distribution", "pca", "heatmap", "all"),
  n_top = 10,
  ...
)
```

## Arguments

- x:

  An outlier_detector object

- type:

  Character. Type of plot: "score", "features", "distribution", "pca",
  "heatmap", "all"

- n_top:

  Integer. Number of top outliers to highlight in plots. Default: 10

- ...:

  Additional arguments passed to plotting functions

## Value

A ggplot2 object or list of plots (if type = "all")

## Examples

``` r
if (FALSE) { # \dontrun{
result <- detect_outliers(mtcars)

# Score distribution plot
plot(result, type = "score")

# Feature importance for outliers
plot(result, type = "features")

# All plots
plots <- plot(result, type = "all")
} # }
```
