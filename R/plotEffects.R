#' Plot a predictor's effect with a rug of the raw data above it
#'
#' Draws the effect of `var` as a line with an uncertainty ribbon, and stacks a
#' rug of the raw data directly above it on a shared x axis. The rug is the
#' point: it shows where the data actually is, so a bend in the curve can be
#' read against how much evidence sits under it.
#'
#' @param model A fitted model. GAMs from \pkg{mgcv} are shown as partial
#'   effects; other model classes are shown as predictions. See Details.
#' @param dat Raw data used to fit the model, for the accompanying rug plot.
#'   It must be the data the model was *fitted* on: effects are reported in the
#'   model's own units, so a rug drawn from differently scaled data would sit on
#'   a different x axis than the curve above it.
#' @param var Name of the predictor to plot, as a string.
#' @param xlab Label for the x-axis, describing `var` with units where
#'   applicable. Defaults to the variable's own name.
#' @param ylab Label for the y-axis. Defaults to naming whichever quantity was
#'   actually computed -- `"Partial Effect"` or `"Predicted Value"`.
#' @param scale `"auto"` (the default), `"link"`, or `"response"`. `"auto"`
#'   gives a GAM its partial effect on the link scale and every other model its
#'   predictions on the response scale. For a GAM this argument chooses between
#'   two different quantities, not just two axis scales; see Details.
#' @param interval `"se"` for a `+/- 1` standard error ribbon (the default, and
#'   what this package has always drawn), or `"ci"` for a confidence interval at
#'   `level`.
#' @param level Confidence level used when `interval = "ci"`. Ignored otherwise.
#' @param n Number of points at which to evaluate the effect. Ignored for the
#'   GAM partial-effect path, where \pkg{gratia} chooses the grid.
#' @param transform Optional parameter indicating how to transform the variable,
#'   if applicable. Applied to both the curve and the rug, so they stay aligned.
#' @param rug.type Type of rug plot to draw above the effect.
#' @param bins Number of bins for a histogram rug.
#' @param ... Passed through to the backend, [gratia::smooth_estimates()] or
#'   [marginaleffects::predictions()].
#'
#' @details
#' What gets plotted depends on the model, because the natural quantity differs:
#'
#' * A **GAM** is shown as the *partial effect* of the smooth
#'   -- the term's own contribution, centered to average zero. This is the
#'   quantity `fancygam`, this package's predecessor, always plotted, and it
#'   remains the default so existing code is unaffected.
#' * **Any other model**, and a GAM asked for `scale = "response"`, is shown as
#'   *predicted values*: the model's fitted output as `var` varies, with the
#'   other predictors held at representative values.
#'
#' The y-axis label reports which one you got. Do not compare a partial effect
#' against a prediction as though they were on the same footing -- one is
#' centered on zero and excludes the rest of the model, the other is not and
#' does not.
#'
#' Note that the default `interval = "se"` ribbon spans roughly 68%, not 95%.
#' It is the historical default of this package; pass `interval = "ci"` for a
#' conventional confidence interval.
#'
#' On the response scale, `interval = "ci"` is built on the link scale and
#' back-transformed, so it stays within the range the response admits -- a
#' probability band will not run past 0 or 1. `interval = "se"` cannot use that
#' construction, since an asymmetric interval has no single standard error
#' behind it. Prefer `"ci"` when plotting probabilities.
#'
#' @return A `patchwork` object: the rug above, the effect curve below.
#'
#' @family effect plots
#' @seealso [combinePlots()] to show several predictors at once, [plotRugs()]
#'   for the rug on its own, and [mgcv::gam()] or
#'   [marginaleffects::predictions()] for the machinery underneath.
#'
#' @references
#' Wood, S. N. (2017). *Generalized Additive Models: An Introduction with R*
#' (2nd ed.). Chapman and Hall/CRC. \doi{10.1201/9781315370279}
#'
#' Arel-Bundock, V., Greifer, N., & Heiss, A. (2024). How to interpret
#' statistical models using marginaleffects for R and Python.
#' *Journal of Statistical Software*, 111(9), 1-32.
#' \doi{10.18637/jss.v111.i09}
#'
#' @examples
#' # A GAM: partial effect of the smooth, with the data rug above it
#' gam.fit <- mgcv::gam(Petal.Length ~ s(Sepal.Length), data = iris)
#' plotEffects(gam.fit, iris, "Sepal.Length", xlab = "Sepal length (cm)")
#'
#' # A linear model: predicted values, via marginaleffects
#' lm.fit <- lm(Petal.Length ~ Sepal.Length + Species, data = iris)
#' plotEffects(lm.fit, iris, "Sepal.Length")
#'
#' # A logistic regression on the response scale, with a 95% interval
#' glm.fit <- glm(am ~ wt + hp, data = mtcars, family = binomial)
#' plotEffects(glm.fit, mtcars, "wt", scale = "response",
#'             interval = "ci", rug.type = "density")
#'
#' @export
plotEffects <- function(model, dat, var, xlab = var, ylab = NULL,
                        scale = c("auto", "link", "response"),
                        interval = c("se", "ci"),
                        level = 0.95,
                        n = 100,
                        transform = c("none", "log", "log10", "sqrt"),
                        rug.type = c("histogram", "density"),
                        bins = 30,
                        ...) {

  transform <- check_transform(transform)
  rug.type <- check_choice(rug.type, c("histogram", "density"), "type")

  est <- effect_estimates(model, var, scale = scale, interval = interval,
                          level = level, n = n, ...)

  # Set from the frame rather than from `scale`, so the label always names the
  # quantity that was actually computed -- including when a GAM asked for the
  # response scale got predictions instead of a partial effect.
  if (is.null(ylab)) ylab <- attr(est, "quantity")

  var.plot <- ggplot2::ggplot(
    est,
    mapping = ggplot2::aes(x = switch(transform,
                                      none = .data$.x,
                                      log = log(.data$.x),
                                      log10 = log10(.data$.x),
                                      sqrt = sqrt(.data$.x)),
                           y = .data$.estimate)) +
    ggplot2::geom_ribbon(mapping = ggplot2::aes(ymin = .data$.lower,
                                                ymax = .data$.upper),
                         alpha = 0.5) +
    ggplot2::geom_line() +
    ggplot2::labs(x = xlab, y = ylab) +
    ggplot2::theme_bw()

  rug.plot <- plotRugs(dat = dat, var = var, type = rug.type,
                       transform = transform, bins = bins)

  list(rug.plot, var.plot) |> patchwork::wrap_plots(nrow = 2, heights = c(1, 5))
}
