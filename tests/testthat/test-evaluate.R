make_eval_data <- function() {
  set.seed(1)
  d <- data.frame(x1 = runif(600, 1, 10), x2 = runif(600, 1, 10),
                  x3 = runif(600, 1, 10))
  d$y <- rbinom(600, 1, plogis(-3 + 0.6 * d$x1))
  d
}

eval_fixture <- function() {
  d <- make_eval_data()
  list(fit = glm(y ~ x1 + x2 + x3, data = d[1:300, ], family = binomial),
       train = d[1:300, ],
       test = d[301:600, ])
}

test_that("threshold_metrics returns the standard columns and attributes", {
  f <- eval_fixture()
  m <- threshold_metrics(f$fit, f$test)

  expect_true(all(c(".threshold", ".sensitivity", ".specificity",
                    ".tpr", ".fpr", ".tss") %in% names(m)))
  expect_true(all(m$.sensitivity >= 0 & m$.sensitivity <= 1))
  expect_true(all(m$.specificity >= 0 & m$.specificity <= 1))
  expect_equal(m$.tss, m$.sensitivity + m$.specificity - 1)
  expect_equal(attr(m, "n"), nrow(f$test))
  expect_false(attr(m, "in.sample"))
})

test_that("our AUC agrees with an independent implementation", {
  # Computed from ranks here, so ties are handled exactly. Checked against
  # yardstick rather than against a number this package produced itself.
  skip_if_not_installed("yardstick")
  f <- eval_fixture()

  ours <- attr(threshold_metrics(f$fit, f$test), "auc")
  theirs <- as.numeric(yardstick::roc_auc_vec(
    factor(f$test$y, levels = c("1", "0")),
    stats::predict(f$fit, f$test, type = "response")
  ))

  expect_equal(ours, theirs)
})

test_that("the ROC starts at the origin and ends at (1, 1)", {
  # Without the "classify nothing as positive" corner the curve does not start
  # at (0, 0) and the area is understated.
  f <- eval_fixture()
  m <- threshold_metrics(f$fit, f$test)

  expect_equal(c(m$.fpr[1], m$.tpr[1]), c(0, 0))
  expect_equal(c(m$.fpr[nrow(m)], m$.tpr[nrow(m)]), c(1, 1))
})

test_that("a perfect model scores 1 and a useless one scores about a half", {
  # Scored in-sample on purpose: the point is the arithmetic at the extremes,
  # and separating train from test would only add noise to a known answer.
  set.seed(1)
  d <- data.frame(x = c(rnorm(100, -3), rnorm(100, 3)))
  d$y <- rep(0:1, each = 100)
  perfect <- suppressWarnings(glm(y ~ x, data = d, family = binomial))

  expect_equal(suppressWarnings(attr(threshold_metrics(perfect, d), "auc")), 1)

  noise <- d
  set.seed(2)
  noise$y <- rbinom(200, 1, 0.5)
  useless <- glm(y ~ x, data = noise, family = binomial)
  expect_lt(
    abs(suppressWarnings(attr(threshold_metrics(useless, noise), "auc")) - 0.5),
    0.15
  )
})

test_that("tied predictions collapse to one operating point per threshold", {
  # Otherwise several rows share a cutoff with different scores.
  f <- eval_fixture()
  m <- threshold_metrics(f$fit, f$test)

  expect_equal(anyDuplicated(m$.threshold), 0)
})

test_that("evaluating on the training data warns and is flagged", {
  # The single most important behaviour here: an in-sample ROC can look
  # excellent for a model with no predictive value.
  f <- eval_fixture()

  expect_warning(threshold_metrics(f$fit, f$train), "optimistic")
  expect_true(suppressWarnings(attr(threshold_metrics(f$fit, f$train),
                                    "in.sample")))
})

test_that("plots built from in-sample metrics say so", {
  f <- eval_fixture()

  p <- suppressWarnings(plotROC(f$fit, f$train))
  expect_match(p$labels$caption, "In-sample")

  q <- plotROC(f$fit, f$test)
  expect_null(q$labels$caption)
})

test_that("newdata is required rather than defaulted to the training data", {
  f <- eval_fixture()

  expect_error(threshold_metrics(f$fit), "newdata is required")
  expect_error(permutation_importance(f$fit), "newdata is required")
})

