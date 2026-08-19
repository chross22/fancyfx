#' Permutation importance for a fitted model
#'
#' Shuffles one predictor at a time and measures how much worse the model gets.
#' Model-agnostic: it needs nothing from the model but the ability to predict,
#' so it works the same for a GAM, a GLM, a mixed model or a Bayesian fit, and
#' the numbers mean the same thing across all of them.
#'
#' @param model A fitted model.
#' @param newdata Data to measure importance on. **Required, and it should not
#'   be the data the model was fitted to** -- importance measured in-sample
#'   rewards a variable for the overfitting it enabled. See
#'   [threshold_metrics()] for the same caveat about evaluation data.
#' @param vars Predictors to permute. Defaults to every predictor in the model.
#' @param n.perm Number of permutations per variable. More is steadier and
#'   slower; the default is a reasonable compromise for a plot.
#' @param metric `"auto"`, `"auc"`, or `"rmse"`. `"auto"` picks AUC for a
#'   binary response and RMSE otherwise.
#' @param seed Random seed. Set by default because permutation importance is
#'   stochastic, and an unseeded figure cannot be reproduced.
#' @param ... Passed to [stats::predict()].
#'
#' @details
#' Importance is the loss of performance when a variable is made uninformative:
#' its column is shuffled, breaking any relationship with the response while
#' leaving its marginal distribution intact, and the model is scored again. For
#' AUC importance is the drop; for RMSE it is the increase. Either way, larger
#' means the model was relying on that variable more, and a value at or below
#' zero means the model was not using it usefully at all.
#'
#' Two things this measure does not do, both worth knowing before reading the
#' plot:
#'
#' * **Correlated predictors share credit unevenly.** If two variables carry
#'   much the same information, permuting either one alone barely hurts,
#'   because the other still carries it. Both look unimportant, and the pair is
#'   not. This bites hard on environmental covariates, which are routinely
#'   collinear.
#' * **It measures use, not effect.** A variable can be important here and have
#'   an effect too small to matter, or the reverse. Read it beside
#'   [plotEffects()], not instead of it.
#'
#' @return A data frame with one row per variable per permutation: `.variable`,
#'   `.permutation`, `.importance`. Carries attributes `metric`, `baseline`,
#'   and `in.sample`.
#'
#' @family evaluation plots
#' @seealso [plotImportance()] to draw it, [plotEffects()] for the shape of an
#'   effect rather than its weight.
#'
#' @references
#' Breiman, L. (2001). Random forests. *Machine Learning*, 45(1), 5-32.
#' \doi{10.1023/A:1010933404324}
#'
#' @examples
#' set.seed(1)
#' dat <- data.frame(x1 = runif(400, 1, 10), x2 = runif(400, 1, 10))
#' dat$y <- rbinom(400, 1, plogis(-3 + 0.6 * dat$x1))
#'
#' fit <- glm(y ~ x1 + x2, data = dat[1:200, ], family = binomial)
#' imp <- permutation_importance(fit, dat[201:400, ], n.perm = 5)
#'
#' aggregate(.importance ~ .variable, data = imp, FUN = mean)
#'
#' @export
permutation_importance <- function(model, newdata, vars = NULL,
                                   n.perm = 10,
                                   metric = c("auto", "auc", "rmse"),
                                   seed = 1,
                                   ...) {
  # A misspelled formal would otherwise be swallowed by ... and passed to a
  # backend that ignores it, leaving no sign the request was dropped.
  warn_misspelled_dots(names(list(...)), names(formals()))

  if (missing(newdata) || is.null(newdata)) {
    stop("newdata is required: importance measured on the data the model was ",
         "fitted to rewards a variable for the overfitting it enabled.",
         call. = FALSE)
  }
  newdata <- as.data.frame(newdata)
  # gamm4 and gamm hand back a wrapper that formula() and predict() both refuse.
  model <- unwrap_gam(model)

  metric <- check_choice(metric, c("auto", "auc", "rmse"), "metric")
  if (!is.numeric(n.perm) || length(n.perm) != 1 || n.perm < 1) {
    stop("n.perm must be a single positive number, not: ",
         paste(format(n.perm), collapse = ", "), call. = FALSE)
  }

  observed <- model_outcome(model, newdata)
  if (metric == "auto") {
    metric <- if (is_binary(observed)) "auc" else "rmse"
  }
  if (metric == "auc") {
    observed <- binary_response(model, newdata)
  }

  if (is.null(vars)) vars <- model_predictors(model)
  missing.vars <- setdiff(vars, names(newdata))
  if (length(missing.vars)) {
    stop("newdata has no column(s): ", paste(missing.vars, collapse = ", "),
         call. = FALSE)
  }
  if (!length(vars)) {
    stop("No predictors found to permute.", call. = FALSE)
  }

  in.sample <- is_training_data(model, newdata)
  if (isTRUE(in.sample)) {
    warning("Measuring importance on the data the model was fitted to. ",
            "Plots built from this will say so.", call. = FALSE)
  }

  score <- function(dat) {
    predicted <- predict_probability(model, dat, ...)
    if (metric == "auc") auc(observed, predicted) else rmse(observed, predicted)
  }
  baseline <- score(newdata)

  # Seeded so a figure can be reproduced. Restored afterwards, because silently
  # resetting the caller's RNG stream would change results elsewhere in their
  # script for reasons they would struggle to find.
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

  out <- do.call(rbind, lapply(vars, function(v) {
    drops <- vapply(seq_len(n.perm), function(i) {
      shuffled <- newdata
      shuffled[[v]] <- sample(shuffled[[v]])
      permuted <- score(shuffled)
      # AUC: importance is how much worse it got. RMSE: same idea, opposite
      # sign, so both read "bigger means the model relied on it more".
      if (metric == "auc") baseline - permuted else permuted - baseline
    }, numeric(1))

    data.frame(.variable = v, .permutation = seq_len(n.perm),
               .importance = drops)
  }))

  out$.variable <- factor(out$.variable, levels = vars)
  rownames(out) <- NULL
  attr(out, "metric") <- metric
  attr(out, "baseline") <- baseline
  attr(out, "in.sample") <- in.sample
  out
}

