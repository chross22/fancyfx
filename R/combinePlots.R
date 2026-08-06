#' Combine multiple smooth plots for simultaneous display
#'
#' @param model GAM produced using mgcv
#' @param dat Raw data the model was fitted on
#' @param vars Variables of interest
#' @param title Plot title, optional
#' @param var.transform How to transform the variables before plotting. One
#'   value used for every variable, or one per entry in `vars`.
#' @param rug.type Type of rug plot to draw beneath each smooth
#' @param bins Number of bins for a histogram rug
#' @return The arranged smooth plots
#' @export
combinePlots <- function(model, dat, vars, title = "",
                         var.transform = c("none", "log", "log10", "sqrt"),
                         rug.type = c("histogram", "density"),
                         bins = 30) {

  rug.type <- check_choice(rug.type, c("histogram", "density"), "type")
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

  smooth.plots <- lapply(seq_along(vars), function(i) {
    plotSmooths(model, dat, vars[[i]],
                xlab = vars[[i]], ylab = "Partial Effect",
                transform = var.transform[[i]],
                rug.type = rug.type, bins = bins)
  })

  arranged <- ggpubr::ggarrange(plotlist = smooth.plots,
                                common.legend = TRUE,
                                labels = letters[seq_along(vars)])

  ggpubr::annotate_figure(arranged, top = title)
}
