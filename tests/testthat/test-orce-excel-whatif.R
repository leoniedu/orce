fixture <- readRDS(test_path("fixtures", "test-orce-data.rds"))

params_default <- list(
  custo_litro_combustivel = 6,
  kml = 10,
  custo_hora_viagem = 10,
  dias_coleta_entrevistador_max = 14,
  diarias_entrevistador_max = Inf,
  n_entrevistadores_min = 1
)

resultado_default <- orce(
  ucs = fixture$ucs,
  agencias = fixture$agencias,
  distancias_ucs = fixture$dists,
  dias_coleta_entrevistador_max = params_default$dias_coleta_entrevistador_max,
  custo_litro_combustivel = params_default$custo_litro_combustivel,
  kml = params_default$kml,
  custo_hora_viagem = params_default$custo_hora_viagem,
  use_cache = FALSE
)

ag_default <- fixture$agencias |>
  dplyr::mutate(
    agencia_nome = paste("Ag", agencia_codigo),
    municipio_codigo = substr(agencia_codigo, 1, 7),
    municipio_nome = paste("Mun", substr(agencia_codigo, 1, 7))
  )

uc_default <- fixture$ucs |>
  dplyr::mutate(
    municipio_nome = paste("Mun", municipio_codigo),
    entrevistadores_por_uc = 1L
  )

build_whatif_wb <- function(agencias = ag_default, params = params_default) {
  out <- tempfile(fileext = ".xlsx")
  orce_excel_whatif(
    resultado = resultado_default,
    distancias_ucs = fixture$dists,
    ucs = uc_default,
    agencias = agencias,
    file = out,
    params = params
  )
  list(
    out = out,
    wb = openxlsx2::wb_load(out)
  )
}

read_sheet <- function(wb, sheet, show_formula = FALSE) {
  openxlsx2::wb_to_df(
    wb,
    sheet = sheet,
    col_names = TRUE,
    show_formula = show_formula,
    check_names = FALSE
  )
}

sheet_col <- function(df, label) {
  if (label %in% names(df)) return(df[[label]])
  alt <- make.names(label)
  if (alt %in% names(df)) return(df[[alt]])
  stop("Column not found: ", label, call. = FALSE)
}

read_sheet_xml <- function(path, sheet_index) {
  paste(
    readLines(unz(path, paste0("xl/worksheets/sheet", sheet_index, ".xml")), warn = FALSE),
    collapse = ""
  )
}

test_that("orce_excel_whatif creates file with the new sheet order", {
  ctx <- build_whatif_wb()

  expect_true(file.exists(ctx$out))
  expect_equal(
    unname(ctx$wb$get_sheet_names()),
    c(
      "UPAs",
      "Resumo",
      "Resumo por agência",
      "Parâmetros",
      "Agências",
      "Distâncias",
      "Durações",
      "Diária Município",
      "Diária Pernoite"
    )
  )
})

test_that(".pivot_to_matrix creates correct wide matrix", {
  long <- data.frame(
    row_id = c("A", "A", "B", "B"),
    col_id = c("X", "Y", "X", "Y"),
    value = c(1, 2, 3, 4)
  )

  wide <- orce:::.pivot_to_matrix(long, "row_id", "col_id", "value")

  expect_equal(nrow(wide), 2)
  expect_equal(ncol(wide), 3)
  expect_equal(wide$X, c(1, 3))
  expect_equal(wide$Y, c(2, 4))
})

test_that("matrix sheets keep the expected dimensions", {
  ctx <- build_whatif_wb()

  dist_df <- read_sheet(ctx$wb, "Distâncias")
  dm_df <- read_sheet(ctx$wb, "Diária Município")

  expect_equal(nrow(dist_df), dplyr::n_distinct(uc_default$uc))
  expect_equal(nrow(dm_df), dplyr::n_distinct(uc_default$municipio_codigo))
})

