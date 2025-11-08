# Get Number of Cores for Parallel Processing

Internal helper to determine number of cores to use for parallel
processing in a CRAN-compliant way. Respects R CMD check limitations.

## Usage

``` r
get_n_cores(max_tasks)
```

## Arguments

- max_tasks:

  Maximum number of parallel tasks to run

## Value

Integer number of cores to use
