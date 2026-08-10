importance_fixture <- function() {
  set.seed(1)
  d <- data.frame(x1 = runif(600, 1, 10), x2 = runif(600, 1, 10),
                  x3 = runif(600, 1, 10))
  # Only x1 carries signal, so the ordering has a right answer to check.
  d$y <- rbinom(600, 1, plogis(-3 + 0.6 * d$x1))
  list(fit = glm(y ~ x1 + x2 + x3, data = d[1:300, ], family = binomial),
       train = d[1:300, ],
       test = d[301:600, ])
}

test_that("permutation_importance returns one row per variable per permutation", {
  f <- importance_fixture()
  imp <- permutation_importance(f$fit, f$test, n.perm = 5)

  expect_named(imp, c(".variable", ".permutation", ".importance"))
  expect_equal(nrow(imp), 3 * 5)
  expect_setequal(levels(imp$.variable), c("x1", "x2", "x3"))
  expect_equal(attr(imp, "metric"), "auc")
})

test_that("importance finds the variable that actually carries the signal", {
  f <- importance_fixture()
  imp <- permutation_importance(f$fit, f$test, n.perm = 10)
  means <- tapply(imp$.importance, imp$.variable, mean)

  expect_gt(means[["x1"]], 0.1)
  expect_lt(means[["x2"]], 0.05)
  expect_lt(means[["x3"]], 0.05)
  expect_equal(names(which.max(means)), "x1")
})

test_that("the metric is chosen from the response when not specified", {
  f <- importance_fixture()
  expect_equal(attr(permutation_importance(f$fit, f$test, n.perm = 2),
                    "metric"), "auc")

  # A continuous response has no AUC, so RMSE is the fallback.
  d <- f$train
  continuous <- lm(x2 ~ x1 + x3, data = d)
  expect_equal(attr(permutation_importance(continuous, d[1:50, ], n.perm = 2),
                    "metric"), "rmse")
})

test_that("results are reproducible, because a seeded figure can be redrawn", {
  f <- importance_fixture()

  first <- permutation_importance(f$fit, f$test, n.perm = 5, seed = 42)
  second <- permutation_importance(f$fit, f$test, n.perm = 5, seed = 42)

  expect_equal(first$.importance, second$.importance)
})

test_that("the caller's random stream is left as it was found", {
  # Silently resetting it would change results elsewhere in a user's script
  # for reasons they would struggle to trace.
  f <- importance_fixture()

  set.seed(99)
  before <- runif(1)
  set.seed(99)
  invisible(runif(1))
  after.state <- .Random.seed
  invisible(permutation_importance(f$fit, f$test, n.perm = 2, seed = 7))

  expect_equal(.Random.seed, after.state)
  set.seed(99)
  expect_equal(runif(1), before)
})

test_that("importance on the training data warns and is flagged", {
  f <- importance_fixture()

  expect_warning(permutation_importance(f$fit, f$train, n.perm = 2),
                 "fitted to")
  expect_true(suppressWarnings(
    attr(permutation_importance(f$fit, f$train, n.perm = 2), "in.sample")
  ))
})

test_that("vars selects which predictors to permute", {
  f <- importance_fixture()
  imp <- permutation_importance(f$fit, f$test, vars = "x1", n.perm = 3)

  expect_equal(nrow(imp), 3)
  expect_equal(levels(imp$.variable), "x1")
})

test_that("a variable absent from newdata is named in the error", {
  f <- importance_fixture()

  expect_error(permutation_importance(f$fit, f$test, vars = "nope"),
               "no column\\(s\\): nope")
})

test_that("n.perm is validated", {
  f <- importance_fixture()

  expect_error(permutation_importance(f$fit, f$test, n.perm = 0),
               "single positive number")
})

test_that("an unknown metric is refused", {
  f <- importance_fixture()

  expect_error(permutation_importance(f$fit, f$test, metric = "logloss"),
               "Unknown metric requested")
})

test_that("model_predictors reads terms, not the raw formula", {
  # A term written s(x, by = f) should contribute x and f, not the call.
  d <- importance_fixture()$train
  d$g <- factor(rep(letters[1:3], length.out = nrow(d)))
  fit <- mgcv::gam(y ~ s(x1, by = g) + g + x2, data = d, family = binomial)

  expect_setequal(model_predictors(fit), c("x1", "g", "x2"))
})

test_that("plotImportance returns a ggplot and flags in-sample use", {
  f <- importance_fixture()

  expect_s3_class(plotImportance(f$fit, f$test, n.perm = 3), "ggplot")

  p <- suppressWarnings(plotImportance(f$fit, f$train, n.perm = 3))
  expect_match(p$labels$caption, "In-sample")
})

test_that("the importance axis names the metric it used", {
  expect_match(importance_label("auc"), "AUC")
  expect_match(importance_label("rmse"), "RMSE")
})

test_that("is_binary recognises the forms a presence/absence response takes", {
  expect_true(is_binary(c(0, 1, 1, 0)))
  expect_true(is_binary(c(TRUE, FALSE)))
  expect_true(is_binary(factor(c("a", "b"))))

  expect_false(is_binary(c(1.5, 2.5)))
  expect_false(is_binary(factor(c("a", "b", "c"))))
  expect_false(is_binary(letters[1:2]))
})

test_that("importance works for a GAM as it does for a GLM", {
  f <- importance_fixture()
  fit <- mgcv::gam(y ~ s(x1) + s(x2), data = f$train, family = binomial)

  imp <- permutation_importance(fit, f$test, n.perm = 5)
  means <- tapply(imp$.importance, imp$.variable, mean)

  expect_equal(names(which.max(means)), "x1")
})
