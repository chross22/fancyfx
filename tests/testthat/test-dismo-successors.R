# Four things that did not survive dismo's migration to predicts. All are
# implemented here from their published definitions rather than from dismo's
# source, which is GPL-3 where this package is MIT.

# ── Spatial sorting bias ──────────────────────────────────────────────────────

test_that("an unbiased split scores 1 and a biased one scores near 0", {
  # The statistic is the ratio of two mean nearest-neighbour distances, so a
  # split whose presences and absences are equally far from training scores 1.
  set.seed(1)
  training <- cbind(runif(150, 0, 10), runif(150, 0, 10))
  background <- cbind(runif(60, 0, 40), runif(60, 0, 40))

  # Presences and absences drawn identically: no sorting bias by construction.
  expect_equal(spatial_sorting_bias(background, background, training)[["ssb"]],
               1)

  # Presences on top of the training data, absences far away.
  near <- cbind(runif(60, 0, 10), runif(60, 0, 10))
  far <- cbind(runif(60, 30, 40), runif(60, 30, 40))
  expect_lt(spatial_sorting_bias(near, far, training)[["ssb"]], 0.1)
})

test_that("spatial_sorting_bias reports the distances it divided", {
  set.seed(1)
  training <- cbind(runif(100, 0, 10), runif(100, 0, 10))
  presence <- cbind(runif(40, 0, 10), runif(40, 0, 10))
  absence <- cbind(runif(40, 0, 40), runif(40, 0, 40))

  result <- spatial_sorting_bias(presence, absence, training)

  expect_named(result, c("presence", "absence", "ssb"))
  expect_equal(unname(result[["presence"]] / result[["absence"]]),
               unname(result[["ssb"]]))
})

test_that("great-circle distances are used when asked for", {
  # One degree of latitude is about 111 km.
  expect_equal(haversine(0, 0, 0, 1), 111.19, tolerance = 1e-3)
  # Longitude shortens with latitude: the same degree is shorter at 60 N.
  expect_lt(haversine(0, 60, 1, 60), haversine(0, 0, 1, 0))
})

test_that("nearest_distance finds the nearest, not the first", {
  points <- cbind(0, 0)
  reference <- cbind(c(10, 3, 7), c(0, 0, 0))

  expect_equal(nearest_distance(points, reference), 3)
})

test_that("coordinates are accepted as a matrix or a data frame", {
  as.matrix.input <- cbind(c(1, 2), c(3, 4))
  as.frame <- data.frame(x = c(1, 2), y = c(3, 4))
  as.lonlat <- data.frame(lon = c(1, 2), lat = c(3, 4))

  expect_equal(coordinate_matrix(as.frame, "p"), coordinate_matrix(as.matrix.input, "p"),
               ignore_attr = TRUE)
  expect_equal(coordinate_matrix(as.lonlat, "p"), coordinate_matrix(as.matrix.input, "p"),
               ignore_attr = TRUE)
  expect_error(coordinate_matrix(data.frame(x = 1), "p"), "two coordinate columns")
})

# ── Thinning ──────────────────────────────────────────────────────────────────

test_that("thinning caps the number of points per cell", {
  set.seed(1)
  # Heavily oversampled in one corner, as uneven survey effort produces.
  records <- data.frame(x = c(runif(400, 0, 2), runif(100, 0, 10)),
                        y = c(runif(400, 0, 2), runif(100, 0, 10)))

  thinned <- thin_points(records, n = 1, bins = 10)

  expect_lt(nrow(thinned), nrow(records))
  expect_gt(nrow(thin_points(records, n = 3, bins = 10)), nrow(thinned))
  # Rows come back as they were, not reordered or rebuilt.
  expect_true(all(rownames(thinned) %in% rownames(records)))
  expect_equal(names(thinned), names(records))
})

test_that("thinning really does leave at most n per cell", {
  set.seed(1)
  records <- data.frame(x = runif(500, 0, 10), y = runif(500, 0, 10))

  thinned <- thin_points(records, n = 2, bins = 8)
  size <- hex_size(records$x, 8, NULL)
  index <- hex_assign(thinned$x, thinned$y, size)

  expect_lte(max(table(paste(index$q, index$r))), 2)
})

test_that("both lattices work and thinning is reproducible", {
  set.seed(1)
  records <- data.frame(x = runif(300, 0, 10), y = runif(300, 0, 10))

  expect_equal(thin_points(records, bins = 8, type = "hex"),
               thin_points(records, bins = 8, type = "hex"))
  expect_no_error(thin_points(records, bins = 8, type = "grid"))
  expect_error(thin_points(records, type = "triangle"), "Unknown type")
  expect_error(thin_points(records, n = 0), "at least 1")
  expect_error(thin_points("nope"), "must be a data frame")
})

