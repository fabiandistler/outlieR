# Extract Outlier Summary

Get a clean summary of outliers with row indices and affected columns.

## Usage

``` r
get_outlier_summary(x, detailed = TRUE)
```

## Arguments

- x:

  An outlier_detector object

- detailed:

  Logical. Return detailed scores per column? Default: TRUE

## Value

A data.table with outlier information

## Examples

``` r
if (FALSE) { # \dontrun{
result <- detect_outliers(mtcars)
summary <- get_outlier_summary(result)
print(summary)
} # }
```
