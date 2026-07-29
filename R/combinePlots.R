#' Combine multiple smooth plots for simultaneous display
#' @param model GAM produced using mgcv
#' @param dat Raw data
#' @param vars Variables of interest
#' @param title Plot title, optional
#' @export
combinePlots <- function(model, dat, vars, title = "",
                         var.transform, rug.type) {

  smooth.plots <- lapply(vars, function(var) plotSmooths(model, dat, var,
                                                         xlab = var, ylab = "Partial Effect",
                                                         transform = c("none", "log", "log10", "sqrt")[1],
                                                         rug.type = c("histogram", "density")[1]))

  arranged <- ggpubr::ggarrange(plotlist = smooth.plots,
                                common.legend = TRUE,
                                labels = letters[1:length(vars)])

  ggpubr::annotate_figure(arranged, top = title)

}
