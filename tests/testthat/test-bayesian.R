# Bayesian fits differ from every other backend in three ways that the code has
# to know about: they report an interval and no standard error, brms names its
# random-effects argument re_formula rather than re.form, and they refuse the
# bounded invlink(link) construction.
#
# The dispatch logic for all three is tested against class-mocked objects, which
# costs nothing and runs everywhere. Actually fitting a model means compiling
# Stan code, so those tests are opt-in -- set FANCYFX_TEST_STAN=true to run
# them. They are not skipped because they do not matter; they are skipped
# because a test suite that takes several minutes stops being run at all.

fake_fit <- function(cls) structure(list(), class = cls)

skip_unless_stan_requested <- function(pkg) {
  skip_on_cran()
  skip_if_not_installed(pkg)
  skip_if_not(
    isTRUE(as.logical(Sys.getenv("FANCYFX_TEST_STAN", "false"))),
    paste0("Set FANCYFX_TEST_STAN=true to run ", pkg, " integration tests")
  )
}

test_that("posterior models are recognised, and other models are not", {
  expect_true(is_posterior_model(fake_fit("brmsfit")))
  expect_true(is_posterior_model(fake_fit("stanreg")))

  expect_false(is_posterior_model(make_test_lm()))
  expect_false(is_posterior_model(make_test_gam()))
})

test_that("brms gets re_formula and everything else gets re.form", {
  # Passing re.form to a brmsfit still reaches the prediction function, but
  # marginaleffects warns that it is not an argument it recognises for the
  # class -- noise on every panel, and a sign the call is relying on something
  # not guaranteed to keep working.
  expect_equal(re_form_arg(fake_fit("brmsfit")), "re_formula")
  expect_equal(re_form_arg(fake_fit("stanreg")), "re.form")
  expect_equal(re_form_arg(fake_fit(c("lmerMod", "merMod"))), "re.form")
  expect_equal(re_form_arg(make_test_lm()), "re.form")
})

test_that("Bayesian fits are treated as having random effects", {
  # So the re_formula/re.form argument is forwarded at all.
  expect_true(has_random_effects(fake_fit("brmsfit")))
  expect_true(has_random_effects(fake_fit("stanreg")))
})

test_that("cri is accepted as another name for ci", {
  # A user writing "cri" to say the interval is credible should not meet an
  # error, and should get exactly the same computation.
  expect_equal(check_interval("cri"), "ci")
  expect_equal(check_interval("ci"), "ci")
  expect_equal(check_interval("auto"), "auto")
  expect_error(check_interval("hpdi"), "Unknown interval requested")
})

test_that("interval = 'cri' and 'ci' agree on a frequentist fit too", {
  model <- make_test_lm()

  expect_equal(effect_estimates(model, "x1", interval = "cri"),
               effect_estimates(model, "x1", interval = "ci"))
})

test_that("interval = 'auto' gives a 95% interval, not the narrower SE band", {
  # The package once drew +/- 1 SE, roughly 68% -- half the width of what
  # mgcv::plot.gam and gratia::draw() show, and a width a reader seeing a
  # ribbon on a smooth would very likely misread as 95%.
  for (model in list(make_test_lm(), make_test_gam())) {
    auto <- effect_estimates(model, "x1", interval = "auto")
    ci <- effect_estimates(model, "x1", interval = "ci")
    se <- effect_estimates(model, "x1", interval = "se")

    expect_equal(auto$.lower, ci$.lower)
    expect_gt(mean(auto$.upper - auto$.lower), mean(se$.upper - se$.lower))
  }
})

test_that("the default GAM ribbon is about twice the +/- 1 SE band", {
  # A 95% normal interval is qnorm(0.975) = 1.96 standard errors either side,
  # so it should be almost exactly twice as wide.
  model <- make_test_gam()
  wide <- effect_estimates(model, "x1", interval = "auto")
  narrow <- effect_estimates(model, "x1", interval = "se")

  ratio <- mean(wide$.upper - wide$.lower) / mean(narrow$.upper - narrow$.lower)
  expect_equal(ratio, stats::qnorm(0.975), tolerance = 1e-6)
})

