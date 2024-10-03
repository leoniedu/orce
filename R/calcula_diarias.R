#' Calcula o Número de Diárias
#'
#' Esta função calcula o número de diárias a serem pagas para um deslocamento, considerando o número de dias e se a diária inclui pernoite.
#'
#' @param dias Número de dias do deslocamento.
#' @param meia_diaria Valor lógico indicando se a diária é de apenas meio dia (`TRUE`) ou dia inteiro (`FALSE`).
#'
#' @return O número de diárias a serem pagas.
#'
#' @examples
#' calcula_diarias(dias = 2, meia_diaria = FALSE) # Retorna 1.5
#' calcula_diarias(dias = 2, meia_diaria = TRUE) # Retorna 1
#' calcula_diarias(dias = 5, meia_diaria = TRUE) # Retorna 2.5
#' calcula_diarias(dias = 5, meia_diaria = FALSE) # Retorna 4.5
#'
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
