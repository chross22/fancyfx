# Spatial projection plots. terra is a Suggests, so every test that touches a
# raster has to survive its absence.

skip_if_no_terra <- function() skip_if_not_installed("terra")

# A small domain with real structure rather than noise: temperature falls to
# the north, depth increases offshore, and the "survey" covers only the
# north-west. That makes the south-east genuinely novel, which is what the
# extrapolation surface should find.
spatial_fixture <- function() {
  set.seed(1)
  grid <- terra::rast(nrows = 30, ncols = 40, xmin = -71, xmax = -65,
                      ymin = 41, ymax = 45, crs = "EPSG:4326")
  lon <- terra::init(grid, "x")
  lat <- terra::init(grid, "y")

  sst <- 14 - 1.2 * (lat - 41) + 0.3 * (lon + 71)
  names(sst) <- "sst"
  depth <- 20 + 30 * (lon + 71) + 25 * (45 - lat)
  names(depth) <- "depth"
  covariates <- c(sst, depth)

  points <- data.frame(lon = runif(200, -71, -67.5), lat = runif(200, 42, 45))
  training <- cbind(points,
                    terra::extract(covariates, points[, c("lon", "lat")],
                                   ID = FALSE))
  training$y <- rbinom(200, 1, plogis(-4 + 0.45 * training$sst -
                                        0.01 * training$depth))

  ensemble <- terra::rast(lapply(1:4, function(i) {
    layer <- terra::init(grid, "x")
    terra::values(layer) <- plogis(terra::values(layer) + i / 4 +
                                     rnorm(terra::ncell(grid), 0, 0.1))
    layer
  }))
  names(ensemble) <- paste0("member", 1:4)

  list(covariates = covariates, training = training, ensemble = ensemble,
       grid = grid)
}

# ── ensemble_summary ──────────────────────────────────────────────────────────

test_that("ensemble_summary returns one layer per statistic asked for", {
  skip_if_no_terra()
  f <- spatial_fixture()

  for (statistic in c("sd", "cv", "range", "iqr", "mean", "median")) {
    out <- ensemble_summary(f$ensemble, statistic)
    expect_s4_class(out, "SpatRaster")
    expect_equal(terra::nlyr(out), 1)
    expect_equal(names(out), statistic)
  }
})

test_that("the spread statistics agree with computing them by hand", {
  skip_if_no_terra()
  f <- spatial_fixture()
  members <- terra::values(f$ensemble)

  expect_equal(as.numeric(terra::values(ensemble_summary(f$ensemble, "sd"))),
               apply(members, 1, stats::sd))
  expect_equal(as.numeric(terra::values(ensemble_summary(f$ensemble, "mean"))),
               apply(members, 1, mean))
  expect_equal(as.numeric(terra::values(ensemble_summary(f$ensemble, "range"))),
               apply(members, 1, function(v) diff(range(v))))
})

test_that("a single-layer raster is refused, having no spread to report", {
  skip_if_no_terra()
  f <- spatial_fixture()

  expect_error(ensemble_summary(f$ensemble[[1]], "sd"), "at least two layers")
})

test_that("a coefficient of variation about zero is dropped, not returned as Inf", {
  # Otherwise the map is dominated by cells where the members happened to
  # average out, which is not the same as cells where they disagreed wildly.
  skip_if_no_terra()
  r <- terra::rast(nrows = 4, ncols = 4, vals = c(rep(0, 8), rep(1, 8)))
  ensemble <- c(r, -r)

  out <- terra::values(ensemble_summary(ensemble, "cv"))

  expect_false(any(is.infinite(out)))
  expect_true(any(is.na(out)))
})

test_that("na.rm defaults to FALSE, so a gap in the ensemble stays visible", {
  # Summarising the members that remain reports a narrower uncertainty exactly
  # where the ensemble is least complete.
  skip_if_no_terra()
  r <- terra::rast(nrows = 3, ncols = 3, vals = 1:9)
  gappy <- r
  terra::values(gappy)[1] <- NA
  ensemble <- c(r, gappy, r * 2)

  expect_true(is.na(terra::values(ensemble_summary(ensemble, "sd"))[1]))
  expect_false(is.na(terra::values(ensemble_summary(ensemble, "sd",
                                                    na.rm = TRUE))[1]))
})

test_that("ensemble_summary refuses things that are not rasters", {
  skip_if_no_terra()

  expect_error(ensemble_summary(data.frame(a = 1), "sd"), "must be a SpatRaster")
  expect_error(ensemble_summary(spatial_fixture()$ensemble, "variance"),
               "Unknown statistic requested")
})

# ── MESS ──────────────────────────────────────────────────────────────────────

test_that("mess_similarity matches the definition at known points", {
  # 100 at the median, 0 at either end of the training range, negative beyond,
  # and symmetric about the median for symmetric quantiles.
  reference <- 1:100

  expect_equal(mess_similarity(50.5, reference), 100)
  expect_lt(mess_similarity(0, reference), 0)
  expect_lt(mess_similarity(101, reference), 0)

  # The 25th and 75th percentiles are equally far from the median, so equally
  # similar: 2 * 25 on one side, 200 - 2 * 75 on the other.
  expect_equal(mess_similarity(25, reference), 50)
  expect_equal(mess_similarity(75, reference), 50)
  expect_lte(max(mess_similarity(reference, reference)), 100)
})

