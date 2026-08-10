calibration_fixture <- function() {
  set.seed(1)
  d <- data.frame(x1 = runif(1200, 1, 10), x2 = runif(1200, 1, 10))
  d$y <- rbinom(1200, 1, plogis(-3 + 0.6 * d$x1))
  list(fit = glm(y ~ x1 + x2, data = d[1:600, ], family = binomial),
       train = d[1:600, ],
       test = d[601:1200, ])
}

#' A deliberately over-confident version of a fitted model
#'
#' Inflating the coefficients pushes predictions toward 0 and 1 without
#' changing their order, which is the point: discrimination is untouched and
#' only calibration degrades.
overconfident <- function(fit) {
  fit$coefficients <- fit$coefficients * 2.5
  fit
}

test_that("calibration_estimates returns one row per bin with the standard columns", {
  f <- calibration_fixture()
  cal <- calibration_estimates(f$fit, f$test)

  expect_named(cal, c(".bin", ".predicted", ".observed", ".lower", ".upper",
                      ".n"))
  expect_equal(nrow(cal), 10)
  expect_equal(sum(cal$.n), nrow(f$test))
  expect_false(attr(cal, "in.sample"))
})

test_that("quantile binning gives equal counts and width binning does not", {
  # The trade-off the binning argument exists for.
  f <- calibration_fixture()

  quantile.bins <- calibration_estimates(f$fit, f$test, binning = "quantile")
  width.bins <- calibration_estimates(f$fit, f$test, binning = "width")

  expect_equal(length(unique(quantile.bins$.n)), 1)
  expect_gt(length(unique(width.bins$.n)), 1)
})

test_that("intervals stay inside [0, 1]", {
  # A normal approximation on a bin with few observations, or an observed
  # frequency near 0 or 1, produces bounds outside the range a probability can
  # take -- a plot claiming something impossible.
  f <- calibration_fixture()
  cal <- calibration_estimates(f$fit, f$test, bins = 20)

  expect_true(all(cal$.lower >= 0))
  expect_true(all(cal$.upper <= 1))
  expect_true(all(cal$.lower <= cal$.observed & cal$.observed <= cal$.upper))
})

test_that("the Wilson interval behaves where a normal approximation would not", {
  # Zero successes out of five: the normal approximation gives a zero-width
  # interval at 0, which asserts certainty from almost no data.
  interval <- wilson_interval(0, 5, 0.95)

  expect_gte(interval[1], 0)
  expect_gt(interval[2], 0)
  expect_lte(interval[2], 1)

  # All successes, likewise.
  upper.end <- wilson_interval(5, 5, 0.95)
  expect_lt(upper.end[1], 1)
  expect_lte(upper.end[2], 1)

  # A wide interval from few observations should be wider than from many.
  expect_gt(diff(wilson_interval(5, 10, 0.95)),
            diff(wilson_interval(50, 100, 0.95)))
})

test_that("a well calibrated model gives slope near 1 and intercept near 0", {
  f <- calibration_fixture()
  stats <- attr(calibration_estimates(f$fit, f$test), "calibration")

  expect_named(stats, c("intercept", "slope"))
  expect_lt(abs(stats[["intercept"]]), 0.3)
  expect_lt(abs(stats[["slope"]] - 1), 0.3)
})

test_that("an over-confident model is caught by the slope, not by AUC", {
  # The reason calibration deserves its own plot: inflating the coefficients
  # leaves the ranking untouched, so AUC cannot see the problem at all.
  f <- calibration_fixture()
  bad <- overconfident(f$fit)

  expect_lt(attr(calibration_estimates(bad, f$test), "calibration")[["slope"]],
            0.6)
  expect_equal(attr(threshold_metrics(bad, f$test), "auc"),
               attr(threshold_metrics(f$fit, f$test), "auc"))
})

test_that("the Brier score is the mean squared error of the probabilities", {
  f <- calibration_fixture()
  cal <- calibration_estimates(f$fit, f$test)

  predicted <- stats::predict(f$fit, f$test, type = "response")
  expect_equal(attr(cal, "brier"), mean((predicted - f$test$y)^2),
               ignore_attr = TRUE)

  # Over-confidence should make it worse while leaving AUC alone.
  expect_gt(attr(calibration_estimates(overconfident(f$fit), f$test), "brier"),
            attr(cal, "brier"))
})

