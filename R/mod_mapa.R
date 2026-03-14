#' @keywords internal
mod_mapa_ui <- function(id) {
  ns <- shiny::NS(id)
  mapgl::maplibreOutput(ns("mapa"), height = "500px")
}

#' @keywords internal
mod_mapa_server <- function(id, resultado_ucs, agencias_sf, restricoes_lista) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Paleta de cores por agência
    cores_agencias <- shiny::reactive({
      ag_codigos <- sort(unique(resultado_ucs()$agencia_codigo))
      n <- length(ag_codigos)
      cores <- grDevices::hcl.colors(n, palette = "Set 2")
      stats::setNames(cores, ag_codigos)
    })

    # Dados espaciais de UCs com cores
    ucs_sf <- shiny::reactive({
      res <- resultado_ucs()
      ag_sf <- agencias_sf()
      cores <- cores_agencias()

      # Juntar com coordenadas das agências para pegar geometria das UCs
      # resultado_ucs tem uc e agencia_codigo, precisamos de geometria
      # As UCs em si não têm geometria no resultado — usamos as coordenadas
      # do agencias_sf para posicionar as agências, e as UCs precisam
      # de coordenadas (lat/lon) que devem estar no resultado ou serem fornecidas
      res$cor <- cores[res$agencia_codigo]
      res
    })

    output$mapa <- mapgl::renderMaplibre({
      ag <- agencias_sf()
      ucs <- ucs_sf()
      restricoes <- restricoes_lista()

      # Marcar UCs com restrições
      ucs$restricao <- ""
      for (r in restricoes) {
        if (r$tipo == "bloquear") {
          ucs$restricao[ucs$uc %in% r$uc] <- "bloqueada"
        } else if (r$tipo == "forcar") {
          ucs$restricao[ucs$uc %in% r$uc] <- paste0("forcada -> ", r$agencia_codigo)
        }
      }

      # Converter para sf se tem lat/lon
      if (all(c("lat", "lon") %in% names(ucs))) {
        ucs_pts <- sf::st_as_sf(ucs, coords = c("lon", "lat"), crs = 4326)
      } else if (all(c("latitude", "longitude") %in% names(ucs))) {
        ucs_pts <- sf::st_as_sf(ucs, coords = c("longitude", "latitude"), crs = 4326)
      } else {
        # Sem coordenadas, não plotar UCs
        ucs_pts <- NULL
      }

      m <- mapgl::maplibre(
        bounds = if (!is.null(ucs_pts)) ucs_pts else ag,
        style = mapgl::carto_style("positron")
      )

      # Camada de agências
      if (inherits(ag, "sf")) {
        ag$tipo <- "agencia"
        m <- m |>
          mapgl::add_circle_layer(
            id = "agencias",
            source = ag,
            circle_color = "black",
            circle_radius = 8,
            circle_opacity = 0.9,
            circle_stroke_color = "white",
            circle_stroke_width = 2,
            tooltip = "agencia_codigo"
          )
      }

      # Camada de UCs
      if (!is.null(ucs_pts)) {
        m <- m |>
          mapgl::add_circle_layer(
            id = "ucs",
            source = ucs_pts,
            circle_color = list("get", "cor"),
            circle_radius = 5,
            circle_opacity = 0.8,
            tooltip = "uc"
          )
      }

      m
    })

    # Retornar feature clicada
    feature_click <- shiny::reactive({
      input$mapa_feature_click
    })

    feature_click
  })
}
