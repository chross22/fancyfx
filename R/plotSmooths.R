#' Extract and plot smooths from generalized additive model created using mgcv::gam()
#'
#' @param model GAM produced using mgcv
#' @param dat Raw data used to fit the model, for the accompanying rug plot.
#'   It must be the data the model was *fitted* on: `gratia` reports smooths in
#'   the model's own units, so a rug drawn from differently scaled data would sit
#'   on a different x axis than the smooth above it.
#' @param var Variable smooths to extract
#' @param xlab Label for the x-axis, describing var with units where applicable.
#'   Defaults to the variable's own name.
#' @param ylab Label for y-axis of smooth plot; default is "Partial Effect"
#' @param transform Optional parameter indicating how to transform the variable, if applicable
#' @param rug.type Type of rug plot to draw beneath the smooth
#' @param bins Number of bins for a histogram rug
#' @return A smooth plot for var with its rug plot beneath it
#' @export
plotSmooths <- function(model, dat, var, xlab = var, ylab = "Partial Effect",
                        transform = c("none", "log", "log10", "sqrt"),
                        rug.type = c("histogram", "density"),
                        bins = 30) {

  transform <- check_transform(transform)
  rug.type <- check_choice(rug.type, c("histogram", "density"), "type")

  var.plot <- ggplot2::ggplot(gratia::smooth_estimates(model, select = var, dist = 0.1, partial_match = TRUE),
                              mapping = ggplot2::aes(x = switch(transform,
                                                    none = .data[[var]],
                                                    log = log(.data[[var]]),
                                                    log10 = log10(.data[[var]]),
                                                    sqrt = sqrt(.data[[var]])),
                                         y = .data$.estimate)) +
    ggplot2::geom_line() +
    ggplot2::geom_ribbon(mapping = ggplot2::aes(ymin = .data$.estimate - .data$.se,
                                                ymax = .data$.estimate + .data$.se),
                         alpha = 0.5) +
    ggplot2::labs(x = xlab, y = ylab) +
    ggplot2::theme_bw()

  rug.plot <- plotRugs(dat = dat, var = var, type = rug.type,
                       transform = transform, bins = bins)

  list(rug.plot, var.plot) |> patchwork::wrap_plots(nrow = 2, heights = c(1, 5))
}
