make_compare_models <- function() {
  dat <- test_data()
  list(plain = mgcv::gam(y ~ s(x1), data = dat),
       richer = mgcv::gam(y ~ s(x1) + s(x2), data = dat))
}

test_that("comparePlots arranges one panel per model", {
  models <- make_compare_models()

  result <- comparePlots(models, test_data(), "x1")

  expect_true(inherits(result, "ggplot") || inherits(result, "gg"))
})

test_that("a single model is accepted rather than indexed into", {
  # A fitted model is itself a list, so is.list() cannot tell "one model" from
  # "a list of models" -- indexing a gam would walk into its internals.
  model <- make_test_gam()

  expect_no_error(comparePlots(model, test_data(), "x1"))
  expect_no_error(comparePlots(list(model), test_data(), "x1"))
})

test_that("models of different classes can be compared", {
  dat <- test_data()

  expect_no_error(
    comparePlots(list(GAM = make_test_gam(), Linear = make_test_lm()),
                 dat, "x1", scale = "response")
  )
})

test_that("one data frame is shared across panels, or one supplied per model", {
  models <- make_compare_models()
  dat <- test_data()

  expect_no_error(comparePlots(models, dat, "x1"))
  expect_no_error(comparePlots(models, list(dat, dat), "x1"))
  expect_error(comparePlots(models, list(dat, dat, dat), "x1"),
               "one per model")
})

test_that("var and transform are recycled to one per model, or refused", {
  models <- make_compare_models()
  dat <- test_data()

  expect_no_error(comparePlots(models, dat, "x1"))
  expect_no_error(comparePlots(models, dat, c("x1", "x1")))
  expect_no_error(comparePlots(models, dat, "x1",
                               transform = c("none", "log")))

  expect_error(comparePlots(models, dat, c("x1", "x1", "x2")),
               "var must be one value, or one per model")
  expect_error(comparePlots(models, dat, "x1",
                            transform = c("none", "log", "sqrt")),
               "transform must be one value, or one per model")
})

test_that("comparePlots refuses an empty model list", {
  expect_error(comparePlots(list(), test_data(), "x1"),
               "at least one fitted model")
})

test_that("comparePlots validates the arguments it forwards", {
  models <- make_compare_models()
  dat <- test_data()

  expect_error(comparePlots(models, dat, "x1", rug.type = "violin"),
               "Unknown type requested")
  expect_error(comparePlots(models, dat, "x1", scale = "logit"),
               "Unknown scale requested")
  expect_error(comparePlots(models, dat, "x1", transform = "invalid"),
               "Unknown transformation requested")
  expect_error(comparePlots(models, dat, "x1", level = 95),
               "strictly between 0 and 1")
})
