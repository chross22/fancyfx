#' How much do two predicted distributions overlap?
#'
#' Compares two suitability surfaces cell by cell and reports how similar they
#' are. Used to ask whether two species, two seasons, or the same species under
#' two climate scenarios occupy the same space.
#'
#' @param x,y Two `SpatRaster` layers of predicted suitability, or two numeric
#'   vectors of equal length. Must line up cell for cell.
#' @param statistic `"D"` for Schoener's D, `"I"` for Warren's I, or `"both"`.
#' @param na.rm Whether to drop cells missing from either surface. See Details.
#'
#' @details
#' Both statistics run from 0 (no overlap) to 1 (identical), and both begin by
#' rescaling each surface to sum to 1, so what is compared is the *shape* of
#' each distribution rather than its level. A model predicting uniformly higher
#' suitability than another can still overlap it perfectly.
#'
#' Schoener's D is one minus half the summed absolute difference. Warren's I
#' works on square roots, which makes it less sensitive to a handful of cells
#' where the two surfaces disagree sharply. They usually agree; where they do
#' not, D is being moved by a few strong disagreements and I by the broad
#' pattern.
#'
#' `na.rm` defaults to `FALSE` for the same reason [ensemble_summary()] does.
#' Dropping cells missing from one surface compares the two over a domain
#' neither was asked about, and nothing in the resulting number says how much
#' was discarded. Make the coverage match first, deliberately.
#'
#' Neither statistic is a test. A D of 0.7 is not evidence of anything on its
#' own -- two surfaces built from the same covariates over the same domain will
#' overlap substantially whatever the species do. [niche_equivalency()] is the
#' randomisation test that gives it a reference distribution.
#'
#' @return A named numeric vector.
#'
#' @family spatial plots
#' @seealso [niche_equivalency()] to test it against a null,
#'   [plotUncertainty()] for ensemble spread.
#'
#' @references
#' Warren, D. L., Glor, R. E., & Turelli, M. (2008). Environmental niche
#' equivalency versus conservatism: quantitative approaches to niche evolution.
#' *Evolution*, 62(11), 2868-2883.
#' \doi{10.1111/j.1558-5646.2008.00482.x}
#'
#' @examples
#' set.seed(1)
#' a <- runif(400)
#' b <- a * 0.8 + runif(400) * 0.2
#'
#' niche_overlap(a, b)
#' niche_overlap(a, a)          # identical surfaces
#'
#' @export
niche_overlap <- function(x, y, statistic = c("both", "D", "I"),
                          na.rm = FALSE) {
  statistic <- check_choice(statistic, c("both", "D", "I"), "statistic")

  values <- niche_values(x, y)
  first <- values$x
  second <- values$y

  usable <- !is.na(first) & !is.na(second)
  if (!all(usable)) {
    if (!na.rm) {
      stop("The two surfaces are missing in different places (",
           sum(!usable), " of ", length(usable), " cells). Comparing what ",
           "remains measures overlap over a domain neither surface was asked ",
           "about. Make the coverage match, or pass na.rm = TRUE knowing ",
           "that is what you are doing.", call. = FALSE)
    }
    first <- first[usable]
    second <- second[usable]
  }

  if (!length(first)) {
    stop("No cells are present in both surfaces.", call. = FALSE)
  }
  if (any(first < 0, na.rm = TRUE) || any(second < 0, na.rm = TRUE)) {
    stop("Suitability surfaces must be non-negative to be rescaled into ",
         "distributions.", call. = FALSE)
  }

  # Rescaled to sum to 1, so what is compared is the shape of each surface and
  # not its level.
  first <- first / sum(first)
  second <- second / sum(second)

  overlap <- c(
    D = 1 - 0.5 * sum(abs(first - second)),
    I = 1 - 0.5 * sum((sqrt(first) - sqrt(second))^2)
  )

  if (statistic == "both") overlap else overlap[statistic]
}

