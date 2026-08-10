#' Are the model's predicted probabilities honest?
#'
#' Bins predictions and compares the average prediction in each bin against how
#' often the outcome actually occurred. A well calibrated model that says 0.7
#' is right about 70% of the time.
#'
#' @param model A fitted presence/absence model.
#' @param newdata Data to evaluate on. **Required, and it should not be the
#'   data the model was fitted to.** See [threshold_metrics()].
#' @param bins Number of bins.
#' @param binning `"quantile"` for bins holding equal numbers of observations,
#'   or `"width"` for bins of equal width across `[0, 1]`. See Details.
#' @param folds Optional fold identifiers, one per row of `newdata`. Binning is
#'   done within each fold. Using folds emits a note about what cross-validated
#'   metrics are evidence of.
#' @param level Level for the interval on each bin's observed frequency.
#' @param ... Passed to [stats::predict()].
#'
#' @details
#' Calibration is a different question from discrimination, and a model can be
#' good at one and bad at the other. AUC only cares whether presences are
#' ranked above absences, so it is unchanged by any monotone rescaling of the
#' predictions -- a model can have an excellent AUC while every probability it
#' reports is far too high. If those probabilities feed a decision, an area
#' calculation, or an expected count, calibration is the property that matters
#' and AUC will not reveal it.
#'
#' `binning` trades two problems against each other. Equal-width bins are easy
#' to read but leave the extremes nearly empty, which is exactly where
#' miscalibration shows up, so the noisiest points sit where the interesting
#' behaviour is. Quantile bins put the same number of observations in each,
#' making every point equally reliable, at the cost of bins whose widths vary.
#' Quantile is the default for that reason. The rug drawn by
#' [plotCalibration()] shows which regime you are in.
#'
#' The interval on each bin is a Wilson score interval, not a normal
#' approximation. With few observations in a bin, or an observed frequency near
#' 0 or 1 -- both routine here -- the normal approximation produces bounds
#' outside `[0, 1]`, which would be a plot claiming something impossible.
#'
#' The `"calibration"` attribute holds the intercept and slope from regressing
#' the outcome on the logit of the prediction. A perfectly calibrated model
#' gives intercept 0 and slope 1. A slope below 1 means predictions are too
#' extreme -- too close to 0 and 1 -- which is the usual signature of a model
#' fitted on too little data for its flexibility.
#'
#' @return A data frame with one row per bin: `.bin`, `.predicted`,
#'   `.observed`, `.lower`, `.upper`, `.n`, and `.fold` when folds were
#'   supplied. Carries attributes `calibration`, `brier`, `n` and `in.sample`.
#'
#' @family evaluation plots
#' @seealso [plotCalibration()] to draw it, [threshold_metrics()] for
#'   discrimination.
#'
#' @references
#' Harrell, F. E. (2015). *Regression Modeling Strategies* (2nd ed.). Springer.
#' \doi{10.1007/978-3-319-19425-7}
#'
#' @examples
#' set.seed(1)
#' dat <- data.frame(x1 = runif(600, 1, 10), x2 = runif(600, 1, 10))
#' dat$y <- rbinom(600, 1, plogis(-3 + 0.6 * dat$x1))
#'
#' fit <- glm(y ~ x1 + x2, data = dat[1:300, ], family = binomial)
#' cal <- calibration_estimates(fit, dat[301:600, ])
#'
#' attr(cal, "calibration")   # intercept 0 and slope 1 would be perfect
#' attr(cal, "brier")
#'
#' @export
calibration_estimates <- function(model, newdata, bins = 10,
                                  binning = c("quantile", "width"),
                                  folds = NULL, level = 0.95, ...) {
  if (missing(newdata) || is.null(newdata)) {
    stop("newdata is required: a model scored against the data it was fitted ",
         "to flatters itself. Supply held-out data, or the training data ",
         "explicitly if that is genuinely what you want.", call. = FALSE)
  }
  newdata <- as.data.frame(newdata)
  model <- unwrap_gam(model)

  binning <- check_choice(binning, c("quantile", "width"), "binning")
  check_level(level)
  if (!is.numeric(bins) || length(bins) != 1 || bins < 2) {
    stop("bins must be a single number of at least 2, not: ",
         paste(format(bins), collapse = ", "), call. = FALSE)
  }

  pairs <- evaluation_pairs(model, newdata, folds, ...)
  observed <- pairs$observed
  predicted <- pairs$predicted

  if (!is.null(pairs$folds)) {
    note_cv_folds()
    fold.values <- factor(pairs$folds[pairs$complete])
    parts <- split(seq_along(observed), fold.values)
    out <- do.call(rbind, lapply(names(parts), function(f) {
      i <- parts[[f]]
      cbind(bin_calibration(observed[i], predicted[i], bins, binning, level),
            .fold = factor(f, levels = names(parts)))
    }))
  } else {
    out <- bin_calibration(observed, predicted, bins, binning, level)
  }

  rownames(out) <- NULL
  attr(out, "calibration") <- calibration_fit(observed, predicted)
  # Brier is the mean squared error of the probabilities: one number covering
  # calibration and discrimination together, lower being better.
  attr(out, "brier") <- mean((predicted - observed)^2)
  attr(out, "n") <- length(observed)
  attr(out, "in.sample") <- pairs$in.sample
  out
}

