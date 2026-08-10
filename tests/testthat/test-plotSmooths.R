# plotSmooths() is the deprecated ancestor of plotEffects(). What matters now
# is that it still works and that it says it is going away -- the substantive
# plotting behaviour is covered in test-plotEffects.R.

test_that("plotSmooths warns that it is deprecated and points at the replacement", {
  # The guard fires once per session, so clear it or an earlier test may have
  # already used up the one warning.
  reset_notices()

  expect_warning(plotSmooths(make_test_gam(), test_data(), "x1"),
                 "plotSmooths\\(\\) is deprecated")

  reset_notices()
  expect_warning(plotSmooths(make_test_gam(), test_data(), "x1"),
                 "Use plotEffects\\(\\)")
})

test_that("plotSmooths warns only once per session", {
  # Warning on every call would make a loop over variables unreadable.
  reset_notices()
  suppress_deprecation(plotSmooths(make_test_gam(), test_data(), "x1"))

  expect_no_warning(plotSmooths(make_test_gam(), test_data(), "x1"))
})

test_that("plotSmooths still returns the plot it always did", {
  dat <- test_data()
  model <- make_test_gam()

  old <- suppress_deprecation(plotSmooths(model, dat, "x1", xlab = "X1"))
  new <- plotEffects(model, dat, "x1", xlab = "X1")

  expect_s3_class(old, "patchwork")
  # Same defaults, same quantity, same data underneath.
  expect_equal(effect_panel(old)$labels, effect_panel(new)$labels)
  expect_equal(effect_panel(old)$data, effect_panel(new)$data)
})

test_that("plotSmooths still forwards its arguments", {
  dat <- test_data()
  model <- make_test_gam()

  p <- suppress_deprecation(
    plotSmooths(model, dat, "x1", xlab = "My X", ylab = "My Y")
  )
  expect_equal(effect_panel(p)$labels$x, "My X")
  expect_equal(effect_panel(p)$labels$y, "My Y")

  expect_error(suppress_deprecation(
    plotSmooths(model, dat, "x1", rug.type = "violin")
  ), "Unknown type requested")
})
