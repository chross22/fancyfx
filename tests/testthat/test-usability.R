# Consistency and usability behaviours found by a full audit of the package.

test_that("a misspelled argument warns instead of vanishing into ...", {
  # The failure this prevents: ... forwards to a backend that ignores unknown
  # names, so a typo'd rug.type silently produced the default rug.
  set.seed(1)
  d <- data.frame(x1 = runif(200, 1, 10))
  d$y <- rbinom(200, 1, plogis(-3 + 0.6 * d$x1))
  fit <- mgcv::gam(y ~ s(x1), data = d, family = binomial)

  expect_warning(plotEffects(fit, d, "x1", rugtype = "density"),
                 "Did you mean 'rug.type'")
  expect_no_warning(plotEffects(fit, d, "x1", rug.type = "density"))
})

test_that("the suggestion matches across case, dots and underscores", {
  formals.names <- c("rug.type", "show.auc", "n.perm", "base_size", "min.n",
                     "level")

  for (typo in c("rugtype", "rug_type", "RugType")) {
    expect_warning(warn_misspelled_dots(typo, formals.names), "'rug.type'")
  }
  expect_warning(warn_misspelled_dots("nperm", formals.names), "'n.perm'")
  expect_warning(warn_misspelled_dots("basesize", formals.names), "'base_size'")
  # One character out, on a name long enough for that to be meaningful.
  expect_warning(warn_misspelled_dots("levl", formals.names), "'level'")
})

test_that("genuine backend arguments are left alone", {
  # These are real arguments to gratia, marginaleffects, predict and gbm, and
  # flagging them would make the check worse than useless.
  formals.names <- c("rug.type", "show.auc", "n.perm", "base_size", "min.n",
                     "level", "theme", "n", "bins")

  for (real in c("re.form", "re_formula", "n.trees", "partial_match", "dist",
                 "nsim", "type", "unconditional", "ndraws")) {
    expect_no_warning(warn_misspelled_dots(real, formals.names))
  }
  expect_no_warning(warn_misspelled_dots(character(0), formals.names))
  expect_no_warning(warn_misspelled_dots("", formals.names))
})

test_that("every plot function that takes ... checks it", {
  # Consistency: the guard is only useful if it is everywhere ... is.
  takes.dots <- c("plotEffects", "combinePlots", "comparePlots", "plotROC",
                  "plotThreshold", "plotCalibration", "plotImportance",
                  "threshold_metrics", "calibration_estimates",
                  "permutation_importance")

  for (fn in takes.dots) {
    body.text <- paste(deparse(body(get(fn))), collapse = " ")
    expect_match(body.text, "warn_misspelled_dots", info = fn)
  }
})

test_that("plotEffects takes a title, like every other plot function", {
  set.seed(1)
  d <- data.frame(x1 = runif(200, 1, 10))
  d$y <- rbinom(200, 1, plogis(-3 + 0.6 * d$x1))
  fit <- mgcv::gam(y ~ s(x1), data = d, family = binomial)

  expect_equal(plotEffects(fit, d, "x1", title = "T")[[2]]$labels$title, "T")
  expect_null(plotEffects(fit, d, "x1")[[2]]$labels$title)

  # And it is a formal argument, not something ... happens to swallow.
  expect_true("title" %in% names(formals(plotEffects)))
})

test_that("an equivalency result prints and plots", {
  # It used to return a bare list, so the result could not be looked at.
  set.seed(1)
  grid <- seq(0, 20, length.out = 30)
  fit_density <- function(o) stats::dnorm(grid, mean(o$temp), stats::sd(o$temp))

  result <- niche_equivalency(data.frame(temp = rnorm(40, 8, 1.5)),
                              data.frame(temp = rnorm(40, 14, 1.5)),
                              fit_density, n.rep = 19)

  expect_s3_class(result, "fancyfx_equivalency")
  expect_output(print(result), "Niche equivalency test")
  expect_output(print(result), "p-value")
  expect_s3_class(plot(result), "ggplot")

  # The list contract is unchanged; it just carries a class now.
  expect_named(result, c("observed", "null", "p.value", "statistic", "n.rep"))
})
