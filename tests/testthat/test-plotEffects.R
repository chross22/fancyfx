test_that("plotEffects returns a rug stacked above a curve, for every model type", {
  for (model in list(make_test_gam(), make_test_lm(), make_test_glm())) {
    p <- plotEffects(model, test_data(), "x1")
    expect_s3_class(p, "patchwork")
    expect_s3_class(p, "ggplot")
    expect_length(p, 2)
  }
})

test_that("plotEffects applies xlab and ylab", {
  p <- plotEffects(make_test_gam(), test_data(), "x1", xlab = "My X", ylab = "My Y")

  expect_equal(effect_panel(p)$labels$x, "My X")
  expect_equal(effect_panel(p)$labels$y, "My Y")
})

test_that("xlab defaults to the variable's own name", {
  p <- plotEffects(make_test_gam(), test_data(), "x1")

  expect_equal(effect_panel(p)$labels$x, "x1")
})

test_that("the default ylab names the quantity that was actually computed", {
  # The label is the only thing telling the reader whether they are looking at
  # a centered partial effect or a prediction. It has to follow the backend
  # that ran, not the model class or the scale that was asked for.
  gam.fit <- make_test_gam()

  expect_equal(effect_panel(plotEffects(gam.fit, test_data(), "x1"))$labels$y,
               "Partial Effect")
  expect_equal(
    effect_panel(plotEffects(gam.fit, test_data(), "x1", scale = "response"))$labels$y,
    "Predicted Value"
  )
  expect_equal(effect_panel(plotEffects(make_test_lm(), test_data(), "x1"))$labels$y,
               "Predicted Value")
})

test_that("an explicit ylab still wins over the computed default", {
  p <- plotEffects(make_test_lm(), test_data(), "x1", ylab = "Something else")

  expect_equal(effect_panel(p)$labels$y, "Something else")
})

test_that("plotEffects applies the requested transform to the x mapping", {
  model <- make_test_gam()
  est <- effect_estimates(model, "x1")

  p_none <- plotEffects(model, test_data(), "x1", transform = "none")
  p_log <- plotEffects(model, test_data(), "x1", transform = "log")

  mapped_none <- rlang::eval_tidy(effect_panel(p_none)$mapping$x, est)
  mapped_log <- rlang::eval_tidy(effect_panel(p_log)$mapping$x, est)

  expect_equal(mapped_none, est$.x)
  expect_equal(mapped_log, log(est$.x))
})

test_that("the transform reaches the rug as well as the curve", {
  # If it reached only one of the two, the rug would sit on a different x axis
  # than the curve above it -- which is the entire thing this package exists
  # to get right.
  dat <- test_data()
  p <- plotEffects(make_test_lm(), dat, "x1", transform = "log10")

  rug_mapped <- rlang::eval_tidy(p[[1]]$layers[[1]]$mapping$x, dat)
  expect_equal(rug_mapped, log10(dat$x1))
})

test_that("plotEffects does not clip the y-axis to a fixed range", {
  # Regression test: an earlier version hardcoded
  # coord_cartesian(ylim = c(-10, 5)), which would silently clip any estimate
  # falling outside that window.
  built <- ggplot2::ggplot_build(
    effect_panel(plotEffects(make_test_gam(), test_data(), "x1"))
  )
  panel_range <- built$layout$panel_params[[1]]$y.range

  expect_false(isTRUE(all.equal(panel_range, c(-10, 5))))
})

test_that("the ribbon is drawn under the line, not over it", {
  # Drawing order is load-bearing here: with the ribbon on top at alpha 0.5 the
  # curve itself is washed out, which was the behaviour before plotEffects().
  p <- plotEffects(make_test_lm(), test_data(), "x1")
  geoms <- vapply(effect_panel(p)$layers, function(l) class(l$geom)[1],
                  character(1), USE.NAMES = FALSE)

  expect_equal(geoms, c("GeomRibbon", "GeomLine"))
})

test_that("invalid arguments are refused before anything is drawn", {
  model <- make_test_gam()
  dat <- test_data()

  expect_error(plotEffects(model, dat, "x1", rug.type = "violin"),
               "Unknown type requested")
  expect_error(plotEffects(model, dat, "x1", scale = "logit"),
               "Unknown scale requested")
  expect_error(plotEffects(model, dat, "x1", interval = "band"),
               "Unknown interval requested")
})

test_that("plotEffects errors on an unknown transform", {
  # aes() is lazy, so an invalid transform would otherwise sail through until
  # the plot was built. Forcing a build confirms it still stops.
  expect_error(
    ggplot2::ggplot_build(plotEffects(make_test_gam(), test_data(), "x1",
                                      transform = "invalid")),
    "Unknown transformation requested"
  )
})

test_that("interval and level reach the ribbon", {
  dat <- test_data()
  model <- make_test_lm()

  se <- effect_panel(plotEffects(model, dat, "x1", interval = "se"))
  ci <- effect_panel(plotEffects(model, dat, "x1", interval = "ci", level = 0.99))

  se_width <- se$data$.upper - se$data$.lower
  ci_width <- ci$data$.upper - ci$data$.lower

  expect_true(all(ci_width > se_width))
})
