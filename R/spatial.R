#' Summarise an ensemble of projection rasters
#'
#' Collapses a stack whose layers are ensemble members -- competing models,
#' emissions scenarios, bootstrap replicates -- into one summary layer. The
#' spread statistics are the point: a projection map without one says only what
#' the ensemble guessed, not how much the members disagreed.
#'
#' @param x A `SpatRaster` whose layers are ensemble members.
#' @param statistic What to compute across layers at each cell. `"sd"`,
#'   `"cv"`, `"range"` and `"iqr"` describe disagreement; `"mean"` and
#'   `"median"` describe the projection itself.
#' @param na.rm Whether to ignore members that are missing at a cell. See
#'   Details -- the default is deliberately `FALSE`.
#'
#' @details
#' `na.rm` defaults to `FALSE`, which is the opposite of most R summaries and
#' is deliberate. If one member is missing over part of the domain, taking the
#' spread of the members that remain reports a *narrower* uncertainty exactly
#' where the ensemble is least complete, and nothing on the resulting map says
#' so. Leaving those cells `NA` makes the gap visible. Set `na.rm = TRUE` only
#' once you know why the members differ in coverage.
#'
#' `"cv"` is the standard deviation over the mean. It is the natural choice
#' when members are on a count or density scale, where a spread of 5 means
#' something very different at a mean of 10 than at a mean of 1000. It is a
#' poor choice for probabilities, where the mean can approach zero and the
#' ratio explodes; use `"sd"` there.
#'
#' @return A single-layer `SpatRaster`.
#'
#' @family spatial plots
#' @seealso [plotUncertainty()] to draw it, [mess()] for whether the projection
#'   is extrapolating in the first place.
#'
#' @examples
#' if (requireNamespace("terra", quietly = TRUE)) {
#'   r <- terra::rast(nrows = 20, ncols = 20, vals = runif(400))
#'   ensemble <- c(r, r * 1.2, r * 0.7)
#'   names(ensemble) <- c("model1", "model2", "model3")
#'
#'   ensemble_summary(ensemble, "sd")
#' }
#'
#' @export
ensemble_summary <- function(x, statistic = c("sd", "cv", "range", "iqr",
                                              "mean", "median"),
                             na.rm = FALSE) {
  require_terra()
  statistic <- check_choice(statistic,
                            c("sd", "cv", "range", "iqr", "mean", "median"),
                            "statistic")
  if (!inherits(x, "SpatRaster")) {
    stop("x must be a SpatRaster whose layers are ensemble members, not a <",
         paste(class(x), collapse = "/"), ">.", call. = FALSE)
  }
  if (terra::nlyr(x) < 2) {
    stop("An ensemble needs at least two layers; x has ", terra::nlyr(x),
         ". A single projection has no spread to report.", call. = FALSE)
  }

  out <- switch(
    statistic,
    sd = terra::app(x, stats::sd, na.rm = na.rm),
    mean = terra::app(x, mean, na.rm = na.rm),
    median = terra::app(x, stats::median, na.rm = na.rm),
    range = terra::app(x, function(v) diff(range(v, na.rm = na.rm))),
    iqr = terra::app(x, function(v) {
      stats::IQR(v, na.rm = na.rm)
    }),
    cv = {
      centre <- terra::app(x, mean, na.rm = na.rm)
      spread <- terra::app(x, stats::sd, na.rm = na.rm)
      # A coefficient of variation about a mean of zero is not a large number,
      # it is undefined. Returning Inf would draw a map dominated by cells
      # where the ensemble happened to average out.
      centre[centre == 0] <- NA
      spread / centre
    }
  )

  names(out) <- statistic
  out
}

