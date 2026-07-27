# Small GAM fixture reused across tests. Keeping this cheap and deterministic
# (fixed seed, small n) so tests run fast and consistently.
make_test_gam <- function() {
  set.seed(1)
  dat <- data.frame(x1 = runif(100, 1, 10))
  dat$y <- sin(dat$x1) + rnorm(100, sd = 0.1)
  mgcv::gam(y ~ s(x1), data = dat)
}

test_that("plotSmooths returns a ggplot object", {
  model <- make_test_gam()
  p <- plotSmooths(model, "x1", xlab = "X1")
  expect_s3_class(p, "ggplot")
})

test_that("plotSmooths errors on an unknown transform", {
  # Same lazy-aes() reasoning as plotRugs -- force a build to trigger stop().
  model <- make_test_gam()
  expect_error(
    ggplot2::ggplot_build(plotSmooths(model, "x1", xlab = "X1", transform = "invalid")),
    "Unknown transformation requested"
  )
})

test_that("plotSmooths applies xlab/ylab labels correctly", {
  model <- make_test_gam()
  p <- plotSmooths(model, "x1", xlab = "My X", ylab = "My Y")

  expect_equal(p$labels$x, "My X")
  expect_equal(p$labels$y, "My Y")
})

test_that("plotSmooths uses the default ylab when not supplied", {
  model <- make_test_gam()
  p <- plotSmooths(model, "x1", xlab = "X1")

  expect_equal(p$labels$y, "Partial Effect")
})

test_that("plotSmooths applies the requested transform to the smooth term", {
  model <- make_test_gam()
  smooth_est <- gratia::smooth_estimates(
    model, select = "x1", dist = 0.1, partial_match = TRUE
  )

  p_none <- plotSmooths(model, "x1", xlab = "X1", transform = "none")
  p_log  <- plotSmooths(model, "x1", xlab = "X1", transform = "log")

  mapped_none <- rlang::eval_tidy(p_none$mapping$x, smooth_est)
  mapped_log  <- rlang::eval_tidy(p_log$mapping$x, smooth_est)

  expect_equal(mapped_none, smooth_est$x1)
  expect_equal(mapped_log, log(smooth_est$x1))
})

test_that("plotSmooths does not clip the y-axis to a fixed range", {
  # Regression test: an earlier version hardcoded
  # coord_cartesian(ylim = c(-10, 5)), which would silently clip any
  # estimate +/- se falling outside that window. That's been removed;
  # this confirms the plot's panel range now reflects the actual data
  # rather than a fixed, model-specific window.
  model <- make_test_gam()
  built <- ggplot2::ggplot_build(plotSmooths(model, "x1", xlab = "X1"))
  panel_range <- built$layout$panel_params[[1]]$y.range

  expect_false(isTRUE(all.equal(panel_range, c(-10, 5))))
})
