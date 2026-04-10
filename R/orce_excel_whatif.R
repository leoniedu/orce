#' Gera planilha Excel interativa para análise what-if de custos
#'
#' Gera um arquivo `.xlsx` compatível com LibreOffice para análise interativa
#' de atribuições de UPAs a agências. O usuário pode alterar a coluna
#' "Ag. selecionada" e ver os custos recalculados automaticamente via fórmulas.
#'
#' @param resultado Lista retornada por [orce()]. Deve conter
#'   `resultado_ucs_otimo`, `resultado_ucs_jurisdicao`,
#'   `resultado_agencias_otimo`, `resultado_agencias_jurisdicao`.
#' @param distancias_ucs Data frame com distâncias/durações UPA-agência.
#'   Colunas obrigatórias: `uc`, `agencia_codigo`, `distancia_km`,
#'   `duracao_horas`, `diaria_municipio`, `diaria_pernoite`.
#'   Coluna opcional: `municipio_codigo` (necessária para Diária Município).
#' @param ucs Data frame com dados das UPAs. Colunas obrigatórias: `uc`,
#'   `municipio_codigo`, `dias_coleta`, `viagens`, `diaria_valor`.
#'   Colunas opcionais: `municipio_nome`, `entrevistadores_por_uc`.
#' @param agencias Data frame com dados das agências. Colunas obrigatórias:
#'   `agencia_codigo`. Opcionais: `agencia_nome`, `municipio_codigo`,
#'   `municipio_nome`, `diaria_valor`.
#' @param file Caminho do arquivo `.xlsx` de saída.
#' @param params Lista nomeada com parâmetros usados na estimação orce:
#'   `custo_litro_combustivel` (padrão 6), `kml` (padrão 10),
#'   `custo_hora_viagem` (padrão 10).
#'
#' @return Caminho do arquivo (invisível). Efeito colateral: cria o `.xlsx`.
#'
#' @details
#' ## Parâmetros implementados na planilha
#'
#' As fórmulas Excel utilizam apenas três parâmetros escalares, referenciados
#' via named ranges na aba Parâmetros:
#'
#' - `custo_litro_combustivel`: custo por litro de combustível (R$/L)
#' - `kml`: consumo do veículo (km/L)
#' - `custo_hora_viagem`: custo por hora de deslocamento (R$/h)
#'
#' Parâmetros como `adicional_troca_jurisdicao`, `remuneracao_entrevistador`,
#' `dias_treinamento`, `custo_fixo` e restrições de otimização **não são
#' implementados** na planilha. Os custos de jurisdição e otimizada já
#' refletem esses valores; os custos da agência selecionada usam apenas
#' combustível, horas de viagem e diárias.
#'
#' @export
orce_excel_whatif <- function(resultado, distancias_ucs, ucs, agencias, file, params = list()) {
  # --- Validate inputs ---
  checkmate::assert_list(resultado)
  required_results <- c("resultado_ucs_otimo", "resultado_ucs_jurisdicao",
                        "resultado_agencias_otimo", "resultado_agencias_jurisdicao")
  for (nm in required_results) {
    if (is.null(resultado[[nm]])) cli::cli_abort("resultado must contain {.val {nm}}")
  }
  checkmate::assert_data_frame(distancias_ucs)
  checkmate::assert_data_frame(ucs)
  checkmate::assert_data_frame(agencias)
  checkmate::assert_string(file)

  for (col in c("uc", "agencia_codigo", "distancia_km", "duracao_horas",
                "diaria_municipio", "diaria_pernoite")) {
    if (!col %in% names(distancias_ucs)) cli::cli_abort("distancias_ucs must contain column {.val {col}}")
  }
  for (col in c("uc", "municipio_codigo", "dias_coleta", "viagens", "diaria_valor")) {
    if (!col %in% names(ucs)) cli::cli_abort("ucs must contain column {.val {col}}")
  }
  if (!"agencia_codigo" %in% names(agencias)) cli::cli_abort("agencias must contain column {.val agencia_codigo}")

  # --- Default params ---
  p <- list(
    custo_litro_combustivel = params$custo_litro_combustivel %||% 6,
    kml = params$kml %||% 10,
    custo_hora_viagem = params$custo_hora_viagem %||% 10
  )

  # --- Default optional columns ---
  if (!"entrevistadores_por_uc" %in% names(ucs)) ucs$entrevistadores_por_uc <- 1
  if (!"municipio_nome" %in% names(ucs)) ucs$municipio_nome <- ucs$municipio_codigo
  if (!"agencia_nome" %in% names(agencias)) agencias$agencia_nome <- agencias$agencia_codigo
  if (!"municipio_codigo" %in% names(agencias)) agencias$municipio_codigo <- substr(agencias$agencia_codigo, 1, 7)
  if (!"municipio_nome" %in% names(agencias)) agencias$municipio_nome <- agencias$municipio_codigo

  # --- Prepare UPA data ---
  ucs_jur <- resultado$resultado_ucs_otimo |>
    dplyr::select("uc", agencia_otimizada = "agencia_codigo", "agencia_codigo_jurisdicao") |>
    dplyr::distinct(.data$uc, .keep_all = TRUE)

  upa_data <- ucs |>
    dplyr::select("uc", "municipio_codigo", "municipio_nome", "dias_coleta",
                  "viagens", "entrevistadores_por_uc", "diaria_valor") |>
    dplyr::distinct(.data$uc, .keep_all = TRUE) |>
    dplyr::left_join(ucs_jur, by = "uc") |>
    dplyr::rename(agencia_jurisdicao = "agencia_codigo_jurisdicao")

  agency_codes <- sort(unique(agencias$agencia_codigo))
  n_agencies <- length(agency_codes)
  n_upas <- nrow(upa_data)

  wb <- openxlsx2::wb_workbook()
  .write_parametros(wb, p)
  .write_agencias(wb, agencias, agency_codes)
  .write_matrices(wb, distancias_ucs, upa_data, agency_codes)
  .write_upas(wb, upa_data, agency_codes, n_upas, n_agencies)
  .write_resumo(wb, resultado, agencias, agency_codes, n_upas)
  .format_workbook(wb, n_upas, n_agencies, agency_codes)

  openxlsx2::wb_save(wb, file, overwrite = TRUE)
  invisible(file)
}

