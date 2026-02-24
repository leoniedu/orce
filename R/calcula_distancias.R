#' Calcula Distâncias Entre Origens e Destinos
#'
#' Esta função calcula a distância e duração entre conjuntos de pontos de origem e destino usando o serviço OSRM.
#'
#' @param destinos Um objeto `sf` representando os pontos de destino.
#' @param origens Um objeto `sf` representando os pontos de origem.
#' @param nmax Número máximo de pares origem-destino para cada requisição ao serviço OSRM.
#'   Utilizado para evitar o limite de número de pares por requisição. Padrão: 2000.
#'
#' @return Um `data.frame` com as distâncias (em quilômetros) e durações (em horas) entre cada par
#'   de origem e destino, além dos atributos originais de `origens` e `destinos`.
#'
#' @details
#' A função utiliza o pacote `osrm` para calcular as distâncias e durações entre os pontos de origem e
#' destino. O parâmetro `nmax` permite dividir as requisições ao serviço OSRM em lotes menores,
#' evitando o erro "Too many table coordinates" que ocorre quando o número de pares origem-destino é
#' muito grande.
#'
#' @export
calcula_distancias <- function(destinos, origens, nmax=2000) {
  dec_original <- getOption("OutDec")
  options(OutDec = ".")
  checkmate::assert_class(destinos, "sf")
  checkmate::assert_class(origens, "sf")
  stopifnot(all(!is.na(sf::st_coordinates(destinos))))
  stopifnot(all(!is.na(sf::st_coordinates(origens))))
  destinos_1 <- destinos |>
    ungroup() |>
    mutate(id_destino = seq_len(n()))
  origens_1 <- origens |>
    ungroup() |>
    mutate(id_origem = seq_len(n()))

  get_res <- function(src, dst) {
    requireNamespace("osrm")
    res <- osrm::osrmTable(
      src = src,  # Origem
      dst = dst,  # Destino
      measure = c("distance", "duration") # Medidas
    )
    Sys.sleep(runif(1, 1, 10))
    data.frame(
      id_destino = rep(dst$id_destino, each = nrow(src)),
      id_origem = rep(src$id_origem, times = nrow(dst)),
      distancia_km = round(as.vector(res$distances) / 1000, 2),
      duracao_horas = round(as.vector(res$durations) / 60, 2)
    )
  }

  N <- nrow(origens) * nrow(destinos)
  j <- floor(nmax / nrow(origens))
  v <- rep(seq_len(ceiling(N / j)), each = j)
  ## split para não cair no limite de osrmTable
  dest_list <- destinos_1 |>
    mutate(i = v[seq_len(n())]) |>
    dplyr::group_split(i)
  res0 <- dest_list |>
    purrr::map(~ purrr::possibly(get_res, NULL)(src = origens_1, dst = .x), .progress = TRUE)
  res <- res0|>
    bind_rows()
  options(OutDec = dec_original)
  # Mesclando os resultados com os dados originais para remover colunas desnecessárias e retornar o dataset final
  res |>
    left_join(origens_1 |> sf::st_drop_geometry(), by = "id_origem") |>
    left_join(destinos_1 |> sf::st_drop_geometry(), by = "id_destino") |>
    select(-id_origem, -id_destino)
}
