#' Evaluate predictions you already have
#'
#' Every evaluation function here takes a fitted model and re-predicts. That is
#' the right default -- it keeps the scored predictions and the model provably
#' in step -- but it assumes the caller is holding a model that can reproduce
#' them, and a cross-validated workflow is not.
#'
#' Under k-fold cross-validation each observation is predicted by the one fold
#' model that did not see it. The honest predictions are therefore spread across
#' `k` models, none of which is the final fit, and by the time a pipeline has a
#' single model to hand it has already thrown them away -- or, more often, kept
#' them and has nothing to pass them to. Re-predicting from the final model on
#' the same rows answers a different and more flattering question.
#'
#' `held_out()` is the way in for those. Wrap the observed outcomes and the
#' predictions that were made for them, and pass the result anywhere a model
#' would go:
#'
#' ```r
#' pairs <- held_out(cv$observed, cv$predicted)
#' plotROC(pairs, folds = cv$fold)
#' plotThreshold(pairs, folds = cv$fold)
#' plotCalibration(pairs)
#' ```
#'
#' @section What it does not do:
#' It cannot check the predictions are out of sample. Nothing in a pair of
#' numeric vectors records which model made them or what it was fitted to, so
#' `in.sample` is taken on trust -- the argument exists to be set honestly, and
#' defaults to `FALSE` because that is what the function is named for.
#'
#' That is a real difference from the model path, which inspects the fit and
#' warns when it recognises its own training data. Passing training predictions
#' here gets no warning, because there is nothing to notice it with.
#'
#' It also cannot support [plotImportance()] or [permutation_importance()],
#' which shuffle a predictor and re-predict. That needs a model by construction,
#' not a record of what one once said.
#'
#' @param observed Observed outcomes: `0`/`1`, a logical, or a two-level factor
#'   whose **second** level is the positive case, matching how [stats::glm()]
#'   treats one.
#' @param predicted Predicted probabilities, one per element of `observed`.
#' @param in.sample Whether these predictions were made on the data the model
#'   was fitted to. `FALSE` by default; set `TRUE` and every plot built from
#'   them is annotated as in-sample, exactly as the model path would.
#'
#' @return An object of class `fancyfx_held_out`, accepted wherever a model is.
#'
#' @family evaluation plots
#' @seealso [threshold_metrics()], [plotROC()], [plotThreshold()],
#'   [plotCalibration()].
#'
#' @examples
#' set.seed(1)
#' truth <- rbinom(200, 1, 0.3)
#' score <- plogis(rnorm(200, ifelse(truth == 1, 1, -1)))
#'
#' pairs <- held_out(truth, score)
#' metrics <- threshold_metrics(pairs)
#' metrics$.threshold[which.max(metrics$.tss)]
#'
#' # Fold-wise, when the predictions came from cross-validation.
#' folds <- rep(1:5, length.out = 200)
#' head(threshold_metrics(pairs, folds = folds))
#'
#' @export
held_out <- function(observed, predicted, in.sample = FALSE) {
  observed <- as_binary_outcome(observed)
  predicted <- as.numeric(predicted)

  if (length(observed) != length(predicted)) {
    stop("observed and predicted must be the same length: ", length(observed),
         " and ", length(predicted), ".", call. = FALSE)
  }
  if (!length(observed)) {
    stop("observed and predicted are empty, so there is nothing to score.",
         call. = FALSE)
  }
  finite <- predicted[is.finite(predicted)]
  if (length(finite) && (min(finite) < 0 || max(finite) > 1)) {
    stop("predicted must be probabilities in [0, 1], but they run from ",
         format(min(finite)), " to ", format(max(finite)),
         ". Predictions on the link scale need transforming first.",
         call. = FALSE)
  }
  if (!is.logical(in.sample) || length(in.sample) != 1) {
    stop("in.sample must be TRUE or FALSE.", call. = FALSE)
  }

  structure(
    list(observed = observed, predicted = predicted, in.sample = in.sample),
    class = "fancyfx_held_out"
  )
}

#' Coerce observed outcomes to 0/1
#'
#' The same three forms [binary_response()] accepts, and the same reading of
#' each, so a `held_out()` pair and a model scored on a data frame agree about
#' which class is positive. Split out rather than shared with
#' [binary_response()] because that one reaches into `newdata` for a column
#' named by the model's formula, and here there is no model and no column.
#'
#' @param observed Observed outcomes.
#' @return A 0/1 numeric vector.
#' @keywords internal
as_binary_outcome <- function(observed) {
  if (is.factor(observed)) {
    if (nlevels(observed) != 2) {
      stop("observed has ", nlevels(observed), " levels. Classification ",
           "metrics are defined for a binary outcome only.", call. = FALSE)
    }
    # Second level is the positive case, as glm() itself treats a factor.
    return(as.numeric(observed) - 1)
  }

  if (is.logical(observed)) return(as.numeric(observed))

  values <- unique(stats::na.omit(observed))
  if (!is.numeric(observed) || !all(values %in% c(0, 1))) {
    stop("observed is not a binary outcome (found: ",
         paste(utils::head(sort(values), 4), collapse = ", "),
         if (length(values) > 4) ", ..." else "",
         "). AUC and TSS are defined for presence/absence only -- applied to a ",
         "continuous response they return a number with no meaning.",
         call. = FALSE)
  }
  as.numeric(observed)
}

#' The evaluation pairs a held_out() object already carries
#'
#' The short circuit in [evaluation_pairs()]. There is no model to unwrap, no
#' response column to find and no prediction to make; the work is the checking
#' that the model path does after predicting.
#'
#' @param x A `fancyfx_held_out` object.
#' @param folds Optional fold identifiers, one per observation.
#' @param require.both.classes Whether to refuse data containing only one
#'   outcome class.
#' @return The same list [evaluation_pairs()] returns.
#' @keywords internal
held_out_pairs <- function(x, folds = NULL, require.both.classes = TRUE) {
  observed <- x$observed
  predicted <- x$predicted

  if (!is.null(folds) && length(folds) != length(observed)) {
    stop("folds must have one entry per observation: ", length(observed),
         " expected, ", length(folds), " given.", call. = FALSE)
  }

  complete <- !is.na(observed) & !is.na(predicted)
  observed <- observed[complete]
  predicted <- predicted[complete]

  if (!length(observed)) {
    stop("No observation has both an outcome and a prediction.", call. = FALSE)
  }
  if (require.both.classes && length(unique(observed)) < 2) {
    stop("observed contains only one outcome class, so sensitivity and ",
         "specificity are not both defined. Evaluation needs both presences ",
         "and absences.", call. = FALSE)
  }

  list(observed = observed, predicted = predicted, folds = folds,
       complete = complete, in.sample = x$in.sample)
}

#' Print a held_out object
#'
#' @param x A `fancyfx_held_out` object.
#' @param ... Unused.
#' @return `x`, invisibly.
#' @export
print.fancyfx_held_out <- function(x, ...) {
  cat("<fancyfx held-out predictions>\n")
  cat("  observations: ", length(x$observed), "\n", sep = "")
  cat("  prevalence:   ", format(mean(x$observed, na.rm = TRUE), digits = 3),
      "\n", sep = "")
  cat("  in sample:    ", if (isTRUE(x$in.sample)) "yes" else "no", "\n",
      sep = "")
  invisible(x)
}
