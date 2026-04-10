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

  # --- Headers (row 1) ---
  headers <- c(
    "UPA", "C\u00f3d. Munic\u00edpio", "Munic\u00edpio", "Dias coleta",
    "Viagens", "Entrevistadores", "Valor di\u00e1ria (R$)",
    "Ag. jurisdi\u00e7\u00e3o", "Ag. otimizada", "Ag. selecionada",
    "Nome ag. jurisdi\u00e7\u00e3o", "Nome ag. otimizada", "Nome ag. selecionada",
    "Custo desloc. jurisdi\u00e7\u00e3o (R$)",
    "Custo desloc. otimizada (R$)",
    "Custo desloc. selecionada (R$)",
    "Realocada"
  )
  # Hidden intermediate headers (3 blocks of 12)
  inter_labels <- c("distancia_km", "duracao_horas", "diaria_municipio",
                     "diaria_pernoite", "diaria", "meia_diaria", "trechos",
                     "total_diarias", "custo_diarias", "distancia_total_km",
                     "custo_combustivel", "custo_horas_viagem")
  for (prefix in c("jur", "oti", "sel")) {
    headers <- c(headers, paste0(prefix, "_", inter_labels))
  }
  wb$add_data(sheet = "UPAs", x = matrix(headers, nrow = 1), col_names = FALSE,
              start_row = 1, start_col = 1)

  # --- Fixed data columns (A-J, rows 2..n_upas+1) ---
  fixed_df <- data.frame(
    upa = upa_data$uc,
    mun_cod = upa_data$municipio_codigo,
    mun_nome = upa_data$municipio_nome,
    dias_coleta = upa_data$dias_coleta,
    viagens = upa_data$viagens,
    entrevistadores = upa_data$entrevistadores_por_uc,
    diaria_valor = upa_data$diaria_valor,
    ag_jur = upa_data$agencia_jurisdicao,
    ag_oti = upa_data$agencia_otimizada,
    ag_sel = upa_data$agencia_otimizada,
    stringsAsFactors = FALSE
  )
  wb$add_data(sheet = "UPAs", x = fixed_df, col_names = FALSE,
              start_row = 2, start_col = 1)

  # --- Name lookup formulas (K, L, M = cols 11, 12, 13) ---
  .write_upa_name_formulas(wb, n_upas, agency_col = 8, name_col = 11)
  .write_upa_name_formulas(wb, n_upas, agency_col = 9, name_col = 12)
  .write_upa_name_formulas(wb, n_upas, agency_col = 10, name_col = 13)

  # --- Intermediate + cost formulas for 3 agency variants ---
  .write_agency_formulas(wb, n_upas, n_agencies, agency_col = 8,
                         hidden_start = 18, cost_col = 14)
  .write_agency_formulas(wb, n_upas, n_agencies, agency_col = 9,
                         hidden_start = 30, cost_col = 15)
  .write_agency_formulas(wb, n_upas, n_agencies, agency_col = 10,
                         hidden_start = 42, cost_col = 16)

  # --- Realocada formula (Q = col 17) ---
  for (row in seq_len(n_upas) + 1L) {
    formula <- paste0("J", row, "<>H", row)
    wb$add_formula(sheet = "UPAs", x = formula,
                   dims = paste0("Q", row))
  }

  wb$freeze_pane(sheet = "UPAs", first_row = TRUE)
}

.write_upa_name_formulas <- function(wb, n_upas, agency_col, name_col) {
  ag_letter <- openxlsx2::int2col(agency_col)
  nc <- openxlsx2::int2col(name_col)
  for (row in seq_len(n_upas) + 1L) {
    formula <- paste0(
      "IFERROR(INDEX('Ag\u00eancias'!$B$2:$B$9999,",
      "MATCH(", ag_letter, row, ",'Ag\u00eancias'!$A$2:$A$9999,0)),\"\")"
    )
    wb$add_formula(sheet = "UPAs", x = formula, dims = paste0(nc, row))
  }
}

