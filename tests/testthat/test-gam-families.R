# The GAM family beyond mgcv::gam(): bam for large data, gamm4 and gamm for
# GAMs fitted through a mixed model, and scam for shape-constrained smooths.
#
# What these have in common is that they should all report a *partial effect*
# by default, like any other GAM. Two of them do not get there on their own:
# scam inherits from glm rather than gam, and gamm4/gamm are not fitted models
# at all but lists holding one.

#' Muffle a fitting engine's own convergence chatter
#'
#' A small binomial gamm4 fit makes lme4's Cholesky step complain that a matrix
#' is not positive definite. That is a statement about a toy fixture, not about
#' the code under test, and letting it through buries real warnings.
quiet_fit <- function(expr) {
  withCallingHandlers(expr, warning = function(w) {
    if (grepl("CHOLMOD|positive definite|not converge|failed to converge",
              conditionMessage(w))) {
      invokeRestart("muffleWarning")
    }
  })
}

gam_family_data <- function() {
  set.seed(1)
  d <- data.frame(x1 = runif(400, 1, 10), x2 = runif(400, 1, 10),
                  g = factor(rep(letters[1:8], each = 50)),
                  f = factor(rep(c("a", "b"), length.out = 400)))
  d$y <- sin(d$x1) + d$x2 / 5 + rep(rnorm(8, 0, 0.5), each = 50) +
    rnorm(400, sd = 0.3)
  d$bin <- rbinom(400, 1, plogis(d$x1 - 5))
  d
}

# ── bam ───────────────────────────────────────────────────────────────────────

test_that("bam is handled by the gam method without any code of its own", {
  # bam inherits from gam, so this is a confirmation rather than a feature.
  d <- gam_family_data()
  fit <- mgcv::bam(y ~ s(x1) + s(x2), data = d)

  expect_s3_class(fit, "gam")
  est <- effect_estimates(fit, "x1")

  expect_named(est, c(".x", ".estimate", ".lower", ".upper"))
  expect_equal(attr(est, "quantity"), "Partial Effect")
})

test_that("a discrete bam fit works, though it stores things differently", {
  d <- gam_family_data()
  fit <- mgcv::bam(y ~ s(x1) + s(x2), data = d, discrete = TRUE)

  expect_equal(attr(effect_estimates(fit, "x1"), "quantity"), "Partial Effect")
  expect_s3_class(plotEffects(fit, d, "x1"), "patchwork")
})

test_that("a bam factor-smooth splits into curves like any other GAM", {
  d <- gam_family_data()
  fit <- mgcv::bam(y ~ s(x1, by = f) + f, data = d)

  est <- effect_estimates(fit, "x1")

  expect_true(".group" %in% names(est))
  expect_setequal(levels(est$.group), c("a", "b"))
})

test_that("bam models can be evaluated like any other model", {
  d <- gam_family_data()
  fit <- mgcv::bam(bin ~ s(x1), data = d[1:200, ], family = binomial)

  expect_gt(attr(threshold_metrics(fit, d[201:400, ]), "auc"), 0.5)
})

# ── scam ──────────────────────────────────────────────────────────────────────

test_that("scam reports a partial effect rather than falling through to predictions", {
  # scam inherits from glm, not gam, so without its own method it would land on
  # the prediction backend and quietly report a different quantity than every
  # other GAM in the package.
  skip_if_not_installed("scam")
  d <- gam_family_data()
  fit <- scam::scam(y ~ s(x1, bs = "mpi") + s(x2), data = d)

  est <- effect_estimates(fit, "x1")

  expect_equal(attr(est, "quantity"), "Partial Effect")
  # A partial effect is centered on zero by construction.
  expect_lt(abs(mean(est$.estimate)), 0.15)
})

test_that("a scam shape constraint survives into the plotted estimates", {
  # bs = "mpi" is monotone increasing. If the constraint did not come through,
  # the wrong backend was used.
  skip_if_not_installed("scam")
  d <- gam_family_data()
  fit <- scam::scam(y ~ s(x1, bs = "mpi") + s(x2), data = d)

  est <- effect_estimates(fit, "x1")

  expect_false(is.unsorted(round(est$.estimate, 6)))
})

test_that("scam still offers predictions when asked for the response scale", {
  skip_if_not_installed("scam")
  d <- gam_family_data()
  fit <- scam::scam(y ~ s(x1, bs = "mpi") + s(x2), data = d)

  est <- effect_estimates(fit, "x1", scale = "response")

  expect_equal(attr(est, "quantity"), "Predicted Value")
})

# ── gamm4 and gamm ────────────────────────────────────────────────────────────

