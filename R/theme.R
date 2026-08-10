#' A publication-ready theme for effect plots
#'
#' The default look for [plotEffects()]. Built on [ggpubr::theme_pubr()], which
#' targets the conventions journals tend to expect: no background panel, no
#' grid, plain black axis lines, and text large enough to survive being shrunk
#' into a column.
#'
#' @param base_size Base font size in points. The usual reason to change it is
#'   figure width -- a two-column figure needs larger text than a full-page one
#'   to end up the same size on the page.
#' @param base_family Base font family. Left empty by default so the device
#'   chooses; set it to match a manuscript's font.
#' @param legend Legend position: `"right"`, `"top"`, `"bottom"`, `"left"`, or
#'   `"none"`.
#' @param border Whether to draw a full box around the panel rather than only
#'   the left and bottom axis lines.
#' @param axis.title.size,axis.text.size Size of the axis titles and of the
#'   numbers along the axes.
#' @param title.size,subtitle.size,caption.size Size of the plot title,
#'   subtitle and caption.
#' @param legend.title.size,legend.text.size Size of the legend title and of
#'   its entries.
#' @param strip.text.size Size of facet strip labels.
#'
#' @section Sizing text:
#' Raising `base_size` scales every element at once, keeping their relative
#' sizes balanced, and is usually all that is needed. Each element also takes
#' its own argument for the cases where it is not: a long axis title that needs
#' to be smaller than the numbers beside it, or a journal that specifies a size
#' for one thing and not the rest. Anything left `NULL` follows `base_size`.
#'
#' Panel labels -- the `A`, `B`, `C` on a multi-panel figure -- are drawn by the
#' arranging step rather than the theme, so they have their own `label.size`
#' argument on [combinePlots()] and [comparePlots()].
#'
#' @return A \pkg{ggplot2} theme object.
#'
#' @seealso [plotEffects()], which uses this by default, and
#'   [fancyfx_palette()] for the matching colours.
#'
#' @examples
#' fit <- lm(Petal.Length ~ Sepal.Length, data = iris)
#'
#' # The default
#' plotEffects(fit, iris, "Sepal.Length")
#'
#' # Everything larger, for a narrow two-column figure
#' plotEffects(fit, iris, "Sepal.Length", theme = theme_fancyfx(base_size = 16))
#'
#' # Or one element at a time
#' plotEffects(fit, iris, "Sepal.Length",
#'             theme = theme_fancyfx(base_size = 14,
#'                                   axis.title.size = 18,
#'                                   axis.text.size = 11))
#'
#' # Or hand it any other ggplot2 theme
#' plotEffects(fit, iris, "Sepal.Length", theme = ggplot2::theme_minimal())
#'
#' @export
theme_fancyfx <- function(base_size = 12, base_family = "",
                          legend = "right", border = FALSE,
                          axis.title.size = NULL, axis.text.size = NULL,
                          title.size = NULL, subtitle.size = NULL,
                          caption.size = NULL,
                          legend.title.size = NULL, legend.text.size = NULL,
                          strip.text.size = NULL) {
  # Each element defaults to a multiple of base_size, so raising base_size
  # alone scales the whole figure and stays balanced. Setting one explicitly
  # overrides just that element.
  axis.title.size <- axis.title.size %||% base_size
  axis.text.size <- axis.text.size %||% (base_size * 0.85)
  title.size <- title.size %||% base_size
  subtitle.size <- subtitle.size %||% (base_size * 0.85)
  caption.size <- caption.size %||% (base_size * 0.8)
  legend.title.size <- legend.title.size %||% base_size
  legend.text.size <- legend.text.size %||% (base_size * 0.9)
  strip.text.size <- strip.text.size %||% base_size

  ggpubr::theme_pubr(base_size = base_size, base_family = base_family,
                     legend = legend, border = border) +
    ggplot2::theme(
      # theme_pubr centers the title; a figure panel reads better left-aligned,
      # where it sits over the y axis rather than floating above the middle.
      plot.title = ggplot2::element_text(size = title.size, face = "bold",
                                         hjust = 0),
      plot.subtitle = ggplot2::element_text(size = subtitle.size, hjust = 0),
      plot.caption = ggplot2::element_text(size = caption.size, hjust = 0),
      axis.title = ggplot2::element_text(size = axis.title.size),
      axis.text = ggplot2::element_text(size = axis.text.size),
      legend.title = ggplot2::element_text(size = legend.title.size,
                                           face = "bold"),
      legend.text = ggplot2::element_text(size = legend.text.size),
      strip.text = ggplot2::element_text(size = strip.text.size),
      # The rug sits directly above the curve and shares its x axis, so the
      # gap between the two has to stay small or they stop reading as one
      # figure.
      plot.margin = ggplot2::margin(4, 6, 4, 6)
    )
}

#' Colours for effects split into several curves
#'
#' A six-colour categorical palette, used when an effect splits by a factor --
#' a factor-smooth interaction, most often. Assigned in the order given.
#'
#' @details
#' Chosen by search rather than by eye, and checked against the properties that
#' decide whether a reader can actually tell two curves apart: every colour sits
#' in a mid lightness band, carries enough chroma not to read as grey, clears a
#' 3:1 contrast ratio against a white page, and stays separable under simulated
#' protanopia and deuteranopia.
#'
#' All pairs clear the colour-vision-deficiency floor. The fifth and sixth
#' colours are the closest pair and sit between the floor and the comfortable
#' target, which is why a legend is always drawn -- identity is never carried by
#' colour alone.
#'
#' Six is the limit. Past that, colours stop being tellable apart no matter how
#' they are chosen, and a facet per level communicates far better than a
#' seventh hue; [plotEffects()] says so rather than inventing one.
#'
#' @param n How many colours to return. Defaults to all six.
#'
#' @return A character vector of hex colours.
#'
#' @seealso [theme_fancyfx()] for the matching theme.
#'
#' @examples
#' fancyfx_palette()
#' fancyfx_palette(3)
#'
#' @export
fancyfx_palette <- function(n = 6) {
  pal <- c(
    "#215689",  # blue
    "#B58D2D",  # gold
    "#346210",  # green
    "#C368FD",  # purple
    "#B4677A",  # red
    "#1892A3"   # teal
  )
  if (n > length(pal)) {
    stop("fancyfx_palette() offers at most ", length(pal), " colours; ",
         n, " requested.", call. = FALSE)
  }
  pal[seq_len(n)]
}