test_that("thinning leaves the caller's random stream alone", {
  set.seed(1)
  records <- data.frame(x = runif(200, 0, 10), y = runif(200, 0, 10))

  set.seed(99)
  invisible(runif(1))
  state <- .Random.seed
  invisible(thin_points(records, bins = 5))

  expect_identical(.Random.seed, state)
})

# ── Niche overlap ─────────────────────────────────────────────────────────────

test_that("overlap is 1 for identical surfaces and 0 for disjoint ones", {
  set.seed(1)
  surface <- runif(400)

  expect_equal(unname(niche_overlap(surface, surface)), c(1, 1))

  grid <- seq(0, 20, length.out = 200)
  left <- stats::dnorm(grid, 5, 1)
  right <- stats::dnorm(grid, 15, 1)
  expect_lt(niche_overlap(left, right, "D"), 0.001)
})

test_that("overlap compares shape, not level", {
  # Both surfaces are rescaled to sum to 1, so a uniformly higher one still
  # overlaps perfectly.
  set.seed(1)
  a <- runif(300)
  b <- a * 0.8 + runif(300) * 0.2

  expect_equal(niche_overlap(a, b), niche_overlap(a * 10, b))
  expect_equal(niche_overlap(a, a * 5), niche_overlap(a, a))
})

test_that("D and I are both bounded, with I the less twitchy of the two", {
  set.seed(1)
  a <- runif(300)
  b <- runif(300)
  both <- niche_overlap(a, b)

  expect_named(both, c("D", "I"))
  expect_true(all(both >= 0 & both <= 1))
  # I works on square roots, so a scatter of sharp disagreements moves it less.
  expect_gte(both[["I"]], both[["D"]])
})

test_that("mismatched missingness is refused unless allowed explicitly", {
  a <- c(1, 2, NA, 4)
  b <- c(1, 2, 3, 4)

  expect_error(niche_overlap(a, b), "missing in different places")
  expect_no_error(niche_overlap(a, b, na.rm = TRUE))
})

test_that("niche_overlap validates its inputs", {
  expect_error(niche_overlap(1:3, 1:4), "same length")
  expect_error(niche_overlap(c(-1, 1), c(1, 1)), "non-negative")
  expect_error(niche_overlap(1:3, 1:3, statistic = "J"), "Unknown statistic")
})

test_that("rasters must share a geometry to be compared", {
  skip_if_not_installed("terra")
  a <- terra::rast(nrows = 10, ncols = 10, vals = runif(100))
  b <- terra::rast(nrows = 5, ncols = 5, vals = runif(25))

  expect_error(niche_overlap(a, b), "do not share a geometry")
  expect_equal(unname(niche_overlap(a, a)), c(1, 1))
  expect_error(niche_overlap(a, runif(100)), "or neither")
})

test_that("the equivalency test separates different niches from identical ones", {
  set.seed(1)
  grid <- seq(0, 20, length.out = 50)
  fit_density <- function(occurrence) {
    stats::dnorm(grid, mean(occurrence$temp), stats::sd(occurrence$temp))
  }

  cold <- data.frame(temp = rnorm(60, 8, 1.5))
  warm <- data.frame(temp = rnorm(60, 14, 1.5))
  also.cold <- data.frame(temp = rnorm(60, 8, 1.5))

  different <- niche_equivalency(cold, warm, fit_density, n.rep = 49)
  same <- niche_equivalency(cold, also.cold, fit_density, n.rep = 49)

  expect_lt(different$observed, stats::median(different$null))
  expect_lt(different$p.value, 0.05)
  expect_gt(same$p.value, 0.05)
})

test_that("the p-value cannot be zero, since the observation counts itself", {
  # Reporting less than 1 / (n.rep + 1) would be precision the test does not
  # have.
  set.seed(1)
  grid <- seq(0, 20, length.out = 30)
  fit_density <- function(o) stats::dnorm(grid, mean(o$temp), stats::sd(o$temp))

  result <- niche_equivalency(data.frame(temp = rnorm(40, 5)),
                              data.frame(temp = rnorm(40, 15)),
                              fit_density, n.rep = 9)

  expect_gte(result$p.value, 1 / 10)
  expect_length(result$null, 9)
})

