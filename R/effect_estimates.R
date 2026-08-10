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
#' @param interval `"auto"` (the default), `"se"` for a `+/- 1` standard error
#'   ribbon, or `"ci"` for an interval at `level`. `"auto"` gives the SE ribbon
#'   except for Bayesian fits, which report no standard error and get their
#'   credible interval. `"cri"` is another name for `"ci"`.
#' @param level Interval level, used when `interval = "ci"`.
#' @param n Number of points at which to evaluate the effect.
#' @param re.form For a mixed model, which random effects to include. `NA` (the
#'   default) gives the population-level effect; `NULL` includes all of them.
#'   Not forwarded to models without random effects, which would reject it.
#'   Note that standard errors cover the fixed effects only either way.
#' @param ... Passed to the underlying backend
#'   ([gratia::smooth_estimates()] or [marginaleffects::predictions()]).
#'
#' @details
#' Two backends, because the two quantities they produce are not the same thing:
#'
#' * **GAMs on the link scale** go to [gratia::smooth_estimates()], which
#'   returns the *partial effect* of the smooth: the term's own contribution,
#'   centered so it averages to zero, with the rest of the model excluded. This
#'   is what this package drew before it handled anything but GAMs.
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
                             scale = c("auto", "link", "response"),
                             interval = c("auto", "se", "ci", "cri"),
                             level = 0.95,
                             n = 100,
                             ...) {
  UseMethod("effect_estimates")
}

#' @rdname effect_estimates
#' @export
effect_estimates.gam <- function(model, var,
                                 scale = c("auto", "link", "response"),
                                 interval = c("auto", "se", "ci", "cri"),
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
  # gratia always reports a standard error, so the historical ribbon is always
  # available on this path.
  if (interval == "auto") interval <- "se"

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
    quantity = "Partial Effect",
    group = smooth_group(est)
  )
}

#' Identify the factor a set of smooths is split by
#'
#' A factor-smooth interaction -- `s(x, by = f)` -- is one smooth per level of
#' `f`, and `gratia` returns them stacked in a single frame. Without separating
#' them, `geom_line()` joins the end of one level's curve to the start of the
#' next and draws a zigzag that looks like a single wildly varying smooth.
#'
#' @param est A `gratia::smooth_estimates()` frame, as a data frame.
#' @return A factor of level labels, or `NULL` when the smooth is not split.
#' @keywords internal
smooth_group <- function(est) {
  # gratia names the by-variable in .by, and carries its values in a column of
  # that name. .by is NA for an ordinary smooth.
  if (!(".by" %in% names(est))) return(NULL)
  by.var <- unique(stats::na.omit(est$.by))
  if (length(by.var) != 1 || !(by.var %in% names(est))) return(NULL)

  out <- factor(est[[by.var]])
  # Carried so the legend can be titled with the factor's own name rather than
  # the internal ".group".
  attr(out, "label") <- by.var
  out
}