.write_agency_formulas <- function(wb, n_upas, n_agencies, agency_col, hidden_start, cost_col) {
  h <- function(offset) openxlsx2::int2col(hidden_start + offset)
  ag <- openxlsx2::int2col(agency_col)
  last_data_col <- openxlsx2::int2col(n_agencies + 1L)
  last_upa_row <- n_upas + 1L

  for (row in seq_len(n_upas) + 1L) {
    # Helper refs
    upa_cell <- paste0("A", row)
    mun_cell <- paste0("B", row)
    ag_cell <- paste0(ag, row)
    d_cell <- paste0("D", row)   # dias_coleta
    e_cell <- paste0("E", row)   # viagens
    f_cell <- paste0("F", row)   # entrevistadores
    g_cell <- paste0("G", row)   # diaria_valor

    # col+0: distancia_km (R/AD/AP) INDEX('Distâncias'!...)
    dist_f <- paste0(
      "INDEX('Dist\u00e2ncias'!$B$2:$", last_data_col, "$", last_upa_row,
      ",MATCH(", upa_cell, ",'Dist\u00e2ncias'!$A$2:$A$", last_upa_row, ",0)",
      ",MATCH(", ag_cell, ",'Dist\u00e2ncias'!$B$1:$", last_data_col, "$1,0))"
    )
    wb$add_formula(sheet = "UPAs", x = dist_f,
                   dims = paste0(h(0), row))

    # col+1: duracao_horas INDEX('Durações'!...)
    dur_f <- paste0(
      "INDEX('Dura\u00e7\u00f5es'!$B$2:$", last_data_col, "$", last_upa_row,
      ",MATCH(", upa_cell, ",'Dura\u00e7\u00f5es'!$A$2:$A$", last_upa_row, ",0)",
      ",MATCH(", ag_cell, ",'Dura\u00e7\u00f5es'!$B$1:$", last_data_col, "$1,0))"
    )
    wb$add_formula(sheet = "UPAs", x = dur_f,
                   dims = paste0(h(1), row))

    # col+2: diaria_municipio INDEX('Diária Município'!...)
    dm_f <- paste0(
      "INDEX('Di\u00e1ria Munic\u00edpio'!$B$2:$", last_data_col, "$9999",
      ",MATCH(", mun_cell, ",'Di\u00e1ria Munic\u00edpio'!$A$2:$A$9999,0)",
      ",MATCH(", ag_cell, ",'Di\u00e1ria Munic\u00edpio'!$B$1:$", last_data_col, "$1,0))"
    )
    wb$add_formula(sheet = "UPAs", x = dm_f,
                   dims = paste0(h(2), row))

    # col+3: diaria_pernoite INDEX('Diária Pernoite'!...)
    dp_f <- paste0(
      "INDEX('Di\u00e1ria Pernoite'!$B$2:$", last_data_col, "$", last_upa_row,
      ",MATCH(", upa_cell, ",'Di\u00e1ria Pernoite'!$A$2:$A$", last_upa_row, ",0)",
      ",MATCH(", ag_cell, ",'Di\u00e1ria Pernoite'!$B$1:$", last_data_col, "$1,0))"
    )
    wb$add_formula(sheet = "UPAs", x = dp_f,
                   dims = paste0(h(3), row))

    # col+4: diaria = OR(diaria_municipio, diaria_pernoite)
    diaria_f <- paste0("OR(", h(2), row, ",", h(3), row, ")")
    wb$add_formula(sheet = "UPAs", x = diaria_f,
                   dims = paste0(h(4), row))

    # col+5: meia_diaria = AND(diaria_municipio, NOT(diaria_pernoite))
    meia_f <- paste0("AND(", h(2), row, ",NOT(", h(3), row, "))")
    wb$add_formula(sheet = "UPAs", x = meia_f,
                   dims = paste0(h(5), row))

    # col+6: trechos = IF(AND(diaria, NOT(meia_diaria)), viagens*2, dias_coleta*2)
    trechos_f <- paste0(
      "IF(AND(", h(4), row, ",NOT(", h(5), row, ")),",
      e_cell, "*2,", d_cell, "*2)"
    )
    wb$add_formula(sheet = "UPAs", x = trechos_f,
                   dims = paste0(h(6), row))

    # col+7: total_diarias
    # IF(diaria, IF(dias=0,0,IF(meia_diaria, dias*0.5, IF(dias=1,1.5,dias-0.5))), 0) * entrevistadores
    td_f <- paste0(
      "IF(", h(4), row, ",",
      "IF(", d_cell, "=0,0,",
      "IF(", h(5), row, ",", d_cell, "*0.5,",
      "IF(", d_cell, "=1,1.5,", d_cell, "-0.5))),0)*", f_cell
    )
    wb$add_formula(sheet = "UPAs", x = td_f,
                   dims = paste0(h(7), row))

    # col+8: custo_diarias = total_diarias * diaria_valor
    cd_f <- paste0(h(7), row, "*", g_cell)
    wb$add_formula(sheet = "UPAs", x = cd_f,
                   dims = paste0(h(8), row))

    # col+9: distancia_total_km = trechos * distancia_km
    dtk_f <- paste0(h(6), row, "*", h(0), row)
    wb$add_formula(sheet = "UPAs", x = dtk_f,
                   dims = paste0(h(9), row))

    # col+10: custo_combustivel = (distancia_total_km / kml) * custo_litro_combustivel
    cc_f <- paste0("(", h(9), row, "/kml)*custo_litro_combustivel")
    wb$add_formula(sheet = "UPAs", x = cc_f,
                   dims = paste0(h(10), row))

    # col+11: custo_horas_viagem = trechos * duracao_horas * custo_hora_viagem
    chv_f <- paste0(h(6), row, "*", h(1), row, "*custo_hora_viagem")
    wb$add_formula(sheet = "UPAs", x = chv_f,
                   dims = paste0(h(11), row))
  }

  # --- Visible cost column = custo_diarias + custo_combustivel + custo_horas_viagem ---
  cc <- openxlsx2::int2col(cost_col)
  for (row in seq_len(n_upas) + 1L) {
    cost_f <- paste0(h(8), row, "+", h(10), row, "+", h(11), row)
    wb$add_formula(sheet = "UPAs", x = cost_f, dims = paste0(cc, row))
  }
}

.write_resumo <- function(wb, resultado, agencias, agency_codes, n_upas) {
  wb$add_worksheet("Resumo")
}

.format_workbook <- function(wb, n_upas, n_agencies, agency_codes) {
}
