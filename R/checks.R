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