#' Bin predictions and count how often the outcome occurred
#'
#' @param observed 0/1 numeric vector.
#' @param predicted Numeric vector of predicted probabilities.
#' @param bins Number of bins.
#' @param binning `"quantile"` or `"width"`.
#' @param level Level for the Wilson interval.
#' @return A data frame, one row per non-empty bin.
#' @keywords internal
bin_calibration <- function(observed, predicted, bins, binning, level) {
  breaks <- if (binning == "width") {
    seq(0, 1, length.out = bins + 1)
  } else {
    # Ties can collapse quantiles onto each other, leaving fewer bins than
    # asked for. That is better than empty bins, so it is allowed rather than
    # forced.
    unique(stats::quantile(predicted, probs = seq(0, 1, length.out = bins + 1),
                           na.rm = TRUE))
  }
  if (length(breaks) < 2) {
    stop("Predictions do not vary enough to form calibration bins.",
         call. = FALSE)
  }
  breaks[1] <- min(breaks[1], min(predicted)) - 1e-8
  breaks[length(breaks)] <- max(breaks[length(breaks)], max(predicted)) + 1e-8

  cut.bin <- cut(predicted, breaks = breaks, include.lowest = TRUE)
  parts <- split(seq_along(predicted), cut.bin)
  parts <- parts[lengths(parts) > 0]

  do.call(rbind, lapply(names(parts), function(b) {
    i <- parts[[b]]
    k <- sum(observed[i])
    n <- length(i)
    interval <- wilson_interval(k, n, level)
    data.frame(.bin = b,
               .predicted = mean(predicted[i]),
               .observed = k / n,
               .lower = interval[1],
               .upper = interval[2],
               .n = n)
  }))
}

#' Wilson score interval for a binomial proportion
#'
#' Used in place of a normal approximation, which with few observations or a
#' proportion near 0 or 1 -- both routine in a calibration bin -- produces
#' bounds outside `[0, 1]`.
#'
#' @param k Number of successes.
#' @param n Number of trials.
#' @param level Confidence level.
#' @return A length-2 numeric vector.
#' @keywords internal
wilson_interval <- function(k, n, level) {
  if (!n) return(c(NA_real_, NA_real_))
  z <- stats::qnorm(1 - (1 - level) / 2)
  p <- k / n
  denominator <- 1 + z^2 / n
  centre <- (p + z^2 / (2 * n)) / denominator
  half.width <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / denominator
  c(max(0, centre - half.width), min(1, centre + half.width))
}

#' Calibration intercept and slope
#'
#' Regresses the outcome on the logit of the prediction. Intercept 0 and slope
#' 1 is perfect; a slope below 1 means the predictions are too extreme.
#'
#' @param observed 0/1 numeric vector.
#' @param predicted Numeric vector of predicted probabilities.
#' @return A named numeric vector, or `NA`s if the fit fails.
#' @keywords internal
calibration_fit <- function(observed, predicted) {
  # Predictions of exactly 0 or 1 have infinite logit, which no regression can
  # use. Nudged inside the open interval rather than dropped, so a confident
  # model does not silently lose its most extreme cases.
  eps <- 1e-10
  logit.p <- stats::qlogis(pmin(pmax(predicted, eps), 1 - eps))

  fit <- tryCatch(
    suppressWarnings(stats::glm(observed ~ logit.p, family = stats::binomial)),
    error = function(e) NULL
  )
  if (is.null(fit)) return(c(intercept = NA_real_, slope = NA_real_))

  coefficients <- stats::coef(fit)
  c(intercept = unname(coefficients[1]), slope = unname(coefficients[2]))
}

