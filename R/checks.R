#' Check an argument against its allowed values
#'
#' `match.arg()` would do this, but its message names the formal argument rather
#' than the value that was wrong, and these functions have said "Unknown type
#' requested: x" since they were written. Kept, because the message is better.
#'
#' @param value the value given
#' @param allowed the values accepted
#' @param label what to call it in the error message
#' @return `value`, unchanged
#' @keywords internal
check_choice <- function(value, allowed, label) {
  if (length(value) > 1) value <- value[1]
  if (!(value %in% allowed)) {
    stop("Unknown ", label, " requested: ", value, call. = FALSE)
  }
  value
}

#' Check a transform name
#'
#' @param transform the transform given
#' @return `transform`, unchanged
#' @keywords internal
check_transform <- function(transform) {
  if (length(transform) > 1) transform <- transform[1]
  if (!(transform %in% c("none", "log", "log10", "sqrt"))) {
    stop("Unknown transformation requested: ", transform, call. = FALSE)
  }
  transform
}

#' Recycle a per-panel argument to the number of panels
#'
#' Recycled explicitly rather than by R's rules, so a length that happens to
#' divide into the number of panels but was not meant to be recycled is an
#' error rather than a silently rearranged plot.
#'
#' @param value The argument given.
#' @param n How many panels there are.
#' @param what What to call the argument in the error message.
#' @param units What to call the panels in the error message.
#' @return `value`, of length `n`.
#' @keywords internal
recycle_to <- function(value, n, what, units) {
  if (length(value) == 1) return(rep(value, n))
  if (length(value) != n) {
    stop(what, " must be one value, or one per ", units, ": ",
         n, " expected, ", length(value), " given.", call. = FALSE)
  }
  value
}

#' Build panel labels for a multi-panel figure
#'
#' @param labels What the caller asked for: `"a"` for lower-case letters, `"A"`
#'   for upper-case, `"1"` for numbers, `"none"`/`NULL` for no labels, or a
#'   character vector to use verbatim.
#' @param n How many panels there are.
#' @return A character vector of length `n`, or `NULL` for no labels.
#' @keywords internal
panel_labels <- function(labels, n) {
  if (is.null(labels)) return(NULL)

  if (length(labels) == 1 && labels %in% c("a", "A", "1", "none")) {
    return(switch(labels,
                  a = letters[seq_len(n)],
                  A = LETTERS[seq_len(n)],
                  "1" = as.character(seq_len(n)),
                  none = NULL))
  }

  # Anything else is taken literally, so panels can be labelled with whatever a
  # journal asks for. It still has to match the number of panels, or the labels
  # would silently slide onto the wrong plots.
  if (length(labels) != n) {
    stop("labels must be one of \"a\", \"A\", \"1\", \"none\", or one label ",
         "per panel: ", n, " expected, ", length(labels), " given.",
         call. = FALSE)
  }
  as.character(labels)
}

#' Check a scale name
#'
#' `"auto"` is resolved by each `effect_estimates()` method, not here: the
#' natural scale differs by backend, and only the method knows which it is.
#'
#' @param scale the scale given
#' @return `scale`, unchanged
#' @keywords internal
check_scale <- function(scale) {
  check_choice(scale, c("auto", "link", "response"), "scale")
}

#' Check an interval name
#'
#' `"cri"` is accepted as a name for the same computation: under a Bayesian fit
#' the backend returns a credible interval, and a user who writes `"cri"` to say
#' so should not be met with an error.
#'
#' @param interval the interval given
#' @return `interval`, with `"cri"` normalised to `"ci"`
#' @keywords internal
check_interval <- function(interval) {
  interval <- check_choice(interval, c("auto", "se", "ci", "cri"), "interval")
  if (interval == "cri") "ci" else interval
}

#' Check a confidence level
#'
#' @param level the level given
#' @return `level`, unchanged
#' @keywords internal
check_level <- function(level) {
  if (!is.numeric(level) || length(level) != 1 || is.na(level) ||
      level <= 0 || level >= 1) {
    stop("level must be a single number strictly between 0 and 1, not: ",
         paste(format(level), collapse = ", "), call. = FALSE)
  }
  level
}
