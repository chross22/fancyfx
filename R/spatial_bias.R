#' Spatial sorting bias in a train/test split
#'
#' Asks whether a hold-out is really independent. If the test presences happen
#' to sit closer to the training presences than the test absences do, the model
#' can score well by knowing roughly where the training data was, without
#' knowing anything about the species.
#'
#' @param presence Test presences: a two-column matrix or data frame of
#'   coordinates.
#' @param absence Test absences or background points, likewise.
#' @param reference Training presences, likewise.
#' @param geo Whether the coordinates are longitude and latitude, in which case
#'   distances are great-circle rather than Euclidean.
#'
#' @details
#' The statistic is the ratio of two mean nearest-neighbour distances: from each
#' test presence to the closest training presence, over the same for each test
#' absence, following Hijmans (2012).
#'
#' * **Near 1** -- test presences and test absences are equally far from the
#'   training data. The split is doing its job.
#' * **Near 0** -- test presences sit much closer to training presences. A
#'   model can then score well on proximity alone, and its AUC is measuring the
#'   split rather than the species.
#'
#' This is the quantity behind the warnings elsewhere in this package about
#' random cross-validation folds on spatially correlated data. Those warnings
#' say the problem exists; this measures how bad it is for a particular split,
#' which is the thing worth reporting in a methods section.
#'
#' A low value is not a reason to abandon the model. It is a reason to use
#' spatially blocked folds, or to sample the test absences to match the
#' presences' distance distribution, and then to say which you did.
#'
#' @return A named vector: `presence` and `absence` mean nearest-neighbour
#'   distances, and their ratio `ssb`.
#'
#' @family evaluation plots
#' @seealso [threshold_metrics()], whose `folds` argument is where a spatially
#'   blocked split gets used.
#'
#' @references
#' Hijmans, R. J. (2012). Cross-validation of species distribution models:
#' removing spatial sorting bias and calibration with a null model. *Ecology*,
#' 93(3), 679-688. \doi{10.1890/11-0826.1}
#'
#' @examples
#' set.seed(1)
#' training <- cbind(runif(100, 0, 10), runif(100, 0, 10))
#'
#' # Test presences drawn from the same area as the training data, test
#' # absences from everywhere: the split flatters the model.
#' biased.presence <- cbind(runif(50, 0, 10), runif(50, 0, 10))
#' absence <- cbind(runif(50, 0, 40), runif(50, 0, 40))
#'
#' spatial_sorting_bias(biased.presence, absence, training)
#'
#' @export
spatial_sorting_bias <- function(presence, absence, reference, geo = FALSE) {
  presence <- coordinate_matrix(presence, "presence")
  absence <- coordinate_matrix(absence, "absence")
  reference <- coordinate_matrix(reference, "reference")

  presence.distance <- mean(nearest_distance(presence, reference, geo),
                            na.rm = TRUE)
  absence.distance <- mean(nearest_distance(absence, reference, geo),
                           na.rm = TRUE)

  # A ratio against zero is undefined, not enormous: it happens when every test
  # absence coincides with a training presence, which is a broken split rather
  # than an unbiased one.
  ratio <- if (absence.distance == 0) NA_real_ else {
    presence.distance / absence.distance
  }

  c(presence = presence.distance, absence = absence.distance, ssb = ratio)
}

#' Distance from each point to the nearest reference point
#'
#' @param points Two-column matrix of coordinates.
#' @param reference Two-column matrix of coordinates.
#' @param geo Whether to use great-circle distances.
#' @return A numeric vector, one distance per row of `points`.
#' @keywords internal
nearest_distance <- function(points, reference, geo = FALSE) {
  vapply(seq_len(nrow(points)), function(i) {
    distances <- if (geo) {
      haversine(points[i, 1], points[i, 2], reference[, 1], reference[, 2])
    } else {
      sqrt((points[i, 1] - reference[, 1])^2 +
             (points[i, 2] - reference[, 2])^2)
    }
    min(distances, na.rm = TRUE)
  }, numeric(1))
}

#' Great-circle distance in kilometres
#'
#' Implemented here rather than depending on a geospatial stack for five lines
#' of trigonometry.
#'
#' @param lon1,lat1 Coordinates of one point, in degrees.
#' @param lon2,lat2 Coordinates to measure to, in degrees.
#' @return Distances in kilometres.
#' @keywords internal
haversine <- function(lon1, lat1, lon2, lat2) {
  radius <- 6371
  to.radians <- pi / 180
  delta.lon <- (lon2 - lon1) * to.radians
  delta.lat <- (lat2 - lat1) * to.radians

  a <- sin(delta.lat / 2)^2 +
    cos(lat1 * to.radians) * cos(lat2 * to.radians) * sin(delta.lon / 2)^2
  2 * radius * asin(pmin(1, sqrt(a)))
}