#' Plot a calibration curve with a rug of where predictions fall
#'
#' Binned predictions against observed frequency, with the diagonal as the
#' reference: a model that says 0.7 should be right about 70% of the time. The
#' rug above shows where the predictions actually are, which is what tells you
#' whether a bin near the extremes is worth reading at all.
#'
#' @param model A fitted presence/absence model.
#' @param newdata Data to evaluate on. Required; see [threshold_metrics()].
#' @param bins Number of bins.
#' @param binning `"quantile"` (the default) or `"width"`.
#' @param folds Optional fold identifiers, one per row of `newdata`.
#' @param level Level for the interval on each bin.
#' @param title Plot title, optional.
#' @param show.stats Whether to report the calibration intercept and slope on
#'   the plot.
#' @param rug.type Type of rug drawn above the curve.
#' @param rug.bins Number of bins for a histogram rug.
#' @param theme A \pkg{ggplot2} theme. Defaults to [theme_fancyfx()].
#' @param palette Colours used for fold curves. Defaults to
#'   [fancyfx_palette()].
#' @param colour Colour of the curve when there are no folds.
#' @param ... Passed to [calibration_estimates()] and on to [stats::predict()].
#'
#' @details
#' The rug is the same idea as in [plotEffects()], and matters more here than
#' almost anywhere else. Calibration is usually worst at the extremes, and the
#' extremes are usually where the fewest predictions are, so the most
#' eye-catching departures from the diagonal are often the least trustworthy
#' points on the plot. The rug shows that directly, and the interval on each
#' bin shows it again.
#'
#' See [calibration_estimates()] for why quantile binning is the default, and
#' for what the reported intercept and slope mean.
#'
#' @return A `patchwork` object: the rug above, the calibration curve below.
#'
#' @family evaluation plots
#' @seealso [calibration_estimates()] for the numbers, [plotROC()] for
#'   discrimination, which is a different question.
#'
#' @examples
#' set.seed(1)
#' dat <- data.frame(x1 = runif(600, 1, 10), x2 = runif(600, 1, 10))
#' dat$y <- rbinom(600, 1, plogis(-3 + 0.6 * dat$x1))
#'
#' fit <- glm(y ~ x1 + x2, data = dat[1:300, ], family = binomial)
#' plotCalibration(fit, dat[301:600, ])
#'
#' @export
plotCalibration <- function(model, newdata, bins = 10,
                            binning = c("quantile", "width"),
                            folds = NULL, level = 0.95,
                            title = "", show.stats = TRUE,
                            rug.type = c("histogram", "density"),
                            rug.bins = 30,
                            theme = theme_fancyfx(),
                            palette = fancyfx_palette(),
                            colour = fancyfx_palette(1),
                            ...) {

  rug.type <- check_choice(rug.type, c("histogram", "density"), "type")

  cal <- calibration_estimates(model, newdata, bins = bins, binning = binning,
                               folds = folds, level = level, ...)
  grouped <- ".fold" %in% names(cal)

  curve <- ggplot2::ggplot(cal, ggplot2::aes(x = .data$.predicted,
                                             y = .data$.observed)) +
    # Perfect calibration. Drawn first so the data sits over it.
    ggplot2::geom_abline(slope = 1, intercept = 0,
                         linetype = "dashed", colour = "grey60") +
    ggplot2::labs(x = "Predicted probability",
                  y = "Observed frequency",
                  caption = in_sample_caption(attr(cal, "in.sample"))) +
    ggplot2::coord_equal(xlim = c(0, 1), ylim = c(0, 1), expand = FALSE) +
    theme

  if (grouped) {
    n.folds <- nlevels(cal$.fold)
    curve <- curve +
      ggplot2::geom_line(ggplot2::aes(colour = .data$.fold,
                                      group = .data$.fold), alpha = 0.8) +
      ggplot2::geom_point(ggplot2::aes(colour = .data$.fold), size = 1.6) +
      ggplot2::labs(colour = "Fold")
    if (n.folds <= length(palette)) {
      curve <- curve +
        ggplot2::scale_colour_manual(values = palette[seq_len(n.folds)])
    }
  } else {
    curve <- curve +
      # The interval comes before the points so the points stay readable.
      ggplot2::geom_linerange(ggplot2::aes(ymin = .data$.lower,
                                           ymax = .data$.upper),
                              colour = colour, alpha = 0.7) +
      ggplot2::geom_line(colour = colour, alpha = 0.8) +
      ggplot2::geom_point(colour = colour, size = 2)
  }

  if (show.stats) {
    curve <- curve + ggplot2::annotate(
      "text", x = 0.03, y = 0.97, hjust = 0, vjust = 1,
      label = calibration_label(attr(cal, "calibration"), attr(cal, "brier")))
  }

  if (nzchar(title)) curve <- curve + ggplot2::ggtitle(title)

  # The rug is of the predictions themselves, so it shares the curve's x axis:
  # it shows which parts of [0, 1] the model actually uses.
  rug.data <- data.frame(.predicted = predicted_for_rug(model, newdata, ...))
  rug <- plotRugs(dat = rug.data, var = ".predicted", type = rug.type,
                  bins = rug.bins) +
    ggplot2::coord_cartesian(xlim = c(0, 1), expand = FALSE)

  list(rug, curve) |> patchwork::wrap_plots(nrow = 2, heights = c(1, 5))
}

#' Predictions for the rug beneath a calibration curve
#'
#' @param model A fitted model.
#' @param newdata Data to predict over.
#' @param ... Passed to [stats::predict()].
#' @return A numeric vector of predicted probabilities.
#' @keywords internal
predicted_for_rug <- function(model, newdata, ...) {
  predicted <- predict_probability(unwrap_gam(model), as.data.frame(newdata),
                                   ...)
  predicted[!is.na(predicted)]
}

#' Format the calibration statistics for display
#'
#' @param calibration Named vector with `intercept` and `slope`.
#' @param brier The Brier score.
#' @return A single label string.
#' @keywords internal
calibration_label <- function(calibration, brier) {
  if (anyNA(calibration)) {
    return(paste0("Brier = ", format(round(brier, 3), nsmall = 3)))
  }
  paste0("Intercept = ", format(round(calibration[["intercept"]], 2), nsmall = 2),
         "  Slope = ", format(round(calibration[["slope"]], 2), nsmall = 2),
         "\nBrier = ", format(round(brier, 3), nsmall = 3))
}
