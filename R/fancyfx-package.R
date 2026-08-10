#' fancyfx: Publication-Ready Effect Plots for Statistical Models
#'
#' An effect curve on its own is easy to over-read. A confident-looking bend at
#' the far end of the x axis means very little if only three observations sit
#' under it. `fancyfx` addresses that by pairing every effect curve with a rug of
#' the raw data, drawn directly above it on a shared x axis, so the shape of the
#' effect and the weight of evidence behind it are read together.
#'
#' The second thing it is for is getting that figure into a manuscript without
#' a further round of fiddling. Defaults are chosen for publication rather than
#' for exploration, so the plot you get from a bare call is close to the plot
#' you would submit.
#'
#' @section Main functions:
#' \describe{
#'   \item{[plotEffects()]}{One predictor: the effect curve with its rug above.}
#'   \item{[combinePlots()]}{Several predictors, arranged and labelled as panels.}
#'   \item{[comparePlots()]}{Several competing models, side by side.}
#'   \item{[plotRugs()]}{The rug on its own, if you want to compose it yourself.}
#'   \item{[effect_estimates()]}{The tidy numbers behind any of the above.}
#' }
#'
#' @section Publication-ready by default:
#' [theme_fancyfx()] is built on [ggpubr::theme_pubr()]: no background panel, no
#' grid, plain black axis lines, and text sized to survive being shrunk into a
#' journal column. Panels are lettered `A`, `B`, `C`, with the style selectable
#' for whatever a journal asks for.
#'
#' Effects split by a factor are coloured with [fancyfx_palette()], chosen by
#' search rather than by eye: every colour sits in a mid lightness band, clears
#' a 3:1 contrast ratio against a white page, and stays separable under
#' simulated protanopia and deuteranopia. A legend is always drawn, so identity
#' never rests on colour alone.
#'
#' Every one of these is an argument, so a house style can replace any of them.
#'
#' @section Supported models:
#' Generalized additive models fitted with \pkg{mgcv} are handled by
#' [gratia::smooth_estimates()], which reports the *partial effect* of a smooth
#' on the link scale. Every other model class is handled by
#' [marginaleffects::predictions()], which reports *predicted values* with the
#' remaining predictors held at representative values -- this covers `lm`,
#' `glm`, mixed models from \pkg{lme4} and \pkg{glmmTMB}, and Bayesian fits from
#' \pkg{brms} and \pkg{rstanarm}, among many others.
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
