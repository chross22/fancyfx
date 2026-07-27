# Note: addRugsToSmooths()'s roxygen block is still missing a @param dat
# entry (persistent doc-only issue, won't affect these runtime tests but
# will surface as a devtools::document() warning).

make_test_gam <- function() {
  set.seed(1)
  dat <- data.frame(x1 = runif(100, 1, 10), x2 = runif(100, 1, 10))
  dat$y <- sin(dat$x1) + cos(dat$x2) + rnorm(100, sd = 0.1)
  list(
    model = mgcv::gam(y ~ s(x1) + s(x2), data = dat),
    dat = dat
  )
}

test_that("addRugsToSmooths returns a combined patchwork object", {
  fixture <- make_test_gam()

  combined <- addRugsToSmooths(fixture$model, fixture$dat, "x1", xlab = "X1")

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
  # addRugsToSmooths() returns a patchwork object (two combined ggplots),
  # not a single ggplot, so ggplot_build() won't force evaluation here.
  # Rendering to a null device via print() triggers the lazy aes()
  # evaluation the same way ggplot_build() does for a single ggplot.
  fixture <- make_test_gam()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  expect_error(
    print(addRugsToSmooths(fixture$model, fixture$dat, "x1", xlab = "X1", transform = "invalid")),
    "Unknown transformation requested"
  )
})