#' Multivariate environmental similarity surface
#'
#' Where does a projection leave the conditions the model was fitted under?
#' Negative values mark cells outside the training range of at least one
#' covariate -- places where the model is extrapolating rather than
#' interpolating, and where its predictions are guesses dressed as estimates.
#'
#' @param x A `SpatRaster` of covariates to project onto. Layer names must
#'   match the columns of `training`.
#' @param training A data frame of the covariate values the model was fitted
#'   on, or a fitted model to take them from.
#' @param vars Covariates to consider. Defaults to those common to both.
#'
#' @details
#' Implements the MESS of Elith, Kearney and Phillips (2010). For each cell and
#' each covariate, similarity is 100 when the value sits at the median of the
#' training data and falls to 0 at its minimum and maximum, going negative
#' beyond them in proportion to how far outside the range the value lies. The
#' surface reports the **minimum** across covariates, so a cell is flagged as
#' novel if any single covariate is out of range -- which is the useful
#' convention, since one novel variable is enough to invalidate a prediction.
#'
#' What it does not detect is novel *combinations* of covariates that are each
#' individually within range. A cell can be perfectly ordinary on every axis
#' separately and still be somewhere the model has never seen, and MESS will
#' report it as similar. Treat a non-negative surface as the absence of one
#' specific problem, not as a licence to project.
#'
#' @section Which covariate is responsible:
#' The surface says a cell is novel; `limiting = TRUE` says what made it so.
#' That is usually the actionable half -- "this shelf is extrapolated" is a
#' shrug, "extrapolated because its chlorophyll is higher than any training
#' record" is a decision about whether to widen the training window or clip the
#' map. It names the covariate with the lowest similarity, which is the one the
#' minimum was taken from.
#'
#' @section Rasters and data frames:
#' `x` may be a `SpatRaster` of covariate layers or a plain data frame of
#' covariate columns, and the return follows the input. The data frame form is
#' for pipelines that hold their projection as a table of cells rather than as a
#' raster, which is common enough that requiring a round trip through `terra`
#' to score it would be a tax rather than a service.
#'
#' @param limiting Whether to also report the covariate responsible for each
#'   cell's score. `FALSE` by default, so the returned shape is unchanged.
#'
#' @return For a `SpatRaster`, a `SpatRaster` named `mess`, gaining a
#'   categorical `mess_variable` layer when `limiting = TRUE`. For a data frame,
#'   a data frame with a `mess` column and, when `limiting = TRUE`, a
#'   `mess_variable` column. Negative values are novel.
#'
#' @family spatial plots
#' @seealso [plotExtrapolation()] to draw it, [ensemble_summary()] for
#'   disagreement between members.
#'
#' @references
#' Elith, J., Kearney, M., & Phillips, S. (2010). The art of modelling
#' range-shifting species. *Methods in Ecology and Evolution*, 1(4), 330-342.
#' \doi{10.1111/j.2041-210X.2010.00036.x}
#'
#' @examples
#' if (requireNamespace("terra", quietly = TRUE)) {
#'   set.seed(1)
#'   training <- data.frame(temp = rnorm(200, 10, 2), depth = runif(200, 0, 100))
#'
#'   covariates <- c(
#'     terra::rast(nrows = 20, ncols = 20, vals = rnorm(400, 12, 3)),
#'     terra::rast(nrows = 20, ncols = 20, vals = runif(400, -20, 140))
#'   )
#'   names(covariates) <- c("temp", "depth")
#'
#'   novelty <- mess(covariates, training)
#'   # Cells below zero are outside the training range of some covariate.
#' }
#'
#' @export
mess <- function(x, training, vars = NULL, limiting = FALSE) {
  raster <- inherits(x, "SpatRaster")
  if (!raster && !is.data.frame(x)) {
    stop("x must be a SpatRaster or a data frame of covariates, not a <",
         paste(class(x), collapse = "/"), ">.", call. = FALSE)
  }
  if (raster) require_terra()

  training <- training_frame(training)
  vars <- mess_vars(x, training, vars, raster)

  references <- lapply(vars, function(v) {
    reference <- stats::na.omit(training[[v]])
    if (!length(reference)) {
      stop("Training data for '", v, "' is entirely missing.", call. = FALSE)
    }
    reference
  })
  names(references) <- vars

  if (!raster) return(mess_frame(x, references, vars, limiting))

  layers <- lapply(vars, function(v) {
    terra::app(x[[v]], function(p) mess_similarity(p, references[[v]]))
  })

  out <- Reduce(function(a, b) min(a, b), layers)
  names(out) <- "mess"
  if (!limiting) return(out)

  # which.min over the layers, as a categorical layer carrying the names. A
  # raster cannot hold a character, so the codes are the levels table.
  stacked <- Reduce(c, layers)
  worst <- terra::which.min(stacked)
  levels(worst) <- data.frame(value = seq_along(vars), mess_variable = vars)
  names(worst) <- "mess_variable"
  c(out, worst)
}

