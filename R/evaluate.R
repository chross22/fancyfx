#' Threshold-dependent classification metrics across every cutoff
#'
#' Sweeps every threshold the predictions admit and reports what the model
#' would score at each one. The basis of [plotROC()] and [plotThreshold()], and
#' useful on its own for finding the cutoff a decision should actually use.
#'
#' @param model A fitted presence/absence model -- one whose predictions are
#'   probabilities. See Details.
#' @param newdata Data to evaluate on. **Required, and it should not be the
#'   data the model was fitted to.** See the section below.
#' @param folds Optional vector of fold identifiers, one per row of `newdata`,
#'   as produced by a cross-validation scheme. When given, metrics are computed
#'   within each fold and the fold is recorded, so the spread across folds can
#'   be seen rather than averaged away. Using folds emits a note about what
#'   cross-validated metrics are and are not evidence of; see the section
#'   below.
#' @param ... Passed to [stats::predict()]. For a mixed model, `re.form`
#'   defaults to `NA` so held-out groups the model never saw do not error.
#'
#' @details
#' Every metric here is defined for a binary outcome and nothing else. AUC and
#' TSS applied to a Gaussian model of biomass would return a number, and the
#' number would be meaningless, so a non-binary response is refused rather than
#' scored.
#'
#' The response may be `0`/`1`, a logical, or a two-level factor. For a factor,
#' the **second** level is taken as the positive case, matching how
#' [stats::glm()] itself treats one.
#'
#' `.tss` is the True Skill Statistic, `sensitivity + specificity - 1`, also
#' known as Youden's J. Unlike raw accuracy it is not inflated by a rare
#' positive class, which is why species distribution work reaches for it.
#'
#' @section Evaluating on the training data:
#' A model scored against the data it was fitted to flatters itself, sometimes
#' enormously. Passing the training data still works, because refusing outright
#' would be obstructive, but it warns, and every plot built from the result is
#' annotated as in-sample so the figure cannot be mistaken for validation.
#'
#' Cross-validation, through `folds`, sits between the two and is not a
#' substitute for the hold-out. The folds come from the same sample the model
#' was fitted on, so a cross-validated score speaks to how stable the fit is,
#' not to how it will behave somewhere new.
#'
#' For spatial models the gap is wider still. Random folds are optimistic when
#' observations near each other are correlated, because a held-out point
#' usually has a near neighbour among the training folds -- the model has, in
#' effect, already seen it. Spatially blocked folds are the honest version, and
#' the spread across folds is the part worth reading. `threshold_metrics()`
#' says as much, once per session, the first time folds are used.
#'
#' @return A data frame with one row per distinct threshold and columns
#'   `.threshold`, `.sensitivity`, `.specificity`, `.tpr`, `.fpr`, `.tss`, and
#'   `.fold` when folds were supplied. Carries attributes `auc`, `prevalence`,
#'   `n`, and `in.sample`.
#'
#' @family evaluation plots
#' @seealso [plotROC()], [plotThreshold()], [plotImportance()].
#'
#' @references
#' Allouche, O., Tsoar, A., & Kadmon, R. (2006). Assessing the accuracy of
#' species distribution models: prevalence, kappa and the true skill statistic
#' (TSS). *Journal of Applied Ecology*, 43(6), 1223-1232.
#' \doi{10.1111/j.1365-2664.2006.01214.x}
#'
#' @examples
#' set.seed(1)
#' dat <- data.frame(x1 = runif(400, 1, 10), x2 = runif(400, 1, 10))
#' dat$y <- rbinom(400, 1, plogis(-3 + 0.6 * dat$x1))
#' train <- dat[1:200, ]
#' test <- dat[201:400, ]
#'
#' fit <- glm(y ~ x1 + x2, data = train, family = binomial)
#' metrics <- threshold_metrics(fit, test)
#'
#' attr(metrics, "auc")
#' # The cutoff that maximises the True Skill Statistic
#' metrics$.threshold[which.max(metrics$.tss)]
#'
#' @export
threshold_metrics <- function(model, newdata, folds = NULL, ...) {
  # A misspelled formal would otherwise be swallowed by ... and passed to a
  # backend that ignores it, leaving no sign the request was dropped.
  warn_misspelled_dots(names(list(...)), names(formals()))

  supplied <- inherits(model, "fancyfx_held_out")
  if (!supplied && (missing(newdata) || is.null(newdata))) {
    stop("newdata is required: a model scored against the data it was fitted ",
         "to flatters itself. Supply held-out data, or the training data ",
         "explicitly if that is genuinely what you want.\nTo score ",
         "predictions you already have, wrap them with held_out().",
         call. = FALSE)
  }
  if (supplied) newdata <- NULL else newdata <- as.data.frame(newdata)
  # gamm4 and gamm hand back a wrapper that formula() and predict() both refuse.
  pairs <- evaluation_pairs(model, newdata, folds, ...)
  observed <- pairs$observed
  predicted <- pairs$predicted
  folds <- pairs$folds
  complete <- pairs$complete
  in.sample <- pairs$in.sample

  if (is.null(folds)) {
    out <- sweep_thresholds(observed, predicted)
    auc.value <- auc(observed, predicted)
  } else {
    note_cv_folds()

    folds <- folds[complete]
    parts <- split(seq_along(observed), folds)
    usable <- vapply(parts, function(i) length(unique(observed[i])) == 2,
                     logical(1))
    if (!any(usable)) {
      stop("No fold contains both outcome classes, so no fold can be scored.",
           call. = FALSE)
    }
    if (!all(usable)) {
      warning("Dropping fold(s) with only one outcome class: ",
              paste(names(parts)[!usable], collapse = ", "), call. = FALSE)
      parts <- parts[usable]
    }
    out <- do.call(rbind, lapply(names(parts), function(f) {
      i <- parts[[f]]
      cbind(sweep_thresholds(observed[i], predicted[i]),
            .fold = factor(f, levels = names(parts)))
    }))
    # Per fold, so the spread is visible rather than averaged into one number.
    auc.value <- vapply(parts, function(i) auc(observed[i], predicted[i]),
                        numeric(1))
  }

  rownames(out) <- NULL
  attr(out, "auc") <- auc.value
  attr(out, "prevalence") <- mean(observed)
  attr(out, "n") <- length(observed)
  attr(out, "in.sample") <- in.sample
  out
}