test_that("UPAs sheet uses agency names for selection and formulas for derived codes", {
  ctx <- build_whatif_wb()
  upas <- read_sheet(ctx$wb, "UPAs")
  upas_formulas <- read_sheet(ctx$wb, "UPAs", show_formula = TRUE)

  expect_true(all(c(
    "Ag. selecionada M",
    "Cód. ag. selecionada M",
    "Custo desloc. selecionada (R$)",
    "Realocada M"
  ) %in% names(upas_formulas)))

  expect_equal(sheet_col(upas, "Ag. selecionada M"), sheet_col(upas, "Ag. otimizada M"))
  expect_false(any(grepl("^[0-9]+$", sheet_col(upas, "Ag. selecionada M"))))
  expect_true(all(grepl("INDEX\\('Agências'!\\$A\\$2", sheet_col(upas_formulas, "Cód. ag. selecionada M"))))
  expect_true(all(grepl("\\+", sheet_col(upas_formulas, "Custo desloc. selecionada (R$)"))))
  expect_true(all(grepl("IF\\(T", sheet_col(upas_formulas, "Realocada M"))))
})

test_that("UPAs worksheet validates the selected agency by name (both M and F cols)", {
  ctx <- build_whatif_wb()
  upas_xml <- read_sheet_xml(ctx$out, 1)

  # Data validation list should appear for both J (sel M) and K (sel F)
  matches <- gregexpr("<formula1>=agencia_selecao_lista</formula1>", upas_xml, fixed = TRUE)
  expect_gte(length(regmatches(upas_xml, matches)[[1]]), 2L)
})

test_that("Resumo por agência keeps static totals and exposes the new selected formulas", {
  ctx <- build_whatif_wb()
  resumo_ag <- read_sheet(ctx$wb, "Resumo por agência")
  resumo_ag_formulas <- read_sheet(ctx$wb, "Resumo por agência", show_formula = TRUE)

  expect_equal(nrow(resumo_ag), dplyr::n_distinct(ag_default$agencia_codigo))
  expect_true(all(c(
    "Entrevistadores jur.",
    "Entrevistadores sel.",
    "Custo treinamento jur. (R$)",
    "Custo treinamento sel. (R$)",
    "Remuneração jur. (R$)",
    "Remuneração sel. (R$)",
    "Custo total jur. (R$)",
    "Custo total sel. (R$)",
    "% aumento custo total sel. vs ótimo"
  ) %in% names(resumo_ag)))

  expect_equal(
    sum(sheet_col(resumo_ag, "UPAs jur."), na.rm = TRUE),
    sum(resultado_default$resultado_agencias_jurisdicao$n_ucs)
  )
  expect_equal(
    sum(sheet_col(resumo_ag, "Entrevistadores jur."), na.rm = TRUE),
    sum(resultado_default$resultado_agencias_jurisdicao$entrevistadores)
  )
  expect_equal(
    sum(sheet_col(resumo_ag, "Custo treinamento jur. (R$)"), na.rm = TRUE),
    sum(
      resultado_default$resultado_agencias_jurisdicao$entrevistadores *
        resultado_default$resultado_agencias_jurisdicao$custo_treinamento_por_entrevistador
    ),
    tolerance = 0.01
  )
  expect_true(all(grepl("^COUNTIF\\(", sheet_col(resumo_ag_formulas, "UPAs sel."))))
  expect_true(all(grepl("^MAX\\(", sheet_col(resumo_ag_formulas, "Entrevistadores sel."))))
  expect_true(all(grepl("^H[0-9]+\\*IFERROR\\(", sheet_col(resumo_ag_formulas, "Custo treinamento sel. (R$)"))))
  expect_true(all(grepl("^IF\\(AB", sheet_col(resumo_ag_formulas, "% aumento custo total sel. vs ótimo"))))
  expect_true(all(grepl("^H[0-9]+\\*remuneracao_entrevistador", sheet_col(resumo_ag_formulas, "Remuneração sel. (R$)"))))
  expect_true(all(grepl("^W[0-9]+\\+Z", sheet_col(resumo_ag_formulas, "Custo total sel. (R$)"))))
  # Dual-SUMIF: selecionada costs reference both M (T col) and F (U col) codes
  expect_true(all(grepl("SUMIF.*\\$T\\$.*SUMIF.*\\$U\\$", sheet_col(resumo_ag_formulas, "Diárias sel."))))
})

