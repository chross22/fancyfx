# Shared fixtures. These used to be redefined per test file under the same
# name with different return shapes, and testthat sources every file into one
# environment -- so whichever loaded last silently won. Defined once here
# instead.
#
# Kept cheap and deterministic (fixed seed, small n) so tests run fast and
# consistently.

test_data <- function() {
  set.seed(1)
  dat <- data.frame(x1 = runif(100, 1, 10), x2 = runif(100, 1, 10))
  dat$y <- sin(dat$x1) + cos(dat$x2) + rnorm(100, sd = 0.1)
  dat$bin <- rbinom(100, 1, plogis(dat$x1 - 5))
  dat
}

make_test_gam <- function() {
  mgcv::gam(y ~ s(x1) + s(x2), data = test_data())
}

make_test_lm <- function() {
  lm(y ~ x1 + x2, data = test_data())
}

make_test_glm <- function() {
  glm(bin ~ x1 + x2, data = test_data(), family = binomial)
}

# plotEffects() returns a rug stacked above an effect curve. The curve is the
# panel carrying the labels and the mapping.
effect_panel <- function(p) p[[2]]

# plotSmooths() is deprecated and warns once per session; tests that call it
# for reasons other than checking the warning use this to stay quiet.
suppress_deprecation <- function(expr) {
  withCallingHandlers(expr, warning = function(w) {
    if (grepl("deprecated", conditionMessage(w))) invokeRestart("muffleWarning")
  })
}
