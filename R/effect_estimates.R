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
#'   ribbon, or `"ci"` for an interval at `level`. `"auto"` gives a pointwise
#'   interval at `level`, 95% by default. `"cri"` is another name for `"ci"`.
#' @param level Interval level, used when `interval = "ci"`.
#' @param n Number of points at which to evaluate the effect.
#' @param data Optional data frame to take the predictor's range from, for
#'   models that do not keep the data they were fitted on -- a `gbm`, for
#'   instance. [plotEffects()] passes the `dat` it was given.
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
                             data = NULL,
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
  # A 95% interval, matching mgcv::plot.gam (which draws +/- 2 SE) and
  # gratia::draw() (which draws 95%). This package once drew +/- 1 SE, about
  # 68% -- half the width of both -- and a reader seeing a ribbon on a smooth
  # will assume 95%. interval = "se" still gives the narrow band, explicitly.
  if (interval == "auto") interval <- "ci"

  # A partial effect is centered on zero and lives on the link scale by
  # construction; there is nothing coherent to hand back for "response" here.
  # Predictions are what the user actually wants in that case, so fall through
  # to the general backend rather than erroring or, worse, exponentiating a
  # centered term and calling the result a response-scale effect.
  if (scale == "response") {
    return(NextMethod())
  }

  partial_effect(model, var, interval, level, ...)
}

#' @rdname effect_estimates
#' @export
effect_estimates.scam <- function(model, var,
                                  scale = c("auto", "link", "response"),
                                  interval = c("auto", "se", "ci", "cri"),
                                  level = 0.95,
                                  n = 100,
                                  ...) {
  # A shape-constrained GAM is a GAM, and gratia reports its smooths, but scam
  # objects inherit from glm rather than gam -- so without this method they
  # would fall through to the prediction backend and quietly report a different
  # quantity than every other GAM in the package.
  scale <- check_scale(scale)
  interval <- check_interval(interval)
  check_level(level)

  if (scale == "auto") scale <- "link"
  if (interval == "auto") interval <- "ci"

  if (scale == "response") {
    return(NextMethod())
  }

  partial_effect(model, var, interval, level, ...)
}

#' @rdname effect_estimates
#' @export
effect_estimates.gamm4 <- function(model, var, ...) {
  effect_estimates(unwrap_gam(model), var, ...)
}

#' @rdname effect_estimates
#' @export
effect_estimates.gamm <- function(model, var, ...) {
  effect_estimates(unwrap_gam(model), var, ...)
}

