#' Compare the same effect across several models
#'
#' Plots one variable's effect from each of several models, side by side, so
#' competing specifications can be read against each other. The companion to
#' [combinePlots()], which holds the model fixed and varies the predictor.
#'
#' The motivating case is asking what a modelling choice actually bought you:
#' fit the same data with and without a factor-smooth interaction, put the two
#' panels next to each other, and see whether the smooths really do differ by
#' group. Each panel keeps its own rug, so a group with little data is visible
#' rather than inferred.
#'
#' @param models A list of fitted models. Names become the panel titles; if the
#'   list is unnamed, panels are titled `"Model 1"`, `"Model 2"`, and so on.
#'   Models need not be of the same class -- a GAM can be compared against a
#'   GLM, subject to the caveat below.
#' @param dat Raw data the models were fitted on, for the rugs. One data frame
#'   used for every panel, or a list with one per model.
#' @param var Name of the predictor to plot. One name used for every model, or
#'   one per model, for comparing specifications that name a term differently.
#' @param title Overall title for the figure, optional.
#' @param xlab Label for the x-axis of every panel. Defaults to `var`.
#' @param ylab Label for the y-axis of every panel. Defaults per panel to the
#'   quantity that panel actually computed.
#' @param transform How to transform the variable before plotting. One value
#'   used for every panel, or one per model.
#' @param scale `"auto"`, `"link"`, or `"response"`, passed to [plotEffects()].
#' @param interval `"se"` or `"ci"`, passed to [plotEffects()].
#' @param level Confidence level used when `interval = "ci"`.
#' @param n Number of points at which to evaluate each effect.
#' @param rug.type Type of rug plot to draw above each effect.
#' @param bins Number of bins for a histogram rug.
#' @param common.legend Whether the panels share one legend. Worth turning off
#'   when the models are split by different factors, since a shared legend
#'   would then describe only the first.
#' @param labels Panel labels: `"A"` (the default) for upper-case letters, `"a"`
#'   for lower-case, `"1"` for numbers, `"none"` for none, or a character vector
#'   used verbatim, one per panel.
#' @param ... Passed through to [plotEffects()] and on to the backend.
#'
#' @section Comparing like with like:
#' Panels are only comparable if they show the same quantity. A GAM defaults to
#' its partial effect and a GLM to its predictions, and putting those side by
#' side compares a curve centered on zero against one that is not. When the
#' models are of different classes, pass `scale = "response"` so every panel
#' reports predictions, or read the y-axis labels carefully -- they will differ,
#' which is the signal that the panels are not on the same footing.
#'
#' @return The arranged plots, as returned by [ggpubr::ggarrange()].
#'
#' @family effect plots
#' @seealso [combinePlots()] to vary the predictor instead of the model, and
#'   [plotEffects()] for a single panel.
#'
#' @examples
#' # Does letting the smooth vary by species actually buy anything?
#' plain <- mgcv::gam(Petal.Length ~ s(Sepal.Length), data = iris)
#' by.species <- mgcv::gam(Petal.Length ~ s(Sepal.Length, by = Species) + Species,
#'                         data = iris)
#'
#' comparePlots(list("Single smooth" = plain,
#'                   "Smooth by species" = by.species),
#'              iris, "Sepal.Length",
#'              title = "Is a factor-smooth interaction worth it?")
#'
#' # Comparing across model classes: ask for the same quantity from both.
#' comparePlots(list(GAM = plain, Linear = lm(Petal.Length ~ Sepal.Length, iris)),
#'              iris, "Sepal.Length", scale = "response")
#'
#' @export
comparePlots <- function(models, dat, var, title = "",
                         xlab = NULL, ylab = NULL,
                         transform = c("none", "log", "log10", "sqrt"),
                         scale = c("auto", "link", "response"),
                         interval = c("se", "ci"),
                         level = 0.95,
                         n = 100,
                         rug.type = c("histogram", "density"),
                         bins = 30,
                         common.legend = TRUE,
                         labels = "A",
                         ...) {

  # A single model is a comparison of one: degenerate, but harmless, and more
  # useful than refusing it inside a loop over specifications.
  #
  # Tested with identical() rather than is.list(), because a fitted model is
  # itself a list -- is.list() on a gam is TRUE, and indexing it would walk
  # into the model's internals instead of treating it as one panel. A bare
  # list(m1, m2) has class exactly "list"; anything fitted carries its own.
  if (!identical(class(models), "list")) {
    models <- list(models)
  }
  if (!length(models)) {
    stop("models must contain at least one fitted model.", call. = FALSE)
  }

  rug.type <- check_choice(rug.type, c("histogram", "density"), "type")
  scale <- check_scale(scale)
  interval <- check_interval(interval)
  check_level(level)

  if (identical(transform, c("none", "log", "log10", "sqrt"))) {
    transform <- "none"
  }
  transform <- vapply(transform, check_transform, character(1),
                      USE.NAMES = FALSE)
  transform <- recycle_to(transform, length(models), "transform", "model")
  var <- recycle_to(var, length(models), "var", "model")

  # One shared data frame, or one per model. A data frame is itself a list, so
  # the check is on class rather than on is.list().
  dat.list <- if (inherits(dat, "data.frame")) {
    rep(list(dat), length(models))
  } else {
    recycle_to(dat, length(models), "dat", "model")
  }

  panel.titles <- names(models)
  if (is.null(panel.titles)) {
    panel.titles <- paste("Model", seq_along(models))
  }
  # A partly-named list gets the generic label only where a name is missing.
  blank <- !nzchar(panel.titles)
  panel.titles[blank] <- paste("Model", seq_along(models))[blank]

  panels <- lapply(seq_along(models), function(i) {
    p <- plotEffects(models[[i]], dat.list[[i]], var[[i]],
                     xlab = if (is.null(xlab)) var[[i]] else xlab,
                     ylab = ylab,
                     scale = scale, interval = interval, level = level, n = n,
                     transform = transform[[i]],
                     rug.type = rug.type, bins = bins, ...)
    # Titling the effect panel rather than the patchwork keeps the title with
    # the curve it describes, directly under the rug.
    p[[2]] <- p[[2]] + ggplot2::ggtitle(panel.titles[[i]])
    p
  })

  arranged <- ggpubr::ggarrange(plotlist = panels,
                                common.legend = common.legend,
                                labels = panel_labels(labels, length(models)))

  ggpubr::annotate_figure(arranged, top = title)
}
