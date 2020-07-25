# Parses formula and data into a list of objects required
# for fitting the model.
#
# @param formula model formula
# @param data contains data required to construct model objects from formula
parse_mm <- function(formula, data, ...) {

  # formula with no response and no autocorrelation terms
  form <- rhs(formula)
  form <- norws(form)

  mf <- match.call(expand.dots = TRUE)
  mf$formula <- form
  mf$data <- data

  if (is_mixed(formula)) {
    mf[[1L]] <- quote(lme4::glFormula)
    mf$control <- make_glmerControl(
      ignore_lhs = TRUE,
      ignore_x_scale = FALSE
    )
    glmod <- eval(mf, parent.frame())
    x <- glmod$X

    if ("b" %in% colnames(x)) {
      stop("epim does not allow the name 'b' for predictor variables.",
        call. = FALSE
      )
    }

    group <- glmod$reTrms
    group <-
      pad_reTrms(
        Ztlist = group$Ztlist,
        cnms = group$cnms,
        flist = group$flist
      )
    mt <- NULL
  } else {
    mf[[1L]] <- quote(stats::model.frame)
    mf$drop.unused.levels <- TRUE
    mf <- eval(mf, parent.frame())
    mt <- attr(mf, "terms")
    x <- model.matrix(object = mt, data = mf)
    glmod <- group <- NULL
  }

  autocor <- NULL
  if (is_autocor(formula)) {
    trms <- terms_rw(formula)
    autocor <- parse_all_terms(trms, data)

    if ("rw" %in% colnames(x)) {
      stop("epim does not allow the name 'rw' for predictor variables.",
        call. = FALSE
      )
    }
  }

  # dropping redundant columns
  sel <- apply(
    x,
    2L,
    function(a) !all(a == 1) && length(unique(a)) < 2
  )
  x <- x[, !sel, drop = FALSE]
  
  # change namings
  if (length(group$Z)) {
    colnames(group$Z) <- paste0("b[", make_b_nms(group), "]")
  }
  
  if (length(autocor$Z)) {
    colnames(autocor$Z) <- make_rw_nms(formula, data)
  }
  
  # overall model matrix includes FE, RE and autocor
  x <- cbind(x, group$Z, autocor$Z)

  return(loo::nlist(
    x,
    mt,
    glmod,
    group,
    autocor
  ))
}