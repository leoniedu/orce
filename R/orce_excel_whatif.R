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
#' @param params Lista nomeada com parâmetros usados na estimação orce.
#'   A planilha usa diretamente `custo_litro_combustivel` (padrão 6),
#'   `kml` (padrão 10), `custo_hora_viagem` (padrão 10) e, quando
#'   fornecidos, `dias_coleta_entrevistador_max`,
#'   `diarias_entrevistador_max` e `n_entrevistadores_min` para estimar o
#'   número de entrevistadores na agência selecionada.
#'
#' @return Caminho do arquivo (invisível). Efeito colateral: cria o `.xlsx`.
#'
#' @details
#' ## Parâmetros implementados na planilha
#'
#' As fórmulas Excel utilizam parâmetros escalares referenciados via named
#' ranges na aba Parâmetros:
#'
#' - `custo_litro_combustivel`: custo por litro de combustível (R$/L)
#' - `kml`: consumo do veículo (km/L)
#' - `custo_hora_viagem`: custo por hora de deslocamento (R$/h)
#' - `dias_coleta_entrevistador_max`: capacidade por entrevistador
#' - `diarias_entrevistador_max`: limite de diárias por entrevistador
#' - `n_entrevistadores_min`: mínimo de entrevistadores por agência ativa
#'
#' Os custos de jurisdição e otimizada já refletem custos fixos, treinamento e
#' demais restrições da otimização original. Para a agência selecionada, a
#' planilha recalcula o custo de deslocamento por fórmula e estima o número de
#' entrevistadores a partir dos parâmetros de capacidade quando eles são
#' fornecidos; o custo de treinamento usa o custo por entrevistador presente em
#' `resultado_agencias_*`.
#'
#' @examples
#' \dontrun{
#' # Build minimal synthetic inputs
#' set.seed(1)
#' agencias <- data.frame(
#'   agencia_codigo   = c("2900108", "2900207"),
#'   agencia_nome     = c("Agência Aracaju", "Agência Salvador"),
#'   municipio_codigo = c("2900108", "2900207"),
#'   municipio_nome   = c("Aracaju", "Salvador"),
#'   diaria_valor     = c(335, 335),
#'   custo_fixo       = 0,
#'   n_entrevistadores_agencia_max = 10
#' )
#' ucs <- data.frame(
#'   uc               = c("2900001", "2900002", "2900003"),
#'   municipio_codigo = c("2900108", "2900108", "2900207"),
#'   municipio_nome   = c("Aracaju", "Aracaju", "Salvador"),
#'   agencia_codigo   = c("2900108", "2900108", "2900207"),
#'   dias_coleta      = c(5L, 5L, 5L),
#'   viagens          = c(2L, 2L, 2L),
#'   diaria_valor     = c(335, 335, 335)
#' )
#' distancias_ucs <- expand.grid(
#'   uc             = ucs$uc,
#'   agencia_codigo = agencias$agencia_codigo,
#'   stringsAsFactors = FALSE
#' ) |>
#'   dplyr::mutate(
#'     distancia_km     = c(10, 300, 15, 290, 280, 8),
#'     duracao_horas    = distancia_km / 60,
#'     municipio_codigo = ucs$municipio_codigo[match(uc, ucs$uc)],
#'     diaria_municipio = as.integer(distancia_km > 50),
#'     diaria_pernoite  = as.integer(distancia_km > 150)
#'   )
#'
#' r <- orce(
#'   ucs = ucs, agencias = agencias, distancias_ucs = distancias_ucs,
#'   dias_coleta_entrevistador_max = 14, use_cache = FALSE
#' )
#'
#' out <- tempfile(fileext = ".xlsx")
#' orce_excel_whatif(
#'   resultado      = r,
#'   distancias_ucs = distancias_ucs,
#'   ucs            = ucs,
#'   agencias       = agencias,
#'   file           = out,
#'   params         = list(
#'     custo_litro_combustivel = 7,
#'     kml = 10,
#'     custo_hora_viagem = 10,
#'     dias_coleta_entrevistador_max = 14
#'   )
#' )
#' # Open the file in LibreOffice or Excel to explore the what-if analysis
#' # browseURL(out)
#' }
#'
#' @export
orce_excel_whatif <- function(resultado, distancias_ucs, ucs, agencias, file, params = list()) {
  checkmate::assert_list(resultado)
  required_results <- c(
    "resultado_ucs_otimo",
    "resultado_ucs_jurisdicao",
    "resultado_agencias_otimo",
    "resultado_agencias_jurisdicao"
  )
  for (nm in required_results) {
    if (is.null(resultado[[nm]])) cli::cli_abort("resultado must contain {.val {nm}}")
  }
  checkmate::assert_data_frame(distancias_ucs)
  checkmate::assert_data_frame(ucs)
  checkmate::assert_data_frame(agencias)
  checkmate::assert_string(file)

  for (col in c("uc", "agencia_codigo", "distancia_km", "duracao_horas",
                "diaria_municipio", "diaria_pernoite")) {
    if (!col %in% names(distancias_ucs)) {
      cli::cli_abort("distancias_ucs must contain column {.val {col}}")
    }
  }
  for (col in c("uc", "municipio_codigo", "dias_coleta", "viagens", "diaria_valor")) {
    if (!col %in% names(ucs)) {
      cli::cli_abort("ucs must contain column {.val {col}}")
    }
  }
  if (!"agencia_codigo" %in% names(agencias)) {
    cli::cli_abort("agencias must contain column {.val agencia_codigo}")
  }

  p <- list(
    custo_litro_combustivel = params$custo_litro_combustivel %||% 6,
    kml = params$kml %||% 10,
    custo_hora_viagem = params$custo_hora_viagem %||% 10,
    dias_coleta_entrevistador_max = params$dias_coleta_entrevistador_max %||% NA_real_,
    diarias_entrevistador_max = params$diarias_entrevistador_max %||% Inf,
    n_entrevistadores_min = params$n_entrevistadores_min %||% 1
  )

  if (!"entrevistadores_por_uc" %in% names(ucs)) ucs$entrevistadores_por_uc <- 1
  if (!"municipio_nome" %in% names(ucs)) ucs$municipio_nome <- ucs$municipio_codigo

  agencias_norm <- .normalize_agencias_whatif(agencias, resultado)
  agency_codes <- sort(unique(agencias_norm$agencia_codigo))
  upa_data <- .prepare_upa_data(ucs, resultado, agencias_norm)
  resumo_agencia <- .prepare_resumo_por_agencia(resultado, agencias_norm, agency_codes)
  n_upas <- nrow(upa_data)

  wb <- openxlsx2::wb_workbook()
  .init_workbook_sheets(wb)
  .write_parametros(wb, p)
  .write_agencias(wb, agencias_norm, agency_codes)
  .write_matrices(wb, distancias_ucs, upa_data, agency_codes)
  .write_upas(wb, upa_data, n_upas, length(agency_codes))
  n_resumo_agencia <- .write_resumo_por_agencia(wb, resumo_agencia, upa_data, p)
  .write_resumo_geral(wb, n_resumo_agencia)
  wb <- .format_workbook(wb, n_upas, n_resumo_agencia)

  openxlsx2::wb_save(wb, file, overwrite = TRUE)
  invisible(file)
}

