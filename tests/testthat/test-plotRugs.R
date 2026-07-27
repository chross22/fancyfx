test_that("plotRugs returns a ggplot object", {
  dat <- data.frame(x = c(1, 2, 3, 4, 5))
  p <- plotRugs(dat, "x")
  expect_s3_class(p, "ggplot")
})

test_that("plotRugs builds without error for every valid transform", {
  dat <- data.frame(x = c(1, 2, 3, 4, 5))
  for (tr in c("none", "log", "log10", "sqrt")) {
    expect_no_error(ggplot2::ggplot_build(plotRugs(dat, "x", tr)))
  }
})

test_that("plotRugs errors on an unknown transform", {
  # aes() is lazy -- switch() inside it isn't evaluated until the plot is
  # actually built, so we must force that with ggplot_build() to trigger
  # the stop() branch.
  dat <- data.frame(x = c(1, 2, 3, 4, 5))
  expect_error(
    ggplot2::ggplot_build(plotRugs(dat, "x", "invalid")),
    "Unknown transformation requested"
  )
})

test_that("plotRugs applies the correct transform to the mapped variable", {
  dat <- data.frame(x = c(1, 10, 100))

  p_none  <- plotRugs(dat, "x", "none")
  p_log   <- plotRugs(dat, "x", "log")
  p_log10 <- plotRugs(dat, "x", "log10")
  p_sqrt  <- plotRugs(dat, "x", "sqrt")

  mapped_none  <- rlang::eval_tidy(p_none$layers[[1]]$mapping$x, dat)
  mapped_log   <- rlang::eval_tidy(p_log$layers[[1]]$mapping$x, dat)
  mapped_log10 <- rlang::eval_tidy(p_log10$layers[[1]]$mapping$x, dat)
  mapped_sqrt  <- rlang::eval_tidy(p_sqrt$layers[[1]]$mapping$x, dat)

  expect_equal(mapped_none, dat$x)
  expect_equal(mapped_log, log(dat$x))
  expect_equal(mapped_log10, log10(dat$x))
  expect_equal(mapped_sqrt, sqrt(dat$x))
})

test_that("plotRugs defaults to 'none' when transform is not supplied", {
  dat <- data.frame(x = c(1, 10, 100))
  p_default <- plotRugs(dat, "x")
  mapped_default <- rlang::eval_tidy(p_default$layers[[1]]$mapping$x, dat)
  expect_equal(mapped_default, dat$x)
})