#' Pull comparable numeric vectors out of the accepted inputs
#'
#' @param x,y Two rasters or two numeric vectors.
#' @return A list with `x` and `y`.
#' @keywords internal
niche_values <- function(x, y) {
  if (inherits(x, "SpatRaster") || inherits(y, "SpatRaster")) {
    require_terra()
    if (!inherits(x, "SpatRaster") || !inherits(y, "SpatRaster")) {
      stop("Both surfaces must be SpatRasters, or neither.", call. = FALSE)
    }
    if (terra::nlyr(x) != 1 || terra::nlyr(y) != 1) {
      stop("Each surface must be a single layer.", call. = FALSE)
    }
    if (!terra::compareGeom(x, y, stopOnError = FALSE)) {
      stop("The two rasters do not share a geometry, so their cells do not ",
           "correspond. Resample one onto the other first.", call. = FALSE)
    }
    return(list(x = terra::values(x)[, 1], y = terra::values(y)[, 1]))
  }

  x <- as.numeric(x)
  y <- as.numeric(y)
  if (length(x) != length(y)) {
    stop("The two surfaces must be the same length: ", length(x), " and ",
         length(y), " given.", call. = FALSE)
  }
  list(x = x, y = y)
}

#' Test an observed overlap against a null of interchangeable occurrences
#'
#' A pair of surfaces will overlap substantially whatever the species do, simply
#' because both were built from the same covariates over the same domain. This
#' asks whether the observed overlap is higher than it would be if the two sets
#' of occurrences were interchangeable.
#'
#' @param occurrence.x,occurrence.y The two occurrence data frames the models
#'   were fitted on.
#' @param fit A function taking one occurrence data frame and returning a
#'   suitability surface -- a `SpatRaster` or numeric vector. It is called once
#'   per group per replicate, so it should be cheap.
#' @param n.rep Number of randomisations.
#' @param statistic `"D"` or `"I"`.
#' @param seed Random seed.
#'
#' @details
#' Under the null, the two sets of occurrences are pooled and split again at
#' random into groups of the original sizes, and both models are refitted. The
#' overlap of that pair is one draw from the null distribution. Repeated, it
#' says how much overlap the shared covariates and shared domain buy on their
#' own, following Warren et al. (2008).
#'
#' The observed overlap being *lower* than the null is the informative result:
#' it says the two groups occupy measurably different environments. An overlap
#' inside the null distribution means the data cannot distinguish them, which is
#' not the same as showing they are the same.
#'
#' The test refits the model `2 * n.rep` times, so a slow `fit` makes it slow.
#' That cost is inherent -- the null has to come from the same fitting procedure
#' as the observation, or it is testing something else.
#'
#' @return A list with the `observed` overlap, the `null` distribution, and the
#'   one-sided `p.value` for the observed being lower than the null.
#'
#' @family spatial plots
#' @seealso [niche_overlap()] for the statistic itself.
#'
#' @references
#' Warren, D. L., Glor, R. E., & Turelli, M. (2008). Environmental niche
#' equivalency versus conservatism: quantitative approaches to niche evolution.
#' *Evolution*, 62(11), 2868-2883.
#' \doi{10.1111/j.1558-5646.2008.00482.x}
#'
#' @examples
#' set.seed(1)
#' # Two groups occupying different parts of a covariate
#' a <- data.frame(temp = rnorm(60, 8, 1.5))
#' b <- data.frame(temp = rnorm(60, 14, 1.5))
#'
#' # A toy "model": density of occurrences over a fixed grid
#' grid <- seq(0, 20, length.out = 50)
#' fit_density <- function(occurrence) {
#'   stats::dnorm(grid, mean(occurrence$temp), stats::sd(occurrence$temp))
#' }
#'
#' result <- niche_equivalency(a, b, fit_density, n.rep = 19)
#' result$observed
#' result$p.value
#'
#' @export
niche_equivalency <- function(occurrence.x, occurrence.y, fit, n.rep = 99,
                              statistic = c("D", "I"), seed = 1) {
  statistic <- check_choice(statistic, c("D", "I"), "statistic")
  if (!is.function(fit)) {
    stop("fit must be a function taking one occurrence data frame and ",
         "returning a suitability surface.", call. = FALSE)
  }
  if (!is.numeric(n.rep) || length(n.rep) != 1 || n.rep < 1) {
    stop("n.rep must be a single number of at least 1.", call. = FALSE)
  }

  observed <- niche_overlap(fit(occurrence.x), fit(occurrence.y),
                            statistic = statistic, na.rm = TRUE)

  if (!is.null(seed)) {
    old.seed <- if (exists(".Random.seed", .GlobalEnv)) {
      get(".Random.seed", .GlobalEnv)
    } else {
      NULL
    }
    set.seed(seed)
    on.exit({
      if (!is.null(old.seed)) assign(".Random.seed", old.seed, .GlobalEnv)
    }, add = TRUE)
  }

  pooled <- rbind(occurrence.x, occurrence.y)
  n.x <- nrow(occurrence.x)

  null.distribution <- vapply(seq_len(n.rep), function(i) {
    shuffled <- sample(nrow(pooled))
    left <- pooled[shuffled[seq_len(n.x)], , drop = FALSE]
    right <- pooled[shuffled[-seq_len(n.x)], , drop = FALSE]
    niche_overlap(fit(left), fit(right), statistic = statistic, na.rm = TRUE)
  }, numeric(1))

  # One-sided: the question is whether the two groups overlap LESS than
  # interchangeable ones would. The observed value counts itself, so the
  # p-value can never be zero -- with n.rep replicates the floor is
  # 1 / (n.rep + 1), and reporting less than that would be false precision.
  p.value <- (sum(null.distribution <= observed) + 1) / (n.rep + 1)

  structure(
    list(observed = unname(observed), null = null.distribution,
         p.value = p.value, statistic = statistic, n.rep = n.rep),
    class = "fancyfx_equivalency")
}

