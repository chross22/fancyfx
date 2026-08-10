test_that("every backend returns the same standardized columns", {
  # The whole point of the generic: downstream code should never have to know
  # which backend produced the frame.
  fits <- list(gam = make_test_gam(), lm = make_test_lm(), glm = make_test_glm())

  for (nm in names(fits)) {
    est <- effect_estimates(fits[[nm]], "x1")
    expect_named(est, c(".x", ".estimate", ".lower", ".upper"), info = nm)
    expect_s3_class(est, "data.frame")
    expect_gt(nrow(est), 1)
    expect_true(all(vapply(est, is.numeric, logical(1))), info = nm)
    expect_false(anyNA(est$.estimate), info = nm)
  }
})

test_that("the gam method reproduces gratia's smooth estimates", {
  model <- make_test_gam()
  est <- effect_estimates(model, "x1")
  reference <- gratia::smooth_estimates(model, select = "x1", dist = 0.1,
                                        partial_match = TRUE)
  reference <- as.data.frame(reference)
  reference <- reference[order(reference$x1), , drop = FALSE]

  expect_equal(est$.x, reference$x1)
  expect_equal(est$.estimate, reference$.estimate)
  # Default interval is +/- 1 SE, the ribbon this package has always drawn.
  expect_equal(est$.lower, reference$.estimate - reference$.se)
  expect_equal(est$.upper, reference$.estimate + reference$.se)
})

test_that("scale = 'auto' picks the natural quantity per backend", {
  expect_equal(attr(effect_estimates(make_test_gam(), "x1"), "quantity"),
               "Partial Effect")
  expect_equal(attr(effect_estimates(make_test_lm(), "x1"), "quantity"),
               "Predicted Value")
})

test_that("a GAM asked for the response scale gets predictions, not a partial effect", {
  # A centered partial effect has no coherent back-transformation, so the
  # request falls through to the prediction backend rather than exponentiating
  # a centered term and mislabelling the result.
  model <- make_test_gam()
  partial <- effect_estimates(model, "x1")
  predicted <- effect_estimates(model, "x1", scale = "response")

  expect_equal(attr(predicted, "quantity"), "Predicted Value")
  # Partial effects are centered on zero; predictions are not.
  expect_lt(abs(mean(partial$.estimate)), 0.1)
  expect_false(isTRUE(all.equal(mean(predicted$.estimate), 0, tolerance = 0.1)))
})

test_that("interval = 'ci' is wider than interval = 'se', on both backends", {
  for (model in list(make_test_gam(), make_test_lm())) {
    se <- effect_estimates(model, "x1", interval = "se")
    ci <- effect_estimates(model, "x1", interval = "ci")
    expect_true(all(ci$.upper - ci$.lower > se$.upper - se$.lower))
  }
})

test_that("a higher confidence level widens the interval", {
  narrow <- effect_estimates(make_test_lm(), "x1", interval = "ci", level = 0.80)
  wide <- effect_estimates(make_test_lm(), "x1", interval = "ci", level = 0.99)

  expect_true(all(wide$.upper - wide$.lower > narrow$.upper - narrow$.lower))
})

test_that("n controls the size of the prediction grid", {
  expect_equal(nrow(effect_estimates(make_test_lm(), "x1", n = 25)), 25)
  expect_equal(nrow(effect_estimates(make_test_lm(), "x1", n = 60)), 60)
})

test_that("estimates come back sorted along x", {
  # geom_line() connects points in row order, so an unsorted grid would draw a
  # curve that doubles back on itself.
  for (model in list(make_test_gam(), make_test_lm(), make_test_glm())) {
    expect_false(is.unsorted(effect_estimates(model, "x1")$.x))
  }
})

test_that("the prediction grid stays inside the fitted range of the data", {
  dat <- test_data()
  est <- effect_estimates(make_test_lm(), "x1")

  expect_gte(min(est$.x), min(dat$x1))
  expect_lte(max(est$.x), max(dat$x1))
})

test_that("an unknown variable is refused with a message naming the alternatives", {
  expect_error(effect_estimates(make_test_lm(), "nope"),
               "Could not find 'nope'")
  expect_error(effect_estimates(make_test_lm(), "nope"), "x1")
  expect_error(effect_estimates(make_test_gam(), "nope"),
               "No smooth of 'nope'")
})

test_that("a non-numeric predictor is refused", {
  fit <- lm(Petal.Length ~ Sepal.Length + Species, data = iris)
  expect_error(effect_estimates(fit, "Species"), "not numeric")
})

test_that("a scale the model cannot provide gives an actionable error", {
  # marginaleffects reports this as a bare set-membership assertion, which
  # says nothing about what to do instead.
  expect_error(effect_estimates(make_test_lm(), "x1", scale = "link"),
               "not available for a model of class")
  expect_error(effect_estimates(make_test_lm(), "x1", scale = "link"),
               "scale = \"auto\"", fixed = TRUE)
})

test_that("a binomial glm honours both scales", {
  model <- make_test_glm()
  response <- effect_estimates(model, "x1", scale = "response")
  link <- effect_estimates(model, "x1", scale = "link")

  # Probabilities are bounded; the log-odds they came from are not.
  expect_true(all(response$.estimate >= 0 & response$.estimate <= 1))
  expect_equal(attr(link, "quantity"), "Predicted Value (link scale)")
  expect_equal(stats::plogis(link$.estimate), response$.estimate)
})

test_that("response-scale intervals respect the bounds of the response", {
  # A delta-method band built directly on the response scale runs past [0, 1]
  # near the ends of a logistic curve, which reads as the model claiming
  # something impossible. Computing on the link scale and back-transforming
  # keeps it honest.
  est <- effect_estimates(make_test_glm(), "x1", scale = "response",
                          interval = "ci")

  expect_true(all(est$.lower >= 0))
  expect_true(all(est$.upper <= 1))
  expect_true(all(est$.lower <= est$.estimate & est$.estimate <= est$.upper))
})

test_that("a model without a link scale still gets response predictions", {
  # The bounded path is a preference, not a requirement: a Gaussian lm has no
  # "invlink(link)" and must fall back rather than error.
  est <- effect_estimates(make_test_lm(), "x1", scale = "response",
                          interval = "ci")

  expect_equal(nrow(est), 100)
  expect_false(anyNA(est$.estimate))
})

test_that("the SE ribbon still works on the response scale", {
  # The bounded construction returns no std.error, so interval = "se" has to
  # take the plain response path rather than silently producing empty columns.
  est <- effect_estimates(make_test_glm(), "x1", scale = "response",
                          interval = "se")

  expect_equal(nrow(est), 100)
  expect_false(anyNA(est$.lower))
  expect_true(all(est$.lower <= est$.estimate & est$.estimate <= est$.upper))
})

test_that("invalid arguments are refused before any fitting work happens", {
  model <- make_test_lm()
  expect_error(effect_estimates(model, "x1", scale = "logit"),
               "Unknown scale requested")
  expect_error(effect_estimates(model, "x1", interval = "band"),
               "Unknown interval requested")
  expect_error(effect_estimates(model, "x1", level = 95), "strictly between 0 and 1")
  expect_error(effect_estimates(model, "x1", level = 0), "strictly between 0 and 1")
  expect_error(effect_estimates(model, "x1", level = c(0.8, 0.9)),
               "strictly between 0 and 1")
})