#' The covariates a MESS surface can be built from
#'
#' @param x A `SpatRaster` or data frame of covariates.
#' @param training Training data.
#' @param vars Requested covariates, or `NULL` for the ones in common.
#' @param raster Whether `x` is a raster, for the error wording.
#' @return A character vector of covariate names.
#' @keywords internal
mess_vars <- function(x, training, vars, raster) {
  available <- names(x)
  if (is.null(vars)) vars <- intersect(available, names(training))

  if (!length(vars)) {
    stop("No covariates in common between the ",
         if (raster) "raster (" else "data (",
         paste(available, collapse = ", "), ") and the training data (",
         paste(names(training), collapse = ", "), ").", call. = FALSE)
  }
  missing.vars <- setdiff(vars, available)
  if (length(missing.vars)) {
    stop(if (raster) "Raster has no layer(s): " else "Data has no column(s): ",
         paste(missing.vars, collapse = ", "), call. = FALSE)
  }
  vars
}

#' MESS over a data frame of cells
#'
#' @param x A data frame of covariates.
#' @param references Training values per covariate.
#' @param vars Covariate names.
#' @param limiting Whether to name the covariate responsible.
#' @return A data frame with `mess` and optionally `mess_variable`.
#' @keywords internal
mess_frame <- function(x, references, vars, limiting = FALSE) {
  similarity <- vapply(vars, function(v) {
    mess_similarity(x[[v]], references[[v]])
  }, numeric(nrow(x)))

  # vapply drops to a plain vector for a single row, which then indexes as if
  # it were one column of many.
  similarity <- matrix(similarity, nrow = nrow(x),
                       dimnames = list(NULL, vars))

  out <- data.frame(mess = apply(similarity, 1, min, na.rm = FALSE))
  if (!limiting) return(out)

  worst <- apply(similarity, 1, function(row) {
    if (all(is.na(row))) return(NA_integer_)
    which.min(row)
  })
  out$mess_variable <- ifelse(is.na(worst), NA_character_, vars[worst])
  out
}

#' Similarity of values to a reference distribution, on the MESS scale
#'
#' @param p Numeric vector of values to score.
#' @param reference Numeric vector of training values.
#' @return Numeric vector of similarities; negative is outside the range.
#' @keywords internal
mess_similarity <- function(p, reference) {
  reference <- sort(reference)
  n <- length(reference)
  lowest <- reference[1]
  highest <- reference[n]

  # Percentage of the training data at or below each value.
  f <- 100 * findInterval(p, reference) / n

  out <- 2 * f
  upper <- !is.na(f) & f > 50 & f < 100
  out[upper] <- 200 - 2 * f[upper]

  # Outside the range entirely: the score goes negative in proportion to how
  # far outside, which is the whole point of the surface.
  span <- highest - lowest
  below <- !is.na(f) & f == 0
  above <- !is.na(f) & f == 100
  if (span > 0) {
    out[below] <- 100 * (p[below] - lowest) / span
    out[above] <- 100 * (highest - p[above]) / span
  } else {
    # A constant covariate: anything not equal to it is novel, and "how far
    # outside" has no scale to be measured against.
    out[below] <- ifelse(p[below] == lowest, 100, -Inf)
    out[above] <- ifelse(p[above] == highest, 100, -Inf)
  }

  out[is.na(p)] <- NA_real_
  out
}