.coalesce_columns <- function(data, cols) {
  cols <- intersect(cols, names(data))
  if (length(cols) == 0L) return(NULL)
  out <- data[[cols[[1]]]]
  if (length(cols) == 1L) return(out)
  for (col in cols[-1L]) {
    out <- dplyr::coalesce(out, data[[col]])
  }
  out
}

.make_agency_selection_labels <- function(agencia_nome, agencia_codigo) {
  agencia_nome <- ifelse(is.na(agencia_nome) | agencia_nome == "", agencia_codigo, agencia_nome)
  duplicated_name <- duplicated(agencia_nome) | duplicated(agencia_nome, fromLast = TRUE)
  ifelse(duplicated_name, paste0(agencia_nome, " (", agencia_codigo, ")"), agencia_nome)
}

.normalize_agencias_whatif <- function(agencias, resultado) {
  agencias <- agencias |>
    dplyr::mutate(agencia_codigo = as.character(.data$agencia_codigo))

  agencia_nome <- .coalesce_columns(agencias, c("agencia_nome.y", "agencia_nome", "agencia_nome.x"))
  if (is.null(agencia_nome)) agencia_nome <- agencias$agencia_codigo

  municipio_codigo <- .coalesce_columns(agencias, c("municipio_codigo.y", "municipio_codigo", "municipio_codigo.x"))
  if (is.null(municipio_codigo)) municipio_codigo <- substr(agencias$agencia_codigo, 1, 7)

  municipio_nome <- .coalesce_columns(agencias, c("municipio_nome.y", "municipio_nome", "municipio_nome.x"))
  if (is.null(municipio_nome)) municipio_nome <- municipio_codigo

  diaria_valor <- .coalesce_columns(agencias, c("diaria_valor"))
  if (is.null(diaria_valor)) diaria_valor <- rep(NA_real_, nrow(agencias))

  treinamento_lookup <- resultado$resultado_agencias_otimo |>
    dplyr::select("agencia_codigo", "custo_treinamento_por_entrevistador") |>
    dplyr::distinct() |>
    dplyr::mutate(agencia_codigo = as.character(.data$agencia_codigo))

  agencias |>
    dplyr::transmute(
      agencia_codigo = as.character(.data$agencia_codigo),
      agencia_nome = as.character(agencia_nome),
      municipio_codigo = as.character(municipio_codigo),
      municipio_nome = as.character(municipio_nome),
      diaria_valor = diaria_valor
    ) |>
    dplyr::left_join(treinamento_lookup, by = "agencia_codigo") |>
    dplyr::mutate(
      custo_treinamento_por_entrevistador = tidyr::replace_na(.data$custo_treinamento_por_entrevistador, 0),
      agencia_selecao = .make_agency_selection_labels(.data$agencia_nome, .data$agencia_codigo)
    ) |>
    dplyr::arrange(.data$agencia_codigo)
}

