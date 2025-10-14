test_that("detect_outliers works with basic input", {
  result <- detect_outliers(mtcars, verbose = FALSE, tune = FALSE)

  expect_s3_class(result, "outlier_detector")
  expect_true("model" %in% names(result))
  expect_true("scores" %in% names(result))
  expect_true("outliers" %in% names(result))
  expect_length(result$scores, nrow(mtcars))
  expect_length(result$outliers, nrow(mtcars))
})

test_that("detect_outliers respects contamination parameter", {
  result <- detect_outliers(
    mtcars,
    contamination = 0.05,
    verbose = FALSE,
    tune = FALSE
  )

  outlier_rate <- mean(result$outliers)
  expect_true(outlier_rate >= 0.03 && outlier_rate <= 0.07)
})

test_that("detect_outliers works with specific columns", {
  result <- detect_outliers(
    mtcars,
    target_cols = c("mpg", "hp", "wt"),
    verbose = FALSE,
    tune = FALSE
  )

  expect_s3_class(result, "outlier_detector")
  expect_identical(result$preprocessing$original_cols, c("mpg", "hp", "wt"))
})

test_that("detect_outliers handles categorical variables", {
  data <- data.frame(
    x = rnorm(100),
    y = rnorm(100),
    cat = sample(c("A", "B", "C"), 100, replace = TRUE)
  )

  result <- detect_outliers(data, verbose = FALSE, tune = FALSE)

  expect_s3_class(result, "outlier_detector")
  expect_gt(length(result$preprocessing$categorical_cols), 0)
})

test_that("detect_outliers handles missing values", {
  data <- mtcars
  data$mpg[c(1, 5, 10)] <- NA

  expect_warning(
    result <- detect_outliers(data, verbose = FALSE, tune = FALSE),
    "missing values"
  )

  expect_s3_class(result, "outlier_detector")
  expect_false(anyNA(result$scores))
})

test_that("detect_outliers validates inputs", {
  expect_error(
    detect_outliers(list(a = 1, b = 2)),
    "data.frame or data.table"
  )

  expect_error(
    detect_outliers(mtcars, target_cols = "nonexistent"),
    "Columns not found"
  )

  expect_error(
    detect_outliers(mtcars, contamination = 1.5),
    "between 0 and 1"
  )

  expect_error(
    detect_outliers(mtcars[1:5, ]),
    "at least 10 rows"
  )
})

test_that("detect_outliers tuning works", {
  skip_if_not_installed("parallel")

  result <- detect_outliers(
    mtcars,
    tune = TRUE,
    tune_method = "random",
    verbose = FALSE,
    parallel = FALSE
  )

  expect_s3_class(result, "outlier_detector")
  expect_true("ntrees" %in% names(result$params))
})

test_that("get_outlier_summary works", {
  result <- detect_outliers(mtcars, verbose = FALSE, tune = FALSE)
  summary_detailed <- get_outlier_summary(result, detailed = TRUE)
  summary_simple <- get_outlier_summary(result, detailed = FALSE)

  expect_s3_class(summary_detailed, "data.table")
  expect_s3_class(summary_simple, "data.table")
  expect_lte(nrow(summary_simple), nrow(summary_detailed))
  expect_true("row_id" %in% names(summary_simple))
  expect_true("anomaly_score" %in% names(summary_simple))
})

test_that("print method works", {
  result <- detect_outliers(mtcars, verbose = FALSE, tune = FALSE)

  expect_output(print(result), "Outlier Detection Results")
  expect_output(print(result), "Model Configuration")
  expect_output(print(result), "Detection Summary")
})

test_that("summary method works", {
  result <- detect_outliers(mtcars, verbose = FALSE, tune = FALSE)

  expect_output(summary(result), "Outlier Detection Results")
  expect_output(summary(result), "Top 10 Outliers")
})

test_that("outlier_details contains expected columns", {
  result <- detect_outliers(mtcars, verbose = FALSE, tune = FALSE)

  expect_true(data.table::is.data.table(result$outlier_details))
  expect_true("row_id" %in% names(result$outlier_details))
  expect_true("anomaly_score" %in% names(result$outlier_details))
  expect_true("is_outlier" %in% names(result$outlier_details))
  expect_true("n_outlier_features" %in% names(result$outlier_details))
})

test_that("metrics are calculated correctly", {
  result <- detect_outliers(mtcars, verbose = FALSE, tune = FALSE)

  expect_true("mean_score" %in% names(result$metrics))
  expect_true("detection_rate" %in% names(result$metrics))
  expect_true(is.numeric(result$metrics$mean_score))
  expect_gte(result$metrics$detection_rate, 0)
  expect_lte(result$metrics$detection_rate, 1)
})

test_that("seed produces reproducible results", {
  result1 <- detect_outliers(mtcars, seed = 123, verbose = FALSE, tune = FALSE)
  result2 <- detect_outliers(mtcars, seed = 123, verbose = FALSE, tune = FALSE)

  expect_identical(result1$scores, result2$scores)
  expect_identical(result1$outliers, result2$outliers)
})

test_that("data.table input works", {
  dt <- data.table::as.data.table(mtcars)
  result <- detect_outliers(dt, verbose = FALSE, tune = FALSE)

  expect_s3_class(result, "outlier_detector")
})
