test_that("tune_parameters returns valid parameters", {
  data <- data.frame(matrix(rnorm(100 * 5), ncol = 5))
  prep <- prepare_data(data)

  params <- tune_parameters(
    prep$processed,
    method = "random",
    contamination = 0.1,
    parallel = FALSE,
    verbose = FALSE
  )

  expect_true("ntrees" %in% names(params))
  expect_true(is.numeric(params$ntrees))
  expect_gt(params$ntrees, 0)
})

test_that("evaluate_params handles errors gracefully", {
  data <- data.frame(matrix(rnorm(100 * 5), ncol = 5))
  params <- list(ntrees = 100, sample_size = 50, max_depth = 10, ndim = 1)

  result <- evaluate_params(data, params, contamination = 0.1)

  expect_true("score" %in% names(result))
  expect_true(is.numeric(result$score))
})
