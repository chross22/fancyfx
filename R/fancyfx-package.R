#' fancyfx: Flexible Effect Plots for Statistical Models
#'
#' An effect curve on its own is easy to over-read. A confident-looking bend at
#' the far end of the x axis means very little if only three observations sit
#' under it. `fancyfx` addresses that by pairing every effect curve with a rug of
#' the raw data, drawn directly above it on a shared x axis, so the shape of the
#' effect and the weight of evidence behind it are read together.
#'
#' @section Main functions:
#' \describe{
#'   \item{[plotEffects()]}{One predictor: the effect curve with its rug above.}
#'   \item{[combinePlots()]}{Several predictors, arranged and labelled as panels.}
#'   \item{[plotRugs()]}{The rug on its own, if you want to compose it yourself.}
#' }
#'
#' @section Supported models:
#' Generalized additive models fitted with \pkg{mgcv} are handled by
#' [gratia::smooth_estimates()], which reports the *partial effect* of a smooth
#' on the link scale. Every other model class is handled by
#' [marginaleffects::predictions()], which reports *predicted values* with the
#' remaining predictors held at representative values.
#'
#' These are different quantities, and `fancyfx` does not pretend otherwise: the
#' y-axis label changes to say which one you are looking at. See the `scale`
#' argument of [plotEffects()], and the "What the y axis means" section of
#' `vignette("fancyfx")`.
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
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang .data
## usethis namespace: end
NULL
