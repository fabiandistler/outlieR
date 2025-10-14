#' Get Number of Cores for Parallel Processing
#'
#' @description
#' Internal helper to determine number of cores to use for parallel processing
#' in a CRAN-compliant way. Respects R CMD check limitations.
#'
#' @param max_tasks Maximum number of parallel tasks to run
#'
#' @return Integer number of cores to use
#' @keywords internal
get_n_cores <- function(max_tasks) {
  chk <- tolower(Sys.getenv("_R_CHECK_LIMIT_CORES_", ""))
  if (nzchar(chk) && chk == "true") {
    return(2L)
  }

  n_cores <- parallel::detectCores()
  if (is.na(n_cores) || is.null(n_cores)) {
    n_cores <- 1L
  }

  max(1L, min(n_cores - 1L, max_tasks))
}


#' Default Value Operator
#'
#' @description
#' Internal operator to provide default values for NULL.
#'
#' @param x Primary value
#' @param y Default value if x is NULL
#'
#' @return x if not NULL, otherwise y
#' @keywords internal
#' @noRd
`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
