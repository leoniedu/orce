#' Gerar Código R Reproduzível a Partir de Restrições
#'
#' Converte uma lista de restrições (como usada por
#' [orce_aplicar_restricoes()]) em um script R que pode ser copiado e
#' executado para reproduzir as mesmas modificações nos dados de entrada.
#'
#' @param restricoes Lista de restrições no mesmo formato aceito por
#'   [orce_aplicar_restricoes()].
#'
#' @return Uma string contendo código R válido e reproduzível.
#'
#' @export
orce_gerar_codigo <- function(restricoes = list()) {
  if (length(restricoes) == 0) {
    return("# Nenhuma restri\u00e7\u00e3o definida\n")
  }

  linhas <- character()
  linhas <- c(linhas, paste0(
    "# Restri\u00e7\u00f5es para refinamento do plano orce\n",
    "# Gerado em ", Sys.Date(), "\n"
  ))

  for (r in restricoes) {
    if (r$tipo == "bloquear") {
      ucs_str <- .codificar_vetor(r$uc)
      linhas <- c(linhas, paste0(
        "# Bloquear UC ", paste(r$uc, collapse = ", "),
        " da ag\u00eancia ", r$agencia_codigo, "\n",
        "distancias_ucs <- distancias_ucs |>\n",
        "  dplyr::mutate(\n",
        "    distancia_km = dplyr::if_else(\n",
        "      uc %in% ", ucs_str, " & agencia_codigo == \"", r$agencia_codigo, "\",\n",
        "      1e6, distancia_km),\n",
        "    duracao_horas = dplyr::if_else(\n",
        "      uc %in% ", ucs_str, " & agencia_codigo == \"", r$agencia_codigo, "\",\n",
        "      1e6, duracao_horas)\n",
        "  )\n"
      ))

    } else if (r$tipo == "forcar") {
      ucs_str <- .codificar_vetor(r$uc)
      linhas <- c(linhas, paste0(
        "# For\u00e7ar UC ", paste(r$uc, collapse = ", "),
        " para ag\u00eancia ", r$agencia_codigo, "\n",
        "distancias_ucs <- distancias_ucs |>\n",
        "  dplyr::mutate(\n",
        "    distancia_km = dplyr::if_else(\n",
        "      uc %in% ", ucs_str, " & agencia_codigo != \"", r$agencia_codigo, "\",\n",
        "      1e6, distancia_km),\n",
        "    duracao_horas = dplyr::if_else(\n",
        "      uc %in% ", ucs_str, " & agencia_codigo != \"", r$agencia_codigo, "\",\n",
        "      1e6, duracao_horas)\n",
        "  )\n"
      ))

    } else if (r$tipo == "desativar_agencia") {
      linhas <- c(linhas, paste0(
        "# Desativar ag\u00eancia ", r$agencia_codigo, "\n",
        "agencias <- agencias |>\n",
        "  dplyr::filter(agencia_codigo != \"", r$agencia_codigo, "\")\n",
        "distancias_ucs <- distancias_ucs |>\n",
        "  dplyr::filter(agencia_codigo != \"", r$agencia_codigo, "\")\n"
      ))

    } else if (r$tipo == "agencias_treinamento") {
      ag_str <- .codificar_vetor(r$agencias_treinamento)
      linhas <- c(linhas, paste0(
        "# Alterar ag\u00eancias de treinamento\n",
        "agencias_treinamento <- ", ag_str, "\n"
      ))
    }
  }

  # Adicionar chamada orce() comentada
  linhas <- c(linhas, paste0(
    "# Re-otimizar\n",
    "# resultado <- orce(ucs, agencias, distancias_ucs = distancias_ucs, ...)\n"
  ))

  paste(linhas, collapse = "\n")
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
