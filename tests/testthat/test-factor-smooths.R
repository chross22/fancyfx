# A factor-smooth interaction, s(x, by = f), is one smooth per level of f, and
# gratia returns them stacked in a single frame. Treated as one curve they get
# joined end to end into a zigzag that looks like a single wildly varying
# smooth -- which is what this package did before the .group column existed.

make_factor_smooth_data <- function() {
  set.seed(1)
  d <- data.frame(x = runif(300, 1, 10),
                  f = factor(rep(c("a", "b", "c"), 100)))
  d$y <- ifelse(d$f == "a", sin(d$x),
                ifelse(d$f == "b", cos(d$x), d$x / 5)) + rnorm(300, sd = 0.2)
  d
}

make_factor_smooth_gam <- function() {
  mgcv::gam(y ~ s(x, by = f) + f, data = make_factor_smooth_data())
}

test_that("a factor-smooth interaction comes back as separate curves", {
  est <- effect_estimates(make_factor_smooth_gam(), "x")

  expect_true(".group" %in% names(est))
  expect_setequal(levels(est$.group), c("a", "b", "c"))
  # One row per level per evaluation point, not one flattened curve.
  expect_equal(nrow(est), 300)
})

test_that("estimates are sorted within each curve, not across them", {
  # Sorting the whole frame by .x would interleave the three smooths and
  # geom_line() would draw a zigzag between them.
  est <- effect_estimates(make_factor_smooth_gam(), "x")

  by.group <- split(est$.x, est$.group)
  expect_true(all(vapply(by.group, function(z) !is.unsorted(z), logical(1))))
})

test_that("the grouping factor's own name is carried through for the legend", {
  est <- effect_estimates(make_factor_smooth_gam(), "x")
  expect_equal(attr(est, "group.label"), "f")

  p <- plotEffects(make_factor_smooth_gam(), make_factor_smooth_data(), "x")
  expect_equal(p[[2]]$labels$colour, "f")
})

test_that("group.lab overrides the legend title", {
  p <- plotEffects(make_factor_smooth_gam(), make_factor_smooth_data(), "x",
                   group.lab = "Treatment")

  expect_equal(p[[2]]$labels$colour, "Treatment")
})

test_that("the curves are mapped to colour so they are drawn separately", {
  p <- plotEffects(make_factor_smooth_gam(), make_factor_smooth_data(), "x")
  mapping <- p[[2]]$mapping

  expect_true("colour" %in% names(mapping))
  expect_true("group" %in% names(mapping))
})

test_that("an ordinary smooth gains no grouping column", {
  # The grouped path must not switch on for models that have no by-variable.
  est <- effect_estimates(make_test_gam(), "x1")

  expect_false(".group" %in% names(est))
  expect_null(attr(est, "group.label"))

  p <- plotEffects(make_test_gam(), test_data(), "x1")
  expect_false("colour" %in% names(p[[2]]$mapping))
})

test_that("factor smooths survive the multi-panel wrappers", {
  dat <- make_factor_smooth_data()
  model <- make_factor_smooth_gam()

  expect_no_error(combinePlots(model, dat, vars = "x"))
  expect_no_error(
    comparePlots(list(plain = mgcv::gam(y ~ s(x), data = dat),
                      by.factor = model),
                 dat, "x")
  )
})
