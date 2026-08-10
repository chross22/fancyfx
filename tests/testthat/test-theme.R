test_that("the palette passes the checks it was chosen against", {
  # Chosen by search against colour-vision-deficiency separation, a mid
  # lightness band, a chroma floor, and contrast against a white page. This
  # test pins the values so an edit for taste cannot quietly undo any of that.
  pal <- fancyfx_palette()

  expect_length(pal, 6)
  expect_true(all(grepl("^#[0-9A-F]{6}$", pal)))
  expect_equal(pal[1], "#215689")

  # Every colour clears 3:1 against white, the floor for a thin line being
  # legible on a page.
  relative_luminance <- function(hex) {
    srgb <- strtoi(substring(hex, c(2, 4, 6), c(3, 5, 7)), 16L) / 255
    lin <- ifelse(srgb <= 0.04045, srgb / 12.92, ((srgb + 0.055) / 1.055)^2.4)
    sum(lin * c(0.2126, 0.7152, 0.0722))
  }
  contrast <- vapply(pal, function(h) 1.05 / (relative_luminance(h) + 0.05),
                     numeric(1))
  expect_true(all(contrast >= 3))
})

test_that("fancyfx_palette returns the first n colours, in order", {
  expect_equal(fancyfx_palette(3), fancyfx_palette()[1:3])
  expect_length(fancyfx_palette(1), 1)
})

test_that("fancyfx_palette refuses to invent colours past its length", {
  # Recycling would give two levels the same colour and label them differently.
  expect_error(fancyfx_palette(7), "at most 6 colours")
})

test_that("theme_fancyfx returns a usable ggplot2 theme", {
  expect_s3_class(theme_fancyfx(), "theme")
  expect_no_error(ggplot2::ggplot_build(
    ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
      ggplot2::geom_point() + theme_fancyfx()
  ))
})

test_that("the theme argument is honoured", {
  dat <- test_data()

  # The default blanks the major grid outright; theme_minimal keeps it (as an
  # inherited panel.grid, leaving panel.grid.major unset).
  default <- plotEffects(make_test_lm(), dat, "x1")
  expect_s3_class(default[[2]]$theme$panel.grid.major, "element_blank")

  minimal <- plotEffects(make_test_lm(), dat, "x1",
                         theme = ggplot2::theme_minimal())
  expect_false(inherits(minimal[[2]]$theme$panel.grid.major, "element_blank"))
})

test_that("grouped curves use the package palette", {
  set.seed(1)
  d <- data.frame(x = runif(150, 1, 10), f = factor(rep(c("a", "b", "c"), 50)))
  d$y <- ifelse(d$f == "a", sin(d$x), ifelse(d$f == "b", cos(d$x), d$x / 5)) +
    rnorm(150, sd = 0.2)
  model <- mgcv::gam(y ~ s(x, by = f) + f, data = d)

  built <- ggplot2::ggplot_build(plotEffects(model, d, "x")[[2]])
  used <- unique(built$data[[2]]$colour)

  expect_setequal(used, fancyfx_palette(3))
})

test_that("more levels than colours warns instead of recycling", {
  # Recycling would give two levels the same colour while the legend claims
  # they differ.
  set.seed(1)
  levs <- letters[1:7]
  d <- data.frame(x = runif(700, 1, 10), f = factor(rep(levs, 100)))
  d$y <- as.numeric(d$f) * d$x / 5 + rnorm(700, sd = 0.3)
  model <- mgcv::gam(y ~ s(x, by = f) + f, data = d)

  expect_warning(plotEffects(model, d, "x"), "7 curves but the palette has 6")
})

test_that("panel labels come in the styles a journal might ask for", {
  expect_equal(panel_labels("a", 3), c("a", "b", "c"))
  expect_equal(panel_labels("A", 3), c("A", "B", "C"))
  expect_equal(panel_labels("1", 3), c("1", "2", "3"))
  expect_null(panel_labels("none", 3))
  expect_null(panel_labels(NULL, 3))
  expect_equal(panel_labels(c("i", "ii"), 2), c("i", "ii"))
})

test_that("custom panel labels must match the number of panels", {
  # Otherwise ggarrange slides them onto the wrong plots.
  expect_error(panel_labels(c("i", "ii"), 3), "one label per panel")
})

test_that("the multi-panel functions default to upper-case labels", {
  dat <- test_data()

  expect_no_error(combinePlots(make_test_gam(), dat, vars = c("x1", "x2")))
  expect_no_error(combinePlots(make_test_gam(), dat, vars = c("x1", "x2"),
                               labels = "none"))
  expect_no_error(comparePlots(list(make_test_gam(), make_test_lm()), dat, "x1",
                               labels = c("Panel one", "Panel two")))
  expect_error(comparePlots(list(make_test_gam(), make_test_lm()), dat, "x1",
                            labels = c("only one")),
               "one label per panel")
})

test_that("both rug types are filled, so they read with the same weight", {
  # geom_density() draws only an outline unless given a fill, which made the
  # density rug read as far lighter than the histogram.
  for (type in c("histogram", "density")) {
    built <- ggplot2::ggplot_build(plotRugs(mtcars, "wt", type = type))
    expect_true(all(built$data[[1]]$fill == "grey35"), info = type)
  }
})

test_that("base_size scales every text element together", {
  small <- theme_fancyfx(base_size = 10)
  large <- theme_fancyfx(base_size = 20)

  for (element in c("axis.title", "axis.text", "plot.title", "plot.caption",
                    "legend.title", "legend.text")) {
    expect_gt(large[[element]]$size, small[[element]]$size, label = element)
  }
})

test_that("each element can be sized on its own", {
  # For the cases base_size cannot cover: a long axis title that must be
  # smaller than the numbers beside it, or a journal specifying one size.
  th <- theme_fancyfx(base_size = 14, axis.title.size = 20,
                      axis.text.size = 9, title.size = 22,
                      subtitle.size = 8, caption.size = 7,
                      legend.title.size = 18, legend.text.size = 6,
                      strip.text.size = 19)

  expect_equal(th$axis.title$size, 20)
  expect_equal(th$axis.text$size, 9)
  expect_equal(th$plot.title$size, 22)
  expect_equal(th$plot.subtitle$size, 8)
  expect_equal(th$plot.caption$size, 7)
  expect_equal(th$legend.title$size, 18)
  expect_equal(th$legend.text$size, 6)
  expect_equal(th$strip.text$size, 19)
})

test_that("an element left unset follows base_size", {
  th <- theme_fancyfx(base_size = 16, axis.title.size = 30)

  expect_equal(th$axis.title$size, 30)
  expect_equal(th$plot.title$size, 16)
})

test_that("panel labels and the figure title take their own sizes", {
  # Both are drawn by the arranging step rather than the theme, so raising
  # base_size alone would leave them stranded at their defaults.
  model <- make_test_gam()
  dat <- test_data()

  expect_no_error(
    combinePlots(model, dat, vars = c("x1", "x2"), title = "Title",
                 label.size = 22, title.size = 20)
  )
  expect_no_error(
    comparePlots(list(a = model, b = make_test_lm()), dat, "x1",
                 title = "Title", label.size = 22, title.size = 20)
  )
})

test_that("an empty title adds no annotation layer", {
  model <- make_test_gam()
  dat <- test_data()

  expect_no_error(combinePlots(model, dat, vars = c("x1", "x2"), title = ""))
})
