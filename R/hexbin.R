#' Aggregate spatial values into hexagonal bins
#'
#' Summarises covariates, model output or raw observations into a hexagonal
#' lattice. Works on a `SpatRaster` or on a data frame of points, and returns
#' the binned values rather than only a picture, so the result can be analysed,
#' joined or written out.
#'
#' @param x A `SpatRaster`, or a data frame of points.
#' @param value For a data frame, the column to summarise. Omit to count points
#'   instead. Ignored for a raster, which uses its first layer unless `layer`
#'   says otherwise.
#' @param coords For a data frame, the two coordinate columns. Defaults to the
#'   first pair of names found among the usual candidates.
#' @param bins Approximate number of hexagons across the x range. Ignored when
#'   `cellsize` is given.
#' @param cellsize Hexagon size, measured centre to vertex, in the units of the
#'   coordinates. Overrides `bins` when supplied.
#' @param fun How to summarise the values in each hexagon: `"mean"`,
#'   `"median"`, `"sum"`, `"sd"`, `"min"`, `"max"`, or `"count"`.
#' @param min.n Hexagons holding fewer than this many values are dropped. See
#'   Details.
#' @param layer For a raster, which layer to summarise.
#'
#' @details
#' Hexagons over squares for a reason worth stating: every neighbour of a
#' hexagon shares an edge and sits at the same distance, where a square grid
#' has neighbours at two different distances depending on whether they meet at
#' an edge or a corner. That makes hexagons better behaved for anything that
#' depends on adjacency, and it removes the visual grain a square lattice
#' imposes on a map.
#'
#' Binning is also a claim about resolution. A projection raster drawn at native
#' resolution invites the reader to believe every pixel is separately estimated,
#' which is rarely true when the covariates were interpolated from far coarser
#' data. Aggregating to a cell size you can defend is more honest than drawing
#' detail the model does not have.
#'
#' `min.n` exists because a hexagon holding one observation is not a summary of
#' anything, and on a map it is indistinguishable from one holding a thousand.
#' The returned `.n` column reports the count either way.
#'
#' @section Coordinates and area:
#' The lattice is built in whatever units the coordinates are in. For projected
#' coordinates that gives equal-area hexagons, which is what you want. For
#' unprojected longitude and latitude it does not: a degree of longitude
#' shortens toward the poles, so hexagons at the top of a domain cover less
#' ground than those at the bottom, and a count per hexagon is not a density.
#' `hex_bin()` says so once per session when handed lon/lat. Project first if
#' the areas matter.
#'
#' @return A data frame with one row per hexagon: `.x` and `.y` for the centre,
#'   `.value` for the summary, and `.n` for how many values it covers. Carries
#'   a `"cellsize"` attribute.
#'
#' @family spatial plots
#' @seealso [plotHexbin()] to draw it.
#'
#' @examples
#' set.seed(1)
#' points <- data.frame(x = runif(500, 0, 10), y = runif(500, 0, 10))
#' points$catch <- points$x + rnorm(500)
#'
#' binned <- hex_bin(points, value = "catch", bins = 12)
#' head(binned)
#'
#' # Counts rather than a summary of some value
#' head(hex_bin(points, fun = "count", bins = 12))
#'
#' @export
hex_bin <- function(x, value = NULL, coords = NULL, bins = 30,
                    cellsize = NULL, fun = c("mean", "median", "sum", "sd",
                                             "min", "max", "count"),
                    min.n = 1, layer = 1) {
  fun <- check_choice(fun, c("mean", "median", "sum", "sd", "min", "max",
                             "count"), "fun")
  if (!is.numeric(min.n) || length(min.n) != 1 || min.n < 1) {
    stop("min.n must be a single number of at least 1.", call. = FALSE)
  }

  points <- hex_input(x, value, coords, layer)

  if (isTRUE(points$lonlat)) {
    note_once(
      "hex.lonlat",
      "Binning unprojected longitude and latitude. A degree of longitude ",
      "shortens toward the poles, so the hexagons are not equal area and a ",
      "count per hexagon is not a density. Project the coordinates first if ",
      "the areas matter."
    )
  }

  size <- hex_size(points$x, bins, cellsize)
  index <- hex_assign(points$x, points$y, size)
  key <- paste(index$q, index$r, sep = ",")

  parts <- split(seq_along(points$x), key)
  summarise <- hex_summariser(fun)

  out <- do.call(rbind, lapply(parts, function(i) {
    centre <- hex_centre(index$q[i[1]], index$r[i[1]], size)
    values <- points$value[i]
    kept <- values[!is.na(values)]
    data.frame(.x = centre$x, .y = centre$y,
               .value = if (fun == "count") length(i) else summarise(kept),
               .n = length(kept))
  }))

  out <- out[out$.n >= min.n, , drop = FALSE]
  if (!nrow(out)) {
    stop("No hexagon holds at least min.n = ", min.n, " values.",
         call. = FALSE)
  }
  rownames(out) <- NULL
  attr(out, "cellsize") <- size
  out
}