#' Plot permutation importance
#'
#' One row per predictor, ordered by importance, showing the spread across
#' permutations rather than a single bar. The spread is the point: a variable
#' whose importance swings between permutations has not been shown to matter,
#' and a bar chart of means would hide that.
#'
#' @param model A fitted model.
#' @param newdata Data to measure importance on. Required; see
#'   [permutation_importance()].
#' @param vars Predictors to permute. Defaults to every predictor in the model.
#' @param n.perm Number of permutations per variable.
#' @param metric `"auto"`, `"auc"`, or `"rmse"`.
#' @param seed Random seed.
#' @param title Plot title, optional.
#' @param xlab Label for the importance axis. Defaults to naming the metric.
#' @param theme A \pkg{ggplot2} theme. Defaults to [theme_fancyfx()].
#' @param colour Colour for the points and ranges.
#' @param ... Passed to [permutation_importance()] and on to
#'   [stats::predict()].
#'
#' @details
#' Each variable gets a point at its mean importance and a line spanning the
#' permutations. The dashed zero line is the reference: a variable whose range
#' crosses it did no measurable work, since shuffling it left the model no
#' worse than it already was.
#'
#' Read this beside [plotEffects()] rather than instead of it, and see
#' [permutation_importance()] for what correlated predictors do to the
#' ordering -- collinear covariates make each other look unimportant.
#'
#' @return A \pkg{ggplot2} object.
#'
#' @family evaluation plots
#' @seealso [permutation_importance()] for the numbers, [plotEffects()] for the
#'   shape of each effect.
#'
#' @examples
#' set.seed(1)
#' dat <- data.frame(x1 = runif(400, 1, 10), x2 = runif(400, 1, 10),
#'                   x3 = runif(400, 1, 10))
#' dat$y <- rbinom(400, 1, plogis(-3 + 0.6 * dat$x1))
#'
#' fit <- glm(y ~ x1 + x2 + x3, data = dat[1:200, ], family = binomial)
#' plotImportance(fit, dat[201:400, ], n.perm = 5)
#'
#' @export
plotImportance <- function(model, newdata, vars = NULL, n.perm = 10,
                           metric = c("auto", "auc", "rmse"),
                           seed = 1,
                           title = "", xlab = NULL,
                           theme = theme_fancyfx(),
                           colour = fancyfx_palette(1),
                           ...) {
  # A misspelled formal would otherwise be swallowed by ... and passed to a
  # backend that ignores it, leaving no sign the request was dropped.
  warn_misspelled_dots(names(list(...)), names(formals()))


  imp <- permutation_importance(model, newdata, vars = vars, n.perm = n.perm,
                                metric = metric, seed = seed, ...)

  summary.imp <- stats::aggregate(list(.mean = imp$.importance),
                                  by = list(.variable = imp$.variable),
                                  FUN = mean)
  ranges <- stats::aggregate(list(.range = imp$.importance),
                             by = list(.variable = imp$.variable),
                             FUN = range)
  summary.imp$.low <- ranges$.range[, 1]
  summary.imp$.high <- ranges$.range[, 2]

  # Ordered so the plot reads top-down from most to least important.
  summary.imp$.variable <- stats::reorder(summary.imp$.variable,
                                          summary.imp$.mean)

  if (is.null(xlab)) xlab <- importance_label(attr(imp, "metric"))

  ggplot2::ggplot(summary.imp,
                  ggplot2::aes(x = .data$.mean, y = .data$.variable)) +
    # Zero: shuffling this variable left the model no worse than it was.
    ggplot2::geom_vline(xintercept = 0, linetype = "dashed",
                        colour = "grey60") +
    ggplot2::geom_linerange(ggplot2::aes(xmin = .data$.low,
                                         xmax = .data$.high),
                            colour = colour, linewidth = 0.7) +
    ggplot2::geom_point(colour = colour, size = 2.4) +
    ggplot2::labs(x = xlab, y = NULL,
                  title = if (nzchar(title)) title else NULL,
                  caption = in_sample_caption(attr(imp, "in.sample"))) +
    theme
}

