test_that("prepare_data handles numeric data", {
  prep <- prepare_data(mtcars, target_cols = NULL)

  expect_true("processed" %in% names(prep))
  expect_true("info" %in% names(prep))
  expect_equal(nrow(prep$processed), nrow(mtcars))
})

test_that("prepare_data handles categorical data", {
  data <- data.frame(
    x = rnorm(50),
    cat = sample(c("A", "B", "C"), 50, replace = TRUE)
  )

  prep <- prepare_data(data)

  expect_true(ncol(prep$processed) > ncol(data)) # One-hot encoded
  expect_true(length(prep$info$categorical_cols) > 0)
})

test_that("prepare_data imputes missing values", {
  data <- mtcars
  data$mpg[1:3] <- NA

  prep <- prepare_data(data)

  expect_false(anyNA(prep$processed))
})
