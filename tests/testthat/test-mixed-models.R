# Mixed models go through the same marginaleffects backend as any other
# non-GAM fit, so what needs testing is the random-effects handling around it.

skip_if_no <- function(pkg) skip_if_not_installed(pkg)

make_mixed_data <- function() {
  set.seed(1)
  d <- data.frame(g = rep(letters[1:8], each = 25), x = runif(200, 1, 10))
  d$y <- 2 * d$x + rep(rnorm(8, 0, 5), each = 25) + rnorm(200)
  d$bin <- rbinom(200, 1, plogis(d$x - 5))
  d
}

test_that("has_random_effects recognises mixed models and only those", {
  expect_false(has_random_effects(make_test_lm()))
  expect_false(has_random_effects(make_test_gam()))

  skip_if_no("lme4")
  d <- make_mixed_data()
  expect_true(has_random_effects(lme4::lmer(y ~ x + (1 | g), data = d)))
})

test_that("lme4 models produce a standardized effect frame", {
  skip_if_no("lme4")
  d <- make_mixed_data()
  fit <- lme4::lmer(y ~ x + (1 | g), data = d)

  est <- effect_estimates(fit, "x")

  expect_named(est, c(".x", ".estimate", ".lower", ".upper"))
  expect_equal(nrow(est), 100)
  expect_false(anyNA(est$.estimate))
  expect_equal(attr(est, "quantity"), "Predicted Value")
})

test_that("random effects are held at the population level by default", {
  # This is the whole point of defaulting re.form to NA. datagrid() pins the
  # grouping factor to its modal level, so without it the plot silently shows
  # the effect for one arbitrary group rather than the average one -- and the
  # two differ substantially.
  skip_if_no("lme4")
  d <- make_mixed_data()
  fit <- lme4::lmer(y ~ x + (1 | g), data = d)

  population <- effect_estimates(fit, "x")
  one.group <- suppressWarnings(effect_estimates(fit, "x", re.form = NULL))

  expect_equal(population$.estimate,
               effect_estimates(fit, "x", re.form = NA)$.estimate)
  expect_false(isTRUE(all.equal(population$.estimate, one.group$.estimate)))
})

test_that("the backend's fixed-effects-only warning is muffled only at re.form = NA", {
  # marginaleffects says its standard errors cover fixed effects only, and that
  # this is "often appropriate when re.form=NA" -- exactly the case we default
  # to, so repeating it on every panel is noise. A caller who chooses otherwise
  # still hears it.
  skip_if_no("lme4")
  d <- make_mixed_data()
  fit <- lme4::lmer(y ~ x + (1 | g), data = d)

  expect_no_warning(effect_estimates(fit, "x"))
  expect_warning(effect_estimates(fit, "x", re.form = NULL),
                 "fixed-effect")
})

test_that("re.form is not forwarded to models that have no random effects", {
  # Passing it to an lm is an error rather than a no-op, so plotEffects() must
  # not hand its default along to every model it sees.
  expect_no_error(effect_estimates(make_test_lm(), "x1"))
  expect_no_error(plotEffects(make_test_lm(), test_data(), "x1"))
})

test_that("glmmTMB models work on both scales", {
  skip_if_no("glmmTMB")
  d <- make_mixed_data()
  gaussian.fit <- glmmTMB::glmmTMB(y ~ x + (1 | g), data = d)
  binomial.fit <- glmmTMB::glmmTMB(bin ~ x + (1 | g), data = d,
                                   family = stats::binomial)

  expect_equal(nrow(effect_estimates(gaussian.fit, "x")), 100)

  probs <- effect_estimates(binomial.fit, "x", scale = "response")
  expect_true(all(probs$.estimate >= 0 & probs$.estimate <= 1))
})

test_that("plotEffects and comparePlots accept mixed models", {
  skip_if_no("lme4")
  d <- make_mixed_data()
  fit <- lme4::lmer(y ~ x + (1 | g), data = d)

  expect_s3_class(plotEffects(fit, d, "x"), "patchwork")
  expect_no_error(
    comparePlots(list(mixed = fit, flat = lm(y ~ x, data = d)), d, "x")
  )
})
