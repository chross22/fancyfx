hex_points <- function(n = 2000) {
  set.seed(1)
  d <- data.frame(x = runif(n, 0, 10), y = runif(n, 0, 10))
  # A gradient in x, so the binned summary has a right answer to check.
  d$catch <- d$x + rnorm(n)
  d
}

test_that("every point lands in the hexagon whose centre is nearest to it", {
  # The property that makes the lattice a lattice. Cube rounding is easy to get
  # subtly wrong in a way that still looks like hexagons.
  set.seed(1)
  x <- runif(2000, -50, 50)
  y <- runif(2000, -30, 30)
  size <- 2.5

  index <- hex_assign(x, y, size)
  centre <- hex_centre(index$q, index$r, size)
  assigned <- sqrt((x - centre$x)^2 + (y - centre$y)^2)

  realised <- unique(data.frame(q = index$q, r = index$r))
  candidates <- hex_centre(realised$q, realised$r, size)
  nearest <- apply(cbind(x, y), 1, function(p) {
    min(sqrt((p[1] - candidates$x)^2 + (p[2] - candidates$y)^2))
  })

  expect_equal(assigned, nearest)
  # No point can be further from its centre than the circumradius.
  expect_lte(max(assigned), size)
})

test_that("binning keeps every value exactly once", {
  d <- hex_points()
  binned <- hex_bin(d, value = "catch", bins = 12)

  expect_named(binned, c(".x", ".y", ".value", ".n"))
  expect_equal(sum(binned$.n), nrow(d))
  expect_gt(nrow(binned), 1)
})

test_that("counting agrees with the number of points", {
  d <- hex_points()
  counted <- hex_bin(d, fun = "count", bins = 12)

  expect_equal(sum(counted$.value), nrow(d))
  expect_equal(counted$.value, counted$.n)
})

test_that("the summary tracks the gradient it was built from", {
  d <- hex_points()
  binned <- hex_bin(d, value = "catch", bins = 12)

  expect_gt(cor(binned$.x, binned$.value), 0.8)
})

test_that("each summarising function does what it says", {
  d <- hex_points(500)

  for (fun in c("mean", "median", "sum", "sd", "min", "max")) {
    binned <- hex_bin(d, value = "catch", bins = 6, fun = fun)
    expect_false(anyNA(binned$.value), info = fun)
  }

  # Checked against the raw values in one bin, chosen by re-deriving the
  # assignment rather than trusting the function under test.
  binned <- hex_bin(d, value = "catch", bins = 6, fun = "max")
  size <- attr(binned, "cellsize")
  index <- hex_assign(d$x, d$y, size)
  centre <- hex_centre(index$q, index$r, size)
  first <- which(abs(centre$x - binned$.x[1]) < 1e-8 &
                   abs(centre$y - binned$.y[1]) < 1e-8)

  expect_equal(binned$.value[1], max(d$catch[first]))
})

test_that("min.n drops thinly populated hexagons", {
  # One observation is not a summary of anything, and on a map it is
  # indistinguishable from a thousand.
  d <- hex_points(3000)

  expect_lt(nrow(hex_bin(d, value = "catch", bins = 10, min.n = 25)),
            nrow(hex_bin(d, value = "catch", bins = 10)))
  expect_true(all(hex_bin(d, value = "catch", bins = 10, min.n = 25)$.n >= 25))
})

test_that("an impossible min.n says so rather than returning nothing", {
  d <- hex_points(200)

  expect_error(hex_bin(d, value = "catch", bins = 10, min.n = 1e6),
               "No hexagon holds at least")
})

test_that("cellsize overrides bins, and smaller cells give more hexagons", {
  d <- hex_points()

  coarse <- hex_bin(d, value = "catch", cellsize = 2)
  fine <- hex_bin(d, value = "catch", cellsize = 0.5)

  expect_equal(attr(coarse, "cellsize"), 2)
  expect_gt(nrow(fine), nrow(coarse))
})

test_that("coordinate columns are guessed, or named", {
  set.seed(1)
  named <- data.frame(lon = runif(200, 0, 5), lat = runif(200, 0, 5))
  expect_no_error(hex_bin(named, fun = "count", bins = 5))

  odd <- data.frame(easting = runif(200), northing = runif(200))
  expect_error(hex_bin(odd, fun = "count"), "Could not find coordinate columns")
  expect_no_error(hex_bin(odd, coords = c("easting", "northing"),
                          fun = "count", bins = 4))
})