#' Line up observed outcomes against predicted probabilities
#'
#' The shared prologue for every evaluation function: unwrap the model, pull the
#' response out of `newdata`, predict, drop incomplete rows, and say something
#' if the data turns out to be what the model was fitted on. Extracted so the
#' rules about evaluation data are enforced in one place and cannot drift
#' between functions.
#'
#' @param model A fitted model.
#' @param newdata Data to evaluate on.
#' @param folds Optional fold identifiers, one per row of `newdata`.
#' @param require.both.classes Whether to refuse data containing only one
#'   outcome class.
#' @param ... Passed to [stats::predict()].
#' @return A list with `observed`, `predicted`, `folds`, `complete` and
#'   `in.sample`.
#' @keywords internal
evaluation_pairs <- function(model, newdata, folds = NULL,
                             require.both.classes = TRUE, ...) {
  # Predictions supplied directly carry everything this function exists to
  # produce, so there is nothing to predict and nothing to unwrap.
  if (inherits(model, "fancyfx_held_out")) {
    return(held_out_pairs(model, folds, require.both.classes))
  }

  # Unwrapped here rather than in each caller: gamm4 and gamm hand back a
  # wrapper that formula() and predict() both refuse, and every evaluation
  # function reaches this point.
  model <- unwrap_gam(model)

  # Checked against newdata before anything is dropped for missingness. After
  # subsetting, a short folds vector has already been padded with NA to the
  # right length, so the mismatch is invisible and the failure surfaces later
  # as "no fold contains both classes".
  if (!is.null(folds) && length(folds) != nrow(newdata)) {
    stop("folds must have one entry per row of newdata: ", nrow(newdata),
         " expected, ", length(folds), " given.", call. = FALSE)
  }

  observed <- binary_response(model, newdata)
  predicted <- predict_probability(model, newdata, ...)

  if (length(predicted) != length(observed)) {
    stop("Model returned ", length(predicted), " predictions for ",
         length(observed), " rows of newdata.", call. = FALSE)
  }

  in.sample <- is_training_data(model, newdata)
  if (isTRUE(in.sample)) {
    warning("Evaluating on the data the model was fitted to. These metrics ",
            "are optimistic and are not validation. Plots built from them ",
            "will say so.", call. = FALSE)
  }

  complete <- !is.na(observed) & !is.na(predicted)
  observed <- observed[complete]
  predicted <- predicted[complete]
  if (!length(observed)) {
    stop("No rows of newdata have both a response and a prediction.",
         call. = FALSE)
  }
  if (require.both.classes && length(unique(observed)) < 2) {
    stop("newdata contains only one outcome class, so sensitivity and ",
         "specificity are not both defined. Evaluation needs both presences ",
         "and absences.", call. = FALSE)
  }

  list(observed = observed, predicted = predicted,
       folds = if (is.null(folds)) NULL else folds,
       complete = complete, in.sample = in.sample)
}

