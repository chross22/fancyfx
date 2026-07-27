
#' Create rug plots representing distribution of the raw data
#' @param dat Raw data
#' @param var Variable to plot
#' @param transform Optional parameter indicating how to transform the variable, if applicable
#' @return The rug plot from dat for var
#' @export
plotRugs <- function(dat, var, transform = c("none", "log", "log10", "sqrt")[1]) {

  ggplot2::ggplot(data = dat) +
    ggplot2::geom_density(mapping = ggplot2::aes(x = switch(transform,
                                                   none = .data[[var]],
                                                   log = log(.data[[var]]),
                                                   log10 = log10(.data[[var]]),
                                                   sqrt = sqrt(.data[[var]]),
                                                   stop("Unknown transformation requested: ", transform))),
                                        alpha = 0.5) +
    ggplot2::theme_void()

}

