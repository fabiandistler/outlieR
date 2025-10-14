#' Detect Outliers Using Isolation Forest
#'
#' @description
#' Main function to detect outliers in tabular data using isotree with
#' automatic parameter tuning and comprehensive diagnostics.
#'
#' @param data A data.frame or data.table containing the data to analyze
#' @param target_cols Character vector of column names to analyze. If NULL (default),
#'   all numeric columns are used
#' @param contamination Numeric between 0 and 1. Expected proportion of outliers.
#'   Used for automatic threshold determination. Default: 0.1
#' @param tune Logical. Should hyperparameters be tuned? Default: TRUE
#' @param tune_method Character. Tuning method: "grid", "random", or "bayesian". Default: "grid"
#' @param n_trees Integer. Number of trees in isolation forest. Default: 100
#' @param sample_size Integer or "auto". Sample size for each tree. Default: "auto"
#' @param max_depth Integer or "auto". Maximum tree depth. Default: "auto"
#' @param seed Integer. Random seed for reproducibility. Default: NULL
#' @param parallel Logical. Use parallel processing for tuning? Default: TRUE
#' @param verbose Logical. Print progress messages? Default: TRUE
#'
#' @return An object of class "outlier_detector" containing:
#'   \item{model}{The trained isotree model}
#'   \item{scores}{Anomaly scores for each observation}
#'   \item{outliers}{Logical vector indicating outlier status}
#'   \item{outlier_details}{data.table with detailed outlier information per row and column}
#'   \item{threshold}{The anomaly score threshold used}
#'   \item{params}{Model parameters used}
#'   \item{metrics}{Performance metrics}
#'   \item{data}{Original data (optionally stored)}
#'
#' @examples
#' \dontrun{
#' library(outlieR)
#'
#' # Basic usage
#' result <- detect_outliers(mtcars)
#'
#' # With specific columns and custom contamination
#' result <- detect_outliers(
#'   data = iris,
#'   target_cols = c("Sepal.Length", "Sepal.Width"),
#'   contamination = 0.05
#' )
#'
#' # Without automatic tuning
#' result <- detect_outliers(
#'   data = mtcars,
#'   tune = FALSE,
#'   n_trees = 200,
#'   max_depth = 10
#' )
#' }
#'
#' @export
detect_outliers <- function(data,
                            target_cols = NULL,
                            contamination = 0.1,
                            tune = TRUE,
                            tune_method = c("grid", "random", "bayesian"),
                            n_trees = 100,
                            sample_size = "auto",
                            max_depth = "auto",
                            seed = NULL,
                            parallel = TRUE,
                            verbose = TRUE) {
  # Input validation
  tune_method <- match.arg(tune_method)
  validate_inputs(data, target_cols, contamination)

  if (!is.null(seed)) set.seed(seed)

  if (verbose) cli::cli_alert_info("Preprocessing data...")

  # Preprocess and prepare data
  prep_data <- prepare_data(data, target_cols)

  # Parameter tuning or use defaults
  if (tune) {
    if (verbose) cli::cli_alert_info("Tuning hyperparameters using {tune_method} search...")

    params <- tune_parameters(
      data = prep_data$processed,
      method = tune_method,
      contamination = contamination,
      parallel = parallel,
      verbose = verbose
    )
  } else {
    params <- list(
      ntrees = n_trees,
      sample_size = if (sample_size == "auto") NULL else sample_size,
      max_depth = if (max_depth == "auto") NULL else max_depth,
      ndim = 1,
      ntry = NULL
    )
  }

  if (verbose) cli::cli_alert_info("Training isolation forest model...")

  # Train model
  model_args <- list(
    data = prep_data$processed,
    ntrees = params$ntrees,
    sample_size = params$sample_size,
    max_depth = params$max_depth,
    ndim = params$ndim,
    ntry = params$ntry,
    prob_pick_pooled_gain = 0.0,
    prob_pick_avg_gain = 0.0,
    prob_pick_full_gain = 1.0,
    prob_pick_dens = 0.0
  )

  model_args <- model_args[!sapply(model_args, is.null)]

  model <- do.call(isotree::isolation.forest, model_args)

  if (verbose) cli::cli_alert_info("Computing anomaly scores...")

  # Predict anomaly scores
  scores <- predict(model, prep_data$processed, type = "avg_depth")

  # Determine threshold based on contamination
  threshold <- quantile(scores, probs = 1 - contamination, na.rm = TRUE)
  outliers <- scores > threshold

  if (verbose) {
    n_outliers <- sum(outliers)
    pct_outliers <- round(100 * n_outliers / length(outliers), 2)
    cli::cli_alert_success(
      "Detected {n_outliers} outliers ({pct_outliers}% of data)"
    )
  }

  # Generate detailed outlier information
  outlier_details <- generate_outlier_details(
    data = data,
    prep_data = prep_data,
    scores = scores,
    outliers = outliers,
    model = model,
    threshold = threshold
  )

  # Calculate metrics
  metrics <- calculate_metrics(scores, outliers, contamination)

  # Create result object
  result <- structure(
    list(
      model = model,
      scores = scores,
      outliers = outliers,
      outlier_details = outlier_details,
      threshold = threshold,
      params = params,
      metrics = metrics,
      preprocessing = prep_data$info,
      data = if (nrow(data) <= 10000) data else NULL # Store only small datasets
    ),
    class = "outlier_detector"
  )

  if (verbose) cli::cli_alert_success("Outlier detection complete!")

  result
}


