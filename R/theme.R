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
#' # Larger text for a narrow, two-column figure
#' plotEffects(fit, iris, "Sepal.Length", theme = theme_fancyfx(base_size = 14))
#'
#' # Or hand it any other ggplot2 theme
#' plotEffects(fit, iris, "Sepal.Length", theme = ggplot2::theme_minimal())
#'
#' @export
theme_fancyfx <- function(base_size = 12, base_family = "",
                          legend = "right", border = FALSE) {
  ggpubr::theme_pubr(base_size = base_size, base_family = base_family,
                     legend = legend, border = border) +
    ggplot2::theme(
      # theme_pubr centers the title; a figure panel reads better left-aligned,
      # where it sits over the y axis rather than floating above the middle.
      plot.title = ggplot2::element_text(size = base_size, face = "bold",
                                         hjust = 0),
      axis.title = ggplot2::element_text(size = base_size),
      legend.title = ggplot2::element_text(size = base_size, face = "bold"),
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
