#' Plot Outlier Detection Results
#'
#' @description
#' Create comprehensive visualizations of outlier detection results.
#'
#' @param x An outlier_detector object
#' @param type Character. Type of plot: "score", "features", "distribution", "pca", "heatmap", "all"
#' @param n_top Integer. Number of top outliers to highlight in plots. Default: 10
#' @param ... Additional arguments passed to plotting functions
#'
#' @return A ggplot2 object or list of plots (if type = "all")
#'
#' @examples
#' result <- detect_outliers(mtcars, tune = FALSE, verbose = FALSE)
#'
#' # Score distribution plot
#' plot(result, type = "score")
#'
#' \donttest{
#' # Feature importance for outliers
#' plot(result, type = "features")
#'
#' # All plots
#' plots <- plot(result, type = "all")
#' }
#'
#' @export
plot.outlier_detector <- function(x,
                                  type = c("score", "features", "distribution", "pca", "heatmap", "all"),
                                  n_top = 10,
                                  ...) {
  type <- match.arg(type)

  if (type == "all") {
    plots <- list(
      score = plot_score_distribution(x, n_top),
      features = plot_feature_importance(x, n_top),
      distribution = plot_outlier_distribution(x),
      pca = plot_pca_outliers(x, n_top)
    )

    if (requireNamespace("patchwork", quietly = TRUE)) {
      return(patchwork::wrap_plots(plots, ncol = 2))
    } else {
      return(plots)
    }
  }

  switch(type,
    score = plot_score_distribution(x, n_top),
    features = plot_feature_importance(x, n_top),
    distribution = plot_outlier_distribution(x),
    pca = plot_pca_outliers(x, n_top),
    heatmap = plot_outlier_heatmap(x, n_top)
  )
}


#' Plot Anomaly Score Distribution
#'
#' @keywords internal
#' @noRd
plot_score_distribution <- function(x, n_top = 10) {
  dt <- data.table::data.table(
    row_id = seq_along(x$scores),
    score = x$scores,
    is_outlier = x$outliers
  )

  # Identify top outliers
  top_outliers <- dt[is_outlier == TRUE][order(-score)][seq_len(min(n_top, .N))]

  ggplot2::ggplot(dt, ggplot2::aes(x = row_id, y = score)) +
    ggplot2::geom_point(ggplot2::aes(color = is_outlier), alpha = 0.6, size = 2) +
    ggplot2::geom_hline(
      yintercept = x$threshold,
      linetype = "dashed",
      color = "red",
      linewidth = 0.8
    ) +
    ggplot2::geom_point(
      data = top_outliers,
      ggplot2::aes(x = row_id, y = score),
      color = "red",
      size = 4,
      shape = 21,
      fill = NA,
      stroke = 1.5
    ) +
    ggplot2::scale_color_manual(
      values = c("TRUE" = "#D55E00", "FALSE" = "#0072B2"),
      labels = c("TRUE" = "Outlier", "FALSE" = "Normal")
    ) +
    ggplot2::labs(
      title = "Anomaly Score Distribution",
      subtitle = sprintf(
        "Threshold: %.4f | Outliers: %d (%.1f%%)",
        x$threshold,
        sum(x$outliers),
        100 * mean(x$outliers)
      ),
      x = "Observation Index",
      y = "Anomaly Score",
      color = "Classification"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      legend.position = "bottom",
      plot.title = ggplot2::element_text(face = "bold", size = 14),
      plot.subtitle = ggplot2::element_text(color = "gray40")
    )
}


