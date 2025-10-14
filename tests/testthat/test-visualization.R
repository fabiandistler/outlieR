test_that("plot method creates ggplot objects", {
  skip_if_not_installed("ggplot2")

  result <- detect_outliers(mtcars, verbose = FALSE, tune = FALSE)

  p1 <- plot(result, type = "score")
  expect_s3_class(p1, "gg")

  p2 <- plot(result, type = "distribution")
  expect_s3_class(p2, "gg")
})

test_that("plot handles different types", {
  skip_if_not_installed("ggplot2")

  result <- detect_outliers(mtcars, verbose = FALSE, tune = FALSE)

  expect_s3_class(plot(result, type = "score"), "gg")
  expect_s3_class(plot(result, type = "features"), "gg")
  expect_s3_class(plot(result, type = "distribution"), "gg")

  # PCA requires stored data
  if (!is.null(result$data)) {
    expect_s3_class(plot(result, type = "pca"), "gg")
  }
})

test_that("plot handles no outliers gracefully", {
  skip_if_not_installed("ggplot2")

  # Create data with no clear outliers
  data <- data.frame(matrix(rnorm(100 * 5), ncol = 5))
  result <- detect_outliers(
    data,
    contamination = 0.001, # Very low
    verbose = FALSE,
    tune = FALSE
  )

  p <- plot(result, type = "features")
  expect_s3_class(p, "gg")
})
