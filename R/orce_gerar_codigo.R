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
#' @param params_fixos Lista nomeada de parâmetros fixos (não editáveis no UI)
#'   a incluir na chamada `orce()` gerada com seus valores.
#' @param fixar_atribuicoes (Opcional) Data frame com colunas `uc`,
#'   `agencia_codigo` e opcionalmente `valor` (1 = fixar, 0 = bloquear).
#'
#' @return Uma string contendo código R válido e reproduzível.
#'
#' @export
orce_gerar_codigo <- function(restricoes = list(), params_alterados = list(),
                              params_fixos = list(),
                              fixar_atribuicoes = NULL) {
  if (length(restricoes) == 0 && length(params_alterados) == 0 &&
      length(params_fixos) == 0 && is.null(fixar_atribuicoes)) {
    return("# Nenhuma restrição definida\n")
  }

  linhas <- character()
  linhas <- c(linhas, paste0(
    "# Restrições para refinamento do plano orce\n",
    "# Gerado em ", Sys.Date(), "\n"
  ))

  # Gerar lista de restrições
  if (length(restricoes) > 0) {
    restr_items <- vapply(restricoes, function(r) {
      if (r$tipo %in% c("bloquear", "forcar")) {
        paste0("  list(tipo = \"", r$tipo, "\", uc = ",
               .codificar_vetor(r$uc), ", agencia_codigo = \"",
               r$agencia_codigo, "\")")
      } else if (r$tipo == "desativar_agencia") {
        paste0("  list(tipo = \"desativar_agencia\", agencia_codigo = \"",
               r$agencia_codigo, "\")")
      } else if (r$tipo == "agencias_treinamento") {
        paste0("  list(tipo = \"agencias_treinamento\", agencias_treinamento = ",
               .codificar_vetor(r$agencias_treinamento), ")")
      } else {
        ""
      }
    }, character(1))
    restr_items <- restr_items[nzchar(restr_items)]

    linhas <- c(linhas, paste0(
      "restricoes <- list(\n",
      paste(restr_items, collapse = ",\n"),
      "\n)\n"
    ))
    linhas <- c(linhas, paste0(
      "dados <- orce_aplicar_restricoes(\n",
      "  ucs = ucs, agencias = agencias,\n",
      "  distancias_ucs = distancias_ucs,\n",
      "  agencias_treinamento = agencias_treinamento,\n",
      "  restricoes = restricoes\n",
      ")\n"
    ))
  }

  # Gerar fixar_atribuicoes se presente
  if (!is.null(fixar_atribuicoes) && nrow(fixar_atribuicoes) > 0) {
    has_valor <- "valor" %in% names(fixar_atribuicoes) &&
      any(fixar_atribuicoes$valor == 0)
    n_fix <- sum(!has_valor | fixar_atribuicoes$valor == 1)
    n_blk <- if (has_valor) sum(fixar_atribuicoes$valor == 0) else 0L
    label <- paste0(
      if (n_fix > 0) paste0("Fixar ", n_fix) else NULL,
      if (n_fix > 0 && n_blk > 0) " + " else NULL,
      if (n_blk > 0) paste0("Bloquear ", n_blk) else NULL,
      " atribuições UC-agência"
    )
    valor_line <- if (has_valor) {
      paste0(",\n  valor = c(", paste(fixar_atribuicoes$valor, collapse = "L, "),
             "L)")
    } else {
      ""
    }
    linhas <- c(linhas, paste0(
      "# ", label, "\n",
      "fixar_atribuicoes <- data.frame(\n",
      "  uc = ", .codificar_vetor(fixar_atribuicoes$uc), ",\n",
      "  agencia_codigo = ", .codificar_vetor(fixar_atribuicoes$agencia_codigo),
      valor_line,
      "\n)\n"
    ))
  }

  # Gerar chamada orce()
  orce_args <- c(
    if (length(restricoes) > 0) {
      c("  ucs = dados$ucs, agencias = dados$agencias",
        "  distancias_ucs = dados$distancias_ucs")
    } else {
      c("  ucs = ucs, agencias = agencias",
        "  distancias_ucs = distancias_ucs")
    },
    "  resultado_completo = TRUE"
  )

  # agencias_treinamento
  tem_ag_trein <- any(vapply(restricoes, function(r) {
    identical(r$tipo, "agencias_treinamento")
  }, logical(1)))
  if (tem_ag_trein) {
    orce_args <- c(orce_args,
                   "  agencias_treinamento = dados$agencias_treinamento")
  }

  # fixar_atribuicoes
  if (!is.null(fixar_atribuicoes) && nrow(fixar_atribuicoes) > 0) {
    orce_args <- c(orce_args, "  fixar_atribuicoes = fixar_atribuicoes")
  }

  # Parâmetros fixos: inline scalars, reference non-scalars by name
  for (nome in names(params_fixos)) {
    val <- params_fixos[[nome]]
    if (length(val) == 1 && (is.numeric(val) || is.character(val) || is.logical(val))) {
      orce_args <- c(orce_args, paste0("  ", nome, " = ", .formatar_valor(val)))
    } else {
      orce_args <- c(orce_args, paste0("  ", nome, " = ", nome))
    }
  }

  # Parâmetros escalares alterados no UI
  for (nome in names(params_alterados)) {
    val <- params_alterados[[nome]]
    orce_args <- c(orce_args, paste0("  ", nome, " = ", .formatar_valor(val)))
  }

  linhas <- c(linhas, "# Re-otimizar")
  linhas <- c(linhas, paste0(
    "resultado <- orce(\n",
    paste(orce_args, collapse = ",\n"),
    "\n)\n"
  ))

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

#' Formata um valor R escalar como string de código
#' @keywords internal
.formatar_valor <- function(val) {
  if (is.character(val)) {
    paste0("\"", val, "\"")
  } else if (is.infinite(val)) {
    "Inf"
  } else {
    as.character(val)
  }
}