test_that("niche_equivalency validates its inputs", {
  expect_error(niche_equivalency(data.frame(a = 1), data.frame(a = 2),
                                 fit = "not a function"),
               "must be a function")
  expect_error(niche_equivalency(data.frame(a = 1), data.frame(a = 2),
                                 fit = identity, n.rep = 0),
               "at least 1")
})

# ── Deviance and BRTs ─────────────────────────────────────────────────────────

test_that("binomial deviance agrees with what glm reports", {
  # Checked against stats rather than against a number this package produced.
  set.seed(1)
  d <- data.frame(x = runif(300, 1, 10))
  d$y <- rbinom(300, 1, plogis(-3 + 0.6 * d$x))
  fit <- glm(y ~ x, data = d, family = binomial)

  expect_equal(calc_deviance(d$y, fitted(fit), "binomial", mean = FALSE),
               fit$deviance)
})

test_that("poisson and gaussian deviance agree with glm too", {
  set.seed(1)
  d <- data.frame(x = runif(300, 1, 5))
  d$count <- rpois(300, exp(0.4 * d$x))

  poisson.fit <- glm(count ~ x, data = d, family = poisson)
  expect_equal(calc_deviance(d$count, fitted(poisson.fit), "poisson",
                             mean = FALSE),
               poisson.fit$deviance)

  gaussian.fit <- glm(count ~ x, data = d, family = gaussian)
  expect_equal(calc_deviance(d$count, fitted(gaussian.fit), "gaussian",
                             mean = FALSE),
               gaussian.fit$deviance)
})

test_that("a perfect prediction has zero deviance and a wrong one has more", {
  observed <- c(0, 1, 0, 1)

  expect_equal(calc_deviance(observed, observed, "binomial"), 0,
               tolerance = 1e-6)
  expect_gt(calc_deviance(observed, rep(0.5, 4), "binomial"),
            calc_deviance(observed, c(0.1, 0.9, 0.1, 0.9), "binomial"))
})

test_that("calc_deviance refuses predictions on the wrong scale", {
  # Link-scale values passed as probabilities is an easy and silent mistake.
  expect_error(calc_deviance(c(0, 1), c(-2, 3), "binomial"), "link scale")
  expect_error(calc_deviance(c(0, 1), c(1, 2, 3), "binomial"), "same length")
  expect_error(calc_deviance(c(1, 2), c(-1, 1), "poisson"), "non-negative")
})

test_that("boosted regression trees get partial dependence", {
  # marginaleffects does not support gbm, so this has its own method using
  # gbm's own partial dependence -- the quantity dismo::gbm.plot drew.
  skip_if_not_installed("gbm")
  set.seed(1)
  d <- data.frame(x1 = runif(400, 1, 10), x2 = runif(400, 1, 10))
  d$y <- rbinom(400, 1, plogis(-3 + 0.6 * d$x1))
  fit <- gbm::gbm(y ~ x1 + x2, data = d, distribution = "bernoulli",
                  n.trees = 150, verbose = FALSE)

  est <- suppressMessages(effect_estimates(fit, "x1", n = 20))

  expect_named(est, c(".x", ".estimate", ".lower", ".upper"))
  expect_equal(attr(est, "quantity"), "Partial Dependence")
  # x1 carries the signal, so its partial dependence should rise with it.
  expect_gt(cor(est$.x, est$.estimate), 0.8)
})

test_that("a BRT curve is drawn without an invented uncertainty band", {
  skip_if_not_installed("gbm")
  set.seed(1)
  d <- data.frame(x1 = runif(300, 1, 10))
  d$y <- rbinom(300, 1, plogis(-3 + 0.6 * d$x1))
  fit <- gbm::gbm(y ~ x1, data = d, distribution = "bernoulli",
                  n.trees = 100, verbose = FALSE)

  reset_notices()
  expect_message(effect_estimates(fit, "x1", n = 10), "no analytic standard error")

  est <- suppressMessages(effect_estimates(fit, "x1", n = 10))
  expect_equal(est$.lower, est$.estimate)
  expect_equal(est$.upper, est$.estimate)
})

test_that("an unknown BRT predictor is named in the error", {
  skip_if_not_installed("gbm")
  set.seed(1)
  d <- data.frame(x1 = runif(200, 1, 10))
  d$y <- rbinom(200, 1, plogis(d$x1 - 5))
  fit <- gbm::gbm(y ~ x1, data = d, distribution = "bernoulli",
                  n.trees = 100, verbose = FALSE)

  expect_error(effect_estimates(fit, "nope"), "No predictor 'nope'")
})