#' Coerce coordinates to a two-column numeric matrix
#'
#' @param x A matrix, data frame or two-column object of coordinates.
#' @param what What to call it in an error message.
#' @return A two-column numeric matrix.
#' @keywords internal
coordinate_matrix <- function(x, what) {
  # Checked before any column is selected: a one-column frame would otherwise
  # be indexed with an NA name and fail somewhere less informative.
  if (ncol(as.data.frame(x)) < 2) {
    stop(what, " must have two coordinate columns; it has ",
         ncol(as.data.frame(x)), ".", call. = FALSE)
  }
  if (is.data.frame(x)) {
    coords <- if (all(c("x", "y") %in% names(x))) {
      c("x", "y")
    } else if (all(c("lon", "lat") %in% names(x))) {
      c("lon", "lat")
    } else {
      names(x)[1:2]
    }
    x <- as.matrix(x[, coords, drop = FALSE])
  }
  x <- as.matrix(x)

  if (ncol(x) < 2) {
    stop(what, " must have two coordinate columns; it has ", ncol(x), ".",
         call. = FALSE)
  }
  if (!nrow(x)) {
    stop(what, " has no rows.", call. = FALSE)
  }
  storage.mode(x) <- "double"
  x[, 1:2, drop = FALSE]
}

#' Thin points so that no cell holds more than a few
#'
#' Reduces the effect of uneven survey effort. Where records pile up because
#' somewhere was visited often rather than because the species is common there,
#' a model fitted to the raw points learns the sampling as though it were the
#' species.
#'
#' @param x A data frame of points.
#' @param coords The two coordinate columns. Guessed when omitted.
#' @param n Maximum number of points to keep per cell.
#' @param cellsize Cell size in the units of the coordinates. Ignored when
#'   `bins` is used.
#' @param bins Approximate number of cells across the x range, as an
#'   alternative to naming a `cellsize`.
#' @param type `"hex"` for a hexagonal lattice, or `"grid"` for a square one.
#' @param seed Random seed, since which points survive is a random choice among
#'   those sharing a cell.
#'
#' @details
#' Thinning is a blunt instrument and it throws data away. It is worth doing
#' when the clustering is an artefact of where people looked, and worth *not*
#' doing when the clustering is the signal -- there is no way for the function
#' to tell which, so the judgement stays with you.
#'
#' The hexagonal lattice is the default for the same reason [hex_bin()] uses
#' one: its cells have neighbours all at equal distance, where a square grid
#' does not, so thinning is not subtly directional.
#'
#' @return The rows of `x` that survive thinning, in their original order.
#'
#' @family spatial plots
#' @seealso [hex_bin()], which uses the same lattice to summarise rather than
#'   to thin, and [spatial_sorting_bias()] for the related problem in a
#'   train/test split.
#'
#' @examples
#' set.seed(1)
#' # Heavily oversampled in one corner
#' records <- data.frame(
#'   x = c(runif(400, 0, 2), runif(100, 0, 10)),
#'   y = c(runif(400, 0, 2), runif(100, 0, 10))
#' )
#'
#' nrow(records)
#' nrow(thin_points(records, n = 1, bins = 10))
#'
#' @export
thin_points <- function(x, coords = NULL, n = 1, cellsize = NULL, bins = 20,
                        type = c("hex", "grid"), seed = 1) {
  type <- check_choice(type, c("hex", "grid"), "type")
  if (!is.data.frame(x)) {
    stop("x must be a data frame of points, not a <",
         paste(class(x), collapse = "/"), ">.", call. = FALSE)
  }
  if (!is.numeric(n) || length(n) != 1 || n < 1) {
    stop("n must be a single number of at least 1.", call. = FALSE)
  }

  coords <- coords %||% guess_coords(x)
  missing.coords <- setdiff(coords, names(x))
  if (length(missing.coords)) {
    stop("No coordinate column(s): ", paste(missing.coords, collapse = ", "),
         ".", call. = FALSE)
  }

  size <- hex_size(x[[coords[1]]], bins, cellsize)

  key <- if (type == "hex") {
    index <- hex_assign(x[[coords[1]]], x[[coords[2]]], size)
    paste(index$q, index$r, sep = ",")
  } else {
    paste(floor(x[[coords[1]]] / size), floor(x[[coords[2]]] / size),
          sep = ",")
  }

  # Seeded and restored: which of several points in a cell survives is a random
  # choice, and a thinning that moves between runs cannot be reproduced.
  if (!is.null(seed)) {
    old.seed <- if (exists(".Random.seed", .GlobalEnv)) {
      get(".Random.seed", .GlobalEnv)
    } else {
      NULL
    }
    set.seed(seed)
    on.exit({
      if (!is.null(old.seed)) assign(".Random.seed", old.seed, .GlobalEnv)
    }, add = TRUE)
  }

  kept <- unlist(lapply(split(seq_len(nrow(x)), key), function(i) {
    if (length(i) <= n) i else sample(i, n)
  }), use.names = FALSE)

  x[sort(kept), , drop = FALSE]
}
