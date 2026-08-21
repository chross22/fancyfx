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
#'   below it for attention.
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
#' @export
plotRugs <- function(dat, var, type = c("histogram", "density"),
                     transform = c("none", "log", "log10", "sqrt"),
                     bins = 30, fill = "grey35") {

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
  # caller inspecting the plot sees the variable it asked for.
  if (!var %in% names(dat)) {
    dat <- data.frame(rug_values(dat, var), check.names = FALSE)
    names(dat) <- var
  }
  mapping <- ggplot2::aes(x = switch(transform,
                                     none = .data[[var]],
                                     log = log(.data[[var]]),
                                     log10 = log10(.data[[var]]),
                                     sqrt = sqrt(.data[[var]])))

  if (type == "histogram") {
    return(ggplot2::ggplot(data = dat) +
             ggplot2::theme_void() +
             ggplot2::geom_histogram(mapping = mapping, bins = bins,
                                     fill = fill, colour = NA))
  }

  # Filled rather than left as a bare outline, so the two rug types read the
  # same weight above the curve. geom_density() takes no fill unless told, and
  # alpha alone does nothing to an unfilled shape.
  ggplot2::ggplot(data = dat) +
    ggplot2::theme_void() +
    ggplot2::geom_density(mapping = mapping, fill = fill, colour = NA)
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
