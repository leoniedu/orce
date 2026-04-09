# Constantes compartilhadas para restrições
.TIPOS_RESTRICAO <- c("bloquear", "forcar", "desativar_agencia",
                       "agencias_treinamento")
.CUSTO_PROIBITIVO <- 1e6

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
#' - **`bloquear`**: Define `distancia_km` e `duracao_horas` como proibitivos
#'   para o par (UC, agência), tornando a atribuição proibitivamente cara.
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

  for (i in seq_along(restricoes)) {
    r <- restricoes[[i]]

    if (is.null(r$tipo) || !r$tipo %in% .TIPOS_RESTRICAO) {
      cli::cli_abort(
        "Restrição {i} tem tipo inválido: {.val {r$tipo %||% 'NULL'}}. Tipos válidos: {.val {(.TIPOS_RESTRICAO)}}."
      )
    }

    if (r$tipo == "bloquear") {
      checkmate::assert_character(r$uc, min.len = 1)
      checkmate::assert_string(r$agencia_codigo)
      mask <- distancias_ucs$uc %in% r$uc &
        distancias_ucs$agencia_codigo == r$agencia_codigo
      distancias_ucs$distancia_km[mask] <- .CUSTO_PROIBITIVO
      distancias_ucs$duracao_horas[mask] <- .CUSTO_PROIBITIVO

    } else if (r$tipo == "forcar") {
      checkmate::assert_character(r$uc, min.len = 1)
      checkmate::assert_string(r$agencia_codigo)
      mask <- distancias_ucs$uc %in% r$uc &
        distancias_ucs$agencia_codigo != r$agencia_codigo
      distancias_ucs$distancia_km[mask] <- .CUSTO_PROIBITIVO
      distancias_ucs$duracao_horas[mask] <- .CUSTO_PROIBITIVO

    } else if (r$tipo == "desativar_agencia") {
      checkmate::assert_string(r$agencia_codigo)
      agencias <- agencias[agencias$agencia_codigo != r$agencia_codigo, ]
      distancias_ucs <- distancias_ucs[distancias_ucs$agencia_codigo != r$agencia_codigo, ]

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

#' Identificar UCs Afetadas por Restrições
#'
#' Retorna os códigos das UCs que são diretamente afetadas por uma lista de
#' restrições, considerando também UCs atribuídas a agências desativadas.
#' Quando `alocar_por` não é `"uc"`, expande as UCs afetadas para incluir
#' todas as UCs do mesmo grupo de alocação.
#'
#' @param restricoes Lista de restrições (mesmo formato de
#'   [orce_aplicar_restricoes()]).
#' @param resultado_ucs Data frame com o resultado atual da otimização,
#'   contendo ao menos as colunas `uc` e `agencia_codigo`.
#' @param ucs (Opcional) Data frame de UCs contendo a coluna de agrupamento
#'   especificada por `alocar_por`. Necessário quando `alocar_por != "uc"`.
#' @param alocar_por Coluna usada para agrupar UCs na otimização.
#'   Padrão: `"uc"` (sem agrupamento).
#'
#' @return Vetor de caracteres com os códigos das UCs afetadas (sem duplicatas).
#'
#' @export
orce_ucs_afetadas <- function(restricoes, resultado_ucs = NULL,
                               ucs = NULL, alocar_por = "uc") {
  afetadas <- character()
  for (r in restricoes) {
    if (r$tipo %in% c("bloquear", "forcar")) {
      afetadas <- c(afetadas, r$uc)
    } else if (r$tipo == "desativar_agencia" && !is.null(resultado_ucs)) {
      ucs_da_agencia <- resultado_ucs$uc[
        resultado_ucs$agencia_codigo == r$agencia_codigo
      ]
      afetadas <- c(afetadas, ucs_da_agencia)
    }
  }
  afetadas <- unique(afetadas)

  # Expandir para todos os membros do grupo de alocação
  if (alocar_por != "uc" && !is.null(ucs) && length(afetadas) > 0) {
    grupos_afetados <- unique(ucs[[alocar_por]][ucs$uc %in% afetadas])
    afetadas <- unique(ucs$uc[ucs[[alocar_por]] %in% grupos_afetados])
  }
  afetadas
}

#' Anotar data frame de UCs com rótulos de restrições
#' @keywords internal
.anotar_restricoes <- function(df, restricoes) {
  df$restricao <- ""
  for (r in restricoes) {
    if (r$tipo == "bloquear") {
      idx <- df$uc %in% r$uc
      df$restricao[idx] <- paste0(
        df$restricao[idx],
        ifelse(df$restricao[idx] == "", "", "; "),
        "bloqueada de ", r$agencia_codigo
      )
    } else if (r$tipo == "forcar") {
      idx <- df$uc %in% r$uc
      df$restricao[idx] <- paste0("forçada -> ", r$agencia_codigo)
    }
  }
  df
}
