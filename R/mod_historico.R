#' @keywords internal
mod_historico_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::actionButton(ns("restaurar_btn"), "Restaurar selecionado",
                        class = "btn-outline-primary btn-sm mb-2"),
    DT::dataTableOutput(ns("tabela_historico"))
  )
}

#' @keywords internal
mod_historico_server <- function(id, resultado_atual, codigo_texto,
                                nomes_agencias = NULL,
                                restricoes_lista = NULL,
                                params_atuais = NULL,
                                params_iniciais = list()) {
  # Construir snapshot estático: params_iniciais preenchido com defaults
  params_iniciais_completo <- .PARAMS_DEFAULTS
  for (nome in names(params_iniciais)) {
    params_iniciais_completo[[nome]] <- params_iniciais[[nome]]
  }
  # Remover NULLs (dias_coleta_entrevistador_max quando não fornecido)
  params_iniciais_completo <- Filter(Negate(is.null), params_iniciais_completo)

  shiny::moduleServer(id, function(input, output, session) {

    # Armazenar resultados e stats
    historico <- shiny::reactiveVal(list())
    linha_ativa <- shiny::reactiveVal(1L)

    # Formatar valor de parâmetro de forma compacta
    .fmt_param <- function(nome, val) {
      if (is.infinite(val)) {
        paste0(nome, "=Inf")
      } else {
        paste0(nome, "=", val)
      }
    }

    # Resumir todos os parâmetros (para linha inicial)
    .resumir_params <- function(params) {
      if (length(params) == 0) return("")
      partes <- vapply(names(params), function(nome) {
        .fmt_param(nome, params[[nome]])
      }, character(1))
      paste(partes, collapse = "; ")
    }

    # Resumir o que mudou em relação à linha 1
    .resumir_alteracoes <- function(restricoes, params_atual) {
      partes <- character()

      # Restrições por tipo
      if (length(restricoes) > 0) {
        tipos <- vapply(restricoes, function(r) r$tipo, character(1))
        contagens <- table(tipos)
        nomes_tipo <- c(
          bloquear = "bloqueio",
          forcar = "forçamento",
          desativar_agencia = "ag. desativada",
          agencias_treinamento = "ag. treinamento"
        )
        nomes_tipo_pl <- c(
          bloquear = "bloqueios",
          forcar = "forçamentos",
          desativar_agencia = "ag. desativadas",
          agencias_treinamento = "ag. treinamento"
        )
        for (tipo in names(contagens)) {
          n <- contagens[[tipo]]
          if (n == 1) {
            r <- restricoes[tipos == tipo][[1]]
            lbl <- .descrever_restricao(r, nomes_agencias)
          } else {
            lbl <- paste0(n, " ", nomes_tipo_pl[[tipo]] %||% tipo)
          }
          partes <- c(partes, lbl)
        }
      }

      # Parâmetros que diferem do inicial
      todos_nomes <- union(names(params_atual), names(params_iniciais_completo))
      for (nome in todos_nomes) {
        val_atual <- params_atual[[nome]]
        val_ini <- params_iniciais_completo[[nome]]
        if (is.null(val_atual)) next
        # Comparação tolerante (Shiny retorna doubles, defaults podem ser integer)
        igual <- if (is.numeric(val_atual) && is.numeric(val_ini)) {
          isTRUE(all.equal(val_atual, val_ini))
        } else {
          identical(val_atual, val_ini)
        }
        if (!igual) {
          partes <- c(partes, .fmt_param(nome, val_atual))
        }
      }

      if (length(partes) == 0) return("(sem alterações)")
      paste(partes, collapse = "; ")
    }

    # Extrair stats de um resultado
    .extrair_stats <- function(resultado, codigo, alteracoes = "") {
      res_ucs <- resultado$resultado_ucs_otimo
      res_ag <- resultado$resultado_agencias_otimo
      .sum_col <- function(df, col) {
        if (col %in% names(df)) round(sum(df[[col]], na.rm = TRUE), 2) else NA_real_
      }
      data.frame(
        custo_total = round(attr(resultado, "valor"), 2),
        n_agencias = nrow(res_ag),
        entrevistadores = .sum_col(res_ag, "entrevistadores"),
        custo_diarias = .sum_col(res_ag, "custo_diarias"),
        custo_combustivel = .sum_col(res_ag, "custo_combustivel"),
        custo_remuneracao = .sum_col(res_ag, "custo_total_entrevistadores"),
        total_km = round(sum(res_ucs$distancia_km, na.rm = TRUE), 1),
        total_diarias = if ("total_diarias" %in% names(res_ucs))
          sum(res_ucs$total_diarias, na.rm = TRUE) else NA_real_,
        alteracoes = alteracoes,
        codigo = codigo,
        stringsAsFactors = FALSE
      )
    }

    # Registrar resultado inicial
    shiny::observe({
      if (length(historico()) == 0) {
        resumo <- .resumir_params(params_iniciais_completo)
        hist_entry <- list(
          stats = .extrair_stats(resultado_atual(), "(inicial)", resumo),
          resultado = resultado_atual()
        )
        historico(list(hist_entry))
      }
    })

    # Registrar cada novo resultado
    shiny::observeEvent(resultado_atual(), {
      hist <- historico()
      if (length(hist) == 0) return()  # o observe acima cuidará do primeiro

      # Evitar duplicar se é uma restauração
      ultimo_res <- hist[[length(hist)]]$resultado
      if (identical(attr(resultado_atual(), "valor"),
                    attr(ultimo_res, "valor")) &&
          nrow(resultado_atual()$resultado_agencias_otimo) ==
          nrow(ultimo_res$resultado_agencias_otimo)) {
        return()
      }

      restr <- if (!is.null(restricoes_lista)) restricoes_lista() else list()
      p_atual <- if (!is.null(params_atuais)) params_atuais() else list()
      resumo <- .resumir_alteracoes(restr, p_atual)

      nova_entry <- list(
        stats = .extrair_stats(resultado_atual(), codigo_texto(), resumo),
        resultado = resultado_atual()
      )
      historico(c(hist, list(nova_entry)))
      linha_ativa(length(hist) + 1L)
    }, ignoreInit = TRUE)

    # Formatar diferença com sinal (negativo = melhoria)
    .fmt_diff <- function(val, ref, digits = 1) {
      diff <- val - ref
      if (is.na(diff) || diff == 0) return("")
      paste0(" (", ifelse(diff > 0, "+", ""), round(diff, digits), ")")
    }

    # Tabela de exibição com diferenças do baseline
    tabela_hist <- shiny::reactive({
      hist <- historico()
      if (length(hist) == 0) return(data.frame())
      base <- hist[[1]]$stats
      stats_list <- lapply(seq_along(hist), function(i) {
        s <- hist[[i]]$stats
        .col <- function(val, ref, digits = 1) {
          if (is.na(val)) return(NA_character_)
          if (i == 1) as.character(val)
          else paste0(val, .fmt_diff(val, ref, digits))
        }
        data.frame(
          "#" = i,
          "Alterações" = s$alteracoes,
          "Agências" = .col(s$n_agencias, base$n_agencias, 0),
          "Entrev." = .col(s$entrevistadores, base$entrevistadores, 0),
          "Diárias (R$)" = .col(s$custo_diarias, base$custo_diarias, 0),
          "Combust. (R$)" = .col(s$custo_combustivel, base$custo_combustivel, 0),
          "Remun. (R$)" = .col(s$custo_remuneracao, base$custo_remuneracao, 0),
          "Custo total" = .col(s$custo_total, base$custo_total, 2),
          check.names = FALSE,
          stringsAsFactors = FALSE
        )
      })
      do.call(rbind, stats_list)
    })

    output$tabela_historico <- DT::renderDataTable({
      df <- tabela_hist()
      if (nrow(df) == 0) return(DT::datatable(data.frame()))
      DT::datatable(
        df,
        selection = list(mode = "single", selected = linha_ativa()),
        options = list(
          pageLength = 20,
          dom = "t",
          ordering = FALSE,
          language = list(
            emptyTable = "Nenhum resultado ainda."
          )
        ),
        rownames = FALSE
      ) |>
        DT::formatStyle(
          columns = "#",
          target = "row",
          backgroundColor = DT::styleEqual(
            linha_ativa(),
            "#d4edda"
          )
        )
    })

    # Valor de restauração
    restaurar_val <- shiny::reactiveVal(NULL)

    shiny::observeEvent(input$restaurar_btn, {
      sel <- input$tabela_historico_rows_selected
      if (is.null(sel) || length(sel) == 0) {
        shiny::showNotification("Selecione uma linha.", type = "warning")
        return()
      }
      hist <- historico()
      if (sel <= length(hist)) {
        linha_ativa(sel)
        restaurar_val(hist[[sel]]$resultado)
      }
    })

    list(
      restaurar = restaurar_val
    )
  })
}