.prepare_upa_data <- function(ucs, resultado, agencias) {
  ucs_jur <- resultado$resultado_ucs_otimo |>
    dplyr::select("uc", agencia_otimizada = "agencia_codigo", "agencia_codigo_jurisdicao") |>
    dplyr::distinct(.data$uc, .keep_all = TRUE)

  agency_label_lookup <- stats::setNames(agencias$agencia_selecao, agencias$agencia_codigo)
  has_data <- "data" %in% names(ucs)

  base_cols <- c(
    "uc", "municipio_codigo", "municipio_nome", "dias_coleta",
    "viagens", "entrevistadores_por_uc", "diaria_valor"
  )
  if (has_data) base_cols <- c(base_cols, "data")

  upa_data <- ucs |>
    dplyr::select(dplyr::all_of(base_cols)) |>
    dplyr::distinct(.data$uc, .keep_all = TRUE) |>
    dplyr::left_join(ucs_jur, by = "uc") |>
    dplyr::rename(agencia_jurisdicao = "agencia_codigo_jurisdicao")

  period_key <- if (has_data) as.character(upa_data$data) else rep("Total", nrow(upa_data))

  upa_data |>
    dplyr::mutate(
      periodo_key = period_key,
      agencia_jurisdicao_label = unname(agency_label_lookup[.data$agencia_jurisdicao]),
      agencia_otimizada_label = unname(agency_label_lookup[.data$agencia_otimizada]),
      agencia_selecionada_label = .data$agencia_otimizada_label,
      carga_entrevistador = .data$dias_coleta * .data$entrevistadores_por_uc
    ) |>
    dplyr::mutate(
      agencia_jurisdicao_label = dplyr::coalesce(.data$agencia_jurisdicao_label, .data$agencia_jurisdicao),
      agencia_otimizada_label = dplyr::coalesce(.data$agencia_otimizada_label, .data$agencia_otimizada),
      agencia_selecionada_label = dplyr::coalesce(.data$agencia_selecionada_label, .data$agencia_otimizada)
    )
}

.prepare_resumo_por_agencia <- function(resultado, agencias, agency_codes) {
  agg_cols <- c(
    "n_ucs", "entrevistadores", "distancia_total_km", "total_diarias",
    "custo_diarias", "custo_combustivel", "custo_horas_viagem",
    "custo_deslocamento", "custo_treinamento_por_entrevistador"
  )

  r_jur <- resultado$resultado_agencias_jurisdicao |>
    dplyr::mutate(agencia_codigo = as.character(.data$agencia_codigo)) |>
    dplyr::select("agencia_codigo", dplyr::any_of(agg_cols))
  r_ot <- resultado$resultado_agencias_otimo |>
    dplyr::mutate(agencia_codigo = as.character(.data$agencia_codigo)) |>
    dplyr::select("agencia_codigo", dplyr::any_of(agg_cols))

  resumo <- agencias |>
    dplyr::filter(.data$agencia_codigo %in% agency_codes) |>
    dplyr::select("agencia_codigo", "agencia_nome", "custo_treinamento_por_entrevistador") |>
    dplyr::left_join(
      r_jur |> dplyr::rename_with(~ paste0(.x, "_jur"), -"agencia_codigo"),
      by = "agencia_codigo"
    ) |>
    dplyr::left_join(
      r_ot |> dplyr::rename_with(~ paste0(.x, "_ot"), -"agencia_codigo"),
      by = "agencia_codigo"
    )

  for (col in c(
    "entrevistadores_jur",
    "entrevistadores_ot",
    "custo_treinamento_por_entrevistador_jur",
    "custo_treinamento_por_entrevistador_ot"
  )) {
    if (!col %in% names(resumo)) resumo[[col]] <- 0
  }

  resumo |>
    dplyr::mutate(
      dplyr::across(dplyr::where(is.numeric), ~ tidyr::replace_na(.x, 0)),
      custo_treinamento_jur = .data$entrevistadores_jur * .data$custo_treinamento_por_entrevistador_jur,
      custo_treinamento_ot = .data$entrevistadores_ot * .data$custo_treinamento_por_entrevistador_ot
    )
}

.init_workbook_sheets <- function(wb) {
  for (sheet_name in c(
    "Resumo",
    "Resumo por agência",
    "Parâmetros",
    "Agências",
    "Distâncias",
    "Durações",
    "Diária Município",
    "Diária Pernoite",
    "UPAs"
  )) {
    wb$add_worksheet(sheet_name)
  }
}