#' @rdname effect_estimates
#' @export
effect_estimates.default <- function(model, var,
                                     scale = c("auto", "link", "response"),
                                     interval = c("auto", "se", "ci", "cri"),
                                     level = 0.95,
                                     n = 100,
                                     re.form = NA,
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

  # A model summarised from posterior draws reports an interval and no standard
  # error, so a +/- 1 SE ribbon is not something it can produce. "auto" asks for
  # the credible interval there and keeps this package's historical SE ribbon
  # everywhere else.
  if (interval == "auto") {
    interval <- if (is_posterior_model(model)) "ci" else "se"
  }

  # re.form is meaningless to a model with no random effects, and passing it
  # to one is an error rather than a no-op, so it is only forwarded when the
  # model actually has them -- under whichever name the class expects.
  if (has_random_effects(model)) {
    re.args <- list(re.form)
    names(re.args) <- re_form_arg(model)
    est <- do.call(predict_on_scale,
                   c(list(model, newdata, scale, interval, level),
                     re.args, list(...)))
  } else {
    est <- predict_on_scale(model, newdata, scale, interval, level, ...)
  }
  est <- as.data.frame(est)

  # marginaleffects reports an interval whatever we asked for, so a "se" ribbon
  # is rebuilt from std.error rather than read off conf.low/high.
  if (interval == "se" && !("std.error" %in% names(est))) {
    # Reached when a class not recognised as Bayesian still summarises from
    # draws. Falling back is more useful than failing, but it changes what the
    # ribbon means, so it is said out loud rather than done quietly.
    message("This model reports no standard error, so the ribbon shows the ",
            level * 100, "% interval rather than +/- 1 SE.")
    interval <- "ci"
  }

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
  dots <- list(...)
  # marginaleffects warns that its standard errors cover only fixed-effect
  # uncertainty, and says so is "often appropriate when re.form=NA" -- which is
  # exactly the case we default to. Firing that on every panel of every plot is
  # noise, so it is muffled only when re.form is in fact NA. A caller who sets
  # re.form to anything else still hears it, which is when it matters.
  re.given <- dots[intersect(names(dots), c("re.form", "re_formula"))]
  re.name <- names(re.given)
  quiet <- length(re.given) == 1 && length(re.given[[1]]) == 1 &&
    is.na(re.given[[1]])

  # marginaleffects keeps a whitelist of arguments it knows each model class
  # accepts and warns about anything outside it, but the list is incomplete:
  # rstanarm's own posterior_epred() documents the re.form being passed here.
  # The complaint is about the argument *name*, which this package always
  # supplies itself, so it is muffled whatever value the caller chose -- the
  # warning carries no information the caller could act on.
  ours_unrecognised <- function(w) {
    length(re.name) == 1 &&
      grepl("are not known to be supported", conditionMessage(w), fixed = TRUE) &&
      grepl(re.name, conditionMessage(w), fixed = TRUE)
  }
  fixed_effects_only <- function(w) {
    quiet && grepl("only takes into account the uncertainty in fixed-effect",
                   conditionMessage(w), fixed = TRUE)
  }

  predict_with <- function(type) {
    call_backend <- function() {
      marginaleffects::predictions(model, newdata = newdata, type = type,
                                   conf_level = level, ...)
    }
    if (!length(re.name)) return(call_backend())
    withCallingHandlers(call_backend(), warning = function(w) {
      if (fixed_effects_only(w) || ours_unrecognised(w)) {
        invokeRestart("muffleWarning")
      }
    })
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
#' @param group Optional factor splitting the effect into separate curves, as
#'   for a factor-smooth interaction. `NULL` for a single curve.
#' @return A data frame ordered by `.x` within `.group`, with `quantity`
#'   attached.
#' @keywords internal
standardize_effect <- function(x, estimate, lower, upper, quantity,
                               group = NULL) {
  out <- data.frame(.x = x, .estimate = estimate,
                    .lower = lower, .upper = upper)
  group.label <- attr(group, "label")
  if (!is.null(group)) out$.group <- group

  # Sorted because geom_line() connects points in row order, and a backend that
  # returned an unsorted grid would draw a curve that doubles back on itself.
  # Within group, so separate curves are not interleaved.
  out <- if (is.null(group)) {
    out[order(out$.x), , drop = FALSE]
  } else {
    out[order(out$.group, out$.x), , drop = FALSE]
  }
  rownames(out) <- NULL
  attr(out, "quantity") <- quantity
  attr(out, "group.label") <- group.label
  out
}

#' Does this model have random effects?
#'
#' Checked by class rather than by inspecting the fit, because the answer is
#' needed before any prediction is attempted. Covers the mixed-model packages
#' \pkg{marginaleffects} supports and this package has been tested against.
#'
#' @param model A fitted model.
#' @return `TRUE` for a mixed model, `FALSE` otherwise.
#' @keywords internal
has_random_effects <- function(model) {
  inherits(model, c("merMod", "lmerMod", "glmerMod", "nlmerMod", "lmerModLmerTest",
                    "glmmTMB", "lme", "nlme", "glmmadmb", "MixMod",
                    "brmsfit", "stanreg"))
}

#' Is this model summarised from posterior draws?
#'
#' Such models report an interval computed from the draws and no standard
#' error, so a `+/- 1 SE` ribbon is not something they can produce.
#'
#' @param model A fitted model.
#' @return `TRUE` for a Bayesian fit, `FALSE` otherwise.
#' @keywords internal
is_posterior_model <- function(model) {
  inherits(model, c("brmsfit", "stanreg", "stanfit"))
}

#' Name of the random-effects argument for this model class
#'
#' \pkg{brms} calls it `re_formula`; \pkg{lme4}, \pkg{glmmTMB} and
#' \pkg{rstanarm} call it `re.form`. Passing the wrong one to a `brmsfit` still
#' reaches the prediction function, but `marginaleffects` warns that the
#' argument is not one it recognises for the class -- noise on every panel, and
#' a sign the call is relying on something not guaranteed to keep working.
#'
#' @param model A fitted model.
#' @return The argument name, as a string.
#' @keywords internal
re_form_arg <- function(model) {
  if (inherits(model, "brmsfit")) "re_formula" else "re.form"
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
