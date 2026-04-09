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
        res$tooltip_uc <- paste0(res$uc, " → ", res$agencia_nome)
      } else {
        res$tooltip_uc <- paste0(res$uc, " → ", res$agencia_codigo)
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

    # Agências com tooltip contendo nome e active/inactive status
    agencias_sf_tooltip <- shiny::reactive({
      ag <- agencias_sf()
      if (!inherits(ag, "sf")) return(ag)

      res_ucs <- resultado_ucs()
      ativas <- if (!is.null(res_ucs)) unique(res_ucs$agencia_codigo) else character()
      ag$ativa <- ag$agencia_codigo %in% ativas

      if (!is.null(nomes_agencias)) {
        ag$tooltip_ag <- paste0(
          nomes_agencias[ag$agencia_codigo],
          " (", ag$agencia_codigo, ")",
          ifelse(ag$ativa, "", " [sem UCs]")
        )
      } else {
        ag$tooltip_ag <- paste0(
          ag$agencia_codigo,
          ifelse(ag$ativa, "", " [sem UCs]")
        )
      }
      ag
    })

    # Linhas UC -> agência para UCs que trocaram de jurisdição
    linhas_troca <- shiny::reactive({
      ucs_pts <- ucs_sf()
      ag <- agencias_sf_tooltip()
      if (is.null(ucs_pts) || !inherits(ag, "sf")) return(NULL)
      if (!any(ucs_pts$trocou_jurisdicao)) return(NULL)

      trocadas <- ucs_pts[ucs_pts$trocou_jurisdicao, ]
      ag_coords <- sf::st_coordinates(ag)
      ag_lookup <- stats::setNames(
        seq_len(nrow(ag)),
        ag$agencia_codigo
      )

      linhas <- lapply(seq_len(nrow(trocadas)), function(i) {
        uc_coord <- sf::st_coordinates(trocadas[i, ])
        ag_idx <- ag_lookup[trocadas$agencia_codigo[i]]
        if (is.na(ag_idx)) return(NULL)
        sf::st_linestring(rbind(uc_coord[1, ], ag_coords[ag_idx, ]))
      })

      validas <- !vapply(linhas, is.null, logical(1))
      if (!any(validas)) return(NULL)

      sf::st_sf(
        tooltip_linha = trocadas$tooltip_uc[validas],
        cor = trocadas$cor[validas],
        geometry = sf::st_sfc(linhas[validas], crs = 4326)
      )
    })

    output$mapa <- mapgl::renderMaplibre({
      ag <- agencias_sf_tooltip()
      ucs_pts <- ucs_sf()

      m <- mapgl::maplibre(
        bounds = if (!is.null(ucs_pts)) ucs_pts else ag,
        style = mapgl::carto_style("positron")
      )

      if (inherits(ag, "sf")) {
        ag_inativas <- ag[!ag$ativa, ]
        ag_ativas <- ag[ag$ativa, ]

        if (nrow(ag_inativas) > 0) {
          m <- m |>
            mapgl::add_circle_layer(
              id = "agencias_inativas",
              source = ag_inativas,
              circle_color = "grey",
              circle_radius = 8,
              circle_opacity = 0.5,
              circle_stroke_color = "black",
              circle_stroke_width = 1,
              tooltip = "tooltip_ag"
            )
        }

        if (nrow(ag_ativas) > 0) {
          m <- m |>
            mapgl::add_circle_layer(
              id = "agencias",
              source = ag_ativas,
              circle_color = "black",
              circle_radius = 8,
              circle_opacity = 0.9,
              circle_stroke_color = "white",
              circle_stroke_width = 2,
              tooltip = "tooltip_ag"
            )
        }
      }

      linhas <- linhas_troca()
      if (!is.null(linhas) && nrow(linhas) > 0) {
        m <- m |>
          mapgl::add_line_layer(
            id = "linhas_troca",
            source = linhas,
            line_color = list("get", "cor"),
            line_width = 1.5,
            line_opacity = 0.6,
            tooltip = "tooltip_linha"
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

      # Controle de camadas
      layer_ids <- character()
      if (inherits(ag, "sf") && nrow(ag[!ag$ativa, ]) > 0) {
        layer_ids <- c(layer_ids, "agencias_inativas")
      }
      if (inherits(ag, "sf") && nrow(ag[ag$ativa, ]) > 0) {
        layer_ids <- c(layer_ids, "agencias")
      }
      if (!is.null(linhas) && nrow(linhas) > 0) {
        layer_ids <- c(layer_ids, "linhas_troca")
      }
      if (!is.null(ucs_pts)) {
        layer_ids <- c(layer_ids, "ucs")
      }
      if (length(layer_ids) > 0) {
        m <- m |>
          mapgl::add_layers_control(layers = layer_ids, collapsible = TRUE)
      }

      m
    })

    # Retornar feature clicada
    shiny::reactive(input$mapa_feature_click)
  })
}
