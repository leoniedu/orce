#' @keywords internal
mod_parametros_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::hr(),
    bslib::accordion(
      id = ns("accordion_outer"),
      open = FALSE,
      bslib::accordion_panel(
        "Par\u00e2metros",
        bslib::accordion(
          id = ns("accordion"),
          open = FALSE,
          bslib::accordion_panel(
        "Coleta",
        shiny::numericInput(ns("dias_coleta_entrevistador_max"),
                            "Dias coleta/entrevistador (max):",
                            value = NULL, min = 1, step = 1),
        shiny::numericInput(ns("diarias_entrevistador_max"),
                            "Di\u00e1rias/entrevistador (max):",
                            value = NULL, min = 1, step = 1),
        shiny::helpText("Deixe vazio para Inf"),
        shiny::numericInput(ns("n_entrevistadores_min"),
                            "Entrevistadores (min):",
                            value = NULL, min = 1, step = 1)
      ),
      bslib::accordion_panel(
        "Custos",
        shiny::numericInput(ns("remuneracao_entrevistador"),
                            "Remunera\u00e7\u00e3o entrevistador (R$):",
                            value = NULL, min = 0, step = 100),
        shiny::numericInput(ns("custo_litro_combustivel"),
                            "Custo combust\u00edvel (R$/L):",
                            value = NULL, min = 0, step = 0.5),
        shiny::numericInput(ns("custo_hora_viagem"),
                            "Custo hora viagem (R$):",
                            value = NULL, min = 0, step = 1),
        shiny::numericInput(ns("kml"),
                            "Consumo ve\u00edculo (km/L):",
                            value = NULL, min = 1, step = 1),
        shiny::numericInput(ns("adicional_troca_jurisdicao"),
                            "Adicional troca jurisdi\u00e7\u00e3o (R$):",
                            value = NULL, min = 0, step = 100)
      ),
      bslib::accordion_panel(
        "Treinamento",
        shiny::numericInput(ns("dias_treinamento"),
                            "Dias de treinamento:",
                            value = NULL, min = 0, step = 1),
        shiny::uiOutput(ns("treinamento_ui"))
      ),
      bslib::accordion_panel(
        "Solver",
        shiny::numericInput(ns("rel_tol"),
                            "Toler\u00e2ncia relativa:",
                            value = NULL, min = 0, max = 1, step = 0.001),
        shiny::selectInput(ns("solver"),
                           "Solver:",
                           choices = c("highs", "glpk", "symphony"),
                           selected = NULL),
        shiny::numericInput(ns("max_time"),
                            "Tempo m\u00e1ximo (seg):",
                            value = NULL, min = 10, step = 60),
        shiny::numericInput(ns("peso_tsp"),
                            "Peso TSP:",
                            value = NULL, min = 0, step = 0.1)
      )
    )
      )
    )
  )
}

# Definição dos parâmetros e seus defaults (correspondendo a formals de orce())
.PARAMS_DEFAULTS <- list(
  dias_coleta_entrevistador_max = NULL,  # required, no default
  diarias_entrevistador_max = Inf,
  n_entrevistadores_min = 1,
  remuneracao_entrevistador = 0,
  custo_litro_combustivel = 6,
  custo_hora_viagem = 10,
  kml = 10,
  adicional_troca_jurisdicao = 0,
  dias_treinamento = 0,
  rel_tol = 0.005,
  solver = "highs",
  max_time = 1800,
  peso_tsp = 0
)

#' @keywords internal
mod_parametros_server <- function(id, params_iniciais,
                                 agencias_disponiveis,
                                 agencias_treinamento_inicial = NULL,
                                 nomes_agencias = NULL,
                                 limpar = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Inicializar inputs com valores atuais
    shiny::observe({
      for (nome in names(.PARAMS_DEFAULTS)) {
        valor <- params_iniciais[[nome]] %||% .PARAMS_DEFAULTS[[nome]]
        if (nome == "solver") {
          shiny::updateSelectInput(session, nome, selected = valor)
        } else if (nome == "diarias_entrevistador_max" && is.infinite(valor)) {
          shiny::updateNumericInput(session, nome, value = NA)
        } else {
          shiny::updateNumericInput(session, nome, value = valor)
        }
      }
    }) |> shiny::bindEvent(TRUE, once = TRUE)

    # --- Agências de treinamento ---

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

    agencias_treinamento <- shiny::reactiveVal(NULL)
    shiny::observe({
      if (!is.null(agencias_treinamento_inicial)) {
        agencias_treinamento(agencias_treinamento_inicial())
      }
    })

    output$treinamento_ui <- shiny::renderUI({
      shiny::selectizeInput(
        ns("agencias_treinamento_sel"),
        "Ag\u00eancias de treinamento:",
        choices = agencias_choices(),
        selected = agencias_treinamento(),
        multiple = TRUE
      )
    })

    shiny::observeEvent(input$agencias_treinamento_sel, {
      agencias_treinamento(input$agencias_treinamento_sel)
    }, ignoreNULL = FALSE)

    # Resetar agências de treinamento ao limpar tudo
    if (!is.null(limpar)) {
      shiny::observeEvent(limpar(), {
        if (!is.null(agencias_treinamento_inicial)) {
          agencias_treinamento(agencias_treinamento_inicial())
        }
      })
    }

    # --- Parâmetros ---

    # Retornar lista reativa de parâmetros atuais
    params_atuais <- shiny::reactive({
      params <- list()
      for (nome in names(.PARAMS_DEFAULTS)) {
        val <- input[[nome]]
        if (!is.null(val)) {
          if (nome == "diarias_entrevistador_max" && is.na(val)) {
            val <- Inf
          }
          params[[nome]] <- val
        }
      }
      params
    })

    # Retornar apenas parâmetros que diferem dos iniciais (para histórico)
    params_alterados <- shiny::reactive({
      atuais <- params_atuais()
      alterados <- list()
      for (nome in names(atuais)) {
        valor_ini <- params_iniciais[[nome]] %||% .PARAMS_DEFAULTS[[nome]]
        igual <- if (is.numeric(atuais[[nome]]) && is.numeric(valor_ini)) {
          isTRUE(all.equal(atuais[[nome]], valor_ini))
        } else {
          identical(atuais[[nome]], valor_ini)
        }
        if (is.null(valor_ini) || !igual) {
          alterados[[nome]] <- atuais[[nome]]
        }
      }
      alterados
    })

    list(
      params_atuais = params_atuais,
      params_alterados = params_alterados,
      agencias_treinamento = agencias_treinamento
    )
  })
}