#' Coerce the accepted inputs to points with a value
#'
#' @param x A `SpatRaster` or data frame.
#' @param value Column to summarise, for a data frame.
#' @param coords Coordinate columns, for a data frame.
#' @param layer Layer to summarise, for a raster.
#' @return A list with `x`, `y`, `value` and `lonlat`.
#' @keywords internal
hex_input <- function(x, value, coords, layer) {
  if (inherits(x, "SpatRaster")) {
    require_terra()
    if (layer > terra::nlyr(x)) {
      stop("Raster has ", terra::nlyr(x), " layer(s); layer = ", layer,
           " was requested.", call. = FALSE)
    }
    frame <- terra::as.data.frame(x[[layer]], xy = TRUE, na.rm = TRUE)
    return(list(x = frame[[1]], y = frame[[2]], value = frame[[3]],
                lonlat = isTRUE(terra::is.lonlat(x))))
  }

  if (!is.data.frame(x)) {
    stop("x must be a SpatRaster or a data frame, not a <",
         paste(class(x), collapse = "/"), ">.", call. = FALSE)
  }

  coords <- coords %||% guess_coords(x)
  missing.coords <- setdiff(coords, names(x))
  if (length(missing.coords)) {
    stop("No coordinate column(s): ", paste(missing.coords, collapse = ", "),
         ". Name them with the coords argument.", call. = FALSE)
  }

  values <- if (is.null(value)) {
    rep(1, nrow(x))
  } else {
    if (!(value %in% names(x))) {
      stop("No column '", value, "' in x.", call. = FALSE)
    }
    x[[value]]
  }

  list(x = x[[coords[1]]], y = x[[coords[2]]], value = values, lonlat = FALSE)
}

#' Guess which columns hold coordinates
#'
#' @param x A data frame.
#' @return A length-2 character vector.
#' @keywords internal
guess_coords <- function(x) {
  candidates <- list(c("x", "y"), c("lon", "lat"), c("long", "lat"),
                     c("longitude", "latitude"), c("X", "Y"))
  for (pair in candidates) {
    if (all(pair %in% names(x))) return(pair)
  }
  stop("Could not find coordinate columns among: ",
       paste(names(x), collapse = ", "),
       ". Name them with the coords argument.", call. = FALSE)
}

#' Hexagon size from a bin count, unless given outright
#'
#' @param x Numeric vector of x coordinates.
#' @param bins Approximate number of hexagons across the x range.
#' @param cellsize Explicit size, centre to vertex.
#' @return The size, centre to vertex.
#' @keywords internal
hex_size <- function(x, bins, cellsize) {
  if (!is.null(cellsize)) {
    if (!is.numeric(cellsize) || length(cellsize) != 1 || cellsize <= 0) {
      stop("cellsize must be a single positive number.", call. = FALSE)
    }
    return(cellsize)
  }
  if (!is.numeric(bins) || length(bins) != 1 || bins < 1) {
    stop("bins must be a single number of at least 1.", call. = FALSE)
  }

  span <- diff(range(x, na.rm = TRUE))
  if (!is.finite(span) || span == 0) {
    stop("Coordinates do not vary, so no lattice can be built.", call. = FALSE)
  }
  # A pointy-top hexagon is sqrt(3) * size wide, so this many across the range.
  span / (bins * sqrt(3))
}

#' Assign points to hexagons of a pointy-top lattice
#'
#' Uses axial coordinates and cube rounding, which is the standard construction
#' and has the property the tests check: every point lands in the hexagon whose
#' centre is nearest to it.
#'
#' @param x,y Numeric coordinate vectors.
#' @param size Hexagon size, centre to vertex.
#' @return A list of integer axial coordinates `q` and `r`.
#' @keywords internal
hex_assign <- function(x, y, size) {
  q <- (sqrt(3) / 3 * x - 1 / 3 * y) / size
  r <- (2 / 3 * y) / size

  # Cube coordinates sum to zero, so rounding all three independently can break
  # that. The component that moved furthest is recomputed from the other two.
  cube.x <- q
  cube.z <- r
  cube.y <- -cube.x - cube.z

  round.x <- round(cube.x)
  round.y <- round(cube.y)
  round.z <- round(cube.z)

  diff.x <- abs(round.x - cube.x)
  diff.y <- abs(round.y - cube.y)
  diff.z <- abs(round.z - cube.z)

  fix.x <- diff.x > diff.y & diff.x > diff.z
  fix.y <- !fix.x & diff.y > diff.z
  fix.z <- !fix.x & !fix.y

  round.x[fix.x] <- -round.y[fix.x] - round.z[fix.x]
  round.y[fix.y] <- -round.x[fix.y] - round.z[fix.y]
  round.z[fix.z] <- -round.x[fix.z] - round.y[fix.z]

  list(q = round.x, r = round.z)
}

#' Centre of a hexagon from its axial coordinates
#'
#' @param q,r Axial coordinates.
#' @param size Hexagon size, centre to vertex.
#' @return A list with `x` and `y`.
#' @keywords internal
hex_centre <- function(q, r, size) {
  list(x = size * (sqrt(3) * q + sqrt(3) / 2 * r),
       y = size * (3 / 2 * r))
}