.write_parametros <- function(wb, p) {
  param_df <- data.frame(
    Parâmetro = c(
      "Custo litro combustível (R$/L)",
      "Km por litro (km/L)",
      "Custo hora viagem (R$/h)",
      "Dias coleta/entrevistador (max)",
      "Diárias/entrevistador (max)",
      "Entrevistadores (min)"
    ),
    Valor = c(
      p$custo_litro_combustivel,
      p$kml,
      p$custo_hora_viagem,
      p$dias_coleta_entrevistador_max,
      if (is.finite(p$diarias_entrevistador_max)) p$diarias_entrevistador_max else NA_real_,
      p$n_entrevistadores_min
    )
  )
  wb$add_data(sheet = "Parâmetros", x = param_df)
  for (i in seq_len(nrow(param_df))) {
    wb$add_named_region(
      sheet = "Parâmetros",
      dims = paste0("B", i + 1L),
      name = c(
        "custo_litro_combustivel",
        "kml",
        "custo_hora_viagem",
        "dias_coleta_entrevistador_max",
        "diarias_entrevistador_max",
        "n_entrevistadores_min"
      )[[i]]
    )
  }
  wb$freeze_pane(sheet = "Parâmetros", first_row = TRUE)
}

.write_agencias <- function(wb, agencias, agency_codes) {
  ag_df <- agencias |>
    dplyr::filter(.data$agencia_codigo %in% agency_codes) |>
    dplyr::arrange(.data$agencia_codigo) |>
    dplyr::transmute(
      `Cód. agência` = .data$agencia_codigo,
      `Agência` = .data$agencia_nome,
      `Cód. município` = .data$municipio_codigo,
      `Município` = .data$municipio_nome,
      `Valor diária (R$)` = .data$diaria_valor,
      `Custo treinamento / entrevistador (R$)` = .data$custo_treinamento_por_entrevistador,
      `Agência seleção` = .data$agencia_selecao
    )
  wb$add_data(sheet = "Agências", x = ag_df)
  if (nrow(ag_df) > 0) {
    wb$add_named_region(
      sheet = "Agências",
      dims = paste0("G2:G", nrow(ag_df) + 1L),
      name = "agencia_selecao_lista"
    )
  }
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

  dist_mat <- .pivot_to_matrix(dists, "uc", "agencia_codigo", "distancia_km") |>
    dplyr::select("uc", dplyr::all_of(agency_codes))
  wb$add_data(sheet = "Distâncias", x = dist_mat)
  wb$freeze_pane(sheet = "Distâncias", first_row = TRUE)

  dur_mat <- .pivot_to_matrix(dists, "uc", "agencia_codigo", "duracao_horas") |>
    dplyr::select("uc", dplyr::all_of(agency_codes))
  wb$add_data(sheet = "Durações", x = dur_mat)
  wb$freeze_pane(sheet = "Durações", first_row = TRUE)

  if (!"municipio_codigo" %in% names(dists)) {
    mun_lookup <- upa_data |> dplyr::select("uc", "municipio_codigo")
    dists <- dists |> dplyr::left_join(mun_lookup, by = "uc")
  }
  dm_data <- dists |>
    dplyr::distinct(.data$municipio_codigo, .data$agencia_codigo, .keep_all = TRUE)
  dm_mat <- .pivot_to_matrix(dm_data, "municipio_codigo", "agencia_codigo", "diaria_municipio") |>
    dplyr::mutate(dplyr::across(-"municipio_codigo", as.integer)) |>
    dplyr::select("municipio_codigo", dplyr::all_of(agency_codes))
  wb$add_data(sheet = "Diária Município", x = dm_mat)
  wb$freeze_pane(sheet = "Diária Município", first_row = TRUE)

  dp_mat <- .pivot_to_matrix(dists, "uc", "agencia_codigo", "diaria_pernoite") |>
    dplyr::mutate(dplyr::across(-"uc", as.integer)) |>
    dplyr::select("uc", dplyr::all_of(agency_codes))
  wb$add_data(sheet = "Diária Pernoite", x = dp_mat)
  wb$freeze_pane(sheet = "Diária Pernoite", first_row = TRUE)
}