.write_parametros <- function(wb, p) {
  wb$add_worksheet("Parâmetros")
  labels <- c("Custo litro combustível (R$/L)", "Km por litro (km/L)", "Custo hora viagem (R$/h)")
  values <- c(p$custo_litro_combustivel, p$kml, p$custo_hora_viagem)
  param_names <- c("custo_litro_combustivel", "kml", "custo_hora_viagem")
  param_df <- data.frame(Parâmetro = labels, Valor = values)
  wb$add_data(sheet = "Parâmetros", x = param_df)
  for (i in seq_along(param_names)) {
    wb$add_named_region(sheet = "Parâmetros", dims = paste0("B", i + 1), name = param_names[i])
  }
  wb$freeze_pane(sheet = "Parâmetros", first_row = TRUE)
}

.write_agencias <- function(wb, agencias, agency_codes) {
  wb$add_worksheet("Agências")
  ag_df <- agencias |>
    dplyr::filter(.data$agencia_codigo %in% agency_codes) |>
    dplyr::arrange(.data$agencia_codigo) |>
    dplyr::transmute(
      `Cód. agência` = .data$agencia_codigo,
      `Agência` = .data$agencia_nome,
      `Cód. município` = .data$municipio_codigo,
      `Município` = .data$municipio_nome,
      `Valor diária (R$)` = .data$diaria_valor
    )
  wb$add_data(sheet = "Agências", x = ag_df)
  wb$freeze_pane(sheet = "Agências", first_row = TRUE)
}

.pivot_to_matrix <- function(data, row_col, col_col, value_col) {
  data |>
    dplyr::select(dplyr::all_of(c(row_col, col_col, value_col))) |>
    tidyr::pivot_wider(names_from = dplyr::all_of(col_col), values_from = dplyr::all_of(value_col))
}

.write_matrices <- function(wb, distancias_ucs, upa_data, agency_codes) {
  uc_codes <- upa_data$uc
  dists <- distancias_ucs |>
    dplyr::filter(.data$uc %in% uc_codes, .data$agencia_codigo %in% agency_codes)

  # Sheet 3: Distâncias
  dist_mat <- .pivot_to_matrix(dists, "uc", "agencia_codigo", "distancia_km") |>
    dplyr::select("uc", dplyr::all_of(agency_codes))
  wb$add_worksheet("Distâncias")
  wb$add_data(sheet = "Distâncias", x = dist_mat)
  wb$freeze_pane(sheet = "Distâncias", first_row = TRUE)

  # Sheet 4: Durações
  dur_mat <- .pivot_to_matrix(dists, "uc", "agencia_codigo", "duracao_horas") |>
    dplyr::select("uc", dplyr::all_of(agency_codes))
  wb$add_worksheet("Durações")
  wb$add_data(sheet = "Durações", x = dur_mat)
  wb$freeze_pane(sheet = "Durações", first_row = TRUE)

  # Sheet 5: Diária Município (municipality × agency)
  if (!"municipio_codigo" %in% names(dists)) {
    mun_lookup <- upa_data |> dplyr::select("uc", "municipio_codigo")
    dists <- dists |> dplyr::left_join(mun_lookup, by = "uc")
  }
  dm_data <- dists |>
    dplyr::distinct(.data$municipio_codigo, .data$agencia_codigo, .keep_all = TRUE)
  dm_mat <- .pivot_to_matrix(dm_data, "municipio_codigo", "agencia_codigo", "diaria_municipio") |>
    dplyr::mutate(dplyr::across(-"municipio_codigo", as.integer)) |>
    dplyr::select("municipio_codigo", dplyr::all_of(agency_codes))
  wb$add_worksheet("Diária Município")
  wb$add_data(sheet = "Diária Município", x = dm_mat)
  wb$freeze_pane(sheet = "Diária Município", first_row = TRUE)

  # Sheet 6: Diária Pernoite (UPA × agency)
  dp_mat <- .pivot_to_matrix(dists, "uc", "agencia_codigo", "diaria_pernoite") |>
    dplyr::mutate(dplyr::across(-"uc", as.integer)) |>
    dplyr::select("uc", dplyr::all_of(agency_codes))
  wb$add_worksheet("Diária Pernoite")
  wb$add_data(sheet = "Diária Pernoite", x = dp_mat)
  wb$freeze_pane(sheet = "Diária Pernoite", first_row = TRUE)
}

.write_upas <- function(wb, upa_data, agency_codes, n_upas, n_agencies) {
  wb$add_worksheet("UPAs")
}

.write_resumo <- function(wb, resultado, agencias, agency_codes, n_upas) {
  wb$add_worksheet("Resumo")
}

.format_workbook <- function(wb, n_upas, n_agencies, agency_codes) {
}