#' Note that cross-validated scores are weaker evidence than a hold-out
#'
#' @return Invisibly `NULL`.
#' @keywords internal
note_cv_folds <- function() {
  note_once(
    "cv.folds",
    "Scoring within cross-validation folds. Cross-validated metrics are ",
    "weaker evidence than a genuinely independent hold-out: the folds come ",
    "from the same sample, and the model saw the rest of it. For spatial ",
    "data the gap is wider still, because a held-out point usually has a ",
    "near neighbour in the training folds -- use spatially blocked folds ",
    "rather than random ones, and read the spread across folds as the ",
    "honest part of the picture."
  )
}

#' Sweep every threshold the predictions admit
#'
#' Exact rather than gridded: the curve only changes at observed prediction
#' values, so those are the thresholds worth evaluating, and a fixed grid would
#' either miss corners or waste points on flat stretches.
#'
#' @param observed 0/1 numeric vector.
#' @param predicted Numeric vector of predicted probabilities.
#' @return A data frame of metrics, one row per threshold.
#' @keywords internal
sweep_thresholds <- function(observed, predicted) {
  ord <- order(predicted, decreasing = TRUE)
  obs <- observed[ord]
  prd <- predicted[ord]

  n.pos <- sum(obs)
  n.neg <- length(obs) - n.pos

  tp <- cumsum(obs)
  fp <- cumsum(1 - obs)

  # Ties share a threshold, so only the last row of each run of equal
  # predictions is a real operating point. Keeping them all would put several
  # points at the same cutoff with different scores.
  last <- c(prd[-1] != prd[-length(prd)], TRUE)
  tp <- tp[last]
  fp <- fp[last]
  thresholds <- prd[last]

  # The origin: classify nothing as positive. Without it the curve does not
  # start at (0, 0) and the area is understated.
  tp <- c(0, tp)
  fp <- c(0, fp)
  thresholds <- c(Inf, thresholds)

  sensitivity <- tp / n.pos
  specificity <- (n.neg - fp) / n.neg

  data.frame(
    .threshold = thresholds,
    .sensitivity = sensitivity,
    .specificity = specificity,
    .tpr = sensitivity,
    .fpr = 1 - specificity,
    .tss = sensitivity + specificity - 1
  )
}

#' Area under the ROC curve
#'
#' Computed from ranks rather than by integrating the curve. The rank form is
#' the Mann-Whitney U statistic, which handles tied predictions exactly by
#' giving them mid-ranks; trapezoidal integration over a curve with ties gives
#' a slightly different answer depending on how the ties were ordered.
#'
#' @param observed 0/1 numeric vector.
#' @param predicted Numeric vector of predicted probabilities.
#' @return The AUC, a single number.
#' @keywords internal
auc <- function(observed, predicted) {
  n.pos <- sum(observed == 1)
  n.neg <- sum(observed == 0)
  if (!n.pos || !n.neg) return(NA_real_)

  ranks <- rank(predicted)
  (sum(ranks[observed == 1]) - n.pos * (n.pos + 1) / 2) / (n.pos * n.neg)
}

