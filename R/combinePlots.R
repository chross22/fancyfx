#' Combine multiple effect plots for simultaneous display
#'
#' Runs [plotEffects()] over several predictors and arranges the results as a
#' labelled panel grid. Each panel keeps its own rug, so the panels stay
#' individually readable rather than becoming a wall of curves.
#'
#' @param model A fitted model. GAMs from \pkg{mgcv} are shown as partial
#'   effects; other model classes are shown as predictions. See [plotEffects()].
#' @param dat Raw data the model was fitted on.
#' @param vars Variables of interest, as a character vector.
#' @param title Plot title, optional.
#' @param var.transform How to transform the variables before plotting. One
#'   value used for every variable, or one per entry in `vars`.
#' @param scale `"auto"`, `"link"`, or `"response"`, passed to [plotEffects()].
#' @param interval `"se"` or `"ci"`, passed to [plotEffects()].
#' @param level Confidence level used when `interval = "ci"`.
#' @param n Number of points at which to evaluate each effect.
#' @param rug.type Type of rug plot to draw above each effect.
#' @param bins Number of bins for a histogram rug.
#' @param ... Passed through to [plotEffects()] and on to the backend.
#'
#' @return The arranged effect plots.
#'
#' @family effect plots
#' @seealso [plotEffects()] for a single predictor and for what the y axis
#'   means under each model type.
#'
#' @examples
#' gam.fit <- mgcv::gam(Petal.Length ~ s(Sepal.Length) + s(Petal.Width),
#'                      data = iris)
#' combinePlots(gam.fit, iris, vars = c("Sepal.Length", "Petal.Width"),
#'              title = "Partial effects on petal length")
#'
#' # Non-GAM models work the same way
#' lm.fit <- lm(mpg ~ wt + hp, data = mtcars)
#' combinePlots(lm.fit, mtcars, vars = c("wt", "hp"), rug.type = "density")
#'
#' @export
combinePlots <- function(model, dat, vars, title = "",
                         var.transform = c("none", "log", "log10", "sqrt"),
                         scale = c("auto", "link", "response"),
                         interval = c("se", "ci"),
                         level = 0.95,
                         n = 100,
                         rug.type = c("histogram", "density"),
                         bins = 30,
                         ...) {

  rug.type <- check_choice(rug.type, c("histogram", "density"), "type")
  scale <- check_scale(scale)
  interval <- check_interval(interval)
  check_level(level)

  # One transform for all variables, or one each. Recycled explicitly rather
  # than by R's rules, so a length that divides into `vars` but was not meant
  # to be recycled is an error rather than a silently rearranged plot.
  if (identical(var.transform, c("none", "log", "log10", "sqrt"))) {
    var.transform <- "none"
  }
  var.transform <- vapply(var.transform, check_transform, character(1),
                          USE.NAMES = FALSE)
  if (length(var.transform) == 1) {
    var.transform <- rep(var.transform, length(vars))
  }
  if (length(var.transform) != length(vars)) {
    stop("var.transform must be one value, or one per variable in vars: ",
         length(vars), " expected, ", length(var.transform), " given.",
         call. = FALSE)
  }

  effect.plots <- lapply(seq_along(vars), function(i) {
    plotEffects(model, dat, vars[[i]],
                xlab = vars[[i]],
                scale = scale, interval = interval, level = level, n = n,
                transform = var.transform[[i]],
                rug.type = rug.type, bins = bins, ...)
  })

  arranged <- ggpubr::ggarrange(plotlist = effect.plots,
                                common.legend = TRUE,
                                labels = letters[seq_along(vars)])

  ggpubr::annotate_figure(arranged, top = title)
}
