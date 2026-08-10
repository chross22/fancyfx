test_that("combinePlots runs without error for multiple variables", {
  expect_no_error(
    combinePlots(make_test_gam(), test_data(), vars = c("x1", "x2"))
  )
})

test_that("combinePlots returns a ggarrange/ggplot-compatible object", {
  result <- combinePlots(make_test_gam(), test_data(), vars = c("x1", "x2"))

  # ggarrange() output (post annotate_figure) is a ggplot-renderable grob
  expect_true(inherits(result, "ggplot") || inherits(result, "gg"))
})

test_that("combinePlots handles a single variable", {
  expect_no_error(combinePlots(make_test_gam(), test_data(), vars = "x1"))
})

test_that("combinePlots works for non-GAM models too", {
  # The whole reason the package was renamed: nothing here is GAM-specific.
  expect_no_error(
    combinePlots(make_test_lm(), test_data(), vars = c("x1", "x2"))
  )
  expect_no_error(
    combinePlots(make_test_glm(), test_data(), vars = c("x1", "x2"),
                 scale = "response")
  )
})

test_that("combinePlots errors on an unknown transform passed through", {
  expect_error(
    combinePlots(make_test_gam(), test_data(), vars = c("x1", "x2"),
                 var.transform = "invalid"),
    "Unknown transformation requested"
  )
})

test_that("combinePlots actually applies the arguments it accepts", {
  # var.transform and rug.type were in the signature but never reached the
  # per-variable plotting call: the lapply hardcoded the defaults, so setting
  # either did nothing. R's laziness kept that invisible, since the ignored
  # arguments were never forced.
  model <- make_test_gam()
  dat <- test_data()

  expect_error(combinePlots(model, dat, vars = "x1", rug.type = "violin"),
               "Unknown type requested")
  expect_no_error(
    combinePlots(model, dat, vars = c("x1", "x2"),
                 var.transform = c("none", "log"))
  )
  # One transform per variable, or one for all. A length that is neither is a
  # mistake rather than something to recycle.
  expect_error(
    combinePlots(model, dat, vars = c("x1", "x2"),
                 var.transform = c("none", "log", "sqrt")),
    "one per variable"
  )
})

test_that("combinePlots validates the arguments it forwards to plotEffects", {
  model <- make_test_gam()
  dat <- test_data()

  expect_error(combinePlots(model, dat, vars = "x1", scale = "logit"),
               "Unknown scale requested")
  expect_error(combinePlots(model, dat, vars = "x1", interval = "band"),
               "Unknown interval requested")
  expect_error(combinePlots(model, dat, vars = "x1", level = 95),
               "strictly between 0 and 1")
})

test_that("combinePlots lets each panel label its own quantity", {
  # It used to hardcode ylab = "Partial Effect" for every panel, which would be
  # wrong for any model that reports predictions.
  expect_no_error(
    combinePlots(make_test_lm(), test_data(), vars = c("x1", "x2"))
  )
})
