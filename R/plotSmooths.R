#' Extract and plot smooths from a GAM (deprecated)
#'
#' @description
#' `r lifecycle_badge_deprecated()`
#'
#' `plotSmooths()` was the GAM-only ancestor of [plotEffects()]. It still works
#' and still returns the same plot, but it warns once per session and will be
#' removed in a future release. Rename the call: every argument is unchanged,
#' and the defaults (`scale = "link"`, `interval = "se"`) reproduce exactly what
#' `plotSmooths()` drew.
#'
#' @param model GAM produced using \pkg{mgcv}.
#' @param dat Raw data used to fit the model, for the accompanying rug plot.
#' @param var Variable smooths to extract.
#' @param xlab Label for the x-axis. Defaults to the variable's own name.
#' @param ylab Label for y-axis of smooth plot; default is `"Partial Effect"`.
#' @param transform Optional parameter indicating how to transform the variable,
#'   if applicable.
#' @param rug.type Type of rug plot to draw beneath the smooth.
#' @param bins Number of bins for a histogram rug.
#'
#' @return A smooth plot for `var` with its rug plot above it.
#'
#' @family effect plots
#' @seealso [plotEffects()], which replaces this function.
#'
#' @examples
#' gam.fit <- mgcv::gam(Petal.Length ~ s(Sepal.Length), data = iris)
#'
#' # Deprecated:
#' # plotSmooths(gam.fit, iris, "Sepal.Length")
#'
#' # Use instead:
#' plotEffects(gam.fit, iris, "Sepal.Length")
#'
#' @export
plotSmooths <- function(model, dat, var, xlab = var, ylab = "Partial Effect",
                        transform = c("none", "log", "log10", "sqrt"),
                        rug.type = c("histogram", "density"),
                        bins = 30) {

  deprecate_once(
    "plotSmooths",
    "plotSmooths() is deprecated and will be removed in a future release. ",
    "Use plotEffects() instead -- the arguments are unchanged."
  )

  plotEffects(model = model, dat = dat, var = var, xlab = xlab, ylab = ylab,
              scale = "link", interval = "se",
              transform = transform, rug.type = rug.type, bins = bins)
}
