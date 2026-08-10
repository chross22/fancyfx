#' Create rug plots representing distribution of the raw data
#'
#' The companion to a smooth plot: it shows where the data actually is, so a
#' bend in a smooth can be read against how much evidence sits under it.
#'
#' @param dat Raw data
#' @param var Variable to plot
#' @param type Optional parameter indicating type of plot; default is histogram
#' @param transform Optional parameter indicating how to transform the variable, if applicable
#' @param bins Number of histogram bins. Set explicitly rather than left to
#'   `geom_histogram()`'s default, which is the same 30 but emits a message
#'   about it on every plot. Ignored when `type` is `"density"`.
#' @param fill Fill colour for the rug. Deliberately a neutral grey: the rug
#'   reports where the data is, and should not compete with the effect curve
#'   below it for attention.
#' @return The rug plot from dat for var
#'
#' @family effect plots
#' @seealso [plotEffects()], which stacks this above an effect curve for you.
#'
#' @examples
#' plotRugs(iris, "Sepal.Length")
#' plotRugs(iris, "Sepal.Length", type = "density")
#' plotRugs(mtcars, "disp", transform = "log10", bins = 15)
#'
#' @export
plotRugs <- function(dat, var, type = c("histogram", "density"),
                     transform = c("none", "log", "log10", "sqrt"),
                     bins = 30, fill = "grey35") {

  # Checked here rather than left to the switch() inside aes(). aes() is lazy,
  # so an invalid value would otherwise sail through until the plot was drawn
  # and fail somewhere that says nothing about where it came from.
  type <- check_choice(type, c("histogram", "density"), "type")
  transform <- check_transform(transform)

  mapping <- ggplot2::aes(x = switch(transform,
                                     none = .data[[var]],
                                     log = log(.data[[var]]),
                                     log10 = log10(.data[[var]]),
                                     sqrt = sqrt(.data[[var]])))

  if (type == "histogram") {
    return(ggplot2::ggplot(data = dat) +
             ggplot2::theme_void() +
             ggplot2::geom_histogram(mapping = mapping, bins = bins,
                                     fill = fill, colour = NA))
  }

  # Filled rather than left as a bare outline, so the two rug types read the
  # same weight above the curve. geom_density() takes no fill unless told, and
  # alpha alone does nothing to an unfilled shape.
  ggplot2::ggplot(data = dat) +
    ggplot2::theme_void() +
    ggplot2::geom_density(mapping = mapping, fill = fill, colour = NA)
}