test_that("Resumo sheet summarizes the three scenarios with formulas over Resumo por agência", {
  ctx <- build_whatif_wb()
  resumo <- read_sheet(ctx$wb, "Resumo", show_formula = TRUE)

  expect_equal(sheet_col(resumo, "Cenário"), c("Jurisdição", "Otimizada", "Selecionada"))
  expect_true(all(!grepl("'Resumo por agência'!", sheet_col(resumo, "UPAs"), fixed = TRUE)),
              label = "UPAs totals come from R (static), not SUM over per-agency counts")
  expect_true(all(grepl("'Resumo por agência'!", sheet_col(resumo, "Custo total (R$)"), fixed = TRUE)))
  expect_equal(sheet_col(resumo, "% custo total sel. vs otim.")[[2]], "0")
})

test_that("diarias_entrevistador_max formula references Diárias sel. column (T), not Km total (Q)", {
  ctx <- build_whatif_wb(params = list(
    custo_litro_combustivel = 7,
    kml = 10,
    custo_hora_viagem = 10,
    dias_coleta_entrevistador_max = 14,
    diarias_entrevistador_max = 40
  ))
  resumo_ag_formulas <- read_sheet(ctx$wb, "Resumo por agência", show_formula = TRUE)
  entrev_formulas <- sheet_col(resumo_ag_formulas, "Entrevistadores sel.")

  expect_true(all(grepl("diarias_entrevistador_max", entrev_formulas, fixed = TRUE)))
  # Must reference the "Diárias sel." column (T), not "Km total sel." (Q)
  expect_true(all(grepl("ROUNDUP\\(T[0-9]+/diarias_entrevistador_max", entrev_formulas)))
  expect_false(any(grepl("ROUNDUP\\(Q[0-9]+/diarias_entrevistador_max", entrev_formulas)))
})

test_that("Parâmetros sheet includes transport and staffing parameters", {
  ctx <- build_whatif_wb()
  params_df <- read_sheet(ctx$wb, "Parâmetros")
  vals <- stats::setNames(as.numeric(sheet_col(params_df, "Valor")), sheet_col(params_df, "Parâmetro"))
  resumo_ag_formulas <- read_sheet(ctx$wb, "Resumo por agência", show_formula = TRUE)

  expect_equal(vals[["Custo litro combustível (R$/L)"]], 6)
  expect_equal(vals[["Km por litro (km/L)"]], 10)
  expect_equal(vals[["Custo hora viagem (R$/h)"]], 10)
  expect_equal(vals[["Dias coleta/entrevistador (max)"]], 14)
  expect_true(is.infinite(vals[["Diárias/entrevistador (max)"]]) || is.na(vals[["Diárias/entrevistador (max)"]]))
  expect_equal(vals[["Entrevistadores (min)"]], 1)
  expect_true(all(grepl("dias_coleta_entrevistador_max", sheet_col(resumo_ag_formulas, "Entrevistadores sel."), fixed = TRUE)))
})

test_that("Agências sheet prefers agency names when x/y columns are present", {
  ag_bug <- fixture$agencias |>
    dplyr::mutate(
      agencia_nome.x = agencia_codigo,
      agencia_nome.y = paste("Ag", agencia_codigo),
      municipio_codigo = substr(agencia_codigo, 1, 7),
      municipio_nome = paste("Mun", substr(agencia_codigo, 1, 7))
    ) |>
    dplyr::select(-dplyr::any_of("agencia_nome"))

  ctx <- build_whatif_wb(agencias = ag_bug)
  ag_sheet <- read_sheet(ctx$wb, "Agências")

  expect_equal(sheet_col(ag_sheet, "Agência"), paste("Ag", ag_bug$agencia_codigo))
})