#' Extract a binary response from newdata
#'
#' @param model A fitted model.
#' @param newdata Data containing the response.
#' @return A 0/1 numeric vector.
#' @keywords internal
binary_response <- function(model, newdata) {
  response <- all.vars(stats::formula(model))[1]

  if (!(response %in% names(newdata))) {
    stop("newdata has no column '", response, "', the model's response. ",
         "Evaluation needs the observed outcomes to score predictions against.",
         call. = FALSE)
  }

  observed <- newdata[[response]]

  if (is.factor(observed)) {
    if (nlevels(observed) != 2) {
      stop("'", response, "' has ", nlevels(observed), " levels. ",
           "Classification metrics are defined for a binary outcome only.",
           call. = FALSE)
    }
    # Second level is the positive case, as glm() itself treats a factor.
    return(as.numeric(observed) - 1)
  }

  if (is.logical(observed)) return(as.numeric(observed))

  values <- unique(stats::na.omit(observed))
  if (!is.numeric(observed) || !all(values %in% c(0, 1))) {
    stop("'", response, "' is not a binary outcome (found: ",
         paste(utils::head(sort(values), 4), collapse = ", "),
         if (length(values) > 4) ", ..." else "",
         "). AUC and TSS are defined for presence/absence only -- applied to a ",
         "continuous response they return a number with no meaning.",
         call. = FALSE)
  }
  as.numeric(observed)
}

#' Predict probabilities on new data
#'
#' @param model A fitted model.
#' @param newdata Data to predict over.
#' @param ... Passed to [stats::predict()].
#' @return A numeric vector of predicted probabilities.
#' @keywords internal
predict_probability <- function(model, newdata, ...) {
  args <- list(model, newdata = newdata, type = "response", ...)

  # Held-out data routinely contains groups the model never saw, which is an
  # error rather than a prediction unless the random effects are dropped.
  if (has_random_effects(model) && !any(c("re.form", "re_formula") %in% names(args))) {
    args[[re_form_arg(model)]] <- NA
  }

  predicted <- do.call(stats::predict, args)

  # brms and rstanarm return a draws matrix or a summary matrix rather than a
  # vector; the fitted value is what is wanted here.
  if (is.matrix(predicted)) {
    predicted <- if (nrow(predicted) == nrow(newdata)) {
      predicted[, 1]
    } else {
      colMeans(predicted)
    }
  }

  as.numeric(predicted)
}

#' Is this the data the model was fitted to?
#'
#' @param model A fitted model.
#' @param newdata Data to compare against the model's own frame.
#' @return `TRUE`, `FALSE`, or `NA` when the model does not expose its frame.
#' @keywords internal
is_training_data <- function(model, newdata) {
  train <- tryCatch(stats::model.frame(model), error = function(e) NULL)
  # No frame to compare against, so no honest claim either way. Better to stay
  # silent than to warn on a guess.
  if (is.null(train) || !nrow(train)) return(NA)
  if (nrow(train) != nrow(newdata)) return(FALSE)

  common <- intersect(names(train), names(newdata))
  if (!length(common)) return(NA)

  isTRUE(all.equal(as.data.frame(train)[common],
                   as.data.frame(newdata)[common],
                   check.attributes = FALSE))
}

#' Annotate a plot when its metrics came from the training data
#'
#' @param in.sample `TRUE`, `FALSE`, or `NA`.
#' @return A caption string, or `NULL`.
#' @keywords internal
in_sample_caption <- function(in.sample) {
  if (!isTRUE(in.sample)) return(NULL)
  paste("In-sample: scored on the data the model was fitted to.",
        "Optimistic, and not validation.")
}
