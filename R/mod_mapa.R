#' @keywords internal
mod_mapa_ui <- function(id) {
  ns <- shiny::NS(id)
  mapgl::maplibreOutput(ns("mapa"), height = "500px")
}

#' @keywords internal
mod_mapa_server <- function(id, resultado_ucs, agencias_sf, restricoes_lista,
                            nomes_agencias = NULL) {
  shiny::moduleServer(id, function(input, output, session) {

    # Paleta de cores por agência
    cores_agencias <- shiny::reactive({
      ag_codigos <- sort(unique(resultado_ucs()$agencia_codigo))
      n <- length(ag_codigos)
      cores <- grDevices::hcl.colors(n, palette = "Set 2")
      stats::setNames(cores, ag_codigos)
    })

    # Dados espaciais de UCs com cores e restrições (sf conversion here, not in render)
    ucs_sf <- shiny::reactive({
      res <- resultado_ucs()
      cores <- cores_agencias()
      res$cor <- cores[res$agencia_codigo]
      res <- .anotar_restricoes(res, restricoes_lista())

      # Marcar UCs com troca de jurisdição
      if ("agencia_codigo_jurisdicao" %in% names(res)) {
        res$trocou_jurisdicao <- res$agencia_codigo != res$agencia_codigo_jurisdicao
      } else {
        res$trocou_jurisdicao <- FALSE
      }
      res$stroke_color <- ifelse(res$trocou_jurisdicao, "#e31a1c", "transparent")
      res$stroke_width <- ifelse(res$trocou_jurisdicao, 2, 0)

      # Adicionar nome da agência para tooltip
      if (!is.null(nomes_agencias)) {
        res$agencia_nome <- unname(nomes_agencias[res$agencia_codigo])
        res$tooltip_uc <- paste0(res$uc, " \u2192 ", res$agencia_nome)
      } else {
        res$tooltip_uc <- paste0(res$uc, " \u2192 ", res$agencia_codigo)
      }
      # Enriquecer tooltip com indicação de troca
      if (any(res$trocou_jurisdicao)) {
        jur_nome <- if (!is.null(nomes_agencias)) {
          unname(nomes_agencias[res$agencia_codigo_jurisdicao])
        } else {
          res$agencia_codigo_jurisdicao
        }
        res$tooltip_uc <- ifelse(
          res$trocou_jurisdicao,
          paste0(res$tooltip_uc, " (era ", jur_nome, ")"),
          res$tooltip_uc
        )
      }

      # Converter para sf se tem lat/lon
      if (all(c("lat", "lon") %in% names(res))) {
        sf::st_as_sf(res, coords = c("lon", "lat"), crs = 4326)
      } else if (all(c("latitude", "longitude") %in% names(res))) {
        sf::st_as_sf(res, coords = c("longitude", "latitude"), crs = 4326)
      } else {
        NULL
      }
    })

    # Agências com tooltip contendo nome
    agencias_sf_tooltip <- shiny::reactive({
      ag <- agencias_sf()
      if (inherits(ag, "sf") && !is.null(nomes_agencias)) {
        ag$tooltip_ag <- paste0(
          nomes_agencias[ag$agencia_codigo],
          " (", ag$agencia_codigo, ")"
        )
      } else if (inherits(ag, "sf")) {
        ag$tooltip_ag <- ag$agencia_codigo
      }
      ag
    })

    output$mapa <- mapgl::renderMaplibre({
      ag <- agencias_sf_tooltip()
      ucs_pts <- ucs_sf()

      m <- mapgl::maplibre(
        bounds = if (!is.null(ucs_pts)) ucs_pts else ag,
        style = mapgl::carto_style("positron")
      )

      if (inherits(ag, "sf")) {
        m <- m |>
          mapgl::add_circle_layer(
            id = "agencias",
            source = ag,
            circle_color = "black",
            circle_radius = 8,
            circle_opacity = 0.9,
            circle_stroke_color = "white",
            circle_stroke_width = 2,
            tooltip = "tooltip_ag"
          )
      }

      if (!is.null(ucs_pts)) {
        m <- m |>
          mapgl::add_circle_layer(
            id = "ucs",
            source = ucs_pts,
            circle_color = list("get", "cor"),
            circle_radius = 5,
            circle_opacity = 0.8,
            circle_stroke_color = list("get", "stroke_color"),
            circle_stroke_width = list("get", "stroke_width"),
            tooltip = "tooltip_uc"
          )
      }

      m
    })

    # Retornar feature clicada
    shiny::reactive(input$mapa_feature_click)
  })
}