#' Training covariate values, from a data frame or a fitted model
#'
#' @param training A data frame, or a fitted model to take the frame from.
#' @return A data frame.
#' @keywords internal
training_frame <- function(training) {
  if (is.data.frame(training)) return(training)

  frame <- tryCatch(stats::model.frame(unwrap_gam(training)),
                    error = function(e) NULL)
  if (is.null(frame)) {
    stop("training must be a data frame of covariate values, or a model that ",
         "exposes the data it was fitted on.", call. = FALSE)
  }
  as.data.frame(frame)
}

#' Map the disagreement between ensemble members
#'
#' Draws the spread across an ensemble of projections. The companion to a
#' projection map rather than a replacement for it: the two together say what
#' the ensemble expects and where it is least sure.
#'
#' @param x A `SpatRaster` whose layers are ensemble members, or a
#'   single-layer raster already summarised.
#' @param statistic Spread statistic, passed to [ensemble_summary()]. Ignored
#'   when `x` has one layer.
#' @param na.rm Whether to ignore missing members. Defaults to `FALSE`; see
#'   [ensemble_summary()].
#' @param title Plot title, optional.
#' @param legend.lab Legend title. Defaults to naming the statistic.
#' @param max.cells Largest number of cells to draw. A raster above this is
#'   aggregated first, and the plot says by how much. See Details.
#' @param theme A \pkg{ggplot2} theme. Defaults to [theme_fancyfx()].
#' @param option Viridis colour map option, passed to
#'   [ggplot2::scale_fill_viridis_c()].
#'
#' @details
#' Uncertainty is a magnitude, so it gets a sequential, perceptually uniform
#' viridis scale rather than a rainbow -- on a rainbow the eye invents
#' boundaries where the data has none, which on an uncertainty map means
#' inventing places the ensemble agreed.
#'
#' Projection rasters are routinely millions of cells, and drawing one cell per
#' pixel is both slow and pointless at figure size. Above `max.cells` the
#' raster is aggregated by whole-number factors before plotting. That changes
#' what is on the page, so it is reported in the subtitle rather than done
#' quietly.
#'
#' @return A \pkg{ggplot2} object.
#'
#' @family spatial plots
#' @seealso [ensemble_summary()] for the raster itself, [plotExtrapolation()]
#'   for whether the projection is extrapolating.
#'
#' @examples
#' if (requireNamespace("terra", quietly = TRUE)) {
#'   set.seed(1)
#'   r <- terra::rast(nrows = 30, ncols = 30, vals = runif(900))
#'   ensemble <- c(r, r * 1.2, r * 0.7)
#'   names(ensemble) <- c("model1", "model2", "model3")
#'
#'   plotUncertainty(ensemble)
#' }
#'
#' @export
plotUncertainty <- function(x, statistic = c("sd", "cv", "range", "iqr"),
                            na.rm = FALSE, title = "", legend.lab = NULL,
                            max.cells = 5e5,
                            theme = theme_fancyfx(),
                            option = "viridis") {
  require_terra()
  statistic <- check_choice(statistic, c("sd", "cv", "range", "iqr"),
                            "statistic")

  if (!inherits(x, "SpatRaster")) {
    stop("x must be a SpatRaster, not a <", paste(class(x), collapse = "/"),
         ">.", call. = FALSE)
  }

  summarised <- if (terra::nlyr(x) > 1) {
    ensemble_summary(x, statistic, na.rm = na.rm)
  } else {
    x
  }
  if (is.null(legend.lab)) {
    legend.lab <- if (terra::nlyr(x) > 1) spread_label(statistic) else names(x)[1]
  }

  raster_panel(summarised, title = title, legend.lab = legend.lab,
               max.cells = max.cells, theme = theme) +
    ggplot2::scale_fill_viridis_c(option = option, na.value = "transparent")
}