test_that("a model that does not keep its data can borrow the plotting data", {
  # model.frame() fails on a gbm, so the predictor's range has to come from
  # the data already passed in for the rug.
  skip_if_not_installed("gbm")
  set.seed(1)
  d <- data.frame(x1 = runif(300, 1, 10))
  d$y <- rbinom(300, 1, plogis(d$x1 - 5))
  fit <- gbm::gbm(y ~ x1, data = d, distribution = "bernoulli",
                  n.trees = 100, verbose = FALSE)

  expect_s3_class(suppressMessages(plotEffects(fit, d, "x1", n = 10)),
                  "patchwork")
})

test_that("mess scores a data frame the same as the raster of the same cells", {
  skip_if_not_installed("terra")
  # The two paths must be one method with two doors. A separate implementation
  # for data frames would be free to drift, and nothing outside would notice.
  set.seed(1)
  training <- data.frame(temp = rnorm(200, 10, 2), depth = runif(200, 0, 100))
  covariates <- c(
    terra::rast(nrows = 10, ncols = 10, vals = rnorm(100, 12, 3)),
    terra::rast(nrows = 10, ncols = 10, vals = runif(100, -20, 140))
  )
  names(covariates) <- c("temp", "depth")

  by_raster <- mess(covariates, training)
  by_frame <- mess(as.data.frame(covariates), training)

  expect_equal(by_frame$mess, as.numeric(terra::values(by_raster)[, 1]))
})

test_that("mess names the covariate that made a cell novel", {
  training <- data.frame(temp = c(4, 8, 12, 16), depth = c(10, 20, 30, 40))
  # Row 1 is ordinary; row 2 is far too warm; row 3 is far too deep.
  cells <- data.frame(temp = c(10, 40, 10), depth = c(25, 25, 400))

  out <- mess(cells, training, limiting = TRUE)

  expect_equal(names(out), c("mess", "mess_variable"))
  expect_gt(out$mess[1], 0)
  expect_lt(out$mess[2], 0)
  expect_lt(out$mess[3], 0)
  expect_equal(out$mess_variable[2], "temp")
  expect_equal(out$mess_variable[3], "depth")
})

test_that("limiting is off by default, so the returned shape is unchanged", {
  training <- data.frame(temp = c(4, 8, 12, 16))
  cells <- data.frame(temp = c(10, 40))

  expect_equal(names(mess(cells, training)), "mess")
  expect_equal(names(mess(cells, training, limiting = TRUE)),
               c("mess", "mess_variable"))
})

test_that("the raster's limiting layer carries the covariate names", {
  skip_if_not_installed("terra")
  set.seed(2)
  training <- data.frame(temp = rnorm(100, 10, 2), depth = runif(100, 0, 100))
  covariates <- c(
    terra::rast(nrows = 8, ncols = 8, vals = rnorm(64, 12, 4)),
    terra::rast(nrows = 8, ncols = 8, vals = runif(64, -40, 160))
  )
  names(covariates) <- c("temp", "depth")

  out <- mess(covariates, training, limiting = TRUE)

  expect_equal(names(out), c("mess", "mess_variable"))
  # A raster cannot hold a character, so the names live in the levels table.
  levels.table <- terra::levels(out[["mess_variable"]])[[1]]
  expect_setequal(levels.table$mess_variable, c("temp", "depth"))
})

test_that("mess on a data frame handles one row and missing values", {
  training <- data.frame(temp = c(4, 8, 12, 16), depth = c(10, 20, 30, 40))

  one <- mess(data.frame(temp = 10, depth = 25), training, limiting = TRUE)
  expect_equal(nrow(one), 1)
  expect_equal(names(one), c("mess", "mess_variable"))

  # A covariate missing for a cell makes that cell unscoreable, not an error.
  gaps <- mess(data.frame(temp = c(10, NA), depth = c(25, 25)), training,
               limiting = TRUE)
  expect_false(is.na(gaps$mess[1]))
  expect_true(is.na(gaps$mess[2]))
})

test_that("mess refuses what it cannot score, and says which side is short", {
  training <- data.frame(temp = c(4, 8, 12))

  expect_error(mess(list(temp = 1), training), "SpatRaster or a data frame")
  expect_error(mess(data.frame(salinity = 30), training),
               "No covariates in common")
  expect_error(mess(data.frame(temp = 10), training, vars = "depth"),
               "Data has no column")
})