test_that("Entrevistadores sel. equals Entrevistadores otim. at initial state", {
  # At initial state selected == optimized. Simulate the non-pooled formula in R.
  # Wide format: M and F each have their own carga column (carga_m, carga_f)
  # and agency code columns (Cód. ag. otimizada M, Cód. ag. otimizada F).
  verify_entrev <- function(params_test, resultado_test = resultado_default,
                             ucs_test = uc_default) {
    out <- tempfile(fileext = ".xlsx")
    orce_excel_whatif(resultado = resultado_test, distancias_ucs = fixture$dists,
                      ucs = ucs_test, agencias = ag_default, file = out, params = params_test)
    wb      <- openxlsx2::wb_load(out)
    resumo  <- read_sheet(wb, "Resumo por agência")
    upas    <- read_sheet(wb, "UPAs")

    entrev_otim <- sheet_col(resumo, "Entrevistadores otim.")
    ag_codes    <- sheet_col(resumo, "Cód. agência")
    cod_m       <- sheet_col(upas, "Cód. ag. otimizada M")
    cod_f       <- sheet_col(upas, "Cód. ag. otimizada F")
    carga_m     <- sheet_col(upas, "carga_m")
    carga_f     <- sheet_col(upas, "carga_f")
    periodo     <- sheet_col(upas, "periodo_key")
    diarias     <- sheet_col(resumo, "Diárias otim.")
    max_dias    <- params_test$dias_coleta_entrevistador_max

    entrev_formula <- vapply(seq_along(ag_codes), function(idx) {
      ag   <- ag_codes[idx]
      mask_m <- !is.na(cod_m) & cod_m == ag
      mask_f <- !is.na(cod_f) & cod_f == ag
      if (!any(mask_m) && !any(mask_f)) return(0)
      periods <- unique(c(periodo[mask_m], periodo[mask_f]))
      period_terms <- vapply(periods, function(pv) {
        ceiling(sum(carga_m[mask_m & periodo == pv], na.rm = TRUE) / max_dias) +
          ceiling(sum(carga_f[mask_f & periodo == pv], na.rm = TRUE) / max_dias)
      }, numeric(1))
      diarias_term <- if (is.finite(params_test$diarias_entrevistador_max)) {
        ceiling(diarias[idx] / params_test$diarias_entrevistador_max)
      } else 0
      n_min_term <- params_test$n_entrevistadores_min * (any(mask_m) || any(mask_f))
      max(max(period_terms), diarias_term, n_min_term, 0)
    }, numeric(1))

    expect_equal(unname(entrev_formula), entrev_otim,
                 label = paste("params:", paste(names(params_test), params_test,
                                                sep = "=", collapse = ", ")))
  }

  verify_entrev(params_default)

  params2 <- list(
    custo_litro_combustivel = 6, kml = 10, custo_hora_viagem = 10,
    dias_coleta_entrevistador_max = 14, diarias_entrevistador_max = 40,
    n_entrevistadores_min = 2
  )
  res2 <- orce(
    ucs = fixture$ucs, agencias = fixture$agencias, distancias_ucs = fixture$dists,
    dias_coleta_entrevistador_max = 14, diarias_entrevistador_max = 40,
    n_entrevistadores_min = 2,
    custo_litro_combustivel = 6, kml = 10, custo_hora_viagem = 10, use_cache = FALSE
  )
  verify_entrev(params2, resultado_test = res2)
})

test_that("fallback interviewer formula used when dias_coleta_entrevistador_max is Inf", {
  params_inf <- params_default
  params_inf$dias_coleta_entrevistador_max <- Inf
  ctx <- build_whatif_wb(params = params_inf)
  resumo_ag_formulas <- read_sheet(ctx$wb, "Resumo por agência", show_formula = TRUE)

  interviewers_col <- sheet_col(resumo_ag_formulas, "Entrevistadores sel.")
  expect_true(all(grepl("^MAX\\(SUMIF\\(", interviewers_col)))
  expect_false(any(grepl("dias_coleta_entrevistador_max", interviewers_col, fixed = TRUE)))
})

test_that("IFERROR wraps INDEX/MATCH formulas in UPAs hidden columns", {
  ctx <- build_whatif_wb()
  upas_xml <- read_sheet_xml(ctx$out, 1)
  expect_match(upas_xml, "IFERROR(INDEX", fixed = TRUE)
})