#' Extract Outlier Summary
#'
#' @description
#' Get a clean summary of outliers with row indices and affected columns.
#'
#' @param x An outlier_detector object
#' @param detailed Logical. Return detailed scores per column? Default: TRUE
#'
#' @return A data.table with outlier information
#'
#' @examples
#' \dontrun{
#' result <- detect_outliers(mtcars)
#' summary <- get_outlier_summary(result)
#' print(summary)
#' }
#'
#' @export
get_outlier_summary <- function(x, detailed = TRUE) {
  stopifnot(inherits(x, "outlier_detector"))

  dt <- data.table::as.data.table(x$outlier_details)

  if (detailed) {
    dt[is_outlier == TRUE][order(-anomaly_score)]
  } else {
    dt[is_outlier == TRUE, .(row_id, anomaly_score, n_outlier_features)][order(-anomaly_score)]
  }
}


#' Print Method for Outlier Detector
#'
#' @param x An outlier_detector object
#' @param ... Additional arguments (ignored)
#'
#' @export
print.outlier_detector <- function(x, ...) {
  n_total <- length(x$outliers)
  n_outliers <- sum(x$outliers)
  pct_outliers <- round(100 * n_outliers / n_total, 2)

  cat("\n=== Outlier Detection Results ===\n\n")

  cat("Model Configuration:\n")
  cat("  - Algorithm: Isolation Forest (isotree)\n")
  cat("  - Number of trees:", x$params$ntrees, "\n")
  cat("  - Sample size:", x$params$sample_size %||% "auto", "\n")
  cat("  - Max depth:", x$params$max_depth %||% "auto", "\n\n")

  cat("Detection Summary:\n")
  cat("  - Total observations:", n_total, "\n")
  cat("  - Outliers detected:", n_outliers, "(", pct_outliers, "%)\n")
  cat("  - Anomaly score threshold:", round(x$threshold, 4), "\n\n")

  cat("Performance Metrics:\n")
  for (metric_name in names(x$metrics)) {
    metric_value <- round(x$metrics[[metric_name]], 4)
    cat("  -", metric_name, ":", metric_value, "\n")
  }
  cat("\n")

  cat("Use plot() to visualize results\n")
  cat("Use get_outlier_summary() to see detailed outlier information\n")

  invisible(x)
}


#' Summary Method for Outlier Detector
#'
#' @param object An outlier_detector object
#' @param ... Additional arguments (ignored)
#'
#' @export
summary.outlier_detector <- function(object, ...) {
  print(object)

  cat("\nTop 10 Outliers:\n")
  top_outliers <- get_outlier_summary(object, detailed = FALSE) |>
    dplyr::slice_head(n = 10)

  print(top_outliers)

  invisible(object)
}