#' The six corners of each hexagon, as polygon rows
#'
#' @param centres A data frame with `.x` and `.y`.
#' @param size Hexagon size, centre to vertex.
#' @return A data frame of vertices with a `.id` per hexagon.
#' @keywords internal
hex_polygons <- function(centres, size) {
  # Pointy-top: the first corner is at -30 degrees, and they run every 60.
  angles <- (seq_len(6) - 1) * 60 - 30
  angles <- angles * pi / 180

  n <- nrow(centres)
  data.frame(
    .id = rep(seq_len(n), each = 6),
    .x = rep(centres$.x, each = 6) + size * rep(cos(angles), times = n),
    .y = rep(centres$.y, each = 6) + size * rep(sin(angles), times = n),
    .value = rep(centres$.value, each = 6),
    .n = rep(centres$.n, each = 6)
  )
}

#' The summarising function behind a name
#'
#' @param fun One of the accepted names.
#' @return A function of one numeric vector.
#' @keywords internal
hex_summariser <- function(fun) {
  switch(fun,
         mean = mean,
         median = stats::median,
         sum = sum,
         sd = stats::sd,
         min = function(v) if (length(v)) min(v) else NA_real_,
         max = function(v) if (length(v)) max(v) else NA_real_,
         count = length)
}

#' Map values aggregated into hexagonal bins
#'
#' Draws the output of [hex_bin()]. Useful for showing survey effort or catch
#' at a resolution the data supports, and for aggregating a projection raster
#' to a cell size you can defend rather than drawing every pixel as though it
#' were separately estimated.
#'
#' @param x A `SpatRaster`, a data frame of points, or a frame already returned
#'   by [hex_bin()].
#' @param value For a data frame, the column to summarise. Omit to count
#'   points.
#' @param coords For a data frame, the two coordinate columns.
#' @param bins Approximate number of hexagons across the x range.
#' @param cellsize Hexagon size, centre to vertex. Overrides `bins`.
#' @param fun How to summarise each hexagon; see [hex_bin()].
#' @param min.n Hexagons holding fewer than this many values are dropped.
#' @param layer For a raster, which layer to summarise.
#' @param title Plot title, optional.
#' @param legend.lab Legend title. Defaults to naming the summary.
#' @param theme A \pkg{ggplot2} theme. Defaults to [theme_fancyfx()].
#' @param option Viridis colour map option.
#' @param colour Outline colour for each hexagon. `NA` for none, which is
#'   usually right at small cell sizes.
#'
#' @details
#' The fill is a sequential viridis scale, because a binned summary is a
#' magnitude. See [hex_bin()] for why hexagons rather than squares, what
#' `min.n` is for, and the caveat about binning unprojected coordinates.
#'
#' @return A \pkg{ggplot2} object.
#'
#' @family spatial plots
#' @seealso [hex_bin()] for the binned values themselves.
#'
#' @examples
#' set.seed(1)
#' points <- data.frame(x = runif(800, 0, 10), y = runif(800, 0, 10))
#' points$catch <- points$x + rnorm(800)
#'
#' plotHexbin(points, value = "catch", bins = 14)
#'
#' # Survey effort: how many observations fall in each hexagon
#' plotHexbin(points, fun = "count", bins = 14, legend.lab = "Observations")
#'
#' @export
plotHexbin <- function(x, value = NULL, coords = NULL, bins = 30,
                       cellsize = NULL,
                       fun = c("mean", "median", "sum", "sd", "min", "max",
                               "count"),
                       min.n = 1, layer = 1, title = "", legend.lab = NULL,
                       theme = theme_fancyfx(), option = "viridis",
                       colour = NA) {

  already.binned <- is.data.frame(x) &&
    all(c(".x", ".y", ".value", ".n") %in% names(x))

  binned <- if (already.binned) {
    x
  } else {
    fun <- check_choice(fun, c("mean", "median", "sum", "sd", "min", "max",
                               "count"), "fun")
    hex_bin(x, value = value, coords = coords, bins = bins,
            cellsize = cellsize, fun = fun, min.n = min.n, layer = layer)
  }

  size <- attr(binned, "cellsize")
  if (is.null(size)) {
    stop("Binned data carries no cellsize attribute; pass the frame returned ",
         "by hex_bin() rather than a modified copy.", call. = FALSE)
  }

  if (is.null(legend.lab)) {
    legend.lab <- if (already.binned) {
      "Value"
    } else if (fun == "count") {
      "Count"
    } else {
      paste0(toupper(substring(fun, 1, 1)), substring(fun, 2))
    }
  }

  polygons <- hex_polygons(binned, size)

  ggplot2::ggplot(polygons,
                  ggplot2::aes(x = .data$.x, y = .data$.y,
                               group = .data$.id, fill = .data$.value)) +
    ggplot2::geom_polygon(colour = colour, linewidth = 0.1) +
    ggplot2::scale_fill_viridis_c(option = option, na.value = "transparent") +
    ggplot2::labs(x = NULL, y = NULL, fill = legend.lab,
                  title = if (nzchar(title)) title else NULL) +
    ggplot2::coord_fixed(ratio = 1) +
    theme
}
