#' @keywords internal
mod_restricoes_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::h4("Seleção"),
    shiny::verbatimTextOutput(ns("selecao_info")),

    shiny::hr(),
    shiny::h4("Adicionar restrição"),

    shiny::selectInput(ns("tipo_restricao"), "Tipo:",
                       choices = c("Bloquear UC da agência" = "bloquear",
                                   "Forçar UC para agência" = "forcar",
                                   "Desativar agência" = "desativar_agencia")),

    shiny::uiOutput(ns("restricao_inputs")),

    shiny::actionButton(ns("adicionar"), "Adicionar restrição",
                        class = "btn-primary btn-sm"),

    shiny::hr(),
    shiny::h4("Restrições ativas"),
    shiny::uiOutput(ns("lista_restricoes"))
  )
}

#' @keywords internal
mod_restricoes_botoes_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::hr(),
    shiny::checkboxInput(ns("fixar_nao_afetadas"),
                         "Fixar UCs não afetadas",
                         value = TRUE),
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
                                  nomes_agencias = NULL,
                                  restricoes_iniciais = list()) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Choices com nomes para dropdowns de agências
    agencias_choices <- shiny::reactive({
      codigos <- agencias_disponiveis()
      if (!is.null(nomes_agencias)) {
        labels <- paste0(nomes_agencias[codigos], " (", codigos, ")")
        stats::setNames(codigos, labels)
      } else {
        codigos
      }
    })

    # Seed initial restrictions with unique IDs
    init_restr <- lapply(restricoes_iniciais, function(r) {
      r$.id <- as.character(as.numeric(Sys.time()) * 1000 + sample(10000, 1))
      r
    })

    # Estado reativo: lista de restrições
    restricoes <- shiny::reactiveVal(init_restr)

    # Mostrar seleção atual
    output$selecao_info <- shiny::renderText({
      uc <- selected_uc()
      ag <- selected_agencia()
      linhas <- character()
      if (!is.null(uc)) linhas <- c(linhas, paste("UC:", uc))
      if (!is.null(ag)) {
        ag_label <- if (!is.null(nomes_agencias) && ag %in% names(nomes_agencias)) {
          paste0(nomes_agencias[[ag]], " (", ag, ")")
        } else {
          ag
        }
        linhas <- c(linhas, paste("Agência:", ag_label))
      }
      if (length(linhas) == 0) "Nenhuma seleção"
      else paste(linhas, collapse = "\n")
    })

    # Inputs dinâmicos conforme tipo de restrição
    output$restricao_inputs <- shiny::renderUI({
      tipo <- input$tipo_restricao
      if (is.null(tipo)) return(NULL)

      uc_sel <- selected_uc()
      ag_sel <- selected_agencia()
      choices <- agencias_choices()

      if (tipo %in% c("bloquear", "forcar")) {
        shiny::tagList(
          shiny::selectizeInput(ns("uc_alvo"), "UC:",
                                choices = ucs_disponiveis(),
                                selected = uc_sel,
                                multiple = TRUE),
          shiny::selectInput(ns("agencia_alvo"), "Agência:",
                             choices = choices,
                             selected = ag_sel)
        )
      } else if (tipo == "desativar_agencia") {
        shiny::selectInput(ns("agencia_alvo"), "Agência:",
                           choices = choices,
                           selected = ag_sel)
      }
    })

    # Adicionar restrição
    shiny::observeEvent(input$adicionar, {
      tipo <- input$tipo_restricao
      nova <- NULL

      if (tipo %in% c("bloquear", "forcar")) {
        uc <- input$uc_alvo
        ag <- input$agencia_alvo
        if (is.null(uc) || length(uc) == 0 || is.null(ag)) {
          shiny::showNotification("Selecione UC e agência.", type = "warning")
          return()
        }
        nova <- list(tipo = tipo, uc = uc, agencia_codigo = ag)

      } else if (tipo == "desativar_agencia") {
        ag <- input$agencia_alvo
        if (is.null(ag)) {
          shiny::showNotification("Selecione uma agência.", type = "warning")
          return()
        }
        nova <- list(tipo = tipo, agencia_codigo = ag)
      }

      if (!is.null(nova)) {
        nova$.id <- as.character(as.numeric(Sys.time()) * 1000 + sample(1000, 1))
        restricoes(c(restricoes(), list(nova)))
        shiny::showNotification("Restrição adicionada.", type = "message")
      }
    })

    # Registro de observers de remoção (plain env to avoid reactive side effects)
    obs_remocao <- new.env(parent = emptyenv())

    # Renderizar lista de restrições ativas
    output$lista_restricoes <- shiny::renderUI({
      restr <- restricoes()
      if (length(restr) == 0) {
        return(shiny::p("Nenhuma restrição."))
      }
      itens <- lapply(restr, function(r) {
        rid <- r$.id
        descricao <- .descrever_restricao(r, nomes_agencias)
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

    # Observar botões de remoção (criar observer uma única vez por ID, destruir ao remover)
    shiny::observe({
      restr <- restricoes()
      ids_atuais <- vapply(restr, function(r) r$.id, character(1))
      ids_registrados <- ls(obs_remocao)

      # Criar observers para novas restrições
      for (rid in setdiff(ids_atuais, ids_registrados)) {
        local({
          my_rid <- rid
          btn_id <- paste0("remover_", my_rid)
          obs_remocao[[my_rid]] <- shiny::observeEvent(input[[btn_id]], {
            atual <- restricoes()
            restricoes(Filter(function(r) r$.id != my_rid, atual))
          }, ignoreInit = TRUE)
        })
      }

      # Destruir observers de restrições removidas
      for (rid in setdiff(ids_registrados, ids_atuais)) {
        obs_remocao[[rid]]$destroy()
        rm(list = rid, envir = obs_remocao)
      }
    })

    # Limpar tudo
    shiny::observeEvent(input$limpar, {
      restricoes(list())
    })

    # Retornar valores
    list(
      restricoes = restricoes,
      reotimizar = shiny::reactive(input$reotimizar),
      limpar = shiny::reactive(input$limpar),
      fixar_nao_afetadas = shiny::reactive(input$fixar_nao_afetadas)
    )
  })
}

#' Descrever restrição em texto legível
#' @keywords internal
.descrever_restricao <- function(r, nomes_agencias = NULL) {
  .nome_ag <- function(codigo) {
    if (!is.null(nomes_agencias) && codigo %in% names(nomes_agencias)) {
      nomes_agencias[[codigo]]
    } else {
      codigo
    }
  }
  switch(r$tipo,
    bloquear = paste0("Bloquear ", paste(r$uc, collapse = ", "),
                      " de ", .nome_ag(r$agencia_codigo)),
    forcar = paste0("Forçar ", paste(r$uc, collapse = ", "),
                    " → ", .nome_ag(r$agencia_codigo)),
    desativar_agencia = paste0("Desativar ", .nome_ag(r$agencia_codigo)),
    agencias_treinamento = paste0("Treinamento: ",
                                   paste(vapply(r$agencias_treinamento, .nome_ag,
                                                character(1)), collapse = ", ")),
    paste("Restrição:", r$tipo)
  )
}
