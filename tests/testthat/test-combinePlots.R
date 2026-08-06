make_test_gam <- function() {
  set.seed(1)
  dat <- data.frame(x1 = runif(100, 1, 10), x2 = runif(100, 1, 10))
  dat$y <- sin(dat$x1) + cos(dat$x2) + rnorm(100, sd = 0.1)
  list(
    model = mgcv::gam(y ~ s(x1) + s(x2), data = dat),
    dat = dat
  )
}

test_that("plotSmooths returns a combined patchwork object", {
  fixture <- make_test_gam()

  combined <- plotSmooths(fixture$model, fixture$dat, "x1", xlab = "X1")

  expect_s3_class(combined, "patchwork")
})

test_that("combinePlots runs without error for multiple variables", {
  fixture <- make_test_gam()

  expect_no_error(
    combinePlots(fixture$model, fixture$dat, vars = c("x1", "x2"))
  )
})

test_that("combinePlots returns a ggarrange/ggplot-compatible object", {
  fixture <- make_test_gam()

  result <- combinePlots(fixture$model, fixture$dat, vars = c("x1", "x2"))

  # ggarrange() output (post annotate_figure) is a ggplot-renderable grob
  expect_true(inherits(result, "ggplot") || inherits(result, "gg"))
})

test_that("combinePlots handles a single variable", {
  fixture <- make_test_gam()

  expect_no_error(
    combinePlots(fixture$model, fixture$dat, vars = "x1")
  )
})

test_that("combinePlots errors on an unknown transform passed through", {
  fixture <- make_test_gam()

  expect_error(
    combinePlots(fixture$model, fixture$dat, vars = c("x1", "x2"),
                 var.transform = "invalid"),
    "Unknown transformation requested"
  )
})

test_that("combinePlots actually applies the arguments it accepts", {
  # var.transform and rug.type were in the signature but never reached
  # plotSmooths(): the lapply hardcoded the defaults, so setting either did
  # nothing. R's laziness kept that invisible, since the ignored arguments
  # were never forced.
  fixture <- make_test_gam()

  expect_error(
    combinePlots(fixture$model, fixture$dat, vars = "x1", rug.type = "violin"),
    "Unknown type requested"
  )
  expect_no_error(
    combinePlots(fixture$model, fixture$dat, vars = c("x1", "x2"),
                 var.transform = c("none", "log"))
  )
  # One transform per variable, or one for all. A length that is neither is a
  # mistake rather than something to recycle.
  expect_error(
    combinePlots(fixture$model, fixture$dat, vars = c("x1", "x2"),
                 var.transform = c("none", "log", "sqrt")),
    "one per variable"
  )
})
