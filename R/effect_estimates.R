#' Extract a variable's effect from a model as a tidy data frame
#'
#' The one place in the package that knows anything about model classes.
#' Everything downstream -- the transforms, the ribbon, the rug, the panel
#' arranging -- works off the standardized frame this returns, so adding support
#' for a new kind of model means writing a method here and nothing else.
#'
#' Exported both because the tidy frame is useful on its own, and so support
#' for further model classes can be added from outside the package by writing
#' an `effect_estimates()` method.
#'
#' @param model A fitted model.
#' @param var Name of the predictor whose effect to extract, as a string.
#' @param scale `"auto"` (the default), `"link"`, or `"response"`. `"auto"`
#'   resolves to whichever is natural for the backend -- `"link"` for a GAM
#'   partial effect, `"response"` for predictions. See Details: for GAMs this
#'   chooses between two genuinely different quantities, not two axis scales.
#' @param interval `"se"` for a `+/- 1` standard error ribbon, `"ci"` for a
#'   confidence interval at `level`.
#' @param level Confidence level, used when `interval = "ci"`.
#' @param n Number of points at which to evaluate the effect.
#' @param ... Passed to the underlying backend
#'   ([gratia::smooth_estimates()] or [marginaleffects::predictions()]).
#'
#' @details
#' Two backends, because the two quantities they produce are not the same thing:
#'
#' * **GAMs on the link scale** go to [gratia::smooth_estimates()], which
#'   returns the *partial effect* of the smooth: the term's own contribution,
#'   centered so it averages to zero, with the rest of the model excluded. This
#'   is what `fancygam`, this package's predecessor, always plotted.
#' * **Everything else** goes to [marginaleffects::predictions()], which returns
#'   *predicted values* -- the model's actual fitted output as `var` varies,
#'   with the other predictors held at representative values (means for numeric
#'   predictors, modes for factors).
#'
#' A centered partial effect has no meaningful back-transformation to the
#' response scale on its own, so asking a GAM for `scale = "response"` gives you
#' predictions rather than an incoherent partial effect. The returned frame
#' carries a `"quantity"` attribute recording which of the two you got, and
#' [plotEffects()] uses it to label the y axis honestly.
#'
#' @return A data frame with four columns -- `.x`, `.estimate`, `.lower`,
#'   `.upper` -- and a `"quantity"` attribute naming what was computed, which
#'   [plotEffects()] uses to label the y axis.
#'
#' @seealso [plotEffects()], which turns this into a plot.
#'
#' @examples
#' gam.fit <- mgcv::gam(Petal.Length ~ s(Sepal.Length), data = iris)
#' est <- effect_estimates(gam.fit, "Sepal.Length")
#' head(est)
#' attr(est, "quantity")
#'
#' # The same call against a model of any other class
#' lm.fit <- lm(Petal.Length ~ Sepal.Length + Species, data = iris)
#' head(effect_estimates(lm.fit, "Sepal.Length"))
#'
#' # Useful on its own if you would rather build the plot yourself
#' ggplot2::ggplot(est, ggplot2::aes(.data$.x, .data$.estimate)) +
#'   ggplot2::geom_line()
#'
#' @export
effect_estimates <- function(model, var,
                             scale = c("link", "response"),
                             interval = c("se", "ci"),
                             level = 0.95,
                             n = 100,
                             ...) {
  UseMethod("effect_estimates")
}

#' @rdname effect_estimates
#' @export
effect_estimates.gam <- function(model, var,
                                 scale = c("auto", "link", "response"),
                                 interval = c("se", "ci"),
                                 level = 0.95,
                                 n = 100,
                                 ...) {
  scale <- check_scale(scale)
  interval <- check_interval(interval)
  check_level(level)

  # The natural quantity for a GAM is the partial effect, which lives on the
  # link scale. This is also what this package drew before it handled anything
  # but GAMs, so "auto" keeps old code producing identical plots.
  if (scale == "auto") scale <- "link"

  # A partial effect is centered on zero and lives on the link scale by
  # construction; there is nothing coherent to hand back for "response" here.
  # Predictions are what the user actually wants in that case, so fall through
  # to the general backend rather than erroring or, worse, exponentiating a
  # centered term and calling the result a response-scale effect.
  if (scale == "response") {
    return(NextMethod())
  }

  # gratia raises its own error for a name it cannot match, and suggests
  # partial_match = TRUE -- advice that cannot help here, since we already pass
  # it. Say what is actually wrong and list what the model does offer.
  est <- tryCatch(
    gratia::smooth_estimates(model, select = var, dist = 0.1,
                             partial_match = TRUE, ...),
    error = function(e) {
      if (grepl("match any smooths", conditionMessage(e))) {
        available <- tryCatch(gratia::smooths(model), error = function(e) NULL)
        stop("No smooth of '", var, "' found in the model",
             if (length(available)) {
               paste0(" (available: ", paste(available, collapse = ", "), ")")
             },
             ". For a term the model treats parametrically rather than as a ",
             "smooth, use scale = \"response\" to plot its predictions.",
             call. = FALSE)
      }
      stop(e)
    }
  )
  est <- as.data.frame(est)

  mult <- if (interval == "se") 1 else stats::qnorm(1 - (1 - level) / 2)

  standardize_effect(
    x = est[[var]],
    estimate = est$.estimate,
    lower = est$.estimate - mult * est$.se,
    upper = est$.estimate + mult * est$.se,
    quantity = "Partial Effect"
  )
}