test_that("a non-binary response is refused rather than scored", {
  # AUC and TSS on a Gaussian model would return a meaningless number.
  d <- make_eval_data()
  fit <- lm(x2 ~ x1, data = d)

  expect_error(threshold_metrics(fit, d), "not a binary outcome")
  expect_error(threshold_metrics(fit, d), "presence/absence")
})

test_that("factor and logical responses are handled", {
  d <- make_eval_data()
  d$yf <- factor(ifelse(d$y == 1, "present", "absent"),
                 levels = c("absent", "present"))
  d$yl <- d$y == 1

  # In-sample by design: what is being checked is that the two encodings give
  # the same answer, not the size of the answer.
  factor.fit <- glm(yf ~ x1, data = d, family = binomial)
  logical.fit <- glm(yl ~ x1, data = d, family = binomial)

  # Second factor level is the positive case, as glm() itself treats one.
  expect_equal(suppressWarnings(attr(threshold_metrics(factor.fit, d), "auc")),
               suppressWarnings(attr(threshold_metrics(logical.fit, d), "auc")))
})

test_that("a response with only one class is refused", {
  f <- eval_fixture()
  one.class <- f$test[f$test$y == 1, ]

  expect_error(threshold_metrics(f$fit, one.class),
               "only one outcome class")
})

test_that("newdata without the response column says which column is missing", {
  f <- eval_fixture()

  expect_error(threshold_metrics(f$fit, f$test[, c("x1", "x2", "x3")]),
               "no column 'y'")
})

test_that("folds produce per-fold curves and per-fold AUCs", {
  f <- eval_fixture()
  set.seed(2)
  folds <- sample(rep(1:4, length.out = nrow(f$test)))

  m <- suppressMessages(threshold_metrics(f$fit, f$test, folds = folds))

  expect_true(".fold" %in% names(m))
  expect_equal(nlevels(m$.fold), 4)
  expect_length(attr(m, "auc"), 4)
})

test_that("using folds notes that they are weaker evidence than a hold-out", {
  # Cross-validated metrics come from the same sample the model was fitted on,
  # and for spatial data random folds leak neighbours across the split.
  reset_notices()
  f <- eval_fixture()
  set.seed(2)
  folds <- sample(rep(1:4, length.out = nrow(f$test)))

  expect_message(threshold_metrics(f$fit, f$test, folds = folds),
                 "weaker evidence")

  # Once per session: a loop over panels should not repeat the paragraph.
  expect_no_message(threshold_metrics(f$fit, f$test, folds = folds))
})

test_that("mismatched folds are refused", {
  f <- eval_fixture()

  expect_error(
    suppressMessages(threshold_metrics(f$fit, f$test, folds = 1:3)),
    "one entry per row"
  )
})

test_that("plotROC and plotThreshold return ggplot objects", {
  f <- eval_fixture()

  expect_s3_class(plotROC(f$fit, f$test), "ggplot")
  expect_s3_class(plotThreshold(f$fit, f$test), "ggplot")
})

test_that("plotThreshold refuses a metric it does not have", {
  f <- eval_fixture()

  expect_error(plotThreshold(f$fit, f$test, metrics = "kappa"),
               "Unknown metric requested")
})

test_that("the marked threshold is the one maximising TSS", {
  f <- eval_fixture()
  m <- threshold_metrics(f$fit, f$test)
  finite <- m[is.finite(m$.threshold), ]

  best <- best_thresholds(m, grouped = FALSE)

  expect_equal(best$.threshold, finite$.threshold[which.max(finite$.tss)])
})

test_that("the AUC label reports a range across folds, not just a mean", {
  # A mean hides a fold that failed behind ones that did not.
  expect_match(auc_label(0.8412), "AUC = 0.841")
  expect_match(auc_label(c(0.8, 0.9)), "across 2 folds")
  expect_match(auc_label(c(0.8, 0.9)), "0.800-0.900")
})

test_that("GAMs are evaluated the same way as anything else", {
  d <- make_eval_data()
  fit <- mgcv::gam(y ~ s(x1) + s(x2), data = d[1:300, ], family = binomial)

  m <- threshold_metrics(fit, d[301:600, ])

  expect_gt(attr(m, "auc"), 0.5)
  expect_false(attr(m, "in.sample"))
})