.write_upas <- function(wb, upa_data, n_upas, n_agencies) {
  headers <- c(
    "UPA", "Cód. Município", "Município", "Dias coleta",
    "Viagens", "Entrevistadores", "Valor diária (R$)",
    "Ag. jurisdição", "Ag. otimizada", "Ag. selecionada",
    "Cód. ag. jurisdição", "Cód. ag. otimizada", "Cód. ag. selecionada",
    "Custo desloc. jurisdição (R$)",
    "Custo desloc. otimizada (R$)",
    "Custo desloc. selecionada (R$)",
    "Realocada",
    "periodo_key", "carga_entrevistador"
  )
  inter_labels <- c(
    "distancia_km", "duracao_horas", "diaria_municipio",
    "diaria_pernoite", "diaria", "meia_diaria", "trechos",
    "total_diarias", "custo_diarias", "distancia_total_km",
    "custo_combustivel", "custo_horas_viagem"
  )
  for (prefix in c("jur", "oti", "sel")) {
    headers <- c(headers, paste0(prefix, "_", inter_labels))
  }

  wb$add_data(
    sheet = "UPAs",
    x = matrix(headers, nrow = 1L),
    col_names = FALSE,
    start_row = 1,
    start_col = 1
  )

  fixed_df <- data.frame(
    upa = upa_data$uc,
    mun_cod = upa_data$municipio_codigo,
    mun_nome = upa_data$municipio_nome,
    dias_coleta = upa_data$dias_coleta,
    viagens = upa_data$viagens,
    entrevistadores = upa_data$entrevistadores_por_uc,
    diaria_valor = upa_data$diaria_valor,
    ag_jur = upa_data$agencia_jurisdicao_label,
    ag_oti = upa_data$agencia_otimizada_label,
    ag_sel = upa_data$agencia_selecionada_label,
    cod_jur = upa_data$agencia_jurisdicao,
    cod_oti = upa_data$agencia_otimizada,
    stringsAsFactors = FALSE
  )
  wb$add_data(sheet = "UPAs", x = fixed_df, col_names = FALSE, start_row = 2, start_col = 1)

  support_df <- data.frame(
    periodo_key = upa_data$periodo_key,
    carga_entrevistador = upa_data$carga_entrevistador
  )
  wb$add_data(sheet = "UPAs", x = support_df, col_names = FALSE, start_row = 2, start_col = 18)

  rows <- seq_len(n_upas) + 1L
  selected_code_formulas <- paste0(
    "IFERROR(INDEX('Agências'!$A$2:$A$9999,MATCH(J", rows,
    ",'Agências'!$G$2:$G$9999,0)),\"\")"
  )
  wb$add_formula(sheet = "UPAs", x = selected_code_formulas, dims = paste0("M2:M", n_upas + 1L))

  .write_agency_formulas(wb, n_upas, n_agencies, agency_col = 11, hidden_start = 20, cost_col = 14)
  .write_agency_formulas(wb, n_upas, n_agencies, agency_col = 12, hidden_start = 32, cost_col = 15)
  .write_agency_formulas(wb, n_upas, n_agencies, agency_col = 13, hidden_start = 44, cost_col = 16)

  realocada_formulas <- paste0("IF(M", rows, "=\"\",FALSE,M", rows, "<>K", rows, ")")
  wb$add_formula(sheet = "UPAs", x = realocada_formulas, dims = paste0("Q2:Q", n_upas + 1L))
  wb$freeze_pane(sheet = "UPAs", first_row = TRUE)
}

