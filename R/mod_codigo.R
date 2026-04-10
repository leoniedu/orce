#' @keywords internal
mod_codigo_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::div(
      class = "d-flex justify-content-between align-items-center mb-2",
      shiny::h4("Código R", class = "mb-0"),
      shiny::actionButton(ns("copiar"), "Copiar",
                          class = "btn-outline-secondary btn-sm")
    ),
    shiny::verbatimTextOutput(ns("codigo"))
  )
}

#' @keywords internal
mod_codigo_server <- function(id, restricoes_lista, agencias_treinamento,
                              agencias_treinamento_inicial,
                              params_alterados = NULL,
                              params_fixos = list(),
                              fixar_atribuicoes = NULL,
                              bloquear_atribuicoes = NULL) {
  shiny::moduleServer(id, function(input, output, session) {

    codigo_texto <- shiny::reactive({
      restr <- restricoes_lista()
      ag_trein <- agencias_treinamento()
      ag_trein_ini <- agencias_treinamento_inicial()

      # Incluir agências de treinamento se existirem (original ou modificada)
      todas_restricoes <- restr
      ag_trein_efetivo <- ag_trein %||% ag_trein_ini
      if (!is.null(ag_trein_efetivo) && length(ag_trein_efetivo) > 0) {
        todas_restricoes <- c(
          todas_restricoes,
          list(list(tipo = "agencias_treinamento",
                    agencias_treinamento = ag_trein_efetivo))
        )
      }

      p_alt <- if (!is.null(params_alterados)) params_alterados() else list()
      fixar <- if (!is.null(fixar_atribuicoes)) fixar_atribuicoes() else NULL
      bloquear <- if (!is.null(bloquear_atribuicoes)) bloquear_atribuicoes() else NULL
      orce_gerar_codigo(todas_restricoes, params_alterados = p_alt,
                        params_fixos = params_fixos,
                        fixar_atribuicoes = fixar,
                        bloquear_atribuicoes = bloquear)
    })

    output$codigo <- shiny::renderText({
      codigo_texto()
    })

    # Copiar para clipboard via JS
    shiny::observeEvent(input$copiar, {
      shiny::showNotification("Código copiado!", type = "message", duration = 2)
      session$sendCustomMessage("copiar_clipboard", codigo_texto())
    })

    codigo_texto
  })
}
