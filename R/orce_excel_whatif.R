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
#' - `remuneracao_entrevistador`: remuneração fixa por entrevistador (R$); padrão 0
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
  alocacao_hibrido  <- NULL
  ag_ot_m           <- NULL
  ag_ot_f           <- NULL
  hibrido           <- FALSE
  if (!is.null(resultado$res_base)) {
    hibrido          <- TRUE
    alocacao_hibrido <- resultado$alocacao
    ag_ot_m <- resultado$res_masculino$resultado_ucs_otimo |>
      dplyr::select("uc", agencia_otimizada_m = "agencia_codigo") |>
      dplyr::distinct(.data$uc, .keep_all = TRUE)
    ag_ot_f <- resultado$res_feminino$resultado_ucs_otimo |>
      dplyr::select("uc", agencia_otimizada_f = "agencia_codigo") |>
      dplyr::distinct(.data$uc, .keep_all = TRUE)
    resultado <- resultado$res_base
    if (!"entrevistadores_por_uc" %in% names(ucs)) ucs$entrevistadores_por_uc <- 2L
  }
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
    n_entrevistadores_min = params$n_entrevistadores_min %||% 1,
    remuneracao_entrevistador = params$remuneracao_entrevistador %||% 0
  )

  if (!"entrevistadores_por_uc" %in% names(ucs)) ucs$entrevistadores_por_uc <- 1
  if (!"municipio_nome" %in% names(ucs)) ucs$municipio_nome <- ucs$municipio_codigo

  agencias_norm <- .normalize_agencias_whatif(agencias, resultado)
  agency_codes <- sort(unique(agencias_norm$agencia_codigo))
  upa_data <- .prepare_upa_data(ucs, resultado, agencias_norm,
                                 ag_ot_m = ag_ot_m, ag_ot_f = ag_ot_f,
                                 alocacao = alocacao_hibrido)
  resumo_agencia <- .prepare_resumo_por_agencia(resultado, agencias_norm, agency_codes)
  if (hibrido) {
    # Rebuild _ot columns from alocacao (true hybrid optimum with fuel sharing).
    # res_base _ot values use a non-hybrid allocation and may include agencies
    # absent from the M+F allocation.
    resumo_agencia <- .rebuild_hybrid_ot(
      resumo_agencia, upa_data, alocacao_hibrido, agencias_norm, p
    )
  }
  n_upas <- nrow(upa_data)

  wb <- openxlsx2::wb_workbook()
  .init_workbook_sheets(wb, hibrido = hibrido)
  .write_parametros(wb, p)
  .write_agencias(wb, agencias_norm, agency_codes)
  .write_matrices(wb, distancias_ucs, upa_data, agency_codes)
  .write_upas(wb, upa_data, n_upas, length(agency_codes))
  n_resumo_agencia <- .write_resumo_por_agencia(wb, resumo_agencia, upa_data, p)
  .write_resumo_geral(wb, n_resumo_agencia)
  if (hibrido) {
    wb$add_data(
      sheet = "Notas",
      x = data.frame(
        `Atenção` = paste0(
          "Modo híbrido: a planilha usa colunas M e F para cada UC. ",
          "Quando M e F vão à mesma agência (compartilha=TRUE), ",
          "km e combustível são divididos por 2 por entrevistador. ",
          "Tempo de viagem NÃO é dividido (cada entrevistador viaja)."
        ),
        check.names = FALSE
      )
    )
    wb$set_col_widths(sheet = "Notas", cols = 1L, widths = 120)
  }
  wb <- .format_workbook(wb, n_upas, n_resumo_agencia)

  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp), add = TRUE)
  openxlsx2::wb_save(wb, tmp, overwrite = TRUE)
  .verify_workbook(openxlsx2::wb_load(tmp), p)

  file.copy(tmp, file, overwrite = TRUE)
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

  treinamento_lookup <- dplyr::bind_rows(
    resultado$resultado_agencias_otimo |>
      dplyr::select("agencia_codigo", "custo_treinamento_por_entrevistador"),
    resultado$resultado_agencias_jurisdicao |>
      dplyr::select("agencia_codigo", "custo_treinamento_por_entrevistador")
  ) |>
    dplyr::distinct(.data$agencia_codigo, .keep_all = TRUE) |>
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