test_that("interval = 'se' still gives the narrow band, now explicitly", {
  model <- make_test_gam()
  est <- effect_estimates(model, "x1", interval = "se")
  reference <- gratia::smooth_estimates(model, select = "x1", dist = 0.1,
                                        partial_match = TRUE)
  reference <- as.data.frame(reference)
  reference <- reference[order(reference$x1), , drop = FALSE]

  expect_equal(est$.lower, reference$.estimate - reference$.se)
})

# ── Integration: needs a compiled Stan model ──────────────────────────────────

#' Muffle Stan's sampler diagnostics
#'
#' These fixtures run two short chains, so Stan rightly complains about
#' effective sample size. That is a statement about the toy fit, not about the
#' code under test -- what is being checked here is plumbing, not inference --
#' and letting it through buries real warnings in the test output.
quiet_sampler <- function(expr) {
  withCallingHandlers(expr, warning = function(w) {
    if (grepl("ESS|Effective Samples|R-hat|divergent|Bulk|Tail",
              conditionMessage(w))) {
      invokeRestart("muffleWarning")
    }
  })
}

brms_fixture <- function() {
  set.seed(1)
  d <- data.frame(g = rep(letters[1:6], each = 20), x = runif(120, 1, 10))
  d$y <- 2 * d$x + rep(rnorm(6, 0, 4), each = 20) + rnorm(120)
  list(
    fit = quiet_sampler(
      brms::brm(y ~ x + (1 | g), data = d, chains = 2, iter = 600,
                refresh = 0, seed = 1, silent = 2)
    ),
    dat = d
  )
}

test_that("a brms fit produces a standardized effect frame", {
  skip_unless_stan_requested("brms")
  f <- brms_fixture()

  est <- effect_estimates(f$fit, "x")

  expect_named(est, c(".x", ".estimate", ".lower", ".upper"))
  expect_equal(nrow(est), 100)
  expect_false(anyNA(est$.estimate))
  expect_true(all(est$.lower <= est$.estimate & est$.estimate <= est$.upper))
})

test_that("a brms fit defaults to its credible interval, and level moves it", {
  skip_unless_stan_requested("brms")
  f <- brms_fixture()

  wide <- effect_estimates(f$fit, "x", level = 0.95)
  narrow <- effect_estimates(f$fit, "x", level = 0.80)

  expect_true(all(wide$.upper - wide$.lower >= narrow$.upper - narrow$.lower))
})

test_that("asking a brms fit for an SE ribbon says why it cannot have one", {
  skip_unless_stan_requested("brms")
  f <- brms_fixture()

  expect_message(effect_estimates(f$fit, "x", interval = "se"),
                 "reports no standard error")
})

test_that("re_formula reaches a brms fit and changes the answer", {
  skip_unless_stan_requested("brms")
  f <- brms_fixture()

  population <- effect_estimates(f$fit, "x")
  with.groups <- effect_estimates(f$fit, "x", re.form = NULL)

  expect_false(isTRUE(all.equal(population$.estimate, with.groups$.estimate)))
})

test_that("brms fits plot, and compare against a frequentist fit", {
  skip_unless_stan_requested("brms")
  f <- brms_fixture()

  expect_s3_class(plotEffects(f$fit, f$dat, "x"), "patchwork")
  expect_no_error(
    comparePlots(list(Bayesian = f$fit, REML = lme4::lmer(y ~ x + (1 | g), data = f$dat)),
                 f$dat, "x")
  )
})

test_that("an rstanarm fit produces a standardized effect frame", {
  skip_unless_stan_requested("rstanarm")
  set.seed(1)
  d <- data.frame(x = runif(80, 1, 10))
  d$y <- 2 * d$x + rnorm(80)
  fit <- quiet_sampler(
    rstanarm::stan_glm(y ~ x, data = d, chains = 2, iter = 600,
                       refresh = 0, seed = 1)
  )

  est <- effect_estimates(fit, "x")

  expect_named(est, c(".x", ".estimate", ".lower", ".upper"))
  expect_false(anyNA(est$.estimate))
})
