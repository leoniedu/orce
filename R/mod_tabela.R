#' @keywords internal
mod_tabela_ui <- function(id) {
  ns <- shiny::NS(id)
  DT::dataTableOutput(ns("tabela"))
}

#' @keywords internal
mod_tabela_server <- function(id, resultado_ucs, restricoes_lista) {
  shiny::moduleServer(id, function(input, output, session) {

    tabela_dados <- shiny::reactive({
      res <- resultado_ucs()
      restricoes <- restricoes_lista()

      # Adicionar coluna de restrição
      res$restricao <- ""
      for (r in restricoes) {
        if (r$tipo == "bloquear") {
          idx <- res$uc %in% r$uc
          res$restricao[idx] <- paste0(
            res$restricao[idx],
            ifelse(res$restricao[idx] == "", "", "; "),
            "bloqueada de ", r$agencia_codigo
          )
        } else if (r$tipo == "forcar") {
          idx <- res$uc %in% r$uc
          res$restricao[idx] <- paste0("forcada -> ", r$agencia_codigo)
        }
      }

      # Selecionar colunas relevantes para exibição
      colunas_disponiveis <- intersect(
        c("uc", "agencia_codigo", "distancia_km", "duracao_horas",
          "dias_coleta", "custo_deslocamento", "restricao"),
        names(res)
      )
      res[, colunas_disponiveis, drop = FALSE]
    })

    output$tabela <- DT::renderDataTable({
      DT::datatable(
        tabela_dados(),
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

    # Retornar linha selecionada
    selected_row <- shiny::reactive({
      sel <- input$tabela_rows_selected
      if (is.null(sel) || length(sel) == 0) return(NULL)
      tabela_dados()[sel, ]
    })

    selected_row
  })
}
