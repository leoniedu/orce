#' Calcula o Ponto de Densidade de Unidades Espaciais
#'
#' Calcula o ponto de maior densidade populacional para cada unidade espacial
#' (e.g., setor censitário, município) em um objeto `sf`, com base na coluna
#' de pesos `n` (e.g., número de estabelecimentos).
#'
#' @param cnefe Um objeto `sf` com geometria POINT. Deve conter uma coluna `n`
#'   com o número de estabelecimentos (ou outro peso) e uma coluna com o código
#'   da unidade espacial, cujo nome é especificado em `geoid`.
#' @param geoid Nome da coluna em `cnefe` com o código único da unidade espacial
#'   (e.g., `cod_setor`, `cod_municipio`).
#'
#' @return Um `data.frame` com o código da unidade espacial e as coordenadas
#'   (`lon`, `lat`) do ponto de maior densidade para cada unidade.
#'
#' @details
#' Delega o cálculo de densidade para [pns.zonas::density_point()], que usa
#' estimativa de densidade por kernel gaussiano (pacote `spatstat`) com
#' largura de banda `sigma = max(10% da amplitude, 30 m)`. Unidades com um
#' único ponto são retornadas diretamente.
#'
#' @export
ponto_densidade <- function(cnefe, geoid) {
  if (!inherits(cnefe, "sf")) {
    cli::cli_abort("{.arg cnefe} deve ser um objeto {.cls sf}.")
  }
  if (!"n" %in% names(cnefe)) {
    cli::cli_abort("{.arg cnefe} deve conter uma coluna {.field n}.")
  }
  cnefe |>
    dplyr::select({{ geoid }}, n) |>
    pns.zonas::density_point({{ geoid }}) |>
    add_coordinates() |>
    sf::st_drop_geometry()
}
