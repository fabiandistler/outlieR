#' Prepare Data for Outlier Detection
#'
#' @description
#' Internal function to preprocess and encode data for isotree.
#' Handles missing values, categorical encoding, and scaling.
#'
#' @param data A data.frame or data.table
#' @param target_cols Character vector of columns to use
#'
#' @return List with processed data and preprocessing info
#' @keywords internal
prepare_data <- function(data, target_cols = NULL) {
  # Convert to data.table for efficient processing
  dt <- data.table::as.data.table(data)

  # Select target columns
  if (is.null(target_cols)) {
    # Use all numeric and categorical columns
    usable_cols <- names(dt)[sapply(dt, function(x) {
      is.numeric(x) || is.character(x) || is.factor(x)
    })]

    if (length(usable_cols) == 0) {
      cli::cli_abort("No numeric or categorical columns found in data")
    }

    target_cols <- usable_cols
  } else {
    # Validate specified columns exist
    missing_cols <- setdiff(target_cols, names(dt))
    if (length(missing_cols) > 0) {
      cli::cli_abort("Columns not found: {paste(missing_cols, collapse = ', ')}")
    }
  }

  # Extract target data
  target_data <- dt[, .SD, .SDcols = target_cols]

  # Identify column types
  col_types <- sapply(target_data, function(x) class(x)[1])

  # Handle categorical variables
  cat_cols <- names(col_types[col_types %in% c("character", "factor")])
  num_cols <- setdiff(target_cols, cat_cols)

  processed_data <- data.table::copy(target_data)
  encoding_info <- list()

  # Encode categorical variables (one-hot encoding)
  if (length(cat_cols) > 0) {
    cli::cli_alert_info("Encoding {length(cat_cols)} categorical column{?s}...")

    for (col in cat_cols) {
      # Convert to factor if character
      if (is.character(processed_data[[col]])) {
        data.table::set(processed_data, j = col, value = factor(processed_data[[col]]))
      }

      # Get unique levels
      levels <- levels(processed_data[[col]])
      encoding_info[[col]] <- levels

      # One-hot encode (drop first level to avoid multicollinearity)
      if (length(levels) > 1) {
        for (i in 2:length(levels)) {
          new_col_name <- paste0(col, "_", levels[i])
          processed_data[, (new_col_name) := as.numeric(get(col) == levels[i])]
        }
      }

      # Remove original column
      processed_data[, (col) := NULL]
    }
  }

  # Handle missing values
  missing_counts <- processed_data[, lapply(.SD, function(x) sum(is.na(x)))]
  cols_with_missing <- names(missing_counts)[unlist(missing_counts) > 0]

  if (length(cols_with_missing) > 0) {
    warning(
      "Found missing values in ", length(cols_with_missing),
      " column(s). Imputing with median.",
      call. = FALSE
    )

    for (col in cols_with_missing) {
      if (is.numeric(processed_data[[col]])) {
        median_val <- median(processed_data[[col]], na.rm = TRUE)
        processed_data[is.na(get(col)), (col) := median_val]
      }
    }
  }

  # Convert to data frame (isotree requirement)
  processed_data <- as.data.frame(processed_data)

  # Return results
  list(
    processed = processed_data,
    info = list(
      original_cols = target_cols,
      numeric_cols = num_cols,
      categorical_cols = cat_cols,
      encoding_info = encoding_info,
      processed_cols = names(processed_data),
      n_rows = nrow(processed_data),
      n_cols = ncol(processed_data)
    )
  )
}


#' Validate Inputs
#'
#' @description
#' Internal function to validate input parameters.
#'
#' @keywords internal
validate_inputs <- function(data, target_cols, contamination) {
  # Check data
  if (!is.data.frame(data) && !data.table::is.data.table(data)) {
    cli::cli_abort("{.arg data} must be a data.frame or data.table")
  }

  if (nrow(data) < 10) {
    cli::cli_abort("{.arg data} must have at least 10 rows")
  }

  # Check target_cols
  if (!is.null(target_cols)) {
    if (!is.character(target_cols)) {
      cli::cli_abort("{.arg target_cols} must be a character vector")
    }

    if (length(target_cols) == 0) {
      cli::cli_abort("{.arg target_cols} cannot be empty")
    }
  }

  # Check contamination
  if (!is.numeric(contamination) ||
    length(contamination) != 1 ||
    contamination <= 0 ||
    contamination >= 1) {
    cli::cli_abort("{.arg contamination} must be a single number between 0 and 1")
  }

  invisible(TRUE)
}


