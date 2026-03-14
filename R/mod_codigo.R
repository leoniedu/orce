#' @keywords internal
mod_codigo_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(
      class = "d-flex justify-content-between align-items-center mb-2",
      shiny::h4("C\u00f3digo R", class = "mb-0"),
      shiny::actionButton(ns("copiar"), "Copiar",
                          class = "btn-outline-secondary btn-sm")
    ),
    shiny::verbatimTextOutput(ns("codigo"))
  )
}

#' @keywords internal
mod_codigo_server <- function(id, restricoes_lista, agencias_treinamento,
                              agencias_treinamento_inicial) {
  shiny::moduleServer(id, function(input, output, session) {

    codigo_texto <- shiny::reactive({
      restr <- restricoes_lista()
      ag_trein <- agencias_treinamento()
      ag_trein_ini <- agencias_treinamento_inicial()

      # Incluir agências de treinamento apenas se alteradas
      todas_restricoes <- restr
      if (!is.null(ag_trein) &&
          !identical(sort(ag_trein), sort(ag_trein_ini %||% character()))) {
        todas_restricoes <- c(
          todas_restricoes,
          list(list(tipo = "agencias_treinamento",
                    agencias_treinamento = ag_trein))
        )
      }

      orce_gerar_codigo(todas_restricoes)
    })

    output$codigo <- shiny::renderText({
      codigo_texto()
    })

    # Copiar para clipboard via JS
    shiny::observeEvent(input$copiar, {
      shiny::showNotification("C\u00f3digo copiado!", type = "message", duration = 2)
      session$sendCustomMessage("copiar_clipboard", codigo_texto())
    })

    codigo_texto
  })
}
