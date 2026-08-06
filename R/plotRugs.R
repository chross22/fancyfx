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
#' @return The rug plot from dat for var
#' @export
plotRugs <- function(dat, var, type = c("histogram", "density"),
                     transform = c("none", "log", "log10", "sqrt"),
                     bins = 30) {

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
             ggplot2::geom_histogram(mapping = mapping, bins = bins, alpha = 0.5))
  }

  ggplot2::ggplot(data = dat) +
    ggplot2::theme_void() +
    ggplot2::geom_density(mapping = mapping, alpha = 0.5)
}