.write_agency_formulas <- function(wb, n_upas, n_agencies, agency_col, hidden_start, cost_col) {
  cl <- openxlsx2::int2col
  h <- function(offset) cl(hidden_start + offset)
  ag <- cl(agency_col)
  last_data_col <- cl(n_agencies + 1L)
  last_upa_row <- n_upas + 1L
  rows <- seq_len(n_upas) + 1L

  upa_cell <- paste0("A", rows)
  mun_cell <- paste0("B", rows)
  ag_cell <- paste0(ag, rows)
  d_cell <- paste0("D", rows)
  e_cell <- paste0("E", rows)
  f_cell <- paste0("F", rows)
  g_cell <- paste0("G", rows)

  dist_f <- paste0(
    "IF(", ag_cell, "=\"\",0,IFERROR(INDEX('Distâncias'!$B$2:$", last_data_col, "$", last_upa_row,
    ",MATCH(", upa_cell, ",'Distâncias'!$A$2:$A$", last_upa_row, ",0)",
    ",MATCH(", ag_cell, ",'Distâncias'!$B$1:$", last_data_col, "$1,0)),0))"
  )
  dur_f <- paste0(
    "IF(", ag_cell, "=\"\",0,IFERROR(INDEX('Durações'!$B$2:$", last_data_col, "$", last_upa_row,
    ",MATCH(", upa_cell, ",'Durações'!$A$2:$A$", last_upa_row, ",0)",
    ",MATCH(", ag_cell, ",'Durações'!$B$1:$", last_data_col, "$1,0)),0))"
  )
  dm_f <- paste0(
    "IF(", ag_cell, "=\"\",FALSE,IFERROR(INDEX('Diária Município'!$B$2:$", last_data_col, "$9999",
    ",MATCH(", mun_cell, ",'Diária Município'!$A$2:$A$9999,0)",
    ",MATCH(", ag_cell, ",'Diária Município'!$B$1:$", last_data_col, "$1,0)),FALSE))"
  )
  dp_f <- paste0(
    "IF(", ag_cell, "=\"\",FALSE,IFERROR(INDEX('Diária Pernoite'!$B$2:$", last_data_col, "$", last_upa_row,
    ",MATCH(", upa_cell, ",'Diária Pernoite'!$A$2:$A$", last_upa_row, ",0)",
    ",MATCH(", ag_cell, ",'Diária Pernoite'!$B$1:$", last_data_col, "$1,0)),FALSE))"
  )
  diaria_f <- paste0("OR(", h(2), rows, ",", h(3), rows, ")")
  meia_f <- paste0("AND(", h(2), rows, ",NOT(", h(3), rows, "))")
  trechos_f <- paste0(
    "IF(AND(", h(4), rows, ",NOT(", h(5), rows, ")),",
    e_cell, "*2,", d_cell, "*2)"
  )
  td_f <- paste0(
    "IF(", h(4), rows, ",",
    "IF(", d_cell, "=0,0,",
    "IF(", h(5), rows, ",", d_cell, "*0.5,",
    "IF(", d_cell, "=1,1.5,", d_cell, "-0.5))),0)*", f_cell
  )
  cd_f <- paste0(h(7), rows, "*", g_cell)
  dtk_f <- paste0(h(6), rows, "*", h(0), rows)
  cc_f <- paste0("(", h(9), rows, "/kml)*custo_litro_combustivel")
  chv_f <- paste0(h(6), rows, "*", h(1), rows, "*custo_hora_viagem")
  cost_f <- paste0(h(8), rows, "+", h(10), rows, "+", h(11), rows)

  wb$add_formula(sheet = "UPAs", x = dist_f, dims = paste0(h(0), "2:", h(0), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = dur_f, dims = paste0(h(1), "2:", h(1), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = dm_f, dims = paste0(h(2), "2:", h(2), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = dp_f, dims = paste0(h(3), "2:", h(3), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = diaria_f, dims = paste0(h(4), "2:", h(4), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = meia_f, dims = paste0(h(5), "2:", h(5), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = trechos_f, dims = paste0(h(6), "2:", h(6), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = td_f, dims = paste0(h(7), "2:", h(7), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = cd_f, dims = paste0(h(8), "2:", h(8), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = dtk_f, dims = paste0(h(9), "2:", h(9), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = cc_f, dims = paste0(h(10), "2:", h(10), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = chv_f, dims = paste0(h(11), "2:", h(11), last_upa_row))
  wb$add_formula(
    sheet = "UPAs",
    x = cost_f,
    dims = paste0(cl(cost_col), "2:", cl(cost_col), last_upa_row)
  )
}

.build_selected_interviewers_formula <- function(summary_row, upa_last_row, period_values, p) {
  if (length(period_values) == 0L) period_values <- "Total"

  active_term <- if (is.finite(p$n_entrevistadores_min) && p$n_entrevistadores_min > 0) {
    paste0("IF(E", summary_row, ">0,n_entrevistadores_min,0)")
  } else {
    "0"
  }

  if (is.finite(p$dias_coleta_entrevistador_max) &&
      !is.na(p$dias_coleta_entrevistador_max) &&
      p$dias_coleta_entrevistador_max > 0) {
    period_terms <- vapply(period_values, function(period_value) {
      period_value <- gsub("\"", "\"\"", as.character(period_value), fixed = TRUE)
      paste0(
        "ROUNDUP(SUMIFS(UPAs!$S$2:$S$", upa_last_row,
        ",UPAs!$M$2:$M$", upa_last_row, ",$A", summary_row,
        ",UPAs!$R$2:$R$", upa_last_row, ",\"", period_value,
        "\")/dias_coleta_entrevistador_max,0)"
      )
    }, character(1))
    diarias_term <- if (is.finite(p$diarias_entrevistador_max)) {
      paste0("ROUNDUP(Q", summary_row, "/diarias_entrevistador_max,0)")
    } else {
      "0"
    }
    return(paste0("MAX(", paste(c(period_terms, diarias_term, active_term, "0"), collapse = ","), ")"))
  }

  fallback <- paste0(
    "SUMIF(UPAs!$M$2:$M$", upa_last_row,
    ",$A", summary_row, ",UPAs!$F$2:$F$", upa_last_row, ")"
  )
  paste0("MAX(", fallback, ",", active_term, ",0)")
}

.write_resumo_por_agencia <- function(wb, resumo_agencia, upa_data, p) {
  n_resumo <- nrow(resumo_agencia)
  upa_last_row <- nrow(upa_data) + 1L
  cl <- openxlsx2::int2col

  resumo_df <- data.frame(
    `Cód. agência` = resumo_agencia$agencia_codigo,
    `Agência` = resumo_agencia$agencia_nome,
    `UPAs jur.` = resumo_agencia$n_ucs_jur,
    `UPAs otim.` = resumo_agencia$n_ucs_ot,
    `UPAs sel.` = NA,
    `Entrevistadores jur.` = resumo_agencia$entrevistadores_jur,
    `Entrevistadores otim.` = resumo_agencia$entrevistadores_ot,
    `Entrevistadores sel.` = NA,
    `Custo treinamento jur. (R$)` = resumo_agencia$custo_treinamento_jur,
    `Custo treinamento otim. (R$)` = resumo_agencia$custo_treinamento_ot,
    `Custo treinamento sel. (R$)` = NA,
    `Km total jur.` = resumo_agencia$distancia_total_km_jur,
    `Km total otim.` = resumo_agencia$distancia_total_km_ot,
    `Km total sel.` = NA,
    `Diárias jur.` = resumo_agencia$total_diarias_jur,
    `Diárias otim.` = resumo_agencia$total_diarias_ot,
    `Diárias sel.` = NA,
    `Custo diárias jur. (R$)` = resumo_agencia$custo_diarias_jur,
    `Custo diárias otim. (R$)` = resumo_agencia$custo_diarias_ot,
    `Custo diárias sel. (R$)` = NA,
    `Custo combust. jur. (R$)` = resumo_agencia$custo_combustivel_jur,
    `Custo combust. otim. (R$)` = resumo_agencia$custo_combustivel_ot,
    `Custo combust. sel. (R$)` = NA,
    `Custo horas viagem jur. (R$)` = resumo_agencia$custo_horas_viagem_jur,
    `Custo horas viagem otim. (R$)` = resumo_agencia$custo_horas_viagem_ot,
    `Custo horas viagem sel. (R$)` = NA,
    `Custo desloc. jur. (R$)` = resumo_agencia$custo_deslocamento_jur,
    `Custo desloc. otim. (R$)` = resumo_agencia$custo_deslocamento_ot,
    `Custo desloc. sel. (R$)` = NA,
    `% aumento custo desloc. sel. vs ótimo` = NA
  )
  wb$add_data(sheet = "Resumo por agência", x = resumo_df)

  rows <- seq_len(n_resumo) + 1L
  selected_code_range <- sprintf("UPAs!$M$2:$M$%d", upa_last_row)
  selected_sum_formula <- function(target_col, upa_col) {
    formulas <- paste0(
      "SUMIF(", selected_code_range, ",$A", rows,
      ",UPAs!$", upa_col, "$2:$", upa_col, "$", upa_last_row, ")"
    )
    wb$add_formula(
      sheet = "Resumo por agência",
      x = formulas,
      dims = paste0(target_col, "2:", target_col, n_resumo + 1L)
    )
  }

  wb$add_formula(
    sheet = "Resumo por agência",
    x = paste0("COUNTIF(", selected_code_range, ",A", rows, ")"),
    dims = paste0("E2:E", n_resumo + 1L)
  )
  wb$add_formula(
    sheet = "Resumo por agência",
    x = vapply(
      rows,
      .build_selected_interviewers_formula,
      character(1),
      upa_last_row = upa_last_row,
      period_values = unique(upa_data$periodo_key),
      p = p
    ),
    dims = paste0("H2:H", n_resumo + 1L)
  )
  wb$add_formula(
    sheet = "Resumo por agência",
    x = paste0(
      "H", rows,
      "*IFERROR(INDEX('Agências'!$F$2:$F$9999,MATCH($A", rows,
      ",'Agências'!$A$2:$A$9999,0)),0)"
    ),
    dims = paste0("K2:K", n_resumo + 1L)
  )
  selected_sum_formula("N", cl(53))
  selected_sum_formula("Q", cl(51))
  selected_sum_formula("T", cl(52))
  selected_sum_formula("W", cl(54))
  selected_sum_formula("Z", cl(55))
  selected_sum_formula("AC", "P")
  wb$add_formula(
    sheet = "Resumo por agência",
    x = paste0(
      "IF(AB", rows, "=0,IF(AC", rows, "=0,0,NA()),(AC", rows, "-AB", rows, ")/AB", rows, ")"
    ),
    dims = paste0("AD2:AD", n_resumo + 1L)
  )

  wb$freeze_pane(sheet = "Resumo por agência", first_row = TRUE)
  n_resumo
}

.write_resumo_geral <- function(wb, n_resumo_agencia) {
  resumo_df <- data.frame(
    Cenário = c("Jurisdição", "Otimizada", "Selecionada"),
    `UPAs` = NA,
    `Entrevistadores` = NA,
    `Custo treinamento (R$)` = NA,
    `Km total` = NA,
    `Diárias` = NA,
    `Custo diárias (R$)` = NA,
    `Custo combust. (R$)` = NA,
    `Custo horas viagem (R$)` = NA,
    `Custo desloc. (R$)` = NA,
    `% custo desloc. vs otim.` = NA
  )
  wb$add_data(sheet = "Resumo", x = resumo_df)

  end_row <- n_resumo_agencia + 1L
  sum_formula <- function(source_col) {
    sprintf("SUM('Resumo por agência'!$%s$2:$%s$%d)", source_col, source_col, end_row)
  }

  column_sets <- list(
    c("C", "F", "I", "L", "O", "R", "U", "X", "AA"),
    c("D", "G", "J", "M", "P", "S", "V", "Y", "AB"),
    c("E", "H", "K", "N", "Q", "T", "W", "Z", "AC")
  )
  target_cols <- c("B", "C", "D", "E", "F", "G", "H", "I", "J")

  for (i in seq_along(column_sets)) {
    row_idx <- i + 1L
    for (j in seq_along(target_cols)) {
      wb$add_formula(
        sheet = "Resumo",
        x = sum_formula(column_sets[[i]][[j]]),
        dims = paste0(target_cols[[j]], row_idx)
      )
    }
  }

  wb$add_formula(sheet = "Resumo", x = "IF(J3=0,IF(J2=0,0,NA()),(J2-J3)/J3)", dims = "K2")
  wb$add_formula(sheet = "Resumo", x = "0", dims = "K3")
  wb$add_formula(sheet = "Resumo", x = "IF(J3=0,IF(J4=0,0,NA()),(J4-J3)/J3)", dims = "K4")
  wb$freeze_pane(sheet = "Resumo", first_row = TRUE)
}

.format_workbook <- function(wb, n_upas, n_resumo_agencia) {
  cl <- openxlsx2::int2col
  upa_last <- n_upas + 1L
  resumo_ag_last <- n_resumo_agencia + 1L
  resumo_last <- 4L

  money_fmt <- "#,##0"
  diarias_fmt <- "#,##0.0"
  percent_fmt <- "0.0%"

  wb$set_col_widths(sheet = "Agências", cols = 7, hidden = TRUE)
  wb$set_col_widths(sheet = "UPAs", cols = 18:55, widths = 8.43, hidden = TRUE)

  wb <- openxlsx2::wb_add_fill(
    wb,
    sheet = "UPAs",
    dims = paste0("J1:J", upa_last),
    color = openxlsx2::wb_color(hex = "FFFFFFCC")
  )
  wb <- openxlsx2::wb_add_data_validation(
    wb,
    sheet = "UPAs",
    dims = paste0("J2:J", upa_last),
    type = "list",
    value = "=agencia_selecao_lista"
  )

  for (mc in c(7L, 14:16, 28:31, 40:43, 52:55)) {
    wb <- openxlsx2::wb_add_numfmt(
      wb,
      sheet = "UPAs",
      dims = paste0(cl(mc), "2:", cl(mc), upa_last),
      numfmt = money_fmt
    )
  }
  for (dc in c(27L, 39L, 51L)) {
    wb <- openxlsx2::wb_add_numfmt(
      wb,
      sheet = "UPAs",
      dims = paste0(cl(dc), "2:", cl(dc), upa_last),
      numfmt = diarias_fmt
    )
  }

  for (col_idx in c(3:14, 18:29)) {
    wb <- openxlsx2::wb_add_numfmt(
      wb,
      sheet = "Resumo por agência",
      dims = paste0(cl(col_idx), "2:", cl(col_idx), resumo_ag_last),
      numfmt = money_fmt
    )
  }
  for (col_idx in 15:17) {
    wb <- openxlsx2::wb_add_numfmt(
      wb,
      sheet = "Resumo por agência",
      dims = paste0(cl(col_idx), "2:", cl(col_idx), resumo_ag_last),
      numfmt = diarias_fmt
    )
  }
  wb <- openxlsx2::wb_add_numfmt(
    wb,
    sheet = "Resumo por agência",
    dims = paste0("AD2:AD", resumo_ag_last),
    numfmt = percent_fmt
  )

  for (col_idx in c(2:5, 7:10)) {
    wb <- openxlsx2::wb_add_numfmt(
      wb,
      sheet = "Resumo",
      dims = paste0(cl(col_idx), "2:", cl(col_idx), resumo_last),
      numfmt = money_fmt
    )
  }
  wb <- openxlsx2::wb_add_numfmt(
    wb,
    sheet = "Resumo",
    dims = paste0("F2:F", resumo_last),
    numfmt = diarias_fmt
  )
  wb <- openxlsx2::wb_add_numfmt(
    wb,
    sheet = "Resumo",
    dims = paste0("K2:K", resumo_last),
    numfmt = percent_fmt
  )

  .set_tab_color <- function(wb, sheet_name, rgb_hex) {
    idx <- which(wb$sheet_names == sheet_name)
    if (length(idx) == 1L) {
      wb$worksheets[[idx]]$sheetPr <-
        paste0('<sheetPr><tabColor rgb="', rgb_hex, '"/></sheetPr>')
    }
  }
  ref_sheets <- c("Parâmetros", "Agências", "Distâncias", "Durações", "Diária Município", "Diária Pernoite")
  for (sheet_name in ref_sheets) .set_tab_color(wb, sheet_name, "FFC0C0C0")
  for (sheet_name in c("Resumo", "Resumo por agência", "UPAs")) .set_tab_color(wb, sheet_name, "FF4472C4")
  wb
}