#' Plot Feature Importance for Outliers
#'
#' @keywords internal
#' @noRd
plot_feature_importance <- function(x, n_top = 10) {
  dt <- data.table::as.data.table(x$outlier_details)

  # Get top outliers
  top_outliers <- dt[is_outlier == TRUE][order(-anomaly_score)][seq_len(min(n_top, .N))]

  if (nrow(top_outliers) == 0) {
    return(
      ggplot2::ggplot() +
        ggplot2::annotate("text", x = 0.5, y = 0.5, label = "No outliers detected") +
        ggplot2::theme_void()
    )
  }

  # Extract feature score columns
  score_cols <- grep("^feat_score_", names(top_outliers), value = TRUE)

  if (length(score_cols) == 0) {
    return(
      ggplot2::ggplot() +
        ggplot2::annotate("text",
          x = 0.5, y = 0.5,
          label = "Feature scores not available"
        ) +
        ggplot2::theme_void()
    )
  }

  # Reshape for plotting
  plot_dt <- data.table::melt(
    top_outliers[, c("row_id", score_cols), with = FALSE],
    id.vars = "row_id",
    variable.name = "feature",
    value.name = "score"
  )

  # Clean feature names
  plot_dt[, feature := gsub("^feat_score_", "", feature)]

  # Get top features overall
  feature_importance <- plot_dt[, .(mean_score = mean(score, na.rm = TRUE)), by = feature]
  top_features <- feature_importance[order(-mean_score)][seq_len(min(15, .N)), feature]

  plot_dt_filtered <- plot_dt[feature %in% top_features]

  ggplot2::ggplot(
    plot_dt_filtered,
    ggplot2::aes(x = stats::reorder(feature, score, FUN = mean), y = score)
  ) +
    ggplot2::geom_boxplot(fill = "#D55E00", alpha = 0.6, outlier.shape = NA) +
    ggplot2::geom_jitter(width = 0.2, alpha = 0.4, size = 2, color = "#0072B2") +
    ggplot2::coord_flip() +
    ggplot2::labs(
      title = "Feature Contribution to Outliers",
      subtitle = sprintf("Top %d outliers analyzed", nrow(top_outliers)),
      x = "Feature",
      y = "Robust Z-Score"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = 14),
      plot.subtitle = ggplot2::element_text(color = "gray40")
    )
}


#' Plot Outlier Distribution
#'
#' @keywords internal
#' @noRd
plot_outlier_distribution <- function(x) {
  dt <- data.table::data.table(
    score = x$scores,
    type = ifelse(x$outliers, "Outlier", "Normal")
  )

  ggplot2::ggplot(dt, ggplot2::aes(x = score, fill = type)) +
    ggplot2::geom_histogram(bins = 50, alpha = 0.7, position = "identity") +
    ggplot2::geom_vline(
      xintercept = x$threshold,
      linetype = "dashed",
      color = "red",
      linewidth = 1
    ) +
    ggplot2::scale_fill_manual(
      values = c("Outlier" = "#D55E00", "Normal" = "#0072B2")
    ) +
    ggplot2::labs(
      title = "Score Distribution by Class",
      subtitle = sprintf("Threshold: %.4f", x$threshold),
      x = "Anomaly Score",
      y = "Count",
      fill = "Classification"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      legend.position = "bottom",
      plot.title = ggplot2::element_text(face = "bold", size = 14),
      plot.subtitle = ggplot2::element_text(color = "gray40")
    )
}


