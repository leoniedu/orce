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

  # Lookup de nomes de agências (codigo -> nome)
  nomes_agencias <- if (!is.null(agencias_sf) && "agencia_nome" %in% names(agencias_sf)) {
    stats::setNames(agencias_sf$agencia_nome, agencias_sf$agencia_codigo)
  } else {
    NULL
  }

  # Capturar parâmetros extras para re-otimização
  # Separar escalares (editáveis no UI) de não-escalares (passados direto)
  params_extra <- list(...)
  params_extra_fixos <- Filter(
    function(x) !(length(x) == 1 && (is.numeric(x) || is.character(x))),
    params_extra
  )
  params_extra_escalares <- params_extra[setdiff(names(params_extra),
                                                  names(params_extra_fixos))]

  ui <- bslib::page_sidebar(
    title = "orce: Refinamento de Plano",
    sidebar = bslib::sidebar(
      width = 350,
      mod_restricoes_ui("restricoes"),
      mod_parametros_ui("parametros"),
      mod_restricoes_botoes_ui("restricoes")
    ),
    bslib::navset_card_tab(
      bslib::nav_panel("Mapa", mod_mapa_ui("mapa")),
      bslib::nav_panel("Tabela", mod_tabela_ui("tabela")),
      bslib::nav_panel("Hist\u00f3rico", mod_historico_ui("historico")),
      bslib::nav_panel("C\u00f3digo", mod_codigo_ui("codigo"))
    ),
    # JavaScript para copiar ao clipboard
    shiny::tags$script(shiny::HTML(
      "Shiny.addCustomMessageHandler('copiar_clipboard', function(text) {
         navigator.clipboard.writeText(text);
       });"
    ))
  )

  # Capturar coordenadas das UCs do resultado inicial para re-join após re-otimização
  coords_ucs <- NULL
  res_ucs_ini <- resultado$resultado_ucs_otimo
  if (all(c("lat", "lon") %in% names(res_ucs_ini))) {
    coords_ucs <- unique(res_ucs_ini[, c("uc", "lat", "lon")])
  } else if (all(c("latitude", "longitude") %in% names(res_ucs_ini))) {
    coords_ucs <- unique(res_ucs_ini[, c("uc", "latitude", "longitude")])
  }

  server <- function(input, output, session) {
    # Estado reativo: resultado atual
    resultado_atual <- shiny::reactiveVal(resultado)

    # Estado reativo: seleção
    selected_uc <- shiny::reactiveVal(NULL)
    selected_agencia <- shiny::reactiveVal(NULL)

    # UCs disponíveis (reativo pois muda com re-otimização)
    ucs_disponiveis <- shiny::reactive({
      sort(unique(resultado_atual()$resultado_ucs_otimo$uc))
    })
    # Agências disponíveis (estático — não muda durante a sessão)
    agencias_disponiveis_val <- sort(unique(agencias$agencia_codigo))
    agencias_disponiveis <- shiny::reactive(agencias_disponiveis_val)

    agencias_treinamento_rv <- shiny::reactive(agencias_treinamento)

    # Módulo de restrições
    restricoes_mod <- mod_restricoes_server(
      "restricoes",
      selected_uc = selected_uc,
      selected_agencia = selected_agencia,
      agencias_disponiveis = agencias_disponiveis,
      ucs_disponiveis = ucs_disponiveis,
      nomes_agencias = nomes_agencias
    )

    # Módulo de parâmetros (inclui agências de treinamento)
    parametros_mod <- mod_parametros_server(
      "parametros",
      params_iniciais = params_extra_escalares,
      agencias_disponiveis = agencias_disponiveis,
      agencias_treinamento_inicial = agencias_treinamento_rv,
      nomes_agencias = nomes_agencias,
      limpar = restricoes_mod$limpar
    )

    # Módulo de mapa
    mapa_click <- mod_mapa_server(
      "mapa",
      resultado_ucs = shiny::reactive(resultado_atual()$resultado_ucs_otimo),
      agencias_sf = shiny::reactive(agencias_sf),
      restricoes_lista = restricoes_mod$restricoes,
      nomes_agencias = nomes_agencias
    )

    # Módulo de tabela
    tabela_sel <- mod_tabela_server(
      "tabela",
      resultado_ucs = shiny::reactive(resultado_atual()$resultado_ucs_otimo),
      resultado_agencias = shiny::reactive(resultado_atual()$resultado_agencias_otimo),
      restricoes_lista = restricoes_mod$restricoes,
      nomes_agencias = nomes_agencias
    )

    # Módulo de código
    codigo_mod <- mod_codigo_server(
      "codigo",
      restricoes_lista = restricoes_mod$restricoes,
      agencias_treinamento = parametros_mod$agencias_treinamento,
      agencias_treinamento_inicial = agencias_treinamento_rv,
      params_alterados = parametros_mod$params_atuais,
      params_fixos_nomes = names(params_extra_fixos)
    )

    # Módulo de histórico
    historico_mod <- mod_historico_server(
      "historico",
      resultado_atual = resultado_atual,
      codigo_texto = codigo_mod,
      nomes_agencias = nomes_agencias,
      restricoes_lista = restricoes_mod$restricoes,
      params_atuais = parametros_mod$params_atuais,
      params_iniciais = params_extra_escalares
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
        ag_trein <- parametros_mod$agencias_treinamento()

        # Aplicar restrições aos dados originais
        dados_mod <- orce_aplicar_restricoes(
          ucs = ucs,
          agencias = agencias,
          distancias_ucs = distancias_ucs,
          agencias_treinamento = agencias_treinamento,
          restricoes = restr
        )

        # Montar argumentos para orce() usando parâmetros atuais do módulo
        # params_extra_fixos: data frames/vetores não-editáveis (distancias_agencias, etc.)
        # params_atuais(): escalares editáveis no UI
        args <- c(
          list(
            ucs = dados_mod$ucs,
            agencias = dados_mod$agencias,
            distancias_ucs = dados_mod$distancias_ucs,
            resultado_completo = TRUE,
            use_cache = TRUE
          ),
          params_extra_fixos,
          parametros_mod$params_atuais()
        )

        # Adicionar agencias_treinamento se aplicável
        if (!is.null(ag_trein)) {
          args$agencias_treinamento <- ag_trein
        }

        tryCatch({
          novo_resultado <- do.call(orce, args)

          # Re-juntar coordenadas das UCs para o mapa
          if (!is.null(coords_ucs)) {
            novo_resultado$resultado_ucs_otimo <- dplyr::left_join(
              novo_resultado$resultado_ucs_otimo,
              coords_ucs,
              by = "uc"
            )
          }

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

    # Restaurar resultado do histórico
    shiny::observeEvent(historico_mod$restaurar(), {
      res <- historico_mod$restaurar()
      if (!is.null(res)) {
        resultado_atual(res)
        shiny::showNotification("Resultado restaurado.", type = "message")
      }
    })
  }

  shiny::shinyApp(ui, server)
}