#' @export
print.fancyfx_equivalency <- function(x, ...) {
  cat("Niche equivalency test\n")
  cat("  statistic  ", x$statistic, "\n", sep = "")
  cat("  observed   ", format(round(x$observed, 4), nsmall = 4), "\n", sep = "")
  cat("  null median", format(round(stats::median(x$null), 4), nsmall = 4),
      "\n", sep = " ")
  cat("  p-value    ", format(round(x$p.value, 4), nsmall = 4),
      " (", x$n.rep, " randomisations)\n", sep = "")
  cat("\nObserved below the null means the two groups occupy measurably\n",
      "different environments. Inside it means the data cannot tell them\n",
      "apart, which is not the same as showing they are the same.\n", sep = "")
  invisible(x)
}

#' Plot a niche equivalency test against its null
#'
#' The observed overlap on its own says little -- two surfaces built from the
#' same covariates over the same domain overlap substantially whatever the
#' species do. What makes it readable is seeing it against the distribution of
#' overlaps that interchangeable occurrences would have produced.
#'
#' @param x A result from [niche_equivalency()].
#' @param title Plot title, optional.
#' @param bins Number of histogram bins for the null distribution.
#' @param theme A \pkg{ggplot2} theme. Defaults to [theme_fancyfx()].
#' @param colour Colour of the observed-value line.
#' @param ... Ignored.
#'
#' @return A \pkg{ggplot2} object.
#'
#' @family spatial plots
#' @seealso [niche_equivalency()] for the test itself.
#'
#' @examples
#' set.seed(1)
#' grid <- seq(0, 20, length.out = 50)
#' fit_density <- function(o) stats::dnorm(grid, mean(o$temp), stats::sd(o$temp))
#'
#' result <- niche_equivalency(data.frame(temp = rnorm(60, 8, 1.5)),
#'                             data.frame(temp = rnorm(60, 14, 1.5)),
#'                             fit_density, n.rep = 19)
#' plot(result)
#'
#' @export
plot.fancyfx_equivalency <- function(x, title = "", bins = 20,
                                     theme = theme_fancyfx(),
                                     colour = fancyfx_palette(1), ...) {
  null.frame <- data.frame(.overlap = x$null)

  ggplot2::ggplot(null.frame, ggplot2::aes(x = .data$.overlap)) +
    ggplot2::geom_histogram(bins = bins, fill = "grey70", colour = NA) +
    ggplot2::geom_vline(xintercept = x$observed, colour = colour,
                        linewidth = 1) +
    ggplot2::annotate("text", x = x$observed, y = Inf, hjust = -0.1,
                      vjust = 1.5, colour = colour,
                      label = paste0("observed = ",
                                     format(round(x$observed, 3), nsmall = 3))) +
    ggplot2::labs(
      x = paste0("Overlap (", x$statistic, ") under interchangeable occurrences"),
      y = "Randomisations",
      title = if (nzchar(title)) title else NULL,
      caption = paste0("p = ", format(round(x$p.value, 4), nsmall = 4),
                       " from ", x$n.rep, " randomisations")) +
    theme
}
