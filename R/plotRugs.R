#' Create rug plots representing distribution of the raw data
#'
#' The companion to a smooth plot: it shows where the data actually is, so a
#' bend in a smooth can be read against how much evidence sits under it.
#'
#' @param dat Raw data
#' @param var Variable to plot
#' @param type Optional parameter indicating type of plot; default is histogram
#' @param transform Optional parameter indicating how to transform the variable, if applicable
#' @param bins Number of histogram bins. Set explicitly rather than left to
#'   `geom_histogram()`'s default, which is the same 30 but emits a message
#'   about it on every plot. Ignored when `type` is `"density"`.
#' @param fill Fill colour for the rug. Deliberately a neutral grey: the rug
#'   reports where the data is, and should not compete with the effect curve
#'   below it for attention. Ignored when `group` splits the rug, which colours
#'   it by level instead.
#' @param group Optional name of a factor column in `dat` to split the rug by,
#'   as a string. Under a factor-smooth interaction each curve is fitted to one
#'   level's data only, so an undivided rug reports evidence that does not
#'   belong to the curve the reader is looking at. Split, each level's share of
#'   the data is drawn in that level's own colour.
#' @param palette Colours for the split, as a vector named by level -- the
#'   names are what tie a band of rug to its curve, so an unnamed vector is
#'   assigned in level order and a `NULL` leaves the scale to \pkg{ggplot2}.
#'   Levels the palette does not name are dropped from the rug rather than
#'   drawn in a colour that belongs to another curve.
#' @return The rug plot from dat for var
#'
#' @family effect plots
#' @seealso [plotEffects()], which stacks this above an effect curve for you.
#'
#' @examples
#' plotRugs(iris, "Sepal.Length")
#' plotRugs(iris, "Sepal.Length", type = "density")
#' plotRugs(mtcars, "disp", transform = "log10", bins = 15)
#'
#' # Split by a factor, in the palette the effect curves use
#' plotRugs(iris, "Sepal.Length", group = "Species",
#'          palette = fancyfx_palette(3))
#'
#' @export
plotRugs <- function(dat, var, type = c("histogram", "density"),
                     transform = c("none", "log", "log10", "sqrt"),
                     bins = 30, fill = "grey35",
                     group = NULL, palette = NULL) {

  # Checked here rather than left to the switch() inside aes(). aes() is lazy,
  # so an invalid value would otherwise sail through until the plot was drawn
  # and fail somewhere that says nothing about where it came from.
  type <- check_choice(type, c("histogram", "density"), "type")
  transform <- check_transform(transform)

  # A smooth's term is not always a column name. A model fitted with
  # `s(log10(depth))` has the term `log10(depth)`, and that is what
  # `plotEffects()` asks for a rug of -- so the rug under such a smooth used to
  # fail while the curve above it drew perfectly well.
  #
  # The term is evaluated into a column OF THAT NAME rather than into some
  # internal one, so the mapping below is the same expression either way and a
  # caller inspecting the plot sees the variable it asked for. Added to the
  # data rather than replacing it, because a split rug still needs the column
  # it is grouped by.
  dat <- as.data.frame(dat, check.names = FALSE)
  if (!var %in% names(dat)) dat[[var]] <- rug_values(dat, var)

  split <- rug_group(dat, group, palette)
  group <- split$group
  dat <- split$data
  palette <- split$palette

  mapping <- ggplot2::aes(x = switch(transform,
                                     none = .data[[var]],
                                     log = log(.data[[var]]),
                                     log10 = log10(.data[[var]]),
                                     sqrt = sqrt(.data[[var]])))

  # Set on the built mapping rather than written into a second aes() call,
  # which would mean carrying two near-identical copies of the transform
  # switch and letting them drift apart.
  if (!is.null(group)) {
    mapping[["fill"]] <- ggplot2::aes(fill = .data[[group]])[["fill"]]
  }

  # A split rug is stacked, so its outline is the shape the undivided rug
  # would have had: the reader still sees where the data is, and additionally
  # whose it is. Overlaid instead, the levels would hide one another and the
  # total would be unreadable.
  if (type == "density" && !is.null(group)) {
    # Split, the densities are scaled to counts before being stacked. Each
    # level's density integrates to one on its own, so stacking them raw would
    # draw a level holding a handful of observations as tall a band as one
    # holding hundreds.
    # Through the .data pronoun rather than a bare `count`, which R CMD check
    # cannot tell from an undefined global.
    mapping[["y"]] <- ggplot2::aes(y = ggplot2::after_stat(.data$count))[["y"]]
  }

  # Assembled rather than passed inline, because a `fill = NULL` argument is
  # not a fill left unset: ggplot2 reads it as an instruction to drop the
  # aesthetic, and the split rug would come out uncoloured.
  args <- list(mapping = mapping, colour = NA, position = "stack")
  # Filled rather than left as a bare outline, so the two rug types read the
  # same weight above the curve. geom_density() takes no fill unless told, and
  # alpha alone does nothing to an unfilled shape.
  if (is.null(group)) args$fill <- fill

  layer <- if (type == "histogram") {
    do.call(ggplot2::geom_histogram, c(args, list(bins = bins)))
  } else {
    do.call(ggplot2::geom_density, args)
  }

  plot <- ggplot2::ggplot(data = dat) + ggplot2::theme_void() + layer
  if (!is.null(group) && !is.null(palette)) {
    plot <- plot + ggplot2::scale_fill_manual(values = palette, drop = FALSE)
  }
  plot
}