#' Map where a projection leaves the conditions the model was fitted under
#'
#' Draws a MESS surface: cells below zero are outside the training range of at
#' least one covariate, and predictions there are extrapolations.
#'
#' @param x A `SpatRaster` of covariates, or a single-layer raster already
#'   holding MESS values.
#' @param training A data frame of training covariate values, or a fitted model
#'   to take them from. Required unless `x` is already a MESS surface.
#' @param vars Covariates to consider.
#' @param title Plot title, optional.
#' @param legend.lab Legend title.
#' @param novel.only Whether to show only the novel cells, hiding everything
#'   within the training range.
#' @param max.cells Largest number of cells to draw; above this the raster is
#'   aggregated and the plot says so.
#' @param theme A \pkg{ggplot2} theme. Defaults to [theme_fancyfx()].
#'
#' @details
#' The scale is diverging about zero, because zero is a real boundary and not
#' a midpoint of convenience: on one side the model is interpolating, on the
#' other it is guessing. A sequential scale would hide that edge in a smooth
#' ramp. The two poles are red and blue rather than red and green, so the
#' distinction survives the most common colour vision deficiencies.
#'
#' See [mess()] for what this does and does not detect -- in particular, it
#' cannot see novel *combinations* of individually ordinary covariates.
#'
#' @return A \pkg{ggplot2} object.
#'
#' @family spatial plots
#' @seealso [mess()] for the surface itself, [plotUncertainty()] for
#'   disagreement between ensemble members.
#'
#' @references
#' Elith, J., Kearney, M., & Phillips, S. (2010). The art of modelling
#' range-shifting species. *Methods in Ecology and Evolution*, 1(4), 330-342.
#' \doi{10.1111/j.2041-210X.2010.00036.x}
#'
#' @examples
#' if (requireNamespace("terra", quietly = TRUE)) {
#'   set.seed(1)
#'   training <- data.frame(temp = rnorm(200, 10, 2))
#'   covariates <- terra::rast(nrows = 20, ncols = 20,
#'                             vals = rnorm(400, 12, 3))
#'   names(covariates) <- "temp"
#'
#'   plotExtrapolation(covariates, training)
#' }
#'
#' @export
plotExtrapolation <- function(x, training = NULL, vars = NULL, title = "",
                              legend.lab = "MESS", novel.only = FALSE,
                              max.cells = 5e5,
                              theme = theme_fancyfx()) {
  require_terra()
  if (!inherits(x, "SpatRaster")) {
    stop("x must be a SpatRaster, not a <", paste(class(x), collapse = "/"),
         ">.", call. = FALSE)
  }

  surface <- if (is.null(training)) {
    if (terra::nlyr(x) != 1) {
      stop("training is required unless x is already a single-layer MESS ",
           "surface.", call. = FALSE)
    }
    x
  } else {
    mess(x, training, vars = vars)
  }

  if (novel.only) {
    surface <- terra::ifel(surface < 0, surface, NA)
  }

  panel <- raster_panel(surface, title = title, legend.lab = legend.lab,
                        max.cells = max.cells, theme = theme)

  # Diverging about zero, because zero is where interpolation stops and
  # extrapolation begins. Red and blue rather than red and green, so the
  # distinction survives the common colour vision deficiencies.
  panel +
    ggplot2::scale_fill_gradient2(
      low = "#B2182B", mid = "#F7F7F7", high = "#2166AC",
      midpoint = 0, na.value = "transparent")
}

