#' @keywords internal
mod_tabela_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::navset_card_pill(
    bslib::nav_panel("Por UC", DT::dataTableOutput(ns("tabela_ucs"))),
    bslib::nav_panel("Por Agência", DT::dataTableOutput(ns("tabela_agencias")))
  )
}

#' @keywords internal
mod_tabela_server <- function(id, resultado_ucs, resultado_agencias,
                              restricoes_lista,
                              nomes_agencias = NULL) {
  shiny::moduleServer(id, function(input, output, session) {

    # --- Tabela por UC ---
    tabela_ucs_dados <- shiny::reactive({
      res <- .anotar_restricoes(resultado_ucs(), restricoes_lista())

      if (!is.null(nomes_agencias)) {
        res$agencia_nome <- unname(nomes_agencias[res$agencia_codigo])
      }

      colunas_disponiveis <- intersect(
        c("uc", "agencia_nome", "agencia_codigo", "distancia_km", "duracao_horas",
          "dias_coleta", "custo_deslocamento", "restricao"),
        names(res)
      )
      res[, colunas_disponiveis, drop = FALSE]
    })

    output$tabela_ucs <- DT::renderDataTable({
      DT::datatable(
        tabela_ucs_dados(),
        selection = "single",
        filter = "top",
        options = list(
          pageLength = 15,
          scrollX = TRUE,
          language = list(
            search = "Buscar:",
            lengthMenu = "Mostrar _MENU_ registros"
          )
        )
      )
    })

    # --- Tabela por Agência ---
    tabela_agencias_dados <- shiny::reactive({
      res <- resultado_agencias()
      if (is.null(res) || nrow(res) == 0) return(data.frame())

      if (!is.null(nomes_agencias)) {
        res$agencia_nome <- unname(nomes_agencias[res$agencia_codigo])
      }

      colunas_disponiveis <- intersect(
        c("agencia_nome", "agencia_codigo", "n_ucs", "entrevistadores",
          "custo_fixo", "custo_deslocamento", "custo_total_entrevistadores",
          "n_trocas_jurisdicao", "distancia_km", "distancia_km_tsp"),
        names(res)
      )
      res[, colunas_disponiveis, drop = FALSE]
    })

    output$tabela_agencias <- DT::renderDataTable({
      DT::datatable(
        tabela_agencias_dados(),
        selection = "single",
        filter = "top",
        options = list(
          pageLength = 15,
          scrollX = TRUE,
          language = list(
            search = "Buscar:",
            lengthMenu = "Mostrar _MENU_ registros"
          )
        )
      )
    })

    # Retornar linha selecionada (de qualquer tabela)
    shiny::reactive({
      sel_uc <- input$tabela_ucs_rows_selected
      sel_ag <- input$tabela_agencias_rows_selected
      if (!is.null(sel_uc) && length(sel_uc) > 0) {
        tabela_ucs_dados()[sel_uc, ]
      } else if (!is.null(sel_ag) && length(sel_ag) > 0) {
        tabela_agencias_dados()[sel_ag, ]
      } else {
        NULL
      }
    })
  })
}