test_that("mess scores are never above 100", {
  set.seed(1)
  reference <- rnorm(500)
  expect_lte(max(mess_similarity(rnorm(500), reference)), 100)
})

test_that("mess flags the part of the domain the survey never visited", {
  # The fixture surveys only the north-west, so the south-east should be novel.
  skip_if_no_terra()
  f <- spatial_fixture()

  surface <- mess(f$covariates, f$training)

  expect_s4_class(surface, "SpatRaster")
  expect_equal(names(surface), "mess")
  expect_true(any(terra::values(surface) < 0, na.rm = TRUE))

  # Novelty should concentrate in the south-east corner rather than scatter.
  frame <- terra::as.data.frame(surface, xy = TRUE, na.rm = TRUE)
  novel <- frame[frame$mess < 0, ]
  expect_gt(mean(novel$x), mean(frame$x))
  expect_lt(mean(novel$y), mean(frame$y))
})

test_that("mess takes its training values from a fitted model too", {
  skip_if_no_terra()
  f <- spatial_fixture()
  fit <- mgcv::gam(y ~ s(sst) + s(depth), data = f$training,
                   family = binomial)

  from.model <- mess(f$covariates, fit)
  from.frame <- mess(f$covariates, f$training)

  expect_equal(terra::values(from.model), terra::values(from.frame))
})

test_that("mess reports what it cannot match", {
  skip_if_no_terra()
  f <- spatial_fixture()

  expect_error(mess(f$covariates, data.frame(nothing = 1:10)),
               "No covariates in common")
  expect_error(mess(f$covariates, f$training, vars = "salinity"),
               "no layer\\(s\\): salinity")
  expect_error(mess(data.frame(a = 1), f$training), "must be a SpatRaster")
})

test_that("a constant covariate does not divide by a zero range", {
  skip_if_no_terra()
  constant <- terra::rast(nrows = 4, ncols = 4, vals = 5)
  names(constant) <- "flat"

  out <- terra::values(mess(constant, data.frame(flat = rep(5, 20))))

  expect_false(any(is.nan(out)))
})

# ── Plots ─────────────────────────────────────────────────────────────────────

test_that("plotUncertainty and plotExtrapolation return ggplot objects", {
  skip_if_no_terra()
  f <- spatial_fixture()

  expect_s3_class(plotUncertainty(f$ensemble), "ggplot")
  expect_s3_class(plotExtrapolation(f$covariates, f$training), "ggplot")
})

test_that("an already-summarised raster is drawn as given", {
  skip_if_no_terra()
  f <- spatial_fixture()
  surface <- mess(f$covariates, f$training)

  expect_s3_class(plotExtrapolation(surface), "ggplot")
  expect_error(plotExtrapolation(f$covariates), "training is required")
})

test_that("novel.only hides everything inside the training range", {
  skip_if_no_terra()
  f <- spatial_fixture()

  p <- plotExtrapolation(f$covariates, f$training, novel.only = TRUE)

  expect_true(all(p$data$.value < 0))
})

test_that("a raster too large to draw is aggregated, and the plot says so", {
  # Silently downsampling would misrepresent the map.
  skip_if_no_terra()
  f <- spatial_fixture()

  reduced <- downsample_raster(f$grid, max.cells = 100)
  expect_gt(reduced$factor, 1)
  expect_lte(terra::ncell(reduced$raster), terra::ncell(f$grid))

  p <- plotUncertainty(f$ensemble, max.cells = 100)
  expect_match(p$labels$subtitle, "Aggregated")

  # Below the ceiling, nothing is touched and nothing is claimed.
  expect_equal(downsample_raster(f$grid, max.cells = 1e6)$factor, 1)
  expect_null(plotUncertainty(f$ensemble, max.cells = 1e6)$labels$subtitle)
})

test_that("an unprojected map is not stretched east-west", {
  # A degree of longitude is shorter than a degree of latitude away from the
  # equator, so ratio 1 would distort the map.
  skip_if_no_terra()
  f <- spatial_fixture()

  expect_gt(map_aspect(f$grid), 1)

  projected <- f$grid
  terra::crs(projected) <- "EPSG:32619"
  expect_equal(map_aspect(projected), 1)
})

test_that("plot arguments are validated", {
  skip_if_no_terra()
  f <- spatial_fixture()

  expect_error(plotUncertainty(f$ensemble, statistic = "variance"),
               "Unknown statistic requested")
  expect_error(plotUncertainty(data.frame(a = 1)), "must be a SpatRaster")
  expect_error(plotUncertainty(f$ensemble, max.cells = 0),
               "single positive number")
})

test_that("an all-missing raster is refused rather than drawn empty", {
  skip_if_no_terra()
  empty <- terra::rast(nrows = 4, ncols = 4, vals = NA_real_)

  expect_error(plotUncertainty(c(empty, empty)), "every cell is missing")
})

test_that("spread_label names the statistic on the legend", {
  expect_equal(spread_label("sd"), "Ensemble SD")
  expect_equal(spread_label("cv"), "Ensemble CV")
})
