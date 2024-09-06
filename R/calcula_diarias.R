#' @export
calcula_diarias <- function(dias, meia_diaria) {
  checkmate::assert_integerish(dias, lower = 0)
  checkmate::assert_logical(meia_diaria)
  case_when(
    dias==0 ~ 0,
    meia_diaria ~ dias*.5,
    dias==1 ~ 1.5,
    TRUE ~ dias-.5)
}
