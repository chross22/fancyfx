test_that("plotRugs returns a ggplot object", {
  dat <- data.frame(x = c(1, 2, 3, 4, 5))
  p <- plotRugs(dat, "x")
  expect_s3_class(p, "ggplot")
})

test_that("plotRugs builds without error for every valid transform", {
  dat <- data.frame(x = c(1, 2, 3, 4, 5))
  for (tr in c("none", "log", "log10", "sqrt")) {
    expect_no_error(ggplot2::ggplot_build(plotRugs(dat, "x", transform = tr)))
  }
})

test_that("plotRugs errors on an unknown transform", {
  # The check now runs at call time rather than inside the lazy aes(), so the
  # error arrives before ggplot_build() would have forced it. Kept wrapped so
  # the test still passes either way.
  dat <- data.frame(x = c(1, 2, 3, 4, 5))
  expect_error(
    ggplot2::ggplot_build(plotRugs(dat, "x", transform = "invalid")),
    "Unknown transformation requested"
  )
})

test_that("plotRugs applies the correct transform to the mapped variable", {
  dat <- data.frame(x = c(1, 10, 100))

  p_none  <- plotRugs(dat, "x", transform = "none")
  p_log   <- plotRugs(dat, "x", transform = "log")
  p_log10 <- plotRugs(dat, "x", transform = "log10")
  p_sqrt  <- plotRugs(dat, "x", transform = "sqrt")

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

test_that("an unknown rug type is refused", {
  dat <- data.frame(x = c(1, 2, 3))
  expect_error(plotRugs(dat, "x", type = "violin"), "Unknown type requested")
})

test_that("the histogram sets its bins rather than leaving them to a message", {
  # geom_histogram() emits "using bins = 30" on every plot when bins are not
  # given, which for a multi-panel figure is one message per panel.
  dat <- data.frame(x = rnorm(50))
  expect_silent(p <- plotRugs(dat, "x", bins = 12))
  expect_equal(p$layers[[1]]$stat_params$bins, 12)
})

test_that("a rug can be drawn for a term that is not a column", {
  dat <- data.frame(x = c(1, 10, 100))
  p <- plotRugs(dat, "log10(x)")

  # The evaluated term is carried under its own name, so the mapping is the
  # same expression it would be for a plain column.
  expect_equal(ggplot2::ggplot_build(p)$plot$data[["log10(x)"]], log10(dat$x))
})

test_that("a term that is neither a column nor evaluable says what the data has", {
  dat <- data.frame(x = c(1, 2, 3))
  expect_error(plotRugs(dat, "log10(depth)"), "neither a column")
  expect_error(plotRugs(dat, "log10(depth)"), "x")
})

# Evaluated in the data alone. A term naming a column that is not there must
# not pick up a variable of the same name from the caller and draw a rug of
# something else that happens to be the right length.
test_that("a rug term cannot reach out to the calling environment", {
  dat <- data.frame(x = c(1, 2, 3))
  depth <- c(10, 20, 30)
  expect_error(plotRugs(dat, "log10(depth)"), "neither a column")
})

# A rug drawn in one colour under a factor-smooth interaction reports the whole
# sample's distribution to every curve, when each curve was fitted to one
# level's rows alone. Split, a reader can see which curve the evidence under a
# stretch of x actually belongs to.

test_that("a grouped rug maps fill to the grouping factor", {
  p <- plotRugs(iris, "Sepal.Length", group = "Species")

  expect_true("fill" %in% names(p$layers[[1]]$mapping))
  # Three levels, three colours, and none of them the constant grey an
  # undivided rug is drawn in.
  fills <- unique(ggplot2::ggplot_build(p)$data[[1]]$fill)
  expect_length(fills, 3)
  expect_false("grey35" %in% fills)
})

test_that("a named palette colours each level with its own colour", {
  pal <- stats::setNames(fancyfx_palette(3), levels(iris$Species))
  p <- plotRugs(iris, "Sepal.Length", group = "Species", palette = pal)

  built <- ggplot2::ggplot_build(p)$data[[1]]
  expect_setequal(unique(built$fill), unname(pal))
})

test_that("a level the palette does not name is dropped rather than recoloured", {
  # Otherwise it would be drawn in a colour that belongs to another curve, or
  # in ggplot2's grey for an unmatched level, and read as evidence for it.
  pal <- stats::setNames(fancyfx_palette(2), c("setosa", "versicolor"))
  p <- plotRugs(iris, "Sepal.Length", group = "Species", palette = pal)

  expect_false("virginica" %in% as.character(p$data$Species))
  # The dropped level keeps its place in the scale, so the legend still lists
  # every curve the effect panel draws.
  expect_equal(levels(p$data$Species), names(pal))
})

test_that("an ungrouped rug is unchanged, in the constant fill", {
  built <- ggplot2::ggplot_build(plotRugs(iris, "Sepal.Length"))$data[[1]]
  expect_equal(unique(built$fill), "grey35")
})

test_that("a grouped density rug is stacked on the count scale", {
  # Each level's density integrates to one, so raw stacking would draw a level
  # with a handful of rows as tall a band as one with hundreds.
  d <- rbind(data.frame(x = rnorm(200), f = "many"),
             data.frame(x = rnorm(10), f = "few"))
  p <- plotRugs(d, "x", type = "density", group = "f")

  built <- ggplot2::ggplot_build(p)$data[[1]]
  heights <- tapply(built$ymax - built$ymin, built$group, max)
  expect_gt(max(heights), 5 * min(heights))
})

test_that("a group that is not a column warns and draws the rug undivided", {
  expect_warning(p <- plotRugs(iris, "Sepal.Length", group = "Treatment"),
                 "not a column")
  expect_equal(unique(ggplot2::ggplot_build(p)$data[[1]]$fill), "grey35")
})

test_that("a rug can be split even when the variable is a term", {
  # The evaluated term is added to the data rather than replacing it, so the
  # column being grouped by survives.
  dat <- data.frame(x = c(1, 10, 100, 1000), f = factor(c("a", "a", "b", "b")))
  p <- plotRugs(dat, "log10(x)", group = "f")

  expect_equal(p$data[["log10(x)"]], log10(dat$x))
  expect_true("fill" %in% names(p$layers[[1]]$mapping))
})

test_that("an unnamed palette is assigned in level order", {
  named <- plotRugs(iris, "Sepal.Length", group = "Species",
                    palette = stats::setNames(fancyfx_palette(3),
                                              levels(iris$Species)))
  unnamed <- plotRugs(iris, "Sepal.Length", group = "Species",
                      palette = fancyfx_palette(3))

  expect_equal(ggplot2::ggplot_build(unnamed)$data[[1]]$fill,
               ggplot2::ggplot_build(named)$data[[1]]$fill)
})

test_that("a palette with too few colours warns rather than failing to draw", {
  # Left to the scale this is an error raised at draw time, naming a count of
  # values rather than the argument the colours came from.
  expect_warning(p <- plotRugs(iris, "Sepal.Length", group = "Species",
                               palette = fancyfx_palette(2)),
                 "3 levels but the palette has 2")
  expect_no_error(ggplot2::ggplot_build(p))
})
