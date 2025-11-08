# Prepare Data for Outlier Detection

Internal function to preprocess and encode data for isotree. Handles
missing values, categorical encoding, and scaling.

## Usage

``` r
prepare_data(data, target_cols = NULL)
```

## Arguments

- data:

  A data.frame or data.table

- target_cols:

  Character vector of columns to use

## Value

List with processed data and preprocessing info
