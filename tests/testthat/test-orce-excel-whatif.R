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
      "Resumo",
      "Resumo por agência",
      "Parâmetros",
      "Agências",
      "Distâncias",
      "Durações",
      "Diária Município",
      "Diária Pernoite",
      "UPAs"
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
    "Ag. selecionada",
    "Cód. ag. selecionada",
    "Custo desloc. selecionada (R$)",
    "Realocada"
  ) %in% names(upas_formulas)))

  expect_equal(sheet_col(upas, "Ag. selecionada"), sheet_col(upas, "Ag. otimizada"))
  expect_false(any(grepl("^[0-9]+$", sheet_col(upas, "Ag. selecionada"))))
  expect_true(all(grepl("INDEX\\('Agências'!\\$A\\$2", sheet_col(upas_formulas, "Cód. ag. selecionada"))))
  expect_true(all(grepl("\\+", sheet_col(upas_formulas, "Custo desloc. selecionada (R$)"))))
  expect_true(all(grepl("IF\\(M", sheet_col(upas_formulas, "Realocada"))))
})

test_that("UPAs worksheet is protected and validates the selected agency by name", {
  ctx <- build_whatif_wb()
  upas_xml <- read_sheet_xml(ctx$out, 9)

  expect_match(upas_xml, "sheetProtection", fixed = TRUE)
  expect_match(upas_xml, "<formula1>=agencia_selecao_lista</formula1>", fixed = TRUE)
})

test_that("Resumo por agência keeps static totals and exposes the new selected formulas", {
  ctx <- build_whatif_wb()
  resumo_ag <- read_sheet(ctx$wb, "Resumo por agência")
  resumo_ag_formulas <- read_sheet(ctx$wb, "Resumo por agência", show_formula = TRUE)

  expect_equal(nrow(resumo_ag), dplyr::n_distinct(ag_default$agencia_codigo))
  expect_true(all(make.names(c(
    "Entrevistadores jur.",
    "Entrevistadores sel.",
    "Custo treinamento jur. (R$)",
    "Custo treinamento sel. (R$)",
    "% aumento custo desloc. sel. vs ótimo"
  )) %in% names(resumo_ag)))

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
  expect_true(all(grepl("^IF\\(AB", sheet_col(resumo_ag_formulas, "% aumento custo desloc. sel. vs ótimo"))))
})

test_that("Resumo sheet summarizes the three scenarios with formulas over Resumo por agência", {
  ctx <- build_whatif_wb()
  resumo <- read_sheet(ctx$wb, "Resumo", show_formula = TRUE)

  expect_equal(sheet_col(resumo, "Cenário"), c("Jurisdição", "Otimizada", "Selecionada"))
  expect_true(all(grepl("'Resumo por agência'!", sheet_col(resumo, "UPAs"), fixed = TRUE)))
  expect_true(all(grepl("'Resumo por agência'!", sheet_col(resumo, "Custo desloc. (R$)"), fixed = TRUE)))
  expect_equal(sheet_col(resumo, "% custo desloc. vs otim.")[[2]], "0")
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
  upas_xml <- read_sheet_xml(ctx$out, 9)
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