#' Plot PCA Projection with Outliers
#'
#' @keywords internal
#' @noRd
plot_pca_outliers <- function(x, n_top = 10) {
  if (is.null(x$data)) {
    return(
      ggplot2::ggplot() +
        ggplot2::annotate("text",
          x = 0.5, y = 0.5,
          label = "Original data not stored (dataset too large)"
        ) +
        ggplot2::theme_void()
    )
  }

  # Get numeric columns from preprocessing info
  numeric_cols <- x$preprocessing$numeric_cols

  if (length(numeric_cols) < 2) {
    return(
      ggplot2::ggplot() +
        ggplot2::annotate("text",
          x = 0.5, y = 0.5,
          label = "Need at least 2 numeric columns for PCA"
        ) +
        ggplot2::theme_void()
    )
  }

  # Extract numeric data
  dt <- data.table::as.data.table(x$data)
  numeric_data <- dt[, .SD, .SDcols = numeric_cols]

  # Remove rows with missing values for PCA
  complete_cases <- stats::complete.cases(numeric_data)
  numeric_data_complete <- numeric_data[complete_cases, ]

  if (nrow(numeric_data_complete) < 10) {
    return(
      ggplot2::ggplot() +
        ggplot2::annotate("text",
          x = 0.5, y = 0.5,
          label = "Too many missing values for PCA"
        ) +
        ggplot2::theme_void()
    )
  }

  # Perform PCA
  pca_result <- stats::prcomp(numeric_data_complete, scale. = TRUE, center = TRUE)

  # Create plot data
  plot_dt <- data.table::data.table(
    PC1 = pca_result$x[, 1],
    PC2 = pca_result$x[, 2],
    score = x$scores[complete_cases],
    is_outlier = x$outliers[complete_cases],
    row_id = which(complete_cases)
  )

  # Identify top outliers
  top_outliers <- plot_dt[is_outlier == TRUE][order(-score)][seq_len(min(n_top, .N))]

  # Calculate variance explained
  var_exp <- summary(pca_result)$importance[2, 1:2] * 100

  ggplot2::ggplot(plot_dt, ggplot2::aes(x = PC1, y = PC2)) +
    ggplot2::geom_point(ggplot2::aes(color = score, size = is_outlier), alpha = 0.6) +
    ggplot2::geom_point(
      data = top_outliers,
      ggplot2::aes(x = PC1, y = PC2),
      color = "red",
      size = 6,
      shape = 21,
      fill = NA,
      stroke = 1.5
    ) +
    ggplot2::scale_color_gradient2(
      low = "#0072B2",
      mid = "#F0E442",
      high = "#D55E00",
      midpoint = x$threshold,
      name = "Anomaly\nScore"
    ) +
    ggplot2::scale_size_manual(
      values = c("TRUE" = 3, "FALSE" = 2),
      guide = "none"
    ) +
    ggplot2::labs(
      title = "PCA Projection of Data",
      subtitle = sprintf(
        "PC1: %.1f%% variance | PC2: %.1f%% variance",
        var_exp[1], var_exp[2]
      ),
      x = sprintf("PC1 (%.1f%%)", var_exp[1]),
      y = sprintf("PC2 (%.1f%%)", var_exp[2])
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      legend.position = "right",
      plot.title = ggplot2::element_text(face = "bold", size = 14),
      plot.subtitle = ggplot2::element_text(color = "gray40")
    )
}


#' Plot Outlier Heatmap
#'
#' @keywords internal
#' @noRd
plot_outlier_heatmap <- function(x, n_top = 10) {
  dt <- data.table::as.data.table(x$outlier_details)

  # Get top outliers
  top_outliers <- dt[is_outlier == TRUE][order(-anomaly_score)][seq_len(min(n_top, .N))]

  if (nrow(top_outliers) == 0) {
    return(
      ggplot2::ggplot() +
        ggplot2::annotate("text", x = 0.5, y = 0.5, label = "No outliers detected") +
        ggplot2::theme_void()
    )
  }

  # Extract feature score columns
  score_cols <- grep("^feat_score_", names(top_outliers), value = TRUE)

  if (length(score_cols) == 0) {
    return(
      ggplot2::ggplot() +
        ggplot2::annotate("text",
          x = 0.5, y = 0.5,
          label = "Feature scores not available"
        ) +
        ggplot2::theme_void()
    )
  }

  # Reshape for heatmap
  plot_dt <- data.table::melt(
    top_outliers[, c("row_id", score_cols), with = FALSE],
    id.vars = "row_id",
    variable.name = "feature",
    value.name = "score"
  )

  # Clean feature names
  plot_dt[, feature := gsub("^feat_score_", "", feature)]
  plot_dt[, row_id := as.factor(row_id)]

  ggplot2::ggplot(plot_dt, ggplot2::aes(x = feature, y = row_id, fill = score)) +
    ggplot2::geom_tile(color = "white", linewidth = 0.5) +
    ggplot2::scale_fill_gradient2(
      low = "#0072B2",
      mid = "#F0E442",
      high = "#D55E00",
      midpoint = 3,
      name = "Z-Score"
    ) +
    ggplot2::labs(
      title = "Feature Contributions per Outlier",
      subtitle = sprintf("Top %d outliers", nrow(top_outliers)),
      x = "Feature",
      y = "Row ID"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
      plot.title = ggplot2::element_text(face = "bold", size = 14),
      plot.subtitle = ggplot2::element_text(color = "gray40"),
      legend.position = "right"
    )
}
