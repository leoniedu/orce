#' Aplicativo Shiny para Refinamento Interativo de Planos orce
#'
#' Lança um aplicativo Shiny que permite visualizar, explorar e refinar
#' iterativamente um plano de alocação de UCs a agências. Mudanças feitas na
#' interface geram código R reproduzível.
#'
#' @param resultado Resultado de [orce()] com `resultado_completo = TRUE`.
#' @param ucs Data frame de UCs (mesmo usado na chamada original a [orce()]).
#' @param agencias Data frame de agências.
#' @param distancias_ucs Data frame de distâncias UC–agência.
#' @param agencias_treinamento Vetor de códigos das agências de treinamento
#'   (ou `NULL`).
#' @param agencias_sf (Opcional) Objeto `sf` com geometria de pontos das
#'   agências. Se `NULL`, tenta extrair de `agencias` ou usa
#'   `orcedata::agencias_bdo`.
#' @param ... Parâmetros adicionais a serem preservados nas re-otimizações
#'   (passados para [orce()]).
#'
#' @return Um objeto Shiny app (retorno de [shiny::shinyApp()]).
#'
#' @export
orce_app <- function(resultado, ucs, agencias, distancias_ucs,
                     agencias_treinamento = NULL,
                     agencias_sf = NULL,
                     ...) {
  rlang::check_installed(c("shiny", "bslib", "mapgl", "DT"),
                         reason = "para usar orce_app()")

  # Validar que resultado é completo
  if (is.null(resultado$ucs_agencias_todas)) {
    cli::cli_abort(
      c("{.arg resultado} precisa ser de {.code orce(..., resultado_completo = TRUE)}.",
        "i" = "Re-execute {.fun orce} com {.arg resultado_completo} = {.val TRUE}.")
    )
  }

  # Preparar agencias_sf
  if (is.null(agencias_sf)) {
    if (inherits(agencias, "sf")) {
      agencias_sf <- agencias
    } else {
      # Tentar orcedata
      if (requireNamespace("orcedata", quietly = TRUE)) {
        agencias_bdo <- NULL
        utils::data("agencias_bdo", package = "orcedata", envir = environment())
        agencias_sf <- agencias_bdo |>
          dplyr::semi_join(agencias, by = "agencia_codigo")
      }
    }
  }

  # Capturar parâmetros extras para re-otimização
  params_extra <- list(...)

  ui <- bslib::page_sidebar(
    title = "orce: Refinamento de Plano",
    sidebar = bslib::sidebar(
      width = 350,
      mod_restricoes_ui("restricoes")
    ),
    bslib::navset_card_tab(
      bslib::nav_panel("Mapa", mod_mapa_ui("mapa")),
      bslib::nav_panel("Tabela", mod_tabela_ui("tabela")),
      bslib::nav_panel("C\u00f3digo", mod_codigo_ui("codigo"))
    ),
    # JavaScript para copiar ao clipboard
    shiny::tags$script(shiny::HTML(
      "Shiny.addCustomMessageHandler('copiar_clipboard', function(text) {
         navigator.clipboard.writeText(text);
       });"
    ))
  )

  server <- function(input, output, session) {
    # Estado reativo: resultado atual
    resultado_atual <- shiny::reactiveVal(resultado)

    # Estado reativo: seleção
    selected_uc <- shiny::reactiveVal(NULL)
    selected_agencia <- shiny::reactiveVal(NULL)

    # UCs e agências disponíveis (do resultado atual)
    ucs_disponiveis <- shiny::reactive({
      sort(unique(resultado_atual()$resultado_ucs_otimo$uc))
    })
    agencias_disponiveis <- shiny::reactive({
      sort(unique(agencias$agencia_codigo))
    })

    agencias_treinamento_rv <- shiny::reactiveVal(agencias_treinamento)

    # Módulo de restrições
    restricoes_mod <- mod_restricoes_server(
      "restricoes",
      selected_uc = selected_uc,
      selected_agencia = selected_agencia,
      agencias_disponiveis = agencias_disponiveis,
      ucs_disponiveis = ucs_disponiveis,
      agencias_treinamento_inicial = agencias_treinamento_rv
    )

    # Módulo de mapa
    mapa_click <- mod_mapa_server(
      "mapa",
      resultado_ucs = shiny::reactive(resultado_atual()$resultado_ucs_otimo),
      agencias_sf = shiny::reactive(agencias_sf),
      restricoes_lista = restricoes_mod$restricoes
    )

    # Módulo de tabela
    tabela_sel <- mod_tabela_server(
      "tabela",
      resultado_ucs = shiny::reactive(resultado_atual()$resultado_ucs_otimo),
      restricoes_lista = restricoes_mod$restricoes
    )

    # Módulo de código
    mod_codigo_server(
      "codigo",
      restricoes_lista = restricoes_mod$restricoes,
      agencias_treinamento = restricoes_mod$agencias_treinamento,
      agencias_treinamento_inicial = agencias_treinamento_rv
    )

    # Sincronizar seleção do mapa
    shiny::observeEvent(mapa_click(), {
      click <- mapa_click()
      if (!is.null(click)) {
        if (click$layer == "ucs") {
          selected_uc(click$properties$uc)
        } else if (click$layer == "agencias") {
          selected_agencia(click$properties$agencia_codigo)
        }
      }
    })

    # Sincronizar seleção da tabela
    shiny::observeEvent(tabela_sel(), {
      sel <- tabela_sel()
      if (!is.null(sel)) {
        selected_uc(sel$uc)
        if ("agencia_codigo" %in% names(sel)) {
          selected_agencia(sel$agencia_codigo)
        }
      }
    })

    # Re-otimização
    shiny::observeEvent(restricoes_mod$reotimizar(), {
      shiny::withProgress(message = "Re-otimizando...", {
        # Montar lista completa de restrições
        restr <- restricoes_mod$restricoes()
        ag_trein <- restricoes_mod$agencias_treinamento()

        # Aplicar restrições aos dados originais
        dados_mod <- orce_aplicar_restricoes(
          ucs = ucs,
          agencias = agencias,
          distancias_ucs = distancias_ucs,
          agencias_treinamento = agencias_treinamento,
          restricoes = restr
        )

        # Montar argumentos para orce()
        args <- c(
          list(
            ucs = dados_mod$ucs,
            agencias = dados_mod$agencias,
            distancias_ucs = dados_mod$distancias_ucs,
            resultado_completo = TRUE,
            use_cache = FALSE
          ),
          params_extra
        )

        # Adicionar agencias_treinamento se aplicável
        if (!is.null(ag_trein)) {
          args$agencias_treinamento <- ag_trein
        }

        tryCatch({
          novo_resultado <- do.call(orce, args)
          resultado_atual(novo_resultado)
          shiny::showNotification("Re-otimiza\u00e7\u00e3o conclu\u00edda!",
                                  type = "message")
        }, error = function(e) {
          shiny::showNotification(
            paste("Erro:", conditionMessage(e)),
            type = "error", duration = 10
          )
        })
      })
    }, ignoreInit = TRUE)
  }

  shiny::shinyApp(ui, server)
}