#' The factor a rug is split by
#'
#' Resolves `group` against the data and the palette, and returns the data it
#' should be drawn from alongside it -- levels the palette does not name are
#' dropped, since drawing them would hand a band of rug the colour of a curve
#' it has nothing to do with.
#'
#' @param dat Raw data, already a data frame.
#' @param group A column name, or `NULL` for an undivided rug.
#' @param palette Colours for the split, optionally named by level.
#' @return A list of `group` -- the column name, or `NULL` for an undivided
#'   rug -- the `data` to draw it from, and the `palette` to colour it with,
#'   named by level.
#' @keywords internal
rug_group <- function(dat, group, palette = NULL) {
  undivided <- list(group = NULL, data = dat, palette = NULL)
  if (is.null(group)) return(undivided)

  if (!group %in% names(dat)) {
    # A warning rather than an error: the rug is a companion to the curve, and
    # losing its colours is not worth refusing to draw the figure over.
    warning("'", group, "' is not a column of the data, so the rug is drawn ",
            "undivided.", call. = FALSE)
    return(undivided)
  }

  values <- factor(dat[[group]])
  dat[[group]] <- values
  if (is.null(palette)) return(list(group = group, data = dat, palette = NULL))

  if (is.null(names(palette))) {
    if (length(palette) < nlevels(values)) {
      # Left to the scale, this is an error raised while the plot is being
      # drawn, naming a count of values rather than the argument it came from.
      warning("The rug splits into ", nlevels(values), " levels but the ",
              "palette has ", length(palette), " colours. Falling back to ",
              "ggplot2's default scale.", call. = FALSE)
      return(list(group = group, data = dat, palette = NULL))
    }
    # Assigned in level order, which is the order the curves were coloured in.
    palette <- stats::setNames(palette[seq_len(nlevels(values))],
                               levels(values))
  }

  # Levels come from the palette, not from the data, so a level present here
  # but not among the curves is dropped -- drawing it would hand a band of rug
  # the colour of a curve it has nothing to do with -- and the legend still
  # lists every curve, including one whose data is entirely missing.
  keep <- !is.na(values) & as.character(values) %in% names(palette)
  if (!any(keep)) {
    warning("No rows of the data belong to a level of '", group,
            "' that was drawn, so the rug is drawn undivided.", call. = FALSE)
    return(undivided)
  }
  dat <- dat[keep, , drop = FALSE]
  dat[[group]] <- factor(as.character(values[keep]), levels = names(palette))
  list(group = group, data = dat, palette = palette)
}

#' The values a rug is drawn from
#'
#' A column when `var` names one, and otherwise the term evaluated in the data
#' -- which is what makes a rug possible under `s(log10(depth))` or `s(I(x^2))`.
#' Evaluated in the data frame alone, with no enclosing environment, so that a
#' term naming a column that is not there cannot silently pick up a variable of
#' the same name from the caller and draw a rug of something else entirely.
#'
#' @param dat Raw data.
#' @param var A column name, or a term to evaluate in `dat`.
#' @return A numeric vector.
#' @keywords internal
rug_values <- function(dat, var) {
  dat <- as.data.frame(dat)
  if (var %in% names(dat)) return(dat[[var]])

  expr <- tryCatch(str2lang(var), error = function(e) NULL)
  x <- if (is.null(expr)) NULL else {
    tryCatch(eval(expr, dat, baseenv()), error = function(e) NULL)
  }
  if (is.null(x) || !is.numeric(x) || length(x) != nrow(dat)) {
    stop("'", var, "' is neither a column of the data nor a term that can be ",
         "evaluated in it. The data has: ",
         paste(utils::head(names(dat), 10), collapse = ", "),
         if (length(names(dat)) > 10) ", ...", call. = FALSE)
  }
  x
}