test_that("calibration_fit survives predictions of exactly 0 and 1", {
  # Their logit is infinite, which no regression can use. Nudged inside the
  # open interval rather than dropped, so a confident model does not silently
  # lose its most extreme cases.
  stats <- calibration_fit(c(0, 1, 0, 1, 1, 0), c(0, 1, 0, 1, 0.9, 0.1))

  expect_false(anyNA(stats))
  expect_named(stats, c("intercept", "slope"))
})

test_that("evaluating on the training data warns and is flagged", {
  f <- calibration_fixture()

  expect_warning(calibration_estimates(f$fit, f$train), "optimistic")
  p <- suppressWarnings(plotCalibration(f$fit, f$train))
  expect_match(p[[2]]$labels$caption, "In-sample")
})

test_that("newdata is required", {
  f <- calibration_fixture()

  expect_error(calibration_estimates(f$fit), "newdata is required")
})

test_that("arguments are validated", {
  f <- calibration_fixture()

  expect_error(calibration_estimates(f$fit, f$test, bins = 1),
               "at least 2")
  expect_error(calibration_estimates(f$fit, f$test, binning = "deciles"),
               "Unknown binning requested")
  expect_error(calibration_estimates(f$fit, f$test, level = 95),
               "strictly between 0 and 1")
  expect_error(plotCalibration(f$fit, f$test, rug.type = "violin"),
               "Unknown type requested")
})

test_that("a non-binary response is refused", {
  f <- calibration_fixture()
  continuous <- lm(x2 ~ x1, data = f$train)

  expect_error(calibration_estimates(continuous, f$train),
               "not a binary outcome")
})

test_that("folds bin within each fold and emit the cross-validation note", {
  reset_notices()
  f <- calibration_fixture()
  set.seed(2)
  folds <- sample(rep(1:3, length.out = nrow(f$test)))

  expect_message(calibration_estimates(f$fit, f$test, folds = folds),
                 "weaker evidence")

  cal <- calibration_estimates(f$fit, f$test, folds = folds)
  expect_true(".fold" %in% names(cal))
  expect_equal(nlevels(cal$.fold), 3)
  expect_equal(sum(cal$.n), nrow(f$test))
})

test_that("plotCalibration stacks a rug of the predictions above the curve", {
  # The rug is of predicted probabilities, sharing the curve's x axis, so it
  # shows which parts of [0, 1] the model actually uses -- calibration is worst
  # at the extremes and the extremes usually hold the fewest predictions.
  f <- calibration_fixture()
  p <- plotCalibration(f$fit, f$test)

  expect_s3_class(p, "patchwork")
  expect_length(p, 2)

  rug.values <- ggplot2::ggplot_build(p[[1]])$plot$data$.predicted
  expect_equal(length(rug.values), nrow(f$test))
  expect_true(all(rug.values >= 0 & rug.values <= 1))
})

test_that("the reported statistics reach the plot", {
  f <- calibration_fixture()

  labelled <- plotCalibration(f$fit, f$test, show.stats = TRUE)
  layers <- vapply(labelled[[2]]$layers, function(l) class(l$geom)[1],
                   character(1), USE.NAMES = FALSE)
  expect_true("GeomText" %in% layers)

  bare <- plotCalibration(f$fit, f$test, show.stats = FALSE)
  bare.layers <- vapply(bare[[2]]$layers, function(l) class(l$geom)[1],
                        character(1), USE.NAMES = FALSE)
  expect_false("GeomText" %in% bare.layers)
})

test_that("calibration_label degrades gracefully when the fit failed", {
  expect_match(calibration_label(c(intercept = NA, slope = NA), 0.2),
               "Brier = 0.200")
  expect_match(calibration_label(c(intercept = 0.1, slope = 0.9), 0.2),
               "Slope = 0.90")
})

test_that("GAMs calibrate like anything else", {
  f <- calibration_fixture()
  fit <- mgcv::gam(y ~ s(x1) + s(x2), data = f$train, family = binomial)

  cal <- calibration_estimates(fit, f$test)

  expect_equal(nrow(cal), 10)
  expect_false(anyNA(cal$.observed))
})