#' The partial effect of a smooth, via gratia
#'
#' Shared by every model class \pkg{gratia} can report smooths for, so those
#' classes cannot drift apart in what they compute or how they fail.
#'
#' @param model A fitted model gratia understands.
#' @param var Name of the smoothed predictor.
#' @param interval `"se"` or `"ci"` (already resolved).
#' @param level Interval level.
#' @param ... Passed to [gratia::smooth_estimates()].
#' @return A standardized effect frame.
#' @keywords internal
partial_effect <- function(model, var, interval, level, nsim = 10000,
                           seed = 1, ...) {
  if (interval == "simultaneous") {
    return(simultaneous_effect(model, var, level, nsim, seed, ...))
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

  # partial_match is substring matching, so select = "x1" also picks up a
  # smooth of x11, and the two arrive concatenated -- drawn as one curve that
  # jumps between them. Filtered on a word boundary instead. A factor-smooth
  # interaction still keeps all its levels, since s(x):fa and s(x):fb both
  # match the variable as a whole word.
  wanted <- smooth_labels(model, var)
  if (".smooth" %in% names(est)) {
    est <- est[est$.smooth %in% wanted, , drop = FALSE]
  }
  if (!nrow(est)) {
    stop("No smooth of '", var, "' found in the model.", call. = FALSE)
  }

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

#' A simultaneous confidence band for a smooth
#'
#' A pointwise interval covers the true value at each x separately, with the
#' stated probability at each one. It does not cover the whole curve with that
#' probability -- across a smooth evaluated at a hundred points, the true
#' function will stray outside a pointwise 95% band far more often than 5% of
#' the time. Any claim about the *shape* of a smooth, which is usually the
#' reason for drawing one, is a claim about the whole curve, and wants a band
#' that covers the whole curve.
#'
#' @param model A fitted model gratia understands.
#' @param var Name of the smoothed predictor.
#' @param level Interval level.
#' @param nsim Number of posterior simulations used to find the critical value.
#' @param seed Random seed. The band is simulated, so an unseeded figure cannot
#'   be redrawn exactly.
#' @param ... Passed to [gratia::confint.gam()].
#' @return A standardized effect frame.
#' @keywords internal
simultaneous_effect <- function(model, var, level, nsim, seed, ...) {
  # Seeded and restored, as in permutation_importance(): a simulated band that
  # moves between runs cannot be checked by a reader, and silently resetting
  # the caller's stream would change results elsewhere in their script.
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

  # gratia's confint() wants the smooth's label -- "s(x1)" -- where
  # smooth_estimates() accepts the bare variable name. Handing it "x1" fails
  # with "argument of length 0", which says nothing about what went wrong, so
  # the label is resolved here first.
  est <- stats::confint(model, parm = smooth_labels(model, var),
                        type = "simultaneous", level = level, nsim = nsim, ...)
  est <- as.data.frame(est)

  standardize_effect(
    x = est[[var]],
    estimate = est$.estimate,
    lower = est$.lower_ci,
    upper = est$.upper_ci,
    quantity = "Partial Effect",
    group = smooth_group(est)
  )
}

#' Smooth labels involving a given variable
#'
#' A factor-smooth interaction contributes several labels for one variable --
#' `s(x):fa`, `s(x):fb` and so on -- so this returns all of them.
#'
#' @param model A fitted model gratia understands.
#' @param var Name of the smoothed predictor.
#' @return A character vector of smooth labels.
#' @keywords internal
smooth_labels <- function(model, var) {
  available <- tryCatch(gratia::smooths(model), error = function(e) NULL)
  if (!length(available)) {
    stop("Could not read the smooths of this model.", call. = FALSE)
  }

  # Word boundaries, so asking for "x" does not match a smooth of "x1".
  matched <- available[grepl(paste0("\\b", var, "\\b"), available)]
  if (!length(matched)) {
    stop("No smooth of '", var, "' found in the model (available: ",
         paste(available, collapse = ", "), ").", call. = FALSE)
  }
  matched
}

#' Unwrap a fitted object that carries its GAM in a list element
#'
#' `gamm4::gamm4()` and `mgcv::gamm()` return a list holding the GAM alongside
#' the mixed-model fit it was estimated through, rather than a fitted model
#' object. Nothing downstream can use the wrapper: `marginaleffects` refuses the
#' class outright, and `formula()` and `predict()` both fail on it. The `$gam`
#' element is an ordinary `gam`, so unwrapping makes every path work at once.
#'
#' The random effects are left behind with the wrapper. That is the right
#' default and matches the rest of the package -- the smooth is reported at the
#' population level -- but it does mean the ribbon covers uncertainty in the
#' smooth alone.
#'
#' @param model A fitted model, wrapped or not.
#' @return The `$gam` element when there is one, otherwise `model` unchanged.
#' @keywords internal
unwrap_gam <- function(model) {
  if (!is.list(model) || is.null(model$gam) || !inherits(model$gam, "gam")) {
    return(model)
  }
  inner <- model$gam

  # The unwrapped fit carries class "gam" alone, where one from mgcv::gam()
  # carries c("gam", "glm", "lm"). marginaleffects dispatches on the full
  # inheritance and refuses the truncated form outright, so predictions would
  # be unavailable for exactly these two wrappers and no other GAM.
  #
  # Restoring the classes is safe rather than a fudge: marginaleffects reaches
  # mgcv's own predict() for a gam either way. Estimates come back identical to
  # calling predict(se.fit = TRUE) directly, and standard errors agree to about
  # 1e-7 relative -- marginaleffects differentiates numerically for the delta
  # method, so the last digits differ. The tests assert this rather than taking
  # it on trust.
  if (identical(class(inner), "gam")) {
    class(inner) <- c("gam", "glm", "lm")
  }
  inner
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
                                     data = NULL,
                                     re.form = NA,
                                     ...) {
  # NextMethod() from the gam method arrives with these already checked and
  # collapsed to a single value; checking again is harmless and keeps this
  # method correct when called directly.
  scale <- check_scale(scale)
  interval <- check_interval(interval)
  check_level(level)

  if (interval == "simultaneous") {
    stop("A simultaneous band is available for GAM partial effects only, ",
         "where gratia can simulate from the posterior of the smooth. This ",
         "model of class <", paste(class(model), collapse = "/"), "> is shown ",
         "as predictions instead; use interval = \"ci\" for a pointwise ",
         "interval.", call. = FALSE)
  }

  # Predictions are naturally reported on the response scale, and it is the one
  # type every model class supports -- a Gaussian lm, for instance, refuses
  # "link" outright.
  if (scale == "auto") scale <- "response"

  obs <- model_variable(model, var, data)
  grid <- seq(min(obs, na.rm = TRUE), max(obs, na.rm = TRUE), length.out = n)

  # Built with do.call rather than tidyeval: `var` is a plain string, and
  # do.call keeps this readable without pulling `:=` into the namespace.
  grid.args <- list(model = model)
  grid.args[[var]] <- grid
  if (!is.null(data)) grid.args$newdata <- as.data.frame(data)
  newdata <- do.call(marginaleffects::datagrid, grid.args)

  # A model summarised from posterior draws reports an interval and no standard
  # error, so a +/- 1 SE ribbon is not something it can produce. "auto" asks for
  # the credible interval there and keeps this package's historical SE ribbon
  # everywhere else.
  # 95% throughout: a Bayesian fit reports an interval and no standard error,
  # and for every other class "ci" matches what the rest of the ecosystem draws.
  if (interval == "auto") interval <- "ci"

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
    # This is an attempt whose result may be thrown away, so its warnings are
    # held back rather than emitted. Otherwise a class that does not support
    # the bounded form warns once here and again on the real call, and the
    # caller sees the same complaint twice about one plot.
    held <- list()
    bounded <- withCallingHandlers(
      tryCatch(predict_with("invlink(link)"),
               error = function(e) {
                 if (unsupported_type(e)) NULL else stop(e)
               }),
      warning = function(w) {
        held[[length(held) + 1]] <<- w
        invokeRestart("muffleWarning")
      }
    )
    if (!is.null(bounded)) {
      # Kept after all, so anything it had to say still gets said.
      for (w in held) warning(w)
      return(bounded)
    }
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
#' @param data Optional data to fall back on when the model does not keep the
#'   frame it was fitted with.
#' @return The observed values of `var`.
#' @keywords internal
model_variable <- function(model, var, data = NULL) {
  frame <- tryCatch(stats::model.frame(model), error = function(e) NULL)

  # Not every model keeps the data it was fitted on. A gbm, for one, stores
  # only its variable names, so model.frame() fails and the range has to come
  # from somewhere else -- the data the caller already supplied for the rug.
  if ((is.null(frame) || !(var %in% names(frame))) && !is.null(data)) {
    data <- as.data.frame(data)
    if (var %in% names(data)) frame <- data
  }

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