test_that("roundtrip: per-UPA cost components reconstructed from xlsx matrices match orce output", {
  ctx <- build_whatif_wb()
  wb <- ctx$wb

  dist_wide <- read_sheet(wb, "Distâncias")
  dur_wide <- read_sheet(wb, "Durações")
  dm_wide <- read_sheet(wb, "Diária Município")
  dp_wide <- read_sheet(wb, "Diária Pernoite")

  to_long <- function(wide, id_col, value_col) {
    wide |>
      tidyr::pivot_longer(-dplyr::all_of(id_col),
        names_to = "agencia_codigo",
        values_to = value_col
      )
  }

  dist_long <- to_long(dist_wide, "uc", "distancia_km")
  dur_long <- to_long(dur_wide, "uc", "duracao_horas")
  dm_long <- to_long(dm_wide, "municipio_codigo", "diaria_municipio_mat")
  dp_long <- to_long(dp_wide, "uc", "diaria_pernoite_mat")

  compute_upa_costs <- function(resultado_ucs) {
    resultado_ucs |>
      dplyr::select("uc", "agencia_codigo") |>
      dplyr::left_join(
        uc_default |>
          dplyr::select("uc", "municipio_codigo", "dias_coleta",
            "viagens", "entrevistadores_por_uc", "diaria_valor"),
        by = "uc"
      ) |>
      dplyr::left_join(dist_long, by = c("uc", "agencia_codigo")) |>
      dplyr::left_join(dur_long, by = c("uc", "agencia_codigo")) |>
      dplyr::left_join(dm_long, by = c("municipio_codigo", "agencia_codigo")) |>
      dplyr::left_join(dp_long, by = c("uc", "agencia_codigo")) |>
      dplyr::mutate(
        diaria_municipio = as.logical(diaria_municipio_mat),
        diaria_pernoite = as.logical(diaria_pernoite_mat),
        diaria = diaria_municipio | diaria_pernoite,
        meia_diaria = diaria_municipio & !diaria_pernoite,
        trechos = dplyr::if_else(diaria & !meia_diaria, viagens * 2L, dias_coleta * 2L),
        n_diarias = dplyr::case_when(
          !diaria ~ 0,
          dias_coleta == 0 ~ 0,
          meia_diaria ~ dias_coleta * 0.5,
          dias_coleta == 1 ~ 1.5,
          TRUE ~ dias_coleta - 0.5
        ),
        total_diarias = n_diarias * entrevistadores_por_uc,
        custo_diarias = total_diarias * diaria_valor,
        distancia_total_km = trechos * distancia_km,
        custo_combustivel = (distancia_total_km / params_default$kml) * params_default$custo_litro_combustivel,
        custo_horas_viagem = trechos * duracao_horas * params_default$custo_hora_viagem
      )
  }

  compare_scenario <- function(resultado_ucs) {
    computed <- compute_upa_costs(resultado_ucs)
    cmp <- computed |>
      dplyr::left_join(
        resultado_ucs |>
          dplyr::select(
            "uc",
            orce_trechos = "trechos",
            orce_total_diarias = "total_diarias",
            orce_custo_diarias = "custo_diarias",
            orce_custo_combustivel = "custo_combustivel",
            orce_custo_horas = "custo_horas_viagem"
          ),
        by = "uc"
      )

    expect_equal(cmp$trechos, cmp$orce_trechos)
    expect_equal(cmp$total_diarias, cmp$orce_total_diarias, tolerance = 1e-9)
    expect_equal(cmp$custo_diarias, cmp$orce_custo_diarias, tolerance = 0.01)
    expect_equal(cmp$custo_combustivel, cmp$orce_custo_combustivel, tolerance = 0.01)
    expect_equal(cmp$custo_horas_viagem, cmp$orce_custo_horas, tolerance = 0.01)
  }

  compare_scenario(resultado_default$resultado_ucs_jurisdicao)
  compare_scenario(resultado_default$resultado_ucs_otimo)
})

