#' Plot a predictor's effect with a rug of the raw data above it
#'
#' Draws the effect of `var` as a line with an uncertainty ribbon, and stacks a
#' rug of the raw data directly above it on a shared x axis. The rug is the
#' point: it shows where the data actually is, so a bend in the curve can be
#' read against how much evidence sits under it.
#'
#' @param model A fitted model. GAMs from \pkg{mgcv} are shown as partial
#'   effects; other model classes are shown as predictions. See Details.
#' @param dat Raw data used to fit the model, for the accompanying rug plot.
#'   It must be the data the model was *fitted* on: effects are reported in the
#'   model's own units, so a rug drawn from differently scaled data would sit on
#'   a different x axis than the curve above it.
#' @param var Name of the predictor to plot, as a string.
#' @param xlab Label for the x-axis, describing `var` with units where
#'   applicable. Defaults to the variable's own name.
#' @param ylab Label for the y-axis. Defaults to naming whichever quantity was
#'   actually computed -- `"Partial Effect"` or `"Predicted Value"`.
#' @param title Plot title, optional. Set on the effect panel rather than the
#'   stacked figure, so it sits with the curve it describes rather than above
#'   the rug.
#' @param scale `"auto"` (the default), `"link"`, or `"response"`. `"auto"`
#'   gives a GAM its partial effect on the link scale and every other model its
#'   predictions on the response scale. For a GAM this argument chooses between
#'   two different quantities, not just two axis scales; see Details.
#' @param interval `"auto"` (the default), `"se"` for a `+/- 1` standard error
#'   ribbon, `"ci"` for a pointwise interval at `level`, or `"simultaneous"`
#'   for a band covering the whole curve at `level` -- GAM partial effects
#'   only. `"auto"` gives a pointwise interval at `level`, which is 95% by
#'   default. `"cri"` is accepted as a name for the same thing as `"ci"`.
#' @param level Interval level used when `interval = "ci"`. Ignored otherwise.
#' @param n Number of points at which to evaluate the effect. Ignored for the
#'   GAM partial-effect path, where \pkg{gratia} chooses the grid.
#' @param transform Optional parameter indicating how to transform the variable,
#'   if applicable. Applied to both the curve and the rug, so they stay aligned.
#' @param rug.type Type of rug plot to draw above the effect.
#' @param bins Number of bins for a histogram rug.
#' @param group.lab Legend title used when the effect splits into several
#'   curves, as for a factor-smooth interaction. Defaults to the name of the
#'   factor doing the splitting.
#' @param theme A \pkg{ggplot2} theme for the effect panel. Defaults to
#'   [theme_fancyfx()], a publication-ready theme built on
#'   [ggpubr::theme_pubr()]. Any other theme can be passed instead.
#' @param palette Colours used when the effect splits into several curves.
#'   Defaults to [fancyfx_palette()], which is colour-vision-deficiency safe.
#' @param linewidth Width of the effect line.
#' @param ... Passed through to the backend, [gratia::smooth_estimates()] or
#'   [marginaleffects::predictions()]. For a mixed model this is where
#'   `re.form` goes: it defaults to `NA`, meaning the effect is drawn at the
#'   population level rather than for one arbitrary group. See Details.
#'
#' @details
#' What gets plotted depends on the model, because the natural quantity differs:
#'
#' * A **GAM** is shown as the *partial effect* of the smooth
#'   -- the term's own contribution, centered to average zero. This is the
#'   quantity this package drew before it handled anything but GAMs, and it
#'   remains the default so existing code is unaffected.
#' * **Any other model**, and a GAM asked for `scale = "response"`, is shown as
#'   *predicted values*: the model's fitted output as `var` varies, with the
#'   other predictors held at representative values.
#'
#' The y-axis label reports which one you got. Do not compare a partial effect
#' against a prediction as though they were on the same footing -- one is
#' centered on zero and excludes the rest of the model, the other is not and
#' does not.
#'
#' The default ribbon is a **95% pointwise interval**, matching
#' [mgcv::plot.gam()], which draws `+/- 2 SE`, and [gratia::draw()], which draws
#' 95%. Earlier versions of this package drew `+/- 1 SE` -- roughly 68%, half
#' the width of both -- which a reader seeing a ribbon on a smooth would very
#' likely misread as 95%. Pass `interval = "se"` for that narrower band, now
#' that asking for it is explicit.
#'
#' For a GAM smooth, `interval = "simultaneous"` draws a band covering the
#' whole curve rather than each point separately. A pointwise interval covers
#' the true value at each x with the stated probability *at that x*; across a
#' curve evaluated at a hundred points, the true function strays outside it far
#' more often than the stated rate. Any claim about the *shape* of a smooth --
#' which is usually why one is drawn -- is a claim about the whole curve, and
#' the simultaneous band is the one that supports it. It is noticeably wider,
#' which is the point.
#'
#' A **Bayesian fit** (\pkg{brms}, \pkg{rstanarm}) is summarised from posterior
#' draws, which yield an interval but no standard error, so the ribbon is the
#' credible interval at `level` -- there is no SE ribbon to be had. Write
#' `interval = "cri"` if you would rather say so explicitly; it computes the
#' same thing. \pkg{brms} takes `re_formula` rather than `re.form`, and that
#' translation is handled for you.
#'
#' A **factor-smooth interaction**, `s(x, by = f)`, is one smooth per level of
#' `f`. Those are drawn as separate coloured curves with a legend, rather than
#' joined end to end into a single zigzagging line.
#'
#' For a **mixed model**, `re.form` defaults to `NA`, so the effect is drawn at
#' the population level. This matters: left to the backend's own default, the
#' grouping factor is held at its modal level and the plot silently shows the
#' effect for one arbitrary group rather than the average one. Pass
#' `re.form = NULL` to include the random effects. Note that the ribbon
#' reflects uncertainty in the fixed effects only -- it does not widen to
#' account for variation between groups.
#'
#' On the response scale, `interval = "ci"` is built on the link scale and
#' back-transformed, so it stays within the range the response admits -- a
#' probability band will not run past 0 or 1. `interval = "se"` cannot use that
#' construction, since an asymmetric interval has no single standard error
#' behind it. Prefer `"ci"` when plotting probabilities.
#'
#' @return A `patchwork` object: the rug above, the effect curve below.
#'
#' @family effect plots
#' @seealso [combinePlots()] to show several predictors at once, [plotRugs()]
#'   for the rug on its own, and [mgcv::gam()] or
#'   [marginaleffects::predictions()] for the machinery underneath.
#'
#' @references
#' Wood, S. N. (2017). *Generalized Additive Models: An Introduction with R*
#' (2nd ed.). Chapman and Hall/CRC. \doi{10.1201/9781315370279}
#'
#' Arel-Bundock, V., Greifer, N., & Heiss, A. (2024). How to interpret
#' statistical models using marginaleffects for R and Python.
#' *Journal of Statistical Software*, 111(9), 1-32.
#' \doi{10.18637/jss.v111.i09}
#'
#' @examples
#' # A GAM: partial effect of the smooth, with the data rug above it
#' gam.fit <- mgcv::gam(Petal.Length ~ s(Sepal.Length), data = iris)
#' plotEffects(gam.fit, iris, "Sepal.Length", xlab = "Sepal length (cm)")
#'
#' # A linear model: predicted values, via marginaleffects
#' lm.fit <- lm(Petal.Length ~ Sepal.Length + Species, data = iris)
#' plotEffects(lm.fit, iris, "Sepal.Length")
#'
#' # A logistic regression on the response scale, with a 95% interval
#' glm.fit <- glm(am ~ wt + hp, data = mtcars, family = binomial)
#' plotEffects(glm.fit, mtcars, "wt", scale = "response",
#'             interval = "ci", rug.type = "density")
#'
#' @export
plotEffects <- function(model, dat, var, xlab = var, ylab = NULL, title = "",
                        scale = c("auto", "link", "response"),
                        interval = c("auto", "se", "ci", "cri"),
                        level = 0.95,
                        n = 100,
                        transform = c("none", "log", "log10", "sqrt"),
                        rug.type = c("histogram", "density"),
                        bins = 30,
                        group.lab = NULL,
                        theme = theme_fancyfx(),
                        palette = fancyfx_palette(),
                        linewidth = 0.8,
                        ...) {
  # A misspelled formal would otherwise be swallowed by ... and passed to a
  # backend that ignores it, leaving no sign the request was dropped.
  warn_misspelled_dots(names(list(...)), names(formals()))


  transform <- check_transform(transform)
  rug.type <- check_choice(rug.type, c("histogram", "density"), "type")

  # dat is passed on as a fallback range for models that do not keep the data
  # they were fitted on; it is already to hand for the rug.
  est <- effect_estimates(model, var, scale = scale, interval = interval,
                          level = level, n = n, data = dat, ...)

  # Set from the frame rather than from `scale`, so the label always names the
  # quantity that was actually computed -- including when a GAM asked for the
  # response scale got predictions instead of a partial effect.
  if (is.null(ylab)) ylab <- attr(est, "quantity")

  # A factor-smooth interaction, s(x, by = f), is one curve per level of f.
  # They have to be told apart, or geom_line() joins the end of one level's
  # curve to the start of the next and draws a zigzag.
  grouped <- ".group" %in% names(est)
  if (grouped && is.null(group.lab)) group.lab <- attr(est, "group.label")

  if (grouped) {
    base.aes <- ggplot2::aes(x = switch(transform,
                                        none = .data$.x,
                                        log = log(.data$.x),
                                        log10 = log10(.data$.x),
                                        sqrt = sqrt(.data$.x)),
                             y = .data$.estimate,
                             colour = .data$.group, group = .data$.group)
    ribbon.aes <- ggplot2::aes(ymin = .data$.lower, ymax = .data$.upper,
                               fill = .data$.group, group = .data$.group)
  } else {
    base.aes <- ggplot2::aes(x = switch(transform,
                                        none = .data$.x,
                                        log = log(.data$.x),
                                        log10 = log10(.data$.x),
                                        sqrt = sqrt(.data$.x)),
                             y = .data$.estimate)
    ribbon.aes <- ggplot2::aes(ymin = .data$.lower, ymax = .data$.upper)
  }

  var.plot <- ggplot2::ggplot(est, mapping = base.aes) +
    ggplot2::geom_ribbon(mapping = ribbon.aes, alpha = 0.25, colour = NA) +
    ggplot2::geom_line(linewidth = linewidth) +
    ggplot2::labs(x = xlab, y = ylab,
                  colour = group.lab, fill = group.lab,
                  title = if (nzchar(title)) title else NULL) +
    theme

  if (grouped) {
    levels.n <- nlevels(est$.group)
    if (levels.n > length(palette)) {
      # Past the palette's length, more hues stop being tellable apart. Say so
      # and hand the scale back to ggplot2 rather than silently recycling
      # colours, which would label two different levels identically.
      warning("Effect splits into ", levels.n, " curves but the palette has ",
              length(palette), " colours. Falling back to ggplot2's default ",
              "scale -- consider a facet per level instead.", call. = FALSE)
    } else {
      pal <- palette[seq_len(levels.n)]
      var.plot <- var.plot +
        ggplot2::scale_colour_manual(values = pal) +
        ggplot2::scale_fill_manual(values = pal)
    }
  }

  rug.plot <- plotRugs(dat = dat, var = var, type = rug.type,
                       transform = transform, bins = bins)

  list(rug.plot, var.plot) |> patchwork::wrap_plots(nrow = 2, heights = c(1, 5))
}