#' Axis label naming the importance metric
#'
#' @param metric `"auc"` or `"rmse"`.
#' @return The label to show.
#' @keywords internal
importance_label <- function(metric) {
  switch(metric,
         auc = "Drop in AUC when permuted",
         rmse = "Increase in RMSE when permuted",
         paste("Change in", metric, "when permuted"))
}

#' Root mean squared error
#'
#' @param observed,predicted Numeric vectors of equal length.
#' @return The RMSE.
#' @keywords internal
rmse <- function(observed, predicted) {
  sqrt(mean((observed - predicted)^2, na.rm = TRUE))
}

#' Is this vector a binary outcome?
#'
#' @param x A vector.
#' @return `TRUE` for 0/1, logical, or a two-level factor.
#' @keywords internal
is_binary <- function(x) {
  if (is.logical(x)) return(TRUE)
  if (is.factor(x)) return(nlevels(x) == 2)
  if (!is.numeric(x)) return(FALSE)
  all(unique(stats::na.omit(x)) %in% c(0, 1))
}

#' The model's response, as stored in newdata
#'
#' @param model A fitted model.
#' @param newdata Data containing the response.
#' @return The response vector.
#' @keywords internal
model_outcome <- function(model, newdata) {
  response <- all.vars(stats::formula(model))[1]
  if (!(response %in% names(newdata))) {
    stop("newdata has no column '", response, "', the model's response.",
         call. = FALSE)
  }
  newdata[[response]]
}

#' Predictor names for a fitted model
#'
#' Read from the model's terms rather than its formula, so a term written as
#' `s(x, by = f)` contributes `x` and `f` and not the call around them.
#'
#' @param model A fitted model.
#' @return A character vector of predictor names.
#' @keywords internal
model_predictors <- function(model) {
  terms.obj <- tryCatch(stats::terms(model), error = function(e) NULL)
  all.names <- if (!is.null(terms.obj)) {
    all.vars(stats::delete.response(terms.obj))
  } else {
    utils::tail(all.vars(stats::formula(model)), -1)
  }
  unique(all.names)
}