test_that("orce_excel_whatif accepts an orce_conjunto result via res_base (wide format)", {
  # Simulate orce_conjunto result: same agencies for M and F (non-hybrid UCs).
  # Build a minimal alocacao from resultado_default.
  ucs_ot <- resultado_default$resultado_ucs_otimo
  alocacao_sim <- ucs_ot |>
    dplyr::transmute(
      uc,
      agencia_codigo_m          = agencia_codigo,
      agencia_codigo_f          = agencia_codigo,
      hibrido                   = FALSE,
      custo_combustivel_m       = custo_combustivel / 2,
      custo_combustivel_f       = custo_combustivel / 2,
      distancia_total_km_m      = distancia_total_km / 2,
      distancia_total_km_f      = distancia_total_km / 2,
      duracao_total_horas_m     = duracao_total_horas / 2,
      duracao_total_horas_f     = duracao_total_horas / 2,
      trechos_m                 = trechos / 2,
      trechos_f                 = trechos / 2,
      custo_horas_viagem_m      = custo_horas_viagem / 2,
      custo_horas_viagem_f      = custo_horas_viagem / 2,
      total_diarias_m           = total_diarias / 2,
      total_diarias_f           = total_diarias / 2,
      custo_diarias_m           = custo_diarias / 2,
      custo_diarias_f           = custo_diarias / 2,
      custo_deslocamento        = custo_deslocamento
    )

  conjunto_result <- list(
    res_base      = resultado_default,
    res_masculino = resultado_default,
    res_feminino  = resultado_default,
    alocacao      = alocacao_sim
  )

  n_ucs <- length(unique(resultado_default$resultado_ucs_otimo$uc))
  ucs_no_entrev <- uc_default |> dplyr::select(-"entrevistadores_por_uc")
  params_hybrid <- c(params_default, list(n_entrevistadores_min = 2))

  out <- tempfile(fileext = ".xlsx")
  expect_no_error(
    orce_excel_whatif(
      resultado      = conjunto_result,
      distancias_ucs = fixture$dists,
      ucs            = ucs_no_entrev,
      agencias       = ag_default,
      file           = out,
      params         = params_hybrid
    )
  )
  expect_true(file.exists(out))

  wb      <- openxlsx2::wb_load(out)
  upas_df <- read_sheet(wb, "UPAs")

  # Wide format: one row per UC (not doubled)
  expect_equal(nrow(upas_df), n_ucs)

  # Wide format has separate M and F agency columns, no Gênero column
  expect_true("Ag. otimizada M" %in% names(upas_df))
  expect_true("Ag. otimizada F" %in% names(upas_df))
  expect_false("Gênero" %in% names(upas_df))

  # Since M and F use same resultado_default, Ag. oti M == Ag. oti F
  expect_equal(upas_df[["Ag. otimizada M"]], upas_df[["Ag. otimizada F"]])
  expect_true(all(nchar(upas_df[["Ag. otimizada M"]]) > 0))

  # carga_m and carga_f both = dias_coleta (1 interviewer each in hybrid mode)
  expect_true("carga_m" %in% names(upas_df))
  expect_true("carga_f" %in% names(upas_df))
  expect_equal(upas_df[["carga_m"]], upas_df[["carga_f"]])

  # Entrevistadores otim.: non-pooled, each gender rounds up independently
  resumo_df   <- read_sheet(wb, "Resumo por agência")
  entrev_otim <- resumo_df[["Entrevistadores otim."]]
  max_dias    <- params_default$dias_coleta_entrevistador_max
  n_min       <- 2L
  ag_codes    <- resumo_df[["Cód. agência"]]
  expected    <- vapply(ag_codes, function(ag) {
    mask_m <- !is.na(upas_df[["Cód. ag. otimizada M"]]) & upas_df[["Cód. ag. otimizada M"]] == ag
    mask_f <- !is.na(upas_df[["Cód. ag. otimizada F"]]) & upas_df[["Cód. ag. otimizada F"]] == ag
    if (!any(mask_m) && !any(mask_f)) return(0L)
    as.integer(max(
      ceiling(sum(upas_df[["carga_m"]][mask_m], na.rm = TRUE) / max_dias) +
        ceiling(sum(upas_df[["carga_f"]][mask_f], na.rm = TRUE) / max_dias),
      n_min
    ))
  }, integer(1L))
  expect_equal(entrev_otim, unname(expected))
})