#' Generate Detailed Outlier Information
#'
#' @description
#' Create detailed outlier information showing which columns contribute
#' to each observation being classified as an outlier.
#'
#' @keywords internal
generate_outlier_details <- function(data, prep_data, scores, outliers,
                                     model, threshold) {
  # Calculate per-feature contributions using feature importance proxy
  n_obs <- nrow(prep_data$processed)
  n_features <- ncol(prep_data$processed)
  feature_names <- names(prep_data$processed)

  # For each outlier, identify which features are most unusual
  outlier_indices <- which(outliers)

  # Convert to data.table for efficient processing
  dt_processed <- data.table::as.data.table(prep_data$processed)

  # Calculate robust statistics for each feature
  feature_stats <- lapply(feature_names, function(feat) {
    col_values <- dt_processed[[feat]]
    list(
      median = median(col_values, na.rm = TRUE),
      mad = mad(col_values, na.rm = TRUE)
    )
  })
  names(feature_stats) <- feature_names

  # Initialize result data.table
  result_dt <- data.table::data.table(
    row_id = seq_len(n_obs),
    anomaly_score = scores,
    is_outlier = outliers
  )

  # For outliers, calculate feature-level scores
  if (length(outlier_indices) > 0) {
    # Create feature score matrix for all observations
    all_feature_scores <- matrix(
      NA_real_,
      nrow = n_obs,
      ncol = n_features,
      dimnames = list(NULL, paste0("feat_score_", feature_names))
    )

    # Calculate z-scores for each outlier
    for (i in seq_along(outlier_indices)) {
      idx <- outlier_indices[i]

      # Calculate z-scores for each feature
      feature_scores <- sapply(feature_names, function(feat) {
        obs_val <- dt_processed[[feat]][idx]
        med <- feature_stats[[feat]]$median
        mad_val <- feature_stats[[feat]]$mad

        if (mad_val > 0) {
          abs((obs_val - med) / mad_val)
        } else {
          0
        }
      })

      all_feature_scores[idx, ] <- feature_scores
    }

    # Convert to data.table and add to result
    feature_score_dt <- data.table::as.data.table(all_feature_scores)
    result_dt <- cbind(result_dt, feature_score_dt)

    # Calculate number of outlier features (z-score > 3)
    score_cols <- grep("^feat_score_", names(result_dt), value = TRUE)

    result_dt[, n_outlier_features := {
      if (is_outlier) {
        sum(.SD > 3, na.rm = TRUE)
      } else {
        0L
      }
    }, by = row_id, .SDcols = score_cols]

    # Identify top outlier features
    result_dt[is_outlier == TRUE, top_outlier_features := {
      scores_vec <- unlist(.SD)
      if (all(is.na(scores_vec))) {
        NA_character_
      } else {
        top_idx <- order(scores_vec, decreasing = TRUE, na.last = TRUE)[1:min(3, sum(!is.na(scores_vec)))]
        feat_names <- gsub("^feat_score_", "", score_cols[top_idx])
        feat_names_clean <- feat_names[!is.na(scores_vec[top_idx])]
        if (length(feat_names_clean) > 0) {
          paste(feat_names_clean, collapse = ", ")
        } else {
          NA_character_
        }
      }
    }, by = row_id, .SDcols = score_cols]
  } else {
    result_dt[, n_outlier_features := 0L]
    result_dt[, top_outlier_features := NA_character_]
  }

  # Add original data values for context (only for small datasets)
  if (nrow(data) <= 1000 && !is.null(data)) {
    original_dt <- data.table::as.data.table(data)

    # Avoid column name conflicts
    original_cols <- setdiff(names(original_dt), names(result_dt))
    if (length(original_cols) > 0) {
      result_dt <- cbind(result_dt, original_dt[, .SD, .SDcols = original_cols])
    }
  }

  return(result_dt)
}
