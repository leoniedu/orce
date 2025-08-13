#' @keywords internal
#' Teste da função orce com dados simulados incluindo TSP
#'
#' @param n_agencias Número de agências a criar. Padrão: 10.
#' @param n_ucs Número de UCs a criar. Padrão: 30.
#' @param n_periodos Número de períodos de coleta. Padrão: 2.
#' @param peso_tsp Peso TSP para o teste. Padrão: 0.5.
#' @param solver Solver a usar. Padrão: "cbc".
#'
#' @return Resultado da função orce com dados simulados
#'
#' @export
teste_orce_tsp <- function(n_agencias = 3, n_ucs = 20, n_periodos = 2, peso_tsp = 0.5, solver = "cbc", orce_function=orce::orce, ...) {
  requireNamespace("dplyr")

  # Gerar agências aleatórias
  agencias <- tibble::tibble(
    agencia_codigo = sprintf("AG%04d", 1:n_agencias),
    n_entrevistadores_agencia_max = sample(5:15, n_agencias, replace = TRUE),
    custo_fixo = runif(n_agencias, 1000, 5000),
    diaria_valor = runif(n_agencias, 80, 120),
    lat = runif(n_agencias, -30, -20),
    lon = runif(n_agencias, -60, -40)
  )

  # Gerar UCs aleatórias com múltiplos períodos
  ucs_base <- tibble::tibble(
    uc = sprintf("UC%05d", 1:n_ucs),
    lat = runif(n_ucs, -30, -20),
    lon = runif(n_ucs, -60, -40)
  )

  ucs <- tidyr::expand_grid(
    ucs_base,
    data = sprintf("2024-%02d", 1:n_periodos)
  ) |>
    dplyr::mutate(
      uc = paste0(uc, "_", data),  # Tornar UCs únicos por período
      agencia_codigo = sample(agencias$agencia_codigo, dplyr::n(), replace = TRUE),
      dias_coleta = sample(1:5, dplyr::n(), replace = TRUE),
      viagens = sample(1:3, dplyr::n(), replace = TRUE),
      diaria_valor = sample(agencias$diaria_valor, dplyr::n(), replace = TRUE)
    )

  # Calcular distâncias UC-agência (Euclidiana simplificada)
  distancias_ucs <- tidyr::expand_grid(
    ucs |> dplyr::distinct(uc, lat, lon),
    agencias |> dplyr::select(agencia_codigo, ag_lat = lat, ag_lon = lon)
  ) |>
    dplyr::mutate(
      distancia_km = sqrt((lat - ag_lat)^2 + (lon - ag_lon)^2) * 111, # aprox km
      duracao_horas = distancia_km / 60, # 60 km/h média
      diaria_municipio = distancia_km > 50,
      diaria_pernoite = distancia_km > 150
    ) |>
    dplyr::select(uc, agencia_codigo, distancia_km, duracao_horas, diaria_municipio, diaria_pernoite)

  # Calcular distâncias UC-UC para TSP
  distancias_ucs_ucs <- NULL
  if (peso_tsp > 0) {
    ucs_coords <- ucs |> dplyr::distinct(uc, lat, lon)
    distancias_ucs_ucs <- tidyr::expand_grid(
      ucs_coords |> dplyr::select(uc_orig = uc, lat_orig = lat, lon_orig = lon),
      ucs_coords |> dplyr::select(uc_dest = uc, lat_dest = lat, lon_dest = lon)
    ) |>
      dplyr::filter(uc_orig != uc_dest) |>
      dplyr::mutate(
        distancia_km = sqrt((lat_orig - lat_dest)^2 + (lon_orig - lon_dest)^2) * 111,
        duracao_horas = distancia_km / 60
      ) |>
      dplyr::select(uc_orig, uc_dest, distancia_km, duracao_horas)
  }

  # Calcular distâncias agência-agência
  distancias_agencias <- tidyr::expand_grid(
    agencias |> dplyr::select(agencia_codigo_orig = agencia_codigo, lat_orig = lat, lon_orig = lon),
    agencias |> dplyr::select(agencia_codigo_dest = agencia_codigo, lat_dest = lat, lon_dest = lon)
  ) |>
    dplyr::filter(agencia_codigo_orig != agencia_codigo_dest) |>
    dplyr::mutate(
      distancia_km = sqrt((lat_orig - lat_dest)^2 + (lon_orig - lon_dest)^2) * 111,
      duracao_horas = distancia_km / 60
    ) |>
    dplyr::select(agencia_codigo_orig, agencia_codigo_dest, distancia_km, duracao_horas)

  cat("Testando orce com:", n_agencias, "agências,", n_ucs, "UCs,", n_periodos, "períodos\n")
  cat("peso_tsp =", peso_tsp, "\n")

  # Executar orce
  resultado <- orce_function(
    ucs = ucs,
    agencias = agencias,
    distancias_ucs = distancias_ucs,
    distancias_ucs_ucs = distancias_ucs_ucs,
    distancias_agencias = distancias_agencias,
    dias_coleta_entrevistador_max = 200,
    peso_tsp = peso_tsp,
    solver = solver,
    max_time = 300,
    resultado_completo = TRUE, ...
  )

  # Mostrar resumo dos resultados
  cat("\n=== RESUMO DOS RESULTADOS ===\n")
  cat("Agências ativas:", nrow(resultado$resultado_agencias_otimo), "\n")
  cat("Custo total:", round(attr(resultado, "valor"), 2), "\n")
  cat("Status:", attr(resultado, "solucao_status"), "\n")

  if (!is.null(resultado$rotas_tsp)) {
    cat("\n=== ROTAS TSP ===\n")
    print(resultado$rotas_tsp)
  }

  return(resultado)
}
