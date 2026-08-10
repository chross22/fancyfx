#' @param n.trees For a boosted regression tree, how many trees to use.
#'   Defaults to every tree in the fit, which is rarely what you want -- pass
#'   the number [gbm::gbm.perf()] selected.
#' @rdname effect_estimates
#' @export
effect_estimates.gbm <- function(model, var,
                                 scale = c("auto", "link", "response"),
                                 interval = c("auto", "se", "ci", "cri"),
                                 level = 0.95,
                                 n = 100,
                                 data = NULL,
                                 n.trees = NULL,
                                 ...) {
  if (!requireNamespace("gbm", quietly = TRUE)) {
    stop("Boosted regression trees need the gbm package.\n",
         "  install.packages(\"gbm\")", call. = FALSE)
  }
  scale <- check_scale(scale)
  interval <- check_interval(interval)
  check_level(level)

  # marginaleffects does not support gbm at all, so this method uses gbm's own
  # partial dependence -- the quantity dismo::gbm.plot drew.
  if (scale == "auto") scale <- "link"
  if (!(var %in% model$var.names)) {
    stop("No predictor '", var, "' in the model (available: ",
         paste(model$var.names, collapse = ", "), ").", call. = FALSE)
  }

  n.trees <- n.trees %||% model$n.trees

  grid <- gbm::plot.gbm(model, i.var = var, return.grid = TRUE,
                        n.trees = n.trees,
                        type = if (scale == "response") "response" else "link",
                        continuous.resolution = n, ...)
  grid <- as.data.frame(grid)

  # A boosted ensemble has no analytic standard error for its partial
  # dependence, and nothing here will invent one. The band is drawn with zero
  # width rather than a made-up one, and this says so the first time.
  note_once(
    "brt.no.interval",
    "Boosted regression trees have no analytic standard error for partial ",
    "dependence, so this curve is drawn without an uncertainty band. To put ",
    "one on it, bootstrap the fit and summarise the ensemble -- the spread ",
    "across refits is the honest interval here."
  )

  standardize_effect(
    x = grid[[var]],
    estimate = grid[[2]],
    lower = grid[[2]],
    upper = grid[[2]],
    quantity = if (scale == "response") "Predicted Value" else "Partial Dependence"
  )
}

#' Deviance of a set of predictions
#'
#' How badly the predictions miss, on the scale the model was fitted on. Lower
#' is better, and zero is a perfect fit.
#'
#' @param observed Observed outcomes.
#' @param predicted Predicted values, on the response scale.
#' @param family `"binomial"`, `"poisson"`, `"gaussian"`, or `"laplace"`.
#' @param weights Optional observation weights.
#' @param mean Whether to return the mean deviance per observation rather than
#'   the total.
#'
#' @details
#' Deviance answers a question AUC cannot: AUC only cares about ranking, and
#' will not notice predictions that are ordered correctly but wrong. Deviance
#' penalises confident mistakes hardest, which is usually the failure that
#' matters.
#'
#' It is most useful as a *relative* measure. Compare a model's deviance to the
#' null deviance -- what you would get predicting the overall mean for every
#' observation -- and the ratio is the proportion of deviance explained, the
#' quantity boosted regression tree work reports as a matter of course.
#'
#' @return A single number.
#'
#' @family evaluation plots
#' @seealso [threshold_metrics()] for discrimination,
#'   [calibration_estimates()] for whether the probabilities are honest.
#'
#' @references
#' Elith, J., Leathwick, J. R., & Hastie, T. (2008). A working guide to boosted
#' regression trees. *Journal of Animal Ecology*, 77(4), 802-813.
#' \doi{10.1111/j.1365-2656.2008.01390.x}
#'
#' @examples
#' set.seed(1)
#' dat <- data.frame(x = runif(300, 1, 10))
#' dat$y <- rbinom(300, 1, plogis(-3 + 0.6 * dat$x))
#' fit <- glm(y ~ x, data = dat, family = binomial)
#'
#' fitted.deviance <- calc_deviance(dat$y, fitted(fit), "binomial")
#' null.deviance <- calc_deviance(dat$y, rep(mean(dat$y), nrow(dat)),
#'                                "binomial")
#'
#' # Proportion of deviance explained
#' 1 - fitted.deviance / null.deviance
#'
#' @export
calc_deviance <- function(observed, predicted,
                          family = c("binomial", "poisson", "gaussian",
                                     "laplace"),
                          weights = NULL, mean = TRUE) {
  family <- check_choice(family, c("binomial", "poisson", "gaussian",
                                   "laplace"), "family")

  if (length(observed) != length(predicted)) {
    stop("observed and predicted must be the same length: ", length(observed),
         " and ", length(predicted), " given.", call. = FALSE)
  }
  if (is.factor(observed)) observed <- as.numeric(observed) - 1
  if (is.logical(observed)) observed <- as.numeric(observed)

  weights <- weights %||% rep(1, length(observed))
  if (length(weights) != length(observed)) {
    stop("weights must have one entry per observation.", call. = FALSE)
  }

  deviance <- switch(
    family,
    binomial = {
      if (any(predicted < 0 | predicted > 1, na.rm = TRUE)) {
        stop("Binomial deviance needs predicted probabilities in [0, 1]. ",
             "These look like they are on the link scale.", call. = FALSE)
      }
      # Bounded away from 0 and 1: a confident, wrong prediction would
      # otherwise contribute an infinite deviance and swallow the total.
      eps <- 1e-10
      p <- pmin(pmax(predicted, eps), 1 - eps)
      -2 * sum(weights * (observed * log(p) + (1 - observed) * log(1 - p)))
    },
    poisson = {
      if (any(predicted < 0, na.rm = TRUE)) {
        stop("Poisson deviance needs non-negative predictions.", call. = FALSE)
      }
      term <- ifelse(observed == 0, 0, observed * log(observed / predicted))
      2 * sum(weights * (term - (observed - predicted)))
    },
    gaussian = sum(weights * (observed - predicted)^2),
    laplace = sum(weights * abs(observed - predicted))
  )

  if (mean) deviance / sum(weights) else deviance
}