#' @rdname effect_estimates
#' @export
effect_estimates.default <- function(model, var,
                                     scale = c("auto", "link", "response"),
                                     interval = c("se", "ci"),
                                     level = 0.95,
                                     n = 100,
                                     ...) {
  # NextMethod() from the gam method arrives with these already checked and
  # collapsed to a single value; checking again is harmless and keeps this
  # method correct when called directly.
  scale <- check_scale(scale)
  interval <- check_interval(interval)
  check_level(level)

  # Predictions are naturally reported on the response scale, and it is the one
  # type every model class supports -- a Gaussian lm, for instance, refuses
  # "link" outright.
  if (scale == "auto") scale <- "response"

  obs <- model_variable(model, var)
  grid <- seq(min(obs, na.rm = TRUE), max(obs, na.rm = TRUE), length.out = n)

  # Built with do.call rather than tidyeval: `var` is a plain string, and
  # do.call keeps this readable without pulling `:=` into the namespace.
  grid.args <- list(model = model)
  grid.args[[var]] <- grid
  newdata <- do.call(marginaleffects::datagrid, grid.args)

  est <- as.data.frame(
    predict_on_scale(model, newdata, scale, interval, level, ...)
  )

  # marginaleffects reports a confidence interval whatever we asked for, so a
  # "se" ribbon is rebuilt from std.error rather than read off conf.low/high.
  if (interval == "se") {
    lower <- est$estimate - est$std.error
    upper <- est$estimate + est$std.error
  } else {
    lower <- est$conf.low
    upper <- est$conf.high
  }

  standardize_effect(
    x = est[[var]],
    estimate = est$estimate,
    lower = lower,
    upper = upper,
    quantity = if (scale == "link") "Predicted Value (link scale)" else "Predicted Value"
  )
}

#' Ask marginaleffects for predictions on a given scale
#'
#' Wraps the backend call for two reasons: to prefer an interval construction
#' that respects the bounds of the response, and to turn the backend's
#' complaint about an unsupported scale into advice.
#'
#' @param model A fitted model.
#' @param newdata The grid to predict over.
#' @param scale `"link"` or `"response"` (already resolved from `"auto"`).
#' @param interval `"se"` or `"ci"`.
#' @param level Confidence level.
#' @param ... Passed to [marginaleffects::predictions()].
#' @return The `predictions` object.
#' @keywords internal
predict_on_scale <- function(model, newdata, scale, interval, level, ...) {
  predict_with <- function(type) {
    marginaleffects::predictions(model, newdata = newdata, type = type,
                                 conf_level = level, ...)
  }
  unsupported_type <- function(e) {
    grepl("type", conditionMessage(e), fixed = TRUE)
  }

  # Computing the interval on the link scale and back-transforming it keeps it
  # inside the range the response actually admits. Building it directly on the
  # response scale does not: a delta-method band around a fitted probability
  # near 0 or 1 runs off the end of [0, 1], which reads as the model claiming
  # something impossible. Not every model class offers this, so it is a
  # preference rather than a requirement.
  #
  # Only for interval = "ci". The back-transformed interval is asymmetric about
  # the estimate, so there is no single standard error to build a +/- 1 SE
  # ribbon from -- marginaleffects returns no std.error column at all here.
  if (scale == "response" && interval == "ci") {
    bounded <- tryCatch(predict_with("invlink(link)"),
                        error = function(e) {
                          if (unsupported_type(e)) NULL else stop(e)
                        })
    if (!is.null(bounded)) return(bounded)
  }

  tryCatch(
    predict_with(scale),
    error = function(e) {
      # A Gaussian lm, for instance, has only "response". marginaleffects
      # reports that as a bare set-membership assertion, which says nothing
      # about what the caller should do instead.
      if (unsupported_type(e)) {
        stop("scale = \"", scale, "\" is not available for a model of class <",
             paste(class(model), collapse = "/"), ">. Try scale = \"auto\".\n",
             "  Backend reported: ", conditionMessage(e), call. = FALSE)
      }
      stop(e)
    }
  )
}

#' Assemble the standardized effect frame
#'
#' @param x,estimate,lower,upper Equal-length numeric vectors.
#' @param quantity What was computed, for the y-axis label.
#' @return A data frame ordered by `.x`, with `quantity` attached.
#' @keywords internal
standardize_effect <- function(x, estimate, lower, upper, quantity) {
  out <- data.frame(.x = x, .estimate = estimate,
                    .lower = lower, .upper = upper)
  # Sorted because geom_line() connects points in row order, and a backend that
  # returned an unsorted grid would draw a curve that doubles back on itself.
  out <- out[order(out$.x), , drop = FALSE]
  rownames(out) <- NULL
  attr(out, "quantity") <- quantity
  out
}

#' Recover a predictor's observed values from a fitted model
#'
#' Used to choose the range the effect is evaluated over. Read from the model
#' rather than from the user's `dat`, so the grid can never extend past where
#' the model was actually fitted.
#'
#' @param model A fitted model.
#' @param var Name of the predictor, as a string.
#' @return The observed values of `var`.
#' @keywords internal
model_variable <- function(model, var) {
  frame <- tryCatch(stats::model.frame(model), error = function(e) NULL)

  if (is.null(frame) || !(var %in% names(frame))) {
    # model.frame() names columns by the term as written, so a model fitted with
    # log(x) has no column "x". Point at that rather than leaving the user to
    # guess why a variable they know they used cannot be found.
    stop("Could not find '", var, "' among the model's predictors",
         if (!is.null(frame)) paste0(" (", paste(names(frame), collapse = ", "), ")"),
         ". If the term was transformed in the formula, pass the name as it ",
         "appears there.", call. = FALSE)
  }

  obs <- frame[[var]]
  if (!is.numeric(obs)) {
    stop("'", var, "' is not numeric; fancyfx plots effects over a ",
         "continuous range.", call. = FALSE)
  }
  obs
}