#' Draw a single raster layer as a ggplot panel
#'
#' The shared body of the spatial plots: aggregate if too large to draw,
#' convert to a data frame, and set an aspect ratio that does not distort the
#' map.
#'
#' @param r A single-layer `SpatRaster`.
#' @param title Plot title.
#' @param legend.lab Legend title.
#' @param max.cells Largest number of cells to draw.
#' @param theme A \pkg{ggplot2} theme.
#' @return A \pkg{ggplot2} object without a fill scale.
#' @keywords internal
raster_panel <- function(r, title, legend.lab, max.cells, theme) {
  reduced <- downsample_raster(r, max.cells)

  frame <- terra::as.data.frame(reduced$raster, xy = TRUE, na.rm = TRUE)
  if (!nrow(frame)) {
    stop("Nothing to draw: every cell is missing.", call. = FALSE)
  }
  names(frame)[3] <- ".value"

  subtitle <- if (reduced$factor > 1) {
    paste0("Aggregated ", reduced$factor, "x for display (",
           format(terra::ncell(r), big.mark = ","), " cells)")
  } else {
    NULL
  }

  ggplot2::ggplot(frame, ggplot2::aes(x = .data$x, y = .data$y,
                                      fill = .data$.value)) +
    ggplot2::geom_raster() +
    ggplot2::labs(x = NULL, y = NULL, fill = legend.lab,
                  title = if (nzchar(title)) title else NULL,
                  subtitle = subtitle) +
    ggplot2::coord_fixed(ratio = map_aspect(r), expand = FALSE) +
    theme
}

#' Aggregate a raster that is too large to draw cell by cell
#'
#' @param r A `SpatRaster`.
#' @param max.cells Largest number of cells to keep.
#' @return A list with the possibly-aggregated `raster` and the `factor` used.
#' @keywords internal
downsample_raster <- function(r, max.cells) {
  if (!is.numeric(max.cells) || length(max.cells) != 1 || max.cells < 1) {
    stop("max.cells must be a single positive number.", call. = FALSE)
  }
  if (terra::ncell(r) <= max.cells) return(list(raster = r, factor = 1))

  # Whole-number factor, since terra aggregates by integer blocks. Rounded up
  # so the result lands under the ceiling rather than just over it.
  factor <- ceiling(sqrt(terra::ncell(r) / max.cells))
  list(raster = terra::aggregate(r, fact = factor, fun = "mean",
                                 na.rm = TRUE),
       factor = factor)
}

#' Aspect ratio that keeps a map from being stretched
#'
#' @param r A `SpatRaster`.
#' @return A ratio for [ggplot2::coord_fixed()].
#' @keywords internal
map_aspect <- function(r) {
  # Degrees of longitude shorten toward the poles, so an unprojected raster
  # drawn at ratio 1 is stretched east-west -- badly so at high latitude.
  if (isTRUE(terra::is.lonlat(r))) {
    extent <- terra::ext(r)
    mid.latitude <- (extent[3] + extent[4]) / 2
    return(1 / max(cos(mid.latitude * pi / 180), 1e-6))
  }
  1
}

#' Legend label for a spread statistic
#'
#' @param statistic One of the spread statistics.
#' @return The label to show.
#' @keywords internal
spread_label <- function(statistic) {
  switch(statistic,
         sd = "Ensemble SD",
         cv = "Ensemble CV",
         range = "Ensemble range",
         iqr = "Ensemble IQR",
         statistic)
}

#' Require terra, with an actionable message
#'
#' \pkg{terra} is a Suggests rather than an Imports: the spatial plots are a
#' corner of this package, and most users plotting a GLM should not have to
#' install a geospatial stack to do it.
#'
#' @return Invisibly `TRUE`.
#' @keywords internal
require_terra <- function() {
  if (!requireNamespace("terra", quietly = TRUE)) {
    stop("The spatial plots need the terra package, which is not installed.\n",
         "  install.packages(\"terra\")", call. = FALSE)
  }
  invisible(TRUE)
}