.prepare_upa_data <- function(ucs, resultado, agencias, ag_ot_m = NULL, ag_ot_f = NULL,
                               alocacao = NULL) {
  ucs_jur <- resultado$resultado_ucs_otimo |>
    dplyr::select("uc", agencia_otimizada = "agencia_codigo", "agencia_codigo_jurisdicao") |>
    dplyr::distinct(.data$uc, .keep_all = TRUE)

  # Per-UC jurisdiction and optimized displacement costs (static R values)
  custo_jur_lookup <- resultado$resultado_ucs_jurisdicao |>
    dplyr::select("uc", custo_jur = "custo_deslocamento") |>
    dplyr::distinct(.data$uc, .keep_all = TRUE)

  custo_oti_lookup <- if (!is.null(alocacao)) {
    # Hybrid: use alocacao which applies fuel-sharing logic correctly
    alocacao |>
      dplyr::select("uc", custo_oti = "custo_deslocamento") |>
      dplyr::distinct(.data$uc, .keep_all = TRUE)
  } else {
    resultado$resultado_ucs_otimo |>
      dplyr::select("uc", custo_oti = "custo_deslocamento") |>
      dplyr::distinct(.data$uc, .keep_all = TRUE)
  }

  agency_label_lookup <- stats::setNames(agencias$agencia_selecao, agencias$agencia_codigo)
  has_data <- "data" %in% names(ucs)
  hibrido <- !is.null(ag_ot_m)

  base_cols <- c("uc", "municipio_codigo", "municipio_nome", "dias_coleta",
                 "viagens", "entrevistadores_por_uc", "diaria_valor")
  if (has_data) base_cols <- c(base_cols, "data")

  upa_data <- ucs |>
    dplyr::select(dplyr::all_of(base_cols)) |>
    dplyr::distinct(.data$uc, .keep_all = TRUE) |>
    dplyr::left_join(ucs_jur, by = "uc") |>
    dplyr::rename(agencia_jurisdicao = "agencia_codigo_jurisdicao") |>
    dplyr::left_join(custo_jur_lookup, by = "uc") |>
    dplyr::left_join(custo_oti_lookup, by = "uc")

  period_key <- if (has_data) as.character(upa_data$data) else rep("Total", nrow(upa_data))

  upa_data <- upa_data |>
    dplyr::mutate(periodo_key = period_key)

  # --- M/F agency columns ---
  if (hibrido) {
    upa_data <- upa_data |>
      dplyr::left_join(ag_ot_m, by = "uc") |>
      dplyr::left_join(ag_ot_f, by = "uc") |>
      dplyr::mutate(
        agencia_otimizada_m = dplyr::coalesce(.data$agencia_otimizada_m, .data$agencia_otimizada),
        agencia_otimizada_f = dplyr::coalesce(.data$agencia_otimizada_f, .data$agencia_otimizada)
      )
  } else {
    upa_data <- upa_data |>
      dplyr::mutate(
        agencia_otimizada_m = .data$agencia_otimizada,
        agencia_otimizada_f = dplyr::if_else(.data$entrevistadores_por_uc >= 2L,
                                              .data$agencia_otimizada, NA_character_)
      )
  }

  mk_label <- function(code) {
    lbl <- unname(agency_label_lookup[code])
    dplyr::coalesce(lbl, code)
  }

  upa_data |>
    dplyr::mutate(
      agencia_jurisdicao_label      = mk_label(.data$agencia_jurisdicao),
      agencia_otimizada_m_label     = mk_label(.data$agencia_otimizada_m),
      agencia_otimizada_f_label     = dplyr::if_else(
        is.na(.data$agencia_otimizada_f), NA_character_,
        mk_label(.data$agencia_otimizada_f)
      ),
      agencia_sel_m_label           = .data$agencia_otimizada_m_label,
      agencia_sel_f_label           = .data$agencia_otimizada_f_label,
      # Each gender has 1 interviewer's workload; F is 0 when ent=1 (non-hybrid)
      carga_m = .data$dias_coleta,
      carga_f = dplyr::if_else(!is.na(.data$agencia_otimizada_f), .data$dias_coleta, 0L)
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

.rebuild_hybrid_ot <- function(resumo_agencia, upa_data, alocacao, agencias_norm, p) {
  cl <- openxlsx2::int2col
  # n_ucs_ot: distinct UCs served by each agency (via M or F allocation)
  nm <- upa_data |>
    dplyr::count(agencia_codigo = as.character(.data$agencia_otimizada_m), name = "n_m")
  nf <- upa_data |>
    dplyr::count(agencia_codigo = as.character(.data$agencia_otimizada_f), name = "n_f")
  nb <- upa_data |>
    dplyr::filter(!is.na(.data$agencia_otimizada_f),
                  .data$agencia_otimizada_m == .data$agencia_otimizada_f) |>
    dplyr::count(agencia_codigo = as.character(.data$agencia_otimizada_m), name = "n_both")
  n_ucs_ot <- nm |>
    dplyr::full_join(nf, by = "agencia_codigo") |>
    dplyr::full_join(nb, by = "agencia_codigo") |>
    dplyr::mutate(
      dplyr::across(dplyr::where(is.numeric), ~ tidyr::replace_na(.x, 0L)),
      n_ucs_ot = .data$n_m + .data$n_f - .data$n_both
    ) |>
    dplyr::select("agencia_codigo", "n_ucs_ot")

  # Per-agency costs: pivot alocacao to per-gender-agency rows, apply sharing logic
  cost_long <- dplyr::bind_rows(
    alocacao |> dplyr::transmute(
      agencia_codigo         = as.character(.data$agencia_codigo_m),
      distancia_total_km     = dplyr::if_else(.data$hibrido, .data$distancia_total_km_m,
                                               .data$distancia_total_km_m / 2),
      custo_combustivel      = dplyr::if_else(.data$hibrido, .data$custo_combustivel_m,
                                               .data$custo_combustivel_m / 2),
      total_diarias          = .data$total_diarias_m,
      custo_diarias          = .data$custo_diarias_m
    ),
    alocacao |> dplyr::transmute(
      agencia_codigo         = as.character(.data$agencia_codigo_f),
      distancia_total_km     = dplyr::if_else(.data$hibrido, .data$distancia_total_km_f,
                                               .data$distancia_total_km_f / 2),
      custo_combustivel      = dplyr::if_else(.data$hibrido, .data$custo_combustivel_f,
                                               .data$custo_combustivel_f / 2),
      total_diarias          = .data$total_diarias_f,
      custo_diarias          = .data$custo_diarias_f
    )
  ) |>
    dplyr::summarise(
      distancia_total_km_ot = sum(.data$distancia_total_km),
      custo_combustivel_ot  = sum(.data$custo_combustivel),
      total_diarias_ot      = sum(.data$total_diarias),
      custo_diarias_ot      = sum(.data$custo_diarias),
      .by = "agencia_codigo"
    )

  # entrevistadores_ot: non-pooled (each gender rounds up separately)
  treinamento_lookup <- agencias_norm |>
    dplyr::select("agencia_codigo", "custo_treinamento_por_entrevistador")

  enti_ot <- if (is.finite(p$dias_coleta_entrevistador_max)) {
    carga_m_ag <- upa_data |>
      dplyr::summarise(carga_m = sum(.data$carga_m), .by = "agencia_otimizada_m") |>
      dplyr::rename(agencia_codigo = "agencia_otimizada_m")
    carga_f_ag <- upa_data |>
      dplyr::filter(!is.na(.data$agencia_otimizada_f)) |>
      dplyr::summarise(carga_f = sum(.data$carga_f), .by = "agencia_otimizada_f") |>
      dplyr::rename(agencia_codigo = "agencia_otimizada_f")
    carga_m_ag |>
      dplyr::full_join(carga_f_ag, by = "agencia_codigo") |>
      dplyr::mutate(
        dplyr::across(dplyr::where(is.numeric), ~ tidyr::replace_na(.x, 0)),
        entrevistadores_ot = pmax(
          ceiling(.data$carga_m / p$dias_coleta_entrevistador_max) +
            ceiling(.data$carga_f / p$dias_coleta_entrevistador_max),
          if (is.finite(p$n_entrevistadores_min)) p$n_entrevistadores_min else 0L
        )
      ) |>
      dplyr::select("agencia_codigo", "entrevistadores_ot")
  } else {
    data.frame(agencia_codigo = character(0), entrevistadores_ot = integer(0))
  }

  combined_ot <- n_ucs_ot |>
    dplyr::left_join(cost_long, by = "agencia_codigo") |>
    dplyr::left_join(enti_ot, by = "agencia_codigo") |>
    dplyr::left_join(treinamento_lookup, by = "agencia_codigo") |>
    dplyr::mutate(
      dplyr::across(dplyr::where(is.numeric), ~ tidyr::replace_na(.x, 0)),
      entrevistadores_ot   = tidyr::replace_na(.data$entrevistadores_ot, 0L),
      custo_treinamento_ot = .data$entrevistadores_ot * .data$custo_treinamento_por_entrevistador
    ) |>
    dplyr::select(-"custo_treinamento_por_entrevistador")

  ot_cols <- grep("_ot$", names(resumo_agencia), value = TRUE)
  resumo_agencia |>
    dplyr::select(-dplyr::all_of(ot_cols)) |>
    dplyr::left_join(combined_ot, by = "agencia_codigo") |>
    dplyr::mutate(dplyr::across(dplyr::where(is.numeric), ~ tidyr::replace_na(.x, 0)))
}

.init_workbook_sheets <- function(wb, hibrido = FALSE) {
  if (hibrido) wb$add_worksheet("Notas")
  for (sheet_name in c(
    "UPAs",
    "Resumo",
    "Resumo por agência",
    "Parâmetros",
    "Agências",
    "Distâncias",
    "Durações",
    "Diária Município",
    "Diária Pernoite"
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
      "Entrevistadores (min)",
      "Remuneração/entrevistador (R$)"
    ),
    Valor = c(
      p$custo_litro_combustivel,
      p$kml,
      p$custo_hora_viagem,
      p$dias_coleta_entrevistador_max,
      if (is.finite(p$diarias_entrevistador_max)) p$diarias_entrevistador_max else NA_real_,
      p$n_entrevistadores_min,
      p$remuneracao_entrevistador
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
        "n_entrevistadores_min",
        "remuneracao_entrevistador"
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
    mun_lookup <- upa_data |> dplyr::select("uc", "municipio_codigo") |> dplyr::distinct(.data$uc, .keep_all = TRUE)
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
  # Unified wide-format layout (hybrid and non-hybrid):
  # Visible  1-16: UPA, Cód.Mun(hidden), Município, Dias, Viagens, Val.Diária,
  #                Ag.jur, Ag.oti.M, Ag.oti.F, Ag.sel.M(J), Ag.sel.F(K),
  #                Custo jur(L,static), Custo oti(M,static), Custo sel(N,formula),
  #                Realocada M(O), Realocada F(P)
  # Hidden support 17-25 (Q-Y): Cód.jur, Cód.oti.M, Cód.oti.F,
  #                Cód.sel.M(T,formula), Cód.sel.F(U,formula),
  #                compartilha(V), periodo_key(W), carga_m(X), carga_f(Y)
  # Hidden sel M   26-37 (Z-AK): dist,dur,dm,dp,diaria,meia,trechos,td,cd,dtk,cc,chv
  # Hidden sel F   38-49 (AL-AW): same for F
  inter_labels <- c("dist", "dur", "dm", "dp", "diaria", "meia",
                    "trechos", "td", "cd", "dtk", "cc", "chv")
  headers <- c(
    "UPA", "Cód. Município", "Município", "Dias coleta", "Viagens", "Valor diária (R$)",
    "Ag. jurisdição", "Ag. otimizada M", "Ag. otimizada F",
    "Ag. selecionada M", "Ag. selecionada F",
    "Custo desloc. jurisdição (R$)", "Custo desloc. otimizada (R$)",
    "Custo desloc. selecionada (R$)", "Realocada M", "Realocada F",
    "Cód. ag. jurisdição", "Cód. ag. otimizada M", "Cód. ag. otimizada F",
    "Cód. ag. selecionada M", "Cód. ag. selecionada F",
    "compartilha", "periodo_key", "carga_m", "carga_f",
    paste0("sel_m_", inter_labels),
    paste0("sel_f_", inter_labels)
  )
  wb$add_data(sheet = "UPAs", x = matrix(headers, nrow = 1L),
              col_names = FALSE, start_row = 1, start_col = 1)

  # Static visible data (cols 1-13: UPA through Custo oti)
  fixed_df <- data.frame(
    upa          = upa_data$uc,
    mun_cod      = upa_data$municipio_codigo,
    mun_nome     = upa_data$municipio_nome,
    dias_coleta  = upa_data$dias_coleta,
    viagens      = upa_data$viagens,
    diaria_valor = upa_data$diaria_valor,
    ag_jur       = upa_data$agencia_jurisdicao_label,
    ag_oti_m     = upa_data$agencia_otimizada_m_label,
    ag_oti_f     = tidyr::replace_na(upa_data$agencia_otimizada_f_label, ""),
    ag_sel_m     = upa_data$agencia_sel_m_label,
    ag_sel_f     = tidyr::replace_na(upa_data$agencia_sel_f_label, ""),
    custo_jur    = upa_data$custo_jur,
    custo_oti    = upa_data$custo_oti,
    stringsAsFactors = FALSE
  )
  wb$add_data(sheet = "UPAs", x = fixed_df, col_names = FALSE, start_row = 2, start_col = 1)

  # Static hidden support (cols 17-19, 23-25)
  codes_df <- data.frame(
    cod_jur   = upa_data$agencia_jurisdicao,
    cod_oti_m = upa_data$agencia_otimizada_m,
    cod_oti_f = tidyr::replace_na(upa_data$agencia_otimizada_f, ""),
    stringsAsFactors = FALSE
  )
  wb$add_data(sheet = "UPAs", x = codes_df, col_names = FALSE, start_row = 2, start_col = 17)

  carga_df <- data.frame(
    periodo_key = upa_data$periodo_key,
    carga_m     = upa_data$carga_m,
    carga_f     = upa_data$carga_f
  )
  wb$add_data(sheet = "UPAs", x = carga_df, col_names = FALSE, start_row = 2, start_col = 23)

  rows <- seq_len(n_upas) + 1L
  last_row <- n_upas + 1L

  # Col T (20): Cód.sel.M from J
  wb$add_formula(sheet = "UPAs",
    x = paste0("IFERROR(INDEX('Agências'!$A$2:$A$9999,MATCH(J", rows,
               ",'Agências'!$G$2:$G$9999,0)),\"\")"),
    dims = paste0("T2:T", last_row))

  # Col U (21): Cód.sel.F from K (empty K → empty code)
  wb$add_formula(sheet = "UPAs",
    x = paste0("IF(K", rows, "=\"\",\"\",IFERROR(INDEX('Agências'!$A$2:$A$9999,MATCH(K", rows,
               ",'Agências'!$G$2:$G$9999,0)),\"\"))"),
    dims = paste0("U2:U", last_row))

  # Col V (22): compartilha — TRUE when both have the same non-empty agency
  wb$add_formula(sheet = "UPAs",
    x = paste0("AND(T", rows, "<>\"\",U", rows, "<>\"\",T", rows, "=U", rows, ")"),
    dims = paste0("V2:V", last_row))

  # Sel M (agency=col20=T, hidden_start=26), Sel F (agency=col21=U, hidden_start=38)
  # compartilha_col=22 halves km/fuel when sharing
  .write_agency_formulas(wb, n_upas, n_agencies, agency_col = 20, hidden_start = 26,
                          compartilha_col = 22)
  .write_agency_formulas(wb, n_upas, n_agencies, agency_col = 21, hidden_start = 38,
                          compartilha_col = 22)

  # Col O (15): Realocada M
  wb$add_formula(sheet = "UPAs",
    x = paste0("IF(T", rows, "=\"\",FALSE,T", rows, "<>R", rows, ")"),
    dims = paste0("O2:O", last_row))

  # Col P (16): Realocada F
  wb$add_formula(sheet = "UPAs",
    x = paste0("IF(U", rows, "=\"\",FALSE,U", rows, "<>S", rows, ")"),
    dims = paste0("P2:P", last_row))

  # Col N (14): Custo sel = M(cd+cc+chv) + F(cd+cc+chv)
  # M: cd=AH(34), cc=AJ(36), chv=AK(37)
  # F: cd=AT(46), cc=AV(48), chv=AW(49)
  cl <- openxlsx2::int2col
  cost_sel_f <- paste0(
    cl(34), rows, "+", cl(36), rows, "+", cl(37), rows, "+",
    cl(46), rows, "+", cl(48), rows, "+", cl(49), rows
  )
  wb$add_formula(sheet = "UPAs", x = cost_sel_f, dims = paste0("N2:N", last_row))

  wb$freeze_pane(sheet = "UPAs", first_row = TRUE)
  wb$add_filter(sheet = "UPAs", rows = 1, cols = 1:16)
}

# agency_col: column index of the agency code (T=20 for M, U=21 for F)
# hidden_start: first column of the 12-col hidden calculation block
# compartilha_col: column index of the compartilha flag (V=22); halves dtk when TRUE
.write_agency_formulas <- function(wb, n_upas, n_agencies, agency_col, hidden_start,
                                    compartilha_col = NULL) {
  cl <- openxlsx2::int2col
  h <- function(offset) cl(hidden_start + offset)
  ag <- cl(agency_col)
  last_data_col <- cl(n_agencies + 1L)
  last_upa_row <- n_upas + 1L
  rows <- seq_len(n_upas) + 1L

  upa_cell <- paste0("A", rows)
  mun_cell <- paste0("B", rows)
  ag_cell  <- paste0(ag, rows)
  d_cell   <- paste0("D", rows)
  e_cell   <- paste0("E", rows)
  f_cell   <- paste0("F", rows)   # Valor diária

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
  diaria_f  <- paste0("OR(", h(2), rows, ",", h(3), rows, ")")
  meia_f    <- paste0("AND(", h(2), rows, ",NOT(", h(3), rows, "))")
  trechos_f <- paste0("IF(AND(", h(4), rows, ",NOT(", h(5), rows, ")),",
                       e_cell, "*2,", d_cell, "*2)")
  # td = n_diarias (1 interviewer per gender, no * entrevistadores)
  td_f <- paste0(
    "IF(", h(4), rows, ",",
    "IF(", d_cell, "=0,0,",
    "IF(", h(5), rows, ",", d_cell, "*0.5,",
    "IF(", d_cell, "=1,1.5,", d_cell, "-0.5))),0)"
  )
  cd_f  <- paste0(h(7), rows, "*", f_cell)
  # dtk: halve km/fuel when sharing the same vehicle
  if (is.null(compartilha_col)) {
    dtk_f <- paste0(h(6), rows, "*", h(0), rows)
  } else {
    comp <- cl(compartilha_col)
    dtk_f <- paste0(h(6), rows, "*", h(0), rows, "*IF(", comp, rows, ",0.5,1)")
  }
  cc_f  <- paste0("(", h(9), rows, "/kml)*custo_litro_combustivel")
  if (is.null(compartilha_col)) {
    chv_f <- paste0(h(6), rows, "*", h(1), rows, "*custo_hora_viagem")
  } else {
    comp <- cl(compartilha_col)
    chv_f <- paste0(h(6), rows, "*", h(1), rows, "*custo_hora_viagem*IF(", comp, rows, ",0.5,1)")
  }

  wb$add_formula(sheet = "UPAs", x = dist_f,    dims = paste0(h(0), "2:", h(0), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = dur_f,     dims = paste0(h(1), "2:", h(1), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = dm_f,      dims = paste0(h(2), "2:", h(2), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = dp_f,      dims = paste0(h(3), "2:", h(3), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = diaria_f,  dims = paste0(h(4), "2:", h(4), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = meia_f,    dims = paste0(h(5), "2:", h(5), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = trechos_f, dims = paste0(h(6), "2:", h(6), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = td_f,      dims = paste0(h(7), "2:", h(7), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = cd_f,      dims = paste0(h(8), "2:", h(8), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = dtk_f,     dims = paste0(h(9), "2:", h(9), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = cc_f,      dims = paste0(h(10), "2:", h(10), last_upa_row))
  wb$add_formula(sheet = "UPAs", x = chv_f,     dims = paste0(h(11), "2:", h(11), last_upa_row))
}

# UPAs layout constants (wide format):
#   T(20)=Cód.sel.M, U(21)=Cód.sel.F, W(23)=periodo_key, X(24)=carga_m, Y(25)=carga_f
.build_selected_interviewers_formula <- function(summary_row, upa_last_row, period_values, p,
                                                  diarias_sel_col) {
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
      pv <- gsub("\"", "\"\"", as.character(period_value), fixed = TRUE)
      # Non-pooled: M and F round up independently
      m_term <- paste0(
        "ROUNDUP(SUMIFS(UPAs!$X$2:$X$", upa_last_row,
        ",UPAs!$T$2:$T$", upa_last_row, ",$A", summary_row,
        ",UPAs!$W$2:$W$", upa_last_row, ",\"", pv, "\"",
        ")/dias_coleta_entrevistador_max,0)"
      )
      f_term <- paste0(
        "ROUNDUP(SUMIFS(UPAs!$Y$2:$Y$", upa_last_row,
        ",UPAs!$U$2:$U$", upa_last_row, ",$A", summary_row,
        ",UPAs!$W$2:$W$", upa_last_row, ",\"", pv, "\"",
        ")/dias_coleta_entrevistador_max,0)"
      )
      paste0(m_term, "+", f_term)
    }, character(1))
    diarias_term <- if (is.finite(p$diarias_entrevistador_max)) {
      paste0("ROUNDUP(", diarias_sel_col, summary_row, "/diarias_entrevistador_max,0)")
    } else {
      "0"
    }
    return(paste0("MAX(", paste(c(period_terms, diarias_term, active_term, "0"), collapse = ","), ")"))
  }

  # Fallback when no max capacity: sum of carga_m (via M code) + carga_f (via F code)
  fallback <- paste0(
    "SUMIF(UPAs!$T$2:$T$", upa_last_row, ",$A", summary_row,
    ",UPAs!$X$2:$X$", upa_last_row, ")",
    "+SUMIF(UPAs!$U$2:$U$", upa_last_row, ",$A", summary_row,
    ",UPAs!$Y$2:$Y$", upa_last_row, ")"
  )
  paste0("MAX(", fallback, ",", active_term, ",0)")
}

.write_resumo_por_agencia <- function(wb, resumo_agencia, upa_data, p) {
  n_resumo <- nrow(resumo_agencia)
  upa_last_row <- nrow(upa_data) + 1L
  cl <- openxlsx2::int2col

  resumo_df <- data.frame(
    `Cód. agência`                  = resumo_agencia$agencia_codigo,
    `Agência`                       = resumo_agencia$agencia_nome,
    `UPAs jur.`                     = resumo_agencia$n_ucs_jur,
    `UPAs otim.`                    = resumo_agencia$n_ucs_ot,
    `UPAs sel.`                     = NA,
    `Entrevistadores jur.`          = resumo_agencia$entrevistadores_jur,
    `Entrevistadores otim.`         = resumo_agencia$entrevistadores_ot,
    `Entrevistadores sel.`          = NA,
    `Custo treinamento jur. (R$)`   = resumo_agencia$custo_treinamento_jur,
    `Custo treinamento otim. (R$)`  = resumo_agencia$custo_treinamento_ot,
    `Custo treinamento sel. (R$)`   = NA,
    `Remuneração jur. (R$)`         = resumo_agencia$entrevistadores_jur * p$remuneracao_entrevistador,
    `Remuneração otim. (R$)`        = resumo_agencia$entrevistadores_ot * p$remuneracao_entrevistador,
    `Remuneração sel. (R$)`         = NA,
    `Km total jur.`                 = resumo_agencia$distancia_total_km_jur,
    `Km total otim.`                = resumo_agencia$distancia_total_km_ot,
    `Km total sel.`                 = NA,
    `Diárias jur.`                  = resumo_agencia$total_diarias_jur,
    `Diárias otim.`                 = resumo_agencia$total_diarias_ot,
    `Diárias sel.`                  = NA,
    `Custo diárias jur. (R$)`       = resumo_agencia$custo_diarias_jur,
    `Custo diárias otim. (R$)`      = resumo_agencia$custo_diarias_ot,
    `Custo diárias sel. (R$)`       = NA,
    `Custo combust. jur. (R$)`      = resumo_agencia$custo_combustivel_jur,
    `Custo combust. otim. (R$)`     = resumo_agencia$custo_combustivel_ot,
    `Custo combust. sel. (R$)`      = NA,
    `Custo total jur. (R$)`         = resumo_agencia$custo_diarias_jur +
      resumo_agencia$custo_combustivel_jur +
      resumo_agencia$entrevistadores_jur * p$remuneracao_entrevistador +
      resumo_agencia$custo_treinamento_jur,
    `Custo total otim. (R$)`        = resumo_agencia$custo_diarias_ot +
      resumo_agencia$custo_combustivel_ot +
      resumo_agencia$entrevistadores_ot * p$remuneracao_entrevistador +
      resumo_agencia$custo_treinamento_ot,
    `Custo total sel. (R$)`         = NA,
    `% aumento custo total sel. vs ótimo` = NA,
    check.names = FALSE
  )
  wb$add_data(sheet = "Resumo por agência", x = resumo_df)

  rows       <- seq_len(n_resumo) + 1L
  last_row   <- n_resumo + 1L
  # Wide layout: T(20)=Cód.sel.M, U(21)=Cód.sel.F
  # Sel M block hidden_start=26: td=AG(33), cd=AH(34), dtk=AI(35), cc=AJ(36)
  # Sel F block hidden_start=38: td=AS(45), cd=AT(46), dtk=AU(47), cc=AV(48)
  t_col <- "UPAs!$T$2:$T$"  # Cód.sel.M
  u_col <- "UPAs!$U$2:$U$"  # Cód.sel.F

  dual_sumif <- function(target_col, m_upa_col, f_upa_col) {
    formulas <- paste0(
      "SUMIF(", t_col, upa_last_row, ",$A", rows,
      ",UPAs!$", m_upa_col, "$2:$", m_upa_col, "$", upa_last_row, ")",
      "+SUMIF(", u_col, upa_last_row, ",$A", rows,
      ",UPAs!$", f_upa_col, "$2:$", f_upa_col, "$", upa_last_row, ")"
    )
    wb$add_formula(sheet = "Resumo por agência", x = formulas,
                   dims = paste0(target_col, "2:", target_col, last_row))
  }

  # E: UPAs sel. — count unique UCs served via M or F
  wb$add_formula(
    sheet = "Resumo por agência",
    x = paste0(
      "COUNTIF(", t_col, upa_last_row, ",A", rows, ")",
      "+COUNTIF(", u_col, upa_last_row, ",A", rows, ")",
      "-COUNTIFS(", t_col, upa_last_row, ",A", rows,
      ",", u_col, upa_last_row, ",A", rows, ")"
    ),
    dims = paste0("E2:E", last_row)
  )

  # H: Entrevistadores sel. (non-pooled M+F ROUNDUP)
  wb$add_formula(
    sheet = "Resumo por agência",
    x = vapply(rows, .build_selected_interviewers_formula, character(1),
               upa_last_row = upa_last_row,
               period_values = unique(upa_data$periodo_key),
               p = p,
               diarias_sel_col = "T"),
    dims = paste0("H2:H", last_row)
  )

  # K: Custo treinamento sel.
  wb$add_formula(
    sheet = "Resumo por agência",
    x = paste0("H", rows, "*IFERROR(INDEX('Agências'!$F$2:$F$9999,MATCH($A", rows,
               ",'Agências'!$A$2:$A$9999,0)),0)"),
    dims = paste0("K2:K", last_row)
  )
  # N: Remuneração sel.
  wb$add_formula(sheet = "Resumo por agência",
                 x = paste0("H", rows, "*remuneracao_entrevistador"),
                 dims = paste0("N2:N", last_row))

  # Q: Km total sel.        — AI(35)=dtk_m, AU(47)=dtk_f
  dual_sumif("Q", cl(35), cl(47))
  # T: Diárias sel.         — AG(33)=td_m,  AS(45)=td_f
  dual_sumif("T", cl(33), cl(45))
  # W: Custo diárias sel.   — AH(34)=cd_m,  AT(46)=cd_f
  dual_sumif("W", cl(34), cl(46))
  # Z: Custo combust. sel.  — AJ(36)=cc_m,  AV(48)=cc_f
  dual_sumif("Z", cl(36), cl(48))

  wb$add_formula(sheet = "Resumo por agência",
                 x = paste0("W", rows, "+Z", rows, "+N", rows, "+K", rows),
                 dims = paste0("AC2:AC", last_row))
  wb$add_formula(
    sheet = "Resumo por agência",
    x = paste0("IF(AB", rows, "=0,IF(AC", rows, "=0,0,NA()),(AC", rows,
               "-AB", rows, ")/AB", rows, ")"),
    dims = paste0("AD2:AD", last_row)
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
    `Remuneração (R$)` = NA,
    `Km total` = NA,
    `Diárias` = NA,
    `Custo diárias (R$)` = NA,
    `Custo combust. (R$)` = NA,
    `Custo total (R$)` = NA,
    `% custo total sel. vs otim.` = NA,
    check.names = FALSE
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
  # Wide format: col 2 (Cód.Mun), cols 17-49 (support + hidden formula blocks)
  wb$set_col_widths(sheet = "UPAs", cols = c(2L, 17:49), widths = 8.43, hidden = TRUE)

  for (sel_col in c("J1:J", "K1:K")) {
    wb <- openxlsx2::wb_add_fill(
      wb, sheet = "UPAs",
      dims = paste0(sel_col, upa_last),
      color = openxlsx2::wb_color(hex = "FFFFFFCC")
    )
    wb <- openxlsx2::wb_add_data_validation(
      wb, sheet = "UPAs",
      dims = paste0(sub("1:", "2:", sel_col), upa_last),
      type = "list",
      value = "=agencia_selecao_lista"
    )
  }

  # Money: Valor diária(6), Custo jur/oti/sel(12-14), hidden cd/cc/chv for M(34,36,37) and F(46,48,49)
  for (mc in c(6L, 12:14, 34L, 36L, 37L, 46L, 48L, 49L)) {
    wb <- openxlsx2::wb_add_numfmt(wb, sheet = "UPAs",
      dims = paste0(cl(mc), "2:", cl(mc), upa_last), numfmt = money_fmt)
  }
  # Diárias: td_m(33), td_f(45)
  for (dc in c(33L, 45L)) {
    wb <- openxlsx2::wb_add_numfmt(wb, sheet = "UPAs",
      dims = paste0(cl(dc), "2:", cl(dc), upa_last), numfmt = diarias_fmt)
  }

  # Resumo por agência: cols 3-17 (C:Q = UPAs/Entrev/Trein/Remuner/Km),
  #   21-29 (U:AC = CustoDiár/CustoComb/CustoTotal)
  for (col_idx in c(3:17, 21:29)) {
    wb <- openxlsx2::wb_add_numfmt(
      wb,
      sheet = "Resumo por agência",
      dims = paste0(cl(col_idx), "2:", cl(col_idx), resumo_ag_last),
      numfmt = money_fmt
    )
  }
  # Diárias: cols 18:20 (R:T)
  for (col_idx in 18:20) {
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

  # Resumo: B:F (UPAs/Entrev/Trein/Remuner/Km) + H:J (CustoDiár/CustoComb/CustoTotal)
  for (col_idx in c(2:6, 8:10)) {
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
    dims = paste0("G2:G", resumo_last),
    numfmt = diarias_fmt
  )
  wb <- openxlsx2::wb_add_numfmt(
    wb,
    sheet = "Resumo",
    dims = paste0("K2:K", resumo_last),
    numfmt = percent_fmt
  )

  for (sheet_name in c("Resumo", "Resumo por agência", "Parâmetros", "Agências")) {
    wb$set_col_widths(sheet = sheet_name, cols = seq_len(30L), widths = "auto")
  }
  # UPAs: auto-width visible cols only (col 2 and 17+ are hidden)
  wb$set_col_widths(sheet = "UPAs", cols = c(1L, 3:16L), widths = "auto")

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

.verify_workbook <- function(wb, p) {
  ag_f <- openxlsx2::wb_to_df(wb, sheet = "Resumo por agência",
                               show_formula = TRUE, check_names = FALSE)
  if (nrow(ag_f) == 0L) return(invisible(NULL))

  check <- function(col, pattern, desc) {
    vals <- ag_f[[col]]
    if (is.null(vals)) cli::cli_abort("Coluna {.val {col}} ausente em 'Resumo por agência'.")
    bad <- !grepl(pattern, vals, perl = TRUE)
    if (any(bad, na.rm = TRUE)) {
      cli::cli_abort(c(
        "Fórmula inesperada em {.val {col}} (linha {which(bad)[[1]] + 1L}).",
        "i" = "Esperado padrão: {.code {pattern}}",
        "x" = "Encontrado: {.code {vals[bad][[1]]}}"
      ))
    }
  }

  check("UPAs sel.",                         "^COUNTIF\\(",           "COUNTIF for UPAs sel.")
  check("Entrevistadores sel.",              "^MAX\\(",               "MAX for Entrevistadores sel.")
  check("Custo treinamento sel. (R$)",       "^H[0-9]+\\*IFERROR\\(", "H*IFERROR for treinamento sel.")
  check("Remuneração sel. (R$)",             "^H[0-9]+\\*remuneracao_entrevistador$",
        "H*remuneracao_entrevistador for remuneração sel.")
  check("Diárias sel.",                      "^SUMIF\\(",             "SUMIF for Diárias sel.")
  check("Custo diárias sel. (R$)",           "^SUMIF\\(",             "SUMIF for Custo diárias sel.")
  check("Custo combust. sel. (R$)",          "^SUMIF\\(",             "SUMIF for Custo combust. sel.")
  check("Custo total sel. (R$)",             "^W[0-9]+\\+Z",          "W+Z+... for Custo total sel.")
  check("% aumento custo total sel. vs ótimo", "^IF\\(AB",            "IF(AB for % aumento")

  if (is.finite(p$diarias_entrevistador_max)) {
    vals <- ag_f[["Entrevistadores sel."]]
    if (any(grepl("ROUNDUP\\(Q[0-9]+/diarias_entrevistador_max", vals, perl = TRUE))) {
      cli::cli_abort(c(
        "Coluna errada no termo de diárias de {.val Entrevistadores sel.}.",
        "i" = "A fórmula referencia {.code Q} (Km total sel.) em vez de {.code T} (Diárias sel.).",
        "x" = "Isso causaria superdimensionamento massivo de entrevistadores."
      ))
    }
    if (!any(grepl("ROUNDUP\\(T[0-9]+/diarias_entrevistador_max", vals, perl = TRUE))) {
      cli::cli_abort(
        "Esperado {.code ROUNDUP(T.../diarias_entrevistador_max)} em {.val Entrevistadores sel.} mas não encontrado."
      )
    }
  }

  invisible(NULL)
}