test_that("unwrap_gam finds the GAM inside a wrapper and leaves others alone", {
  d <- gam_family_data()
  plain <- mgcv::gam(y ~ s(x1), data = d)

  expect_identical(unwrap_gam(plain), plain)
  expect_identical(unwrap_gam(lm(y ~ x1, data = d)), lm(y ~ x1, data = d))
  # A bare list with no $gam is not a wrapper.
  expect_identical(unwrap_gam(list(a = 1)), list(a = 1))
})

test_that("unwrap_gam restores the classes an mgcv gam normally carries", {
  # marginaleffects dispatches on the full inheritance and refuses the
  # truncated "gam" that these wrappers hand back.
  skip_if_not_installed("gamm4")
  d <- gam_family_data()
  fit <- gamm4::gamm4(y ~ s(x1), random = ~ (1 | g), data = d)

  expect_identical(class(fit$gam), "gam")
  expect_identical(class(unwrap_gam(fit)), c("gam", "glm", "lm"))
})

test_that("gamm4 and gamm report partial effects", {
  skip_if_not_installed("gamm4")
  d <- gam_family_data()
  g4 <- gamm4::gamm4(y ~ s(x1) + s(x2), random = ~ (1 | g), data = d)
  gm <- mgcv::gamm(y ~ s(x1) + s(x2), random = list(g = ~ 1), data = d)

  for (fit in list(g4, gm)) {
    est <- effect_estimates(fit, "x1")
    expect_equal(attr(est, "quantity"), "Partial Effect")
    expect_false(anyNA(est$.estimate))
  }
})

test_that("unwrapping changes nothing about the smooth itself", {
  skip_if_not_installed("gamm4")
  d <- gam_family_data()
  fit <- gamm4::gamm4(y ~ s(x1) + s(x2), random = ~ (1 | g), data = d)

  expect_equal(effect_estimates(fit, "x1")$.estimate,
               effect_estimates(fit$gam, "x1")$.estimate)
})

test_that("restoring the class gives the same predictions as mgcv's own predict", {
  # The claim that justifies touching the class at all. Estimates match
  # exactly; standard errors agree to about 1e-7 relative, because
  # marginaleffects differentiates numerically for the delta method.
  skip_if_not_installed("gamm4")
  d <- gam_family_data()
  fit <- gamm4::gamm4(y ~ s(x1) + s(x2), random = ~ (1 | g), data = d)
  grid <- data.frame(x1 = seq(2, 9, length.out = 5), x2 = mean(d$x2))

  direct <- stats::predict(fit$gam, newdata = grid, type = "response",
                           se.fit = TRUE)
  ours <- as.data.frame(marginaleffects::predictions(
    unwrap_gam(fit), newdata = grid, type = "response"))

  expect_equal(as.numeric(direct$fit), ours$estimate)
  expect_equal(as.numeric(direct$se.fit), ours$std.error, tolerance = 1e-6)
})

test_that("gamm4 works on the response scale, which needs the unwrap", {
  # marginaleffects refuses the wrapper outright, so without unwrapping this
  # path is unavailable for these two classes and no other GAM.
  skip_if_not_installed("gamm4")
  d <- gam_family_data()
  fit <- gamm4::gamm4(y ~ s(x1) + s(x2), random = ~ (1 | g), data = d)

  est <- effect_estimates(fit, "x1", scale = "response")

  expect_equal(attr(est, "quantity"), "Predicted Value")
  expect_false(anyNA(est$.estimate))
})

test_that("gamm4 fits plot, combine and compare", {
  skip_if_not_installed("gamm4")
  d <- gam_family_data()
  fit <- gamm4::gamm4(y ~ s(x1) + s(x2), random = ~ (1 | g), data = d)

  expect_s3_class(plotEffects(fit, d, "x1"), "patchwork")
  expect_no_error(combinePlots(fit, d, vars = c("x1", "x2")))
  expect_no_error(
    comparePlots(list(mixed = fit, plain = mgcv::gam(y ~ s(x1) + s(x2), data = d)),
                 d, "x1")
  )
})

test_that("evaluation functions accept a wrapper, which formula() alone cannot", {
  # threshold_metrics() reads the response off the formula and predicts; both
  # fail on the wrapper, so it has to unwrap first.
  skip_if_not_installed("gamm4")
  d <- gam_family_data()
  fit <- quiet_fit(gamm4::gamm4(bin ~ s(x1), random = ~ (1 | g), data = d,
                                family = binomial))

  expect_error(stats::formula(fit))
  expect_gt(suppressWarnings(attr(threshold_metrics(fit, d), "auc")), 0.5)
  expect_no_error(
    suppressWarnings(permutation_importance(fit, d, n.perm = 2))
  )
})
