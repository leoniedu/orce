#' Aplicar Restrições Manuais aos Dados de Entrada do orce
#'
#' Modifica os data frames de entrada (`ucs`, `agencias`, `distancias_ucs`) e
#' o vetor `agencias_treinamento` de acordo com uma lista de restrições manuais,
#' permitindo refinar iterativamente um plano de alocação antes de re-otimizar
#' com [orce()].
#'
#' @param ucs Data frame de UCs (mesmo formato aceito por [orce()]).
#' @param agencias Data frame de agências.
#' @param distancias_ucs Data frame de distâncias UC–agência.
#' @param agencias_treinamento Vetor de códigos das agências de treinamento
#'   (ou `NULL`).
#' @param restricoes Lista de restrições. Cada elemento é uma lista com:
#'   \describe{
#'     \item{tipo}{Tipo da restrição: `"bloquear"`, `"forcar"`,
#'       `"desativar_agencia"`, ou `"agencias_treinamento"`.}
#'     \item{uc}{Código(s) da(s) UC(s) afetada(s) (para `"bloquear"` e
#'       `"forcar"`).}
#'     \item{agencia_codigo}{Código da agência alvo (para `"bloquear"`,
#'       `"forcar"` e `"desativar_agencia"`).}
#'     \item{agencias_treinamento}{Vetor de códigos das novas agências de
#'       treinamento (para tipo `"agencias_treinamento"`).}
#'   }
#'
#' @return Lista com os dados modificados:
#'   \describe{
#'     \item{ucs}{Data frame de UCs (inalterado).}
#'     \item{agencias}{Data frame de agências (possivelmente filtrado).}
#'     \item{distancias_ucs}{Data frame de distâncias (possivelmente com
#'       custos proibitivos).}
#'     \item{agencias_treinamento}{Vetor atualizado de agências de treinamento.}
#'   }
#'
#' @details
#' As restrições são aplicadas na ordem fornecida. Cada tipo funciona assim:
#'
#' - **`bloquear`**: Define `distancia_km = 1e6` e `duracao_horas = 1e6` para
#'   o par (UC, agência), tornando a atribuição proibitivamente cara.
#' - **`forcar`**: Define custos proibitivos para todas as *outras* agências
#'   daquela UC, forçando a atribuição à agência especificada.
#' - **`desativar_agencia`**: Remove a agência de `agencias` e de
#'   `distancias_ucs`.
#' - **`agencias_treinamento`**: Substitui o vetor de agências de treinamento.
#'
#' @export
orce_aplicar_restricoes <- function(ucs, agencias, distancias_ucs,
                                    agencias_treinamento = NULL,
                                    restricoes = list()) {
  if (length(restricoes) == 0) {
    return(list(
      ucs = ucs,
      agencias = agencias,
      distancias_ucs = distancias_ucs,
      agencias_treinamento = agencias_treinamento
    ))
  }

  tipos_validos <- c("bloquear", "forcar", "desativar_agencia",
                     "agencias_treinamento")

  for (i in seq_along(restricoes)) {
    r <- restricoes[[i]]

    if (is.null(r$tipo) || !r$tipo %in% tipos_validos) {
      cli::cli_abort(
        "Restri\\u00e7\\u00e3o {i} tem tipo inv\\u00e1lido: {.val {r$tipo %||% 'NULL'}}. Tipos v\\u00e1lidos: {.val {tipos_validos}}."
      )
    }

    if (r$tipo == "bloquear") {
      checkmate::assert_character(r$uc, min.len = 1)
      checkmate::assert_string(r$agencia_codigo)
      distancias_ucs <- distancias_ucs |>
        dplyr::mutate(
          distancia_km = dplyr::if_else(
            uc %in% r$uc & agencia_codigo == r$agencia_codigo,
            1e6, distancia_km
          ),
          duracao_horas = dplyr::if_else(
            uc %in% r$uc & agencia_codigo == r$agencia_codigo,
            1e6, duracao_horas
          )
        )

    } else if (r$tipo == "forcar") {
      checkmate::assert_character(r$uc, min.len = 1)
      checkmate::assert_string(r$agencia_codigo)
      distancias_ucs <- distancias_ucs |>
        dplyr::mutate(
          distancia_km = dplyr::if_else(
            uc %in% r$uc & agencia_codigo != r$agencia_codigo,
            1e6, distancia_km
          ),
          duracao_horas = dplyr::if_else(
            uc %in% r$uc & agencia_codigo != r$agencia_codigo,
            1e6, duracao_horas
          )
        )

    } else if (r$tipo == "desativar_agencia") {
      checkmate::assert_string(r$agencia_codigo)
      agencias <- agencias |>
        dplyr::filter(agencia_codigo != r$agencia_codigo)
      distancias_ucs <- distancias_ucs |>
        dplyr::filter(agencia_codigo != r$agencia_codigo)

    } else if (r$tipo == "agencias_treinamento") {
      checkmate::assert_character(r$agencias_treinamento, min.len = 1)
      agencias_treinamento <- r$agencias_treinamento
    }
  }

  list(
    ucs = ucs,
    agencias = agencias,
    distancias_ucs = distancias_ucs,
    agencias_treinamento = agencias_treinamento
  )
}
