#' Calcula Distâncias Entre Origens e Destinos
#'
#' Calcula a distância e duração entre conjuntos de pontos de origem e destino
#' usando o serviço OSRM. As requisições são enviadas em lotes para evitar o
#' limite de pares por requisição.
#'
#' @param destinos Um objeto `sf` representando os pontos de destino.
#' @param origens Um objeto `sf` representando os pontos de origem.
#' @param chunk_size Número de origens por lote enviado ao OSRM. Padrão: 100L.
#' @param nmax Descontinuado. Número máximo de pares origem-destino por
#'   requisição. Use `chunk_size` no lugar.
#'
#' @return Um `data.frame` com as distâncias (em quilômetros) e durações (em
#'   horas) entre cada par de origem e destino, além dos atributos originais de
#'   `origens` e `destinos`.
#'
#' @details
#' A função utiliza o pacote `osrm` para calcular distâncias e durações. O
#' parâmetro `chunk_size` controla quantas origens são enviadas por requisição,
#' evitando o erro "Too many table coordinates".
#'
#' @export
calcula_distancias <- function(destinos, origens, chunk_size = 100L,
                               nmax = NULL) {
  if (!is.null(nmax)) {
    chunk_size <- max(1L, floor(nmax / nrow(destinos)))
    cli::cli_warn(
      "O argumento {.arg nmax} est\u00e1 descontinuado. Use {.arg chunk_size}.",
      .frequency = "once"
    )
  }

  if (!inherits(destinos, "sf")) {
    cli::cli_abort("{.arg destinos} deve ser um objeto {.cls sf}.")
  }
  if (!inherits(origens, "sf")) {
    cli::cli_abort("{.arg origens} deve ser um objeto {.cls sf}.")
  }
  if (any(is.na(sf::st_coordinates(destinos)))) {
    cli::cli_abort("{.arg destinos} n\u00e3o pode ter coordenadas {.val NA}.")
  }
  if (any(is.na(sf::st_coordinates(origens)))) {
    cli::cli_abort("{.arg origens} n\u00e3o pode ter coordenadas {.val NA}.")
  }

  dec_original <- getOption("OutDec")
  on.exit(options(OutDec = dec_original), add = TRUE)
  options(OutDec = ".")

  destinos_1 <- destinos |>
    dplyr::ungroup() |>
    dplyr::mutate(id_destino = seq_len(dplyr::n()))
  origens_1 <- origens |>
    dplyr::ungroup() |>
    dplyr::mutate(id_origem = seq_len(dplyr::n()))

  n <- nrow(origens_1)
  chunks <- split(seq_len(n), ceiling(seq_len(n) / chunk_size))
  n_failed <- 0L
  results <- vector("list", length(chunks))

  cli::cli_progress_bar("Calculando dist\u00e2ncias", total = length(chunks))

  for (i in seq_along(chunks)) {
    src <- origens_1[chunks[[i]], ]
    results[[i]] <- tryCatch({
      rlang::check_installed("osrm", reason = "para calcular dist\u00e2ncias via OSRM")
      r <- osrm::osrmTable(
        src = src,
        dst = destinos_1,
        measure = c("distance", "duration")
      )
      data.frame(
        id_destino = rep(destinos_1$id_destino, each = nrow(src)),
        id_origem  = rep(src$id_origem, times = nrow(destinos_1)),
        distancia_km   = round(as.vector(r$distances) / 1000, 2),
        duracao_horas  = round(as.vector(r$durations) / 60, 2)
      )
    }, error = function(e) {
      n_failed <<- n_failed + 1L
      NULL
    })
    cli::cli_progress_update()
  }

  cli::cli_progress_done()

  if (n_failed > 0L) {
    cli::cli_warn(
      "{n_failed} lote{?s} falhou ao calcular dist\u00e2ncias e foi ignorado{?s}."
    )
  }

  res <- dplyr::bind_rows(results)

  res |>
    dplyr::left_join(origens_1 |> sf::st_drop_geometry(), by = "id_origem") |>
    dplyr::left_join(destinos_1 |> sf::st_drop_geometry(), by = "id_destino") |>
    dplyr::select(-id_origem, -id_destino)
}
