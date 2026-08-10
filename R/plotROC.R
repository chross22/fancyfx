#' Plot a ROC curve
#'
#' Sensitivity against the false positive rate across every cutoff, with the
#' area under the curve reported. The diagonal is the reference: a model that
#' ranks presences no better than chance lies on it.
#'
#' @param model A fitted presence/absence model.
#' @param newdata Data to evaluate on. Required, and it should not be the data
#'   the model was fitted to -- see [threshold_metrics()].
#' @param folds Optional fold identifiers, one per row of `newdata`. Each fold
#'   is drawn as its own curve, so the spread is visible rather than averaged.
#' @param title Plot title, optional.
#' @param show.auc Whether to report the AUC on the plot.
#' @param theme A \pkg{ggplot2} theme. Defaults to [theme_fancyfx()].
#' @param palette Colours used for fold curves. Defaults to
#'   [fancyfx_palette()].
#' @param linewidth Width of the curve.
#' @param ... Passed to [threshold_metrics()] and on to [stats::predict()].
#'
#' @details
#' The plot is square with equal axes, because a ROC curve read on unequal
#' axes misleads about how far from the diagonal it sits.
#'
#' AUC is computed from ranks, not by integrating the drawn curve, so tied
#' predictions are handled exactly. With `folds`, one AUC per fold is reported
#' as a range rather than a mean: the spread is the informative part.
#'
#' If the metrics came from the model's own training data, the plot says so
#' beneath the axis. That annotation is not decoration -- an in-sample ROC can
#' look excellent for a model with no predictive value at all.
#'
#' @return A \pkg{ggplot2} object.
#'
#' @family evaluation plots
#' @seealso [plotThreshold()] for choosing a cutoff, [threshold_metrics()] for
#'   the numbers underneath.
#'
#' @references
#' Allouche, O., Tsoar, A., & Kadmon, R. (2006). Assessing the accuracy of
#' species distribution models: prevalence, kappa and the true skill statistic
#' (TSS). *Journal of Applied Ecology*, 43(6), 1223-1232.
#' \doi{10.1111/j.1365-2664.2006.01214.x}
#'
#' @examples
#' set.seed(1)
#' dat <- data.frame(x1 = runif(400, 1, 10), x2 = runif(400, 1, 10))
#' dat$y <- rbinom(400, 1, plogis(-3 + 0.6 * dat$x1))
#' train <- dat[1:200, ]
#' test <- dat[201:400, ]
#'
#' fit <- glm(y ~ x1 + x2, data = train, family = binomial)
#' plotROC(fit, test)
#'
#' @export
plotROC <- function(model, newdata = NULL, folds = NULL, title = "",
                    show.auc = TRUE,
                    theme = theme_fancyfx(),
                    palette = fancyfx_palette(),
                    linewidth = 0.8,
                    ...) {

  metrics <- threshold_metrics(model, newdata, folds = folds, ...)
  grouped <- ".fold" %in% names(metrics)

  p <- ggplot2::ggplot(metrics,
                       ggplot2::aes(x = .data$.fpr, y = .data$.tpr)) +
    # Chance, drawn first so the curve sits over it.
    ggplot2::geom_abline(slope = 1, intercept = 0,
                         linetype = "dashed", colour = "grey60") +
    ggplot2::labs(x = "False positive rate (1 - specificity)",
                  y = "True positive rate (sensitivity)",
                  title = if (nzchar(title)) title else NULL,
                  caption = in_sample_caption(attr(metrics, "in.sample"))) +
    # Equal axes and a square panel: on stretched axes a curve looks further
    # from the diagonal than it is.
    ggplot2::coord_equal(xlim = c(0, 1), ylim = c(0, 1), expand = FALSE) +
    theme

  if (grouped) {
    n.folds <- nlevels(metrics$.fold)
    p <- p + ggplot2::geom_step(
      ggplot2::aes(colour = .data$.fold, group = .data$.fold),
      linewidth = linewidth) +
      ggplot2::labs(colour = "Fold")
    if (n.folds <= length(palette)) {
      p <- p + ggplot2::scale_colour_manual(values = palette[seq_len(n.folds)])
    }
  } else {
    # A step, not a line: the empirical ROC is a step function, and joining the
    # corners draws operating points the model cannot actually reach.
    p <- p + ggplot2::geom_step(linewidth = linewidth)
  }

  if (show.auc) {
    p <- p + ggplot2::annotate(
      "text", x = 0.97, y = 0.03, hjust = 1, vjust = 0,
      label = auc_label(attr(metrics, "auc")))
  }

  p
}

#' Format one or several AUC values for display
#'
#' @param auc.value One AUC, or one per fold.
#' @return A single label string.
#' @keywords internal
auc_label <- function(auc.value) {
  if (length(auc.value) == 1) {
    return(paste0("AUC = ", format(round(auc.value, 3), nsmall = 3)))
  }
  # Across folds the range says more than the mean, which hides a fold that
  # failed behind ones that did not.
  paste0("AUC = ", format(round(mean(auc.value), 3), nsmall = 3),
         " (", format(round(min(auc.value), 3), nsmall = 3), "-",
         format(round(max(auc.value), 3), nsmall = 3), " across ",
         length(auc.value), " folds)")
}

