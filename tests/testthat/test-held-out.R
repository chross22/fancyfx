held_out_fixture <- function() {
  set.seed(1)
  d <- data.frame(x1 = runif(600, 1, 10), x2 = runif(600, 1, 10))
  d$y <- rbinom(600, 1, plogis(-3 + 0.6 * d$x1))
  train <- d[1:300, ]
  test <- d[301:600, ]
  fit <- glm(y ~ x1 + x2, data = train, family = binomial)
  list(fit = fit, train = train, test = test,
       predicted = unname(stats::predict(fit, test, type = "response")))
}

test_that("supplied predictions score identically to the model that made them", {
  # The point of the whole entry point: it is a second door into the same
  # arithmetic, not a second implementation of it. If these ever diverge, one
  # of the two is wrong and there is no way to tell which from the outside.
  f <- held_out_fixture()

  by_model <- threshold_metrics(f$fit, f$test)
  by_pairs <- threshold_metrics(held_out(f$test$y, f$predicted))

  expect_equal(as.data.frame(by_pairs), as.data.frame(by_model))
  expect_equal(attr(by_pairs, "auc"), attr(by_model, "auc"))
  expect_equal(attr(by_pairs, "prevalence"), attr(by_model, "prevalence"))
  expect_equal(attr(by_pairs, "n"), attr(by_model, "n"))
})

test_that("calibration agrees between the two paths too", {
  f <- held_out_fixture()

  by_model <- calibration_estimates(f$fit, f$test)
  by_pairs <- calibration_estimates(held_out(f$test$y, f$predicted))

  expect_equal(as.data.frame(by_pairs), as.data.frame(by_model))
  expect_equal(attr(by_pairs, "calibration"), attr(by_model, "calibration"))
  expect_equal(attr(by_pairs, "brier"), attr(by_model, "brier"))
})

test_that("the plots build from supplied predictions", {
  f <- held_out_fixture()
  pairs <- held_out(f$test$y, f$predicted)

  expect_s3_class(plotROC(pairs), "ggplot")
  expect_s3_class(plotThreshold(pairs), "ggplot")
  expect_s3_class(plotCalibration(pairs), "patchwork")
})

test_that("folds group supplied predictions the way they group a model's", {
  f <- held_out_fixture()
  folds <- rep(1:5, length.out = nrow(f$test))

  by_model <- suppressMessages(threshold_metrics(f$fit, f$test, folds = folds))
  by_pairs <- suppressMessages(
    threshold_metrics(held_out(f$test$y, f$predicted), folds = folds)
  )

  expect_equal(as.data.frame(by_pairs), as.data.frame(by_model))
  expect_length(attr(by_pairs, "auc"), 5)
  expect_s3_class(suppressMessages(plotROC(held_out(f$test$y, f$predicted),
                                            folds = folds)), "ggplot")
})

test_that("held_out is not annotated as in-sample unless it says so", {
  # Nothing in two numeric vectors records what model made them, so this is
  # taken on trust. The flag exists to be set honestly.
  f <- held_out_fixture()

  expect_false(attr(threshold_metrics(held_out(f$test$y, f$predicted)),
                    "in.sample"))
  expect_true(attr(threshold_metrics(held_out(f$test$y, f$predicted,
                                              in.sample = TRUE)),
                   "in.sample"))
  # And the caption follows the flag, as it does on the model path.
  expect_null(plotROC(held_out(f$test$y, f$predicted))$labels$caption)
  expect_false(is.null(
    plotROC(held_out(f$test$y, f$predicted, in.sample = TRUE))$labels$caption
  ))
})

test_that("the three response forms are read the same way as a model's", {
  # A two-level factor takes its second level as positive, matching glm().
  f <- held_out_fixture()
  numeric <- held_out(f$test$y, f$predicted)
  logical <- held_out(f$test$y == 1, f$predicted)
  factored <- held_out(factor(ifelse(f$test$y == 1, "yes", "no"),
                              levels = c("no", "yes")), f$predicted)

  expect_equal(numeric$observed, logical$observed)
  expect_equal(numeric$observed, factored$observed)
})

test_that("a malformed pair is refused", {
  expect_error(held_out(c(0, 1, 1), c(0.2, 0.4)), "same length")
  expect_error(held_out(numeric(0), numeric(0)), "nothing to score")
  # Predictions on the link scale are the likely mistake, and they are not
  # probabilities.
  expect_error(held_out(c(0, 1), c(-2.2, 3.1)), "probabilities in \\[0, 1\\]")
  expect_error(held_out(c(0, 1, 2), c(0.1, 0.2, 0.3)), "not a binary outcome")
  expect_error(held_out(factor(c("a", "b", "c")), c(0.1, 0.2, 0.3)),
               "binary outcome only")
  expect_error(held_out(c(0, 1), c(0.2, 0.4), in.sample = "yes"),
               "must be TRUE or FALSE")
})

test_that("one outcome class or a mismatched fold vector is refused", {
  expect_error(threshold_metrics(held_out(c(0, 0, 0), c(0.1, 0.2, 0.3))),
               "only one outcome class")
  expect_error(
    threshold_metrics(held_out(c(0, 1, 1), c(0.1, 0.2, 0.3)), folds = c(1, 2)),
    "one entry per observation"
  )
})

test_that("missing values are dropped as they are on the model path", {
  observed <- c(0, 1, NA, 1, 0)
  predicted <- c(0.1, 0.9, 0.5, NA, 0.2)

  metrics <- threshold_metrics(held_out(observed, predicted))

  expect_equal(attr(metrics, "n"), 3)
})

test_that("a model still requires newdata, and says how to avoid needing it", {
  f <- held_out_fixture()

  expect_error(threshold_metrics(f$fit), "held_out\\(\\)")
  expect_error(calibration_estimates(f$fit), "held_out\\(\\)")
})

test_that("held_out prints what it holds", {
  f <- held_out_fixture()

  expect_output(print(held_out(f$test$y, f$predicted)), "held-out predictions")
  expect_output(print(held_out(f$test$y, f$predicted)), "in sample:    no")
  expect_output(print(held_out(f$test$y, f$predicted, in.sample = TRUE)),
                "in sample:    yes")
})
