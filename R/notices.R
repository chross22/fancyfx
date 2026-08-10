#' Record of which notices have already been given
#'
#' Some of what this package has to say is important once and tedious on every
#' call -- a deprecation, or a caveat about how a metric was computed. Plotting
#' a dozen panels in a loop should not repeat the same paragraph a dozen times,
#' or the reader stops seeing any of it.
#'
#' @keywords internal
#' @noRd
notice.state <- new.env(parent = emptyenv())

#' Warn once per session
#'
#' A hand-rolled stand-in for `lifecycle::deprecate_soft()`. Adding
#' \pkg{lifecycle} to Imports is not worth it for one deprecation.
#'
#' @param id Identifier for this notice, so each one fires independently.
#' @param ... Pieces of the message, pasted together.
#' @return Invisibly `NULL`, called for its side effect.
#' @keywords internal
deprecate_once <- function(id, ...) {
  if (already_said(id)) return(invisible(NULL))
  warning(paste0(...), call. = FALSE)
  invisible(NULL)
}

#' Note something once per session
#'
#' A message rather than a warning: these are caveats worth reading, not signs
#' that anything has gone wrong. `suppressMessages()` silences them.
#'
#' @param id Identifier for this notice, so each one fires independently.
#' @param ... Pieces of the message, pasted together.
#' @return Invisibly `NULL`, called for its side effect.
#' @keywords internal
note_once <- function(id, ...) {
  if (already_said(id)) return(invisible(NULL))
  message(paste0(...))
  invisible(NULL)
}

#' Has this notice been given, and mark it as given
#'
#' @param id Identifier for the notice.
#' @return `TRUE` if it has already been given.
#' @keywords internal
already_said <- function(id) {
  if (isTRUE(notice.state[[id]])) return(TRUE)
  assign(id, TRUE, envir = notice.state)
  FALSE
}

#' Deprecation badge for documentation
#'
#' @return A markdown string marking a topic as deprecated.
#' @keywords internal
lifecycle_badge_deprecated <- function() {
  "**\\[Deprecated\\]**"
}

#' Forget which notices have been given
#'
#' Exists for the tests, which need to observe a once-per-session notice more
#' than once.
#'
#' @return Invisibly `NULL`.
#' @keywords internal
reset_notices <- function() {
  rm(list = ls(notice.state), envir = notice.state)
  invisible(NULL)
}
