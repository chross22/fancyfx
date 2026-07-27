#' Extract and plot smooths from generalized additive model created using mgcv::gam()
#' @param model GAM produced using mgcv
#' @param var Variable smooths to extract
#' @param xlab Label for x-axis of smooth plot, describing var with units where applicable
#' @param ylab Label for y-axis of smooth plot; default is "Partial Effect"
#' @param transform Optional parameter indicating how to transform the variable, if applicable
#' @return The rug plot from dat for var
#' @export
plotSmooths <- function(model, var, xlab, ylab = "Partial Effect",
                        transform = c("none", "log", "log10", "sqrt")[1]) {

 ggplot2::ggplot(gratia::smooth_estimates(model, select = var, dist = 0.1, partial_match = TRUE),
                 mapping = ggplot2::aes(x = switch(transform,
                                                   none = .data[[var]],
                                                   log = log(.data[[var]]),
                                                   log10 = log10(.data[[var]]),
                                                   sqrt = sqrt(.data[[var]]),
                                                   stop("Unknown transformation requested: ", transform)),
                                        y = .estimate)) +
    ggplot2::geom_line() +
    ggplot2::geom_ribbon(mapping = ggplot2::aes(ymin = .estimate-.se, ymax = .estimate+.se), alpha = 0.5) +
    ggplot2::labs(x = xlab, y = ylab) +
    ggplot2::theme_bw()

}
