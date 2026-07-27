#' Add data rugs to smooth plots by combining into a list of plots
#' @param model GAM produced using mgcv
#' @param dat Raw data
#' @param var Variable smooths to extract
#' @param xlab Label for x-axis of smooth plot, describing var with units where applicable
#' @param ylab Label for y-axis of smooth plot; default is "Partial Effect"
#' @param transform Optional parameter indicating how to transform the variable, if applicable
#' @return The rug plot from dat for var
#' @export
addRugsToSmooths <- function(model, dat, var, xlab, ylab = "Partial Effect",
                             transform = c("none", "log", "log10", "sqrt")[1]) {

  var.plot <- plotSmooths(model, var, xlab, ylab, transform)
  rug.plot <- plotRugs(dat, var, transform)

  list(rug.plot, var.plot) |> patchwork::wrap_plots(nrow = 2, heights = c(1, 5))

}


#' Combine plot of smooth and plot of data rugs
#' @param model GAM produced using mgcv
#' @param dat Raw data
#' @param vars Variables of interest
#' @param title Plot title, optional
#' @export
combinePlots <- function(model, dat, vars, title = "") {

  smooth.plots <- lapply(vars, function(var) addRugsToSmooths(model, dat, var, xlab = var))

  arranged <- ggpubr::ggarrange(plotlist = smooth.plots,
                                common.legend = TRUE,
                                labels = letters[1:length(vars)])

  ggpubr::annotate_figure(arranged, top = title)

}