#' Plot classification metrics against the decision threshold
#'
#' Sensitivity, specificity and the True Skill Statistic across every cutoff,
#' with the TSS-maximising threshold marked. The plot a decision actually needs:
#' a ROC curve says how well the model ranks, this says where to cut.
#'
#' @param model A fitted presence/absence model.
#' @param newdata Data to evaluate on. Required, and it should not be the data
#'   the model was fitted to -- see [threshold_metrics()].
#' @param folds Optional fold identifiers, one per row of `newdata`. Metrics
#'   are drawn per fold, so the spread in the chosen cutoff is visible.
#' @param metrics Which curves to draw. Any of `"tss"`, `"sensitivity"`,
#'   `"specificity"`.
#' @param title Plot title, optional.
#' @param mark.best Whether to mark the threshold maximising TSS.
#' @param theme A \pkg{ggplot2} theme. Defaults to [theme_fancyfx()].
#' @param palette Colours for the metric curves. Defaults to
#'   [fancyfx_palette()].
#' @param linewidth Width of the curves.
#' @param ... Passed to [threshold_metrics()] and on to [stats::predict()].
#'
#' @details
#' Sensitivity and specificity trade off against each other, and TSS is their
#' sum less one -- so its peak is the cutoff balancing them best. That is one
#' defensible choice of threshold, not the only one: if a false absence costs
#' more than a false presence, the right cutoff is not where TSS peaks, and the
#' two curves are drawn so that judgement can be made rather than assumed.
#'
#' With `folds`, the TSS-maximising cutoff is marked per fold. Those marks
#' scattering widely is worth more than any single number: it means the chosen
#' threshold is unstable, and reporting one to three decimal places would be
#' false precision.
#'
#' @return A \pkg{ggplot2} object.
#'
#' @family evaluation plots
#' @seealso [plotROC()], [threshold_metrics()].
#'
#' @examples
#' set.seed(1)
#' dat <- data.frame(x1 = runif(400, 1, 10), x2 = runif(400, 1, 10))
#' dat$y <- rbinom(400, 1, plogis(-3 + 0.6 * dat$x1))
#' fit <- glm(y ~ x1 + x2, data = dat[1:200, ], family = binomial)
#'
#' plotThreshold(fit, dat[201:400, ])
#'
#' # TSS alone, without the two curves it is built from
#' plotThreshold(fit, dat[201:400, ], metrics = "tss")
#'
#' @export
plotThreshold <- function(model, newdata = NULL, folds = NULL,
                          metrics = c("tss", "sensitivity", "specificity"),
                          title = "",
                          mark.best = TRUE,
                          theme = theme_fancyfx(),
                          palette = fancyfx_palette(),
                          linewidth = 0.8,
                          ...) {

  allowed <- c("tss", "sensitivity", "specificity")
  metrics <- unique(metrics)
  unknown <- setdiff(metrics, allowed)
  if (length(unknown)) {
    stop("Unknown metric requested: ", paste(unknown, collapse = ", "),
         call. = FALSE)
  }

  scores <- threshold_metrics(model, newdata, folds = folds, ...)
  grouped <- ".fold" %in% names(scores)

  # Long form, one row per threshold per metric, so the curves share a scale
  # and a legend.
  long <- do.call(rbind, lapply(metrics, function(m) {
    out <- data.frame(.threshold = scores$.threshold,
                      .value = scores[[paste0(".", m)]],
                      .metric = factor(metric_label(m),
                                       levels = vapply(metrics, metric_label,
                                                       character(1))))
    if (grouped) out$.fold <- scores$.fold
    out
  }))

  # Inf is the "classify nothing as positive" corner, which the ROC needs and
  # a threshold axis cannot draw.
  long <- long[is.finite(long$.threshold), , drop = FALSE]

  p <- ggplot2::ggplot(long, ggplot2::aes(x = .data$.threshold,
                                          y = .data$.value)) +
    ggplot2::labs(x = "Threshold", y = "Score", colour = NULL,
                  title = if (nzchar(title)) title else NULL,
                  caption = in_sample_caption(attr(scores, "in.sample"))) +
    ggplot2::coord_cartesian(ylim = c(0, 1)) +
    theme

  if (grouped) {
    p <- p + ggplot2::geom_line(
      ggplot2::aes(colour = .data$.metric,
                   group = interaction(.data$.metric, .data$.fold)),
      linewidth = linewidth, alpha = 0.6)
  } else {
    p <- p + ggplot2::geom_line(ggplot2::aes(colour = .data$.metric),
                                linewidth = linewidth)
  }

  if (length(metrics) <= length(palette)) {
    p <- p + ggplot2::scale_colour_manual(values = palette[seq_len(length(metrics))])
  }

  if (mark.best && "tss" %in% metrics) {
    p <- p + ggplot2::geom_vline(
      data = best_thresholds(scores, grouped),
      mapping = ggplot2::aes(xintercept = .data$.threshold),
      linetype = "dashed", colour = "grey40")
  }

  p
}

#' The TSS-maximising threshold, overall or per fold
#'
#' @param scores A `threshold_metrics()` frame.
#' @param grouped Whether the frame carries folds.
#' @return A one-column data frame of thresholds.
#' @keywords internal
best_thresholds <- function(scores, grouped) {
  finite <- scores[is.finite(scores$.threshold), , drop = FALSE]
  if (!nrow(finite)) return(data.frame(.threshold = numeric(0)))

  if (!grouped) {
    return(data.frame(.threshold = finite$.threshold[which.max(finite$.tss)]))
  }
  best <- vapply(split(seq_len(nrow(finite)), finite$.fold), function(i) {
    if (!length(i)) return(NA_real_)
    finite$.threshold[i][which.max(finite$.tss[i])]
  }, numeric(1))
  data.frame(.threshold = unname(best[!is.na(best)]))
}

#' Display name for a metric
#'
#' @param metric One of `"tss"`, `"sensitivity"`, `"specificity"`.
#' @return The label to show.
#' @keywords internal
metric_label <- function(metric) {
  switch(metric,
         tss = "TSS",
         sensitivity = "Sensitivity",
         specificity = "Specificity",
         metric)
}
