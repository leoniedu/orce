#' Gerar Código R Reproduzível a Partir de Restrições
#'
#' Converte uma lista de restrições (como usada por
#' [orce_aplicar_restricoes()]) em um script R que pode ser copiado e
#' executado para reproduzir as mesmas modificações nos dados de entrada.
#'
#' @param restricoes Lista de restrições no mesmo formato aceito por
#'   [orce_aplicar_restricoes()].
#' @param params_alterados Lista nomeada de parâmetros escalares que diferem
#'   dos valores iniciais (ex: `list(rel_tol = 0.01, dias_treinamento = 4)`).
#' @param params_fixos_nomes Vetor de nomes de parâmetros não-escalares
#'   (ex: `"distancias_agencias"`) a incluir na chamada `orce()` gerada.
#'
#' @return Uma string contendo código R válido e reproduzível.
#'
#' @export
orce_gerar_codigo <- function(restricoes = list(), params_alterados = list(),
                              params_fixos_nomes = character()) {
  if (length(restricoes) == 0 && length(params_alterados) == 0 &&
      length(params_fixos_nomes) == 0) {
    return("# Nenhuma restri\u00e7\u00e3o definida\n")
  }

  custo <- format(.CUSTO_PROIBITIVO, scientific = TRUE)

  linhas <- character()
  linhas <- c(linhas, paste0(
    "# Restri\u00e7\u00f5es para refinamento do plano orce\n",
    "# Gerado em ", Sys.Date(), "\n"
  ))

  for (r in restricoes) {
    comentario <- paste0("# ", .descrever_restricao(r), "\n")

    if (r$tipo == "bloquear") {
      ucs_str <- .codificar_vetor(r$uc)
      linhas <- c(linhas, paste0(
        comentario,
        .gerar_mutate_proibitivo(ucs_str, r$agencia_codigo, "==", custo)
      ))

    } else if (r$tipo == "forcar") {
      ucs_str <- .codificar_vetor(r$uc)
      linhas <- c(linhas, paste0(
        comentario,
        .gerar_mutate_proibitivo(ucs_str, r$agencia_codigo, "!=", custo)
      ))

    } else if (r$tipo == "desativar_agencia") {
      linhas <- c(linhas, paste0(
        comentario,
        "agencias <- agencias |>\n",
        "  dplyr::filter(agencia_codigo != \"", r$agencia_codigo, "\")\n",
        "distancias_ucs <- distancias_ucs |>\n",
        "  dplyr::filter(agencia_codigo != \"", r$agencia_codigo, "\")\n"
      ))

    } else if (r$tipo == "agencias_treinamento") {
      ag_str <- .codificar_vetor(r$agencias_treinamento)
      linhas <- c(linhas, paste0(
        comentario,
        "agencias_treinamento <- ", ag_str, "\n"
      ))
    }
  }

  # Gerar chamada orce() com parâmetros alterados
  params_code <- character()

  # Incluir agencias_treinamento se foi definida por restrição
  tem_ag_trein <- any(vapply(restricoes, function(r) {
    identical(r$tipo, "agencias_treinamento")
  }, logical(1)))
  if (tem_ag_trein) {
    params_code <- c(params_code,
                     "  agencias_treinamento = agencias_treinamento")
  }

  # Incluir parâmetros não-escalares (data frames, vetores passados via ...)
  for (nome in params_fixos_nomes) {
    params_code <- c(params_code, paste0("  ", nome, " = ", nome))
  }

  for (nome in names(params_alterados)) {
    val <- params_alterados[[nome]]
    if (is.character(val)) {
      params_code <- c(params_code, paste0("  ", nome, " = \"", val, "\""))
    } else if (is.infinite(val)) {
      params_code <- c(params_code, paste0("  ", nome, " = Inf"))
    } else {
      params_code <- c(params_code, paste0("  ", nome, " = ", val))
    }
  }

  linhas <- c(linhas, "# Re-otimizar")
  if (length(params_code) > 0) {
    linhas <- c(linhas, paste0(
      "resultado <- orce(\n",
      "  ucs = ucs, agencias = agencias,\n",
      "  distancias_ucs = distancias_ucs,\n",
      "  resultado_completo = TRUE,\n",
      paste(params_code, collapse = ",\n"),
      "\n)\n"
    ))
  } else {
    linhas <- c(linhas,
      "# resultado <- orce(ucs, agencias, distancias_ucs = distancias_ucs, ...)\n"
    )
  }

  paste(linhas, collapse = "\n")
}

#' Gerar bloco mutate com custos proibitivos
#' @keywords internal
.gerar_mutate_proibitivo <- function(ucs_str, agencia_codigo, operador, custo) {
  paste0(
    "distancias_ucs <- distancias_ucs |>\n",
    "  dplyr::mutate(\n",
    "    distancia_km = dplyr::if_else(\n",
    "      uc %in% ", ucs_str, " & agencia_codigo ", operador, " \"", agencia_codigo, "\",\n",
    "      ", custo, ", distancia_km),\n",
    "    duracao_horas = dplyr::if_else(\n",
    "      uc %in% ", ucs_str, " & agencia_codigo ", operador, " \"", agencia_codigo, "\",\n",
    "      ", custo, ", duracao_horas)\n",
    "  )\n"
  )
}

#' Codifica vetor de caracteres como código R
#' @keywords internal
.codificar_vetor <- function(x) {
  if (length(x) == 1) {
    paste0("\"", x, "\"")
  } else {
    paste0("c(", paste0("\"", x, "\"", collapse = ", "), ")")
  }
}