test_that("bad input is refused with a message naming the problem", {
  d <- hex_points(100)

  expect_error(hex_bin(d, value = "nope"), "No column 'nope'")
  expect_error(hex_bin(d, coords = c("a", "b")), "No coordinate column")
  expect_error(hex_bin("not data"), "must be a SpatRaster or a data frame")
  expect_error(hex_bin(d, value = "catch", fun = "mode"),
               "Unknown fun requested")
  expect_error(hex_bin(d, value = "catch", min.n = 0), "at least 1")
  expect_error(hex_bin(d, value = "catch", cellsize = -1),
               "single positive number")
})

test_that("coordinates that do not vary cannot form a lattice", {
  flat <- data.frame(x = rep(1, 10), y = runif(10))

  expect_error(hex_bin(flat, fun = "count"), "do not vary")
})

test_that("missing values are excluded from the summary but not the hexagon", {
  d <- hex_points(500)
  d$catch[1:100] <- NA

  binned <- hex_bin(d, value = "catch", bins = 5)

  expect_equal(sum(binned$.n), 400)
  expect_false(anyNA(binned$.value))
})

test_that("a raster is binned like points, covering every cell", {
  skip_if_not_installed("terra")
  r <- terra::rast(nrows = 40, ncols = 50, xmin = 0, xmax = 10,
                   ymin = 0, ymax = 8)
  terra::values(r) <- runif(terra::ncell(r))
  names(r) <- "suitability"

  binned <- hex_bin(r, bins = 15)

  expect_equal(sum(binned$.n), terra::ncell(r))
  expect_gt(nrow(binned), 1)
})

test_that("binning lon/lat notes that the hexagons are not equal area", {
  # A degree of longitude shortens toward the poles, so a count per hexagon is
  # not a density.
  skip_if_not_installed("terra")
  reset_notices()
  r <- terra::rast(nrows = 20, ncols = 20, xmin = -71, xmax = -65,
                   ymin = 41, ymax = 45, crs = "EPSG:4326")
  terra::values(r) <- runif(terra::ncell(r))

  expect_message(hex_bin(r, bins = 8), "not equal area")
  expect_no_message(hex_bin(r, bins = 8))
})

test_that("a layer beyond the raster is refused", {
  skip_if_not_installed("terra")
  r <- terra::rast(nrows = 10, ncols = 10, vals = runif(100))

  expect_error(hex_bin(r, layer = 3), "layer\\(s\\); layer = 3")
})

test_that("hex_polygons draws six corners per hexagon, centred correctly", {
  centres <- data.frame(.x = c(0, 5), .y = c(0, 5), .value = c(1, 2),
                        .n = c(10, 20))
  corners <- hex_polygons(centres, size = 1)

  expect_equal(nrow(corners), 12)
  expect_equal(sort(unique(corners$.id)), c(1, 2))
  # The corners average back to the centre they came from.
  expect_equal(mean(corners$.x[corners$.id == 1]), 0)
  expect_equal(mean(corners$.y[corners$.id == 1]), 0)
  # Every corner sits one circumradius from its centre.
  expect_equal(unique(round(sqrt(corners$.x[corners$.id == 1]^2 +
                                   corners$.y[corners$.id == 1]^2), 8)), 1)
})

test_that("plotHexbin draws points, counts and rasters", {
  d <- hex_points(500)

  expect_s3_class(plotHexbin(d, value = "catch", bins = 8), "ggplot")
  expect_s3_class(plotHexbin(d, fun = "count", bins = 8), "ggplot")

  skip_if_not_installed("terra")
  r <- terra::rast(nrows = 20, ncols = 20, vals = runif(400))
  expect_s3_class(plotHexbin(r, bins = 8), "ggplot")
})

test_that("plotHexbin accepts a frame hex_bin already produced", {
  d <- hex_points(500)
  binned <- hex_bin(d, value = "catch", bins = 8)

  expect_s3_class(plotHexbin(binned), "ggplot")

  # But not one whose cellsize has been stripped, since the hexagons could
  # then be drawn at the wrong size.
  stripped <- binned
  attr(stripped, "cellsize") <- NULL
  expect_error(plotHexbin(stripped), "carries no cellsize")
})

test_that("the legend names the summary that was computed", {
  d <- hex_points(500)

  expect_equal(plotHexbin(d, fun = "count", bins = 6)$labels$fill, "Count")
  expect_equal(plotHexbin(d, value = "catch", bins = 6)$labels$fill, "Mean")
  expect_equal(
    plotHexbin(d, value = "catch", bins = 6, legend.lab = "Catch")$labels$fill,
    "Catch")
})
