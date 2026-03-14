#' @keywords internal
mod_restricoes_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::h4("Sele\u00e7\u00e3o"),
    shiny::verbatimTextOutput(ns("selecao_info")),

    shiny::hr(),
    shiny::h4("Adicionar restri\u00e7\u00e3o"),

    shiny::selectInput(ns("tipo_restricao"), "Tipo:",
                       choices = c("Bloquear UC da ag\u00eancia" = "bloquear",
                                   "For\u00e7ar UC para ag\u00eancia" = "forcar",
                                   "Desativar ag\u00eancia" = "desativar_agencia")),

    shiny::uiOutput(ns("restricao_inputs")),

    shiny::actionButton(ns("adicionar"), "Adicionar restri\u00e7\u00e3o",
                        class = "btn-primary btn-sm"),

    shiny::hr(),
    shiny::h4("Ag\u00eancias de treinamento"),
    shiny::uiOutput(ns("treinamento_ui")),

    shiny::hr(),
    shiny::h4("Restri\u00e7\u00f5es ativas"),
    shiny::uiOutput(ns("lista_restricoes")),

    shiny::hr(),
    shiny::actionButton(ns("reotimizar"), "Re-otimizar",
                        class = "btn-success"),
    shiny::actionButton(ns("limpar"), "Limpar tudo",
                        class = "btn-warning btn-sm")
  )
}

#' @keywords internal
mod_restricoes_server <- function(id, selected_uc, selected_agencia,
                                  agencias_disponiveis,
                                  ucs_disponiveis,
                                  agencias_treinamento_inicial) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Estado reativo: lista de restrições
    restricoes <- shiny::reactiveVal(list())

    # Estado reativo: agências de treinamento
    agencias_treinamento <- shiny::reactiveVal(NULL)

    shiny::observe({
      agencias_treinamento(agencias_treinamento_inicial())
    })

    # Mostrar seleção atual
    output$selecao_info <- shiny::renderText({
      uc <- selected_uc()
      ag <- selected_agencia()
      linhas <- character()
      if (!is.null(uc)) linhas <- c(linhas, paste("UC:", uc))
      if (!is.null(ag)) linhas <- c(linhas, paste("Ag\u00eancia:", ag))
      if (length(linhas) == 0) "Nenhuma sele\u00e7\u00e3o"
      else paste(linhas, collapse = "\n")
    })

    # Inputs dinâmicos conforme tipo de restrição
    output$restricao_inputs <- shiny::renderUI({
      tipo <- input$tipo_restricao
      if (is.null(tipo)) return(NULL)

      uc_sel <- selected_uc()
      ag_sel <- selected_agencia()

      if (tipo %in% c("bloquear", "forcar")) {
        shiny::tagList(
          shiny::selectizeInput(ns("uc_alvo"), "UC:",
                                choices = ucs_disponiveis(),
                                selected = uc_sel,
                                multiple = TRUE),
          shiny::selectInput(ns("agencia_alvo"), "Ag\u00eancia:",
                             choices = agencias_disponiveis(),
                             selected = ag_sel)
        )
      } else if (tipo == "desativar_agencia") {
        shiny::selectInput(ns("agencia_alvo"), "Ag\u00eancia:",
                           choices = agencias_disponiveis(),
                           selected = ag_sel)
      }
    })

    # UI para agências de treinamento
    output$treinamento_ui <- shiny::renderUI({
      shiny::selectizeInput(
        ns("agencias_treinamento_sel"),
        label = NULL,
        choices = agencias_disponiveis(),
        selected = agencias_treinamento(),
        multiple = TRUE
      )
    })

    # Observar mudanças nas agências de treinamento
    shiny::observeEvent(input$agencias_treinamento_sel, {
      agencias_treinamento(input$agencias_treinamento_sel)
    }, ignoreNULL = FALSE)

    # Adicionar restrição
    shiny::observeEvent(input$adicionar, {
      tipo <- input$tipo_restricao
      nova <- NULL

      if (tipo %in% c("bloquear", "forcar")) {
        uc <- input$uc_alvo
        ag <- input$agencia_alvo
        if (is.null(uc) || length(uc) == 0 || is.null(ag)) {
          shiny::showNotification("Selecione UC e ag\u00eancia.", type = "warning")
          return()
        }
        nova <- list(tipo = tipo, uc = uc, agencia_codigo = ag)

      } else if (tipo == "desativar_agencia") {
        ag <- input$agencia_alvo
        if (is.null(ag)) {
          shiny::showNotification("Selecione uma ag\u00eancia.", type = "warning")
          return()
        }
        nova <- list(tipo = tipo, agencia_codigo = ag)
      }

      if (!is.null(nova)) {
        nova$.id <- as.character(as.numeric(Sys.time()) * 1000 + sample(1000, 1))
        restricoes(c(restricoes(), list(nova)))
        shiny::showNotification("Restri\u00e7\u00e3o adicionada.", type = "message")
      }
    })

    # Contador de observers criados (para evitar duplicatas)
    observers_criados <- shiny::reactiveVal(character())

    # Renderizar lista de restrições ativas
    output$lista_restricoes <- shiny::renderUI({
      restr <- restricoes()
      if (length(restr) == 0) {
        return(shiny::p("Nenhuma restri\u00e7\u00e3o."))
      }
      itens <- lapply(restr, function(r) {
        rid <- r$.id
        descricao <- .descrever_restricao(r)
        shiny::div(
          class = "d-flex justify-content-between align-items-center mb-1",
          shiny::span(descricao),
          shiny::actionButton(
            ns(paste0("remover_", rid)),
            "X",
            class = "btn-danger btn-sm",
            style = "padding: 2px 6px; font-size: 11px;"
          )
        )
      })
      shiny::tagList(itens)
    })

    # Observar botões de remoção (criar observer uma única vez por ID)
    shiny::observe({
      restr <- restricoes()
      ids_atuais <- vapply(restr, function(r) r$.id, character(1))
      novos <- setdiff(ids_atuais, observers_criados())

      for (rid in novos) {
        local({
          my_rid <- rid
          btn_id <- paste0("remover_", my_rid)
          shiny::observeEvent(input[[btn_id]], {
            atual <- restricoes()
            restricoes(Filter(function(r) r$.id != my_rid, atual))
          }, ignoreInit = TRUE)
        })
      }

      observers_criados(union(observers_criados(), novos))
    })

    # Limpar tudo
    shiny::observeEvent(input$limpar, {
      restricoes(list())
      agencias_treinamento(agencias_treinamento_inicial())
    })

    # Retornar valores
    list(
      restricoes = restricoes,
      agencias_treinamento = agencias_treinamento,
      reotimizar = shiny::reactive(input$reotimizar)
    )
  })
}

#' Descrever restrição em texto legível
#' @keywords internal
.descrever_restricao <- function(r) {
  switch(r$tipo,
    bloquear = paste0("Bloquear ", paste(r$uc, collapse = ", "),
                      " de ", r$agencia_codigo),
    forcar = paste0("For\u00e7ar ", paste(r$uc, collapse = ", "),
                    " -> ", r$agencia_codigo),
    desativar_agencia = paste0("Desativar ", r$agencia_codigo),
    agencias_treinamento = paste0("Treinamento: ",
                                   paste(r$agencias_treinamento, collapse = ", ")),
    paste("Restri\u00e7\u00e3o:", r$tipo)
  )
}
