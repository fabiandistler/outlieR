test_that("Outlier score logic is correct with synthetic data", {
  withr::local_seed(42)

  n_normal <- 95
  n_outliers <- 5

  normal_data <- data.frame(
    x1 = rnorm(n_normal, mean = 0, sd = 1),
    x2 = rnorm(n_normal, mean = 0, sd = 1)
  )

  outlier_data <- data.frame(
    x1 = rnorm(n_outliers, mean = 10, sd = 0.5),
    x2 = rnorm(n_outliers, mean = 10, sd = 0.5)
  )

  combined_data <- rbind(normal_data, outlier_data)
  true_outliers <- c(rep(FALSE, n_normal), rep(TRUE, n_outliers))

  result <- detect_outliers(
    data = combined_data,
    contamination = 0.05,
    tune = FALSE,
    n_trees = 100,
    parallel = FALSE,
    verbose = FALSE
  )

  detected_outlier_indices <- which(result$outliers)
  true_outlier_indices <- which(true_outliers)

  overlap <- length(intersect(detected_outlier_indices, true_outlier_indices))
  recall <- overlap / length(true_outlier_indices)

  expect_gte(recall, 0.4)
})


test_that("avg_depth vs score output types behave correctly", {
  skip_if_not_installed("isotree")

  withr::local_seed(123)
  test_data <- data.frame(
    x = c(rnorm(50, 0, 1), rnorm(5, 10, 0.5))
  )

  model <- isotree::isolation.forest(test_data, ntrees = 100)

  scores_avg_depth <- predict(model, test_data, type = "avg_depth")
  scores_score <- predict(model, test_data, type = "score")

  expect_true(mean(tail(scores_avg_depth, 5)) < mean(head(scores_avg_depth, 5)))

  expect_true(mean(tail(scores_score, 5)) > mean(head(scores_score, 5)))
})
