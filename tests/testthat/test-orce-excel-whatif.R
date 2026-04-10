fixture <- readRDS(test_path("fixtures", "test-orce-data.rds"))

test_that("orce_excel_whatif creates file with correct sheets", {
  r <- orce(ucs = fixture$ucs, agencias = fixture$agencias,
            distancias_ucs = fixture$dists, dias_coleta_entrevistador_max = 14,
            use_cache = FALSE)
  ag <- fixture$agencias |>
    dplyr::mutate(agencia_nome = paste("Agência", agencia_codigo),
                  municipio_codigo = substr(agencia_codigo, 1, 7),
                  municipio_nome = paste("Município", substr(agencia_codigo, 1, 7)))
  uc <- fixture$ucs |>
    dplyr::mutate(municipio_nome = paste("Município", municipio_codigo),
                  entrevistadores_por_uc = 1)
  out <- withr::local_tempfile(fileext = ".xlsx")
  orce_excel_whatif(resultado = r, distancias_ucs = fixture$dists, ucs = uc,
                    agencias = ag, file = out,
                    params = list(custo_litro_combustivel = 6, kml = 10, custo_hora_viagem = 10))
  expect_true(file.exists(out))
  wb <- openxlsx2::wb_load(out)
  sheets <- wb$get_sheet_names()
  expect_equal(unname(sheets),
    c("Parâmetros", "Agências", "Distâncias", "Durações",
      "Diária Município", "Diária Pernoite", "UPAs", "Resumo"))
})

test_that(".pivot_to_matrix creates correct wide matrix", {
  long <- data.frame(row_id = c("A", "A", "B", "B"), col_id = c("X", "Y", "X", "Y"),
                     value = c(1.0, 2.0, 3.0, 4.0))
  wide <- orce:::.pivot_to_matrix(long, "row_id", "col_id", "value")
  expect_equal(nrow(wide), 2)
  expect_equal(ncol(wide), 3)
  expect_equal(wide$X, c(1.0, 3.0))
  expect_equal(wide$Y, c(2.0, 4.0))
})

test_that(".pivot_to_matrix handles diaria_municipio correctly", {
  dists <- data.frame(uc = c("U1", "U1", "U2", "U2"),
    municipio_codigo = c("M1", "M1", "M1", "M1"),
    agencia_codigo = c("A1", "A2", "A1", "A2"),
    diaria_municipio = c(TRUE, FALSE, TRUE, FALSE))
  dm <- dists |> dplyr::distinct(municipio_codigo, agencia_codigo, .keep_all = TRUE)
  mat <- orce:::.pivot_to_matrix(dm, "municipio_codigo", "agencia_codigo", "diaria_municipio")
  expect_equal(nrow(mat), 1)
  expect_equal(mat$A1, TRUE)
  expect_equal(mat$A2, FALSE)
})

test_that("matrix sheets have correct dimensions", {
  r <- orce(ucs = fixture$ucs, agencias = fixture$agencias,
            distancias_ucs = fixture$dists,
            dias_coleta_entrevistador_max = 14, use_cache = FALSE)
  ag <- fixture$agencias |>
    dplyr::mutate(agencia_nome = paste("Ag", agencia_codigo),
                  municipio_codigo = substr(agencia_codigo, 1, 7),
                  municipio_nome = paste("Mun", substr(agencia_codigo, 1, 7)))
  uc <- fixture$ucs |>
    dplyr::mutate(municipio_nome = paste("Mun", municipio_codigo),
                  entrevistadores_por_uc = 1)
  out <- withr::local_tempfile(fileext = ".xlsx")
  orce_excel_whatif(r, fixture$dists, uc, ag, out)
  wb <- openxlsx2::wb_load(out)

  n_upas <- dplyr::n_distinct(uc$uc)
  n_agencies <- dplyr::n_distinct(ag$agencia_codigo)

  dist_df <- openxlsx2::wb_to_df(wb, sheet = "Distâncias")
  expect_equal(nrow(dist_df), n_upas)

  dm_df <- openxlsx2::wb_to_df(wb, sheet = "Diária Município")
  n_mun <- dplyr::n_distinct(uc$municipio_codigo)
  expect_equal(nrow(dm_df), n_mun)
})

test_that("UPAs sheet has correct fixed columns and row count", {
  r <- orce(ucs = fixture$ucs, agencias = fixture$agencias,
            distancias_ucs = fixture$dists,
            dias_coleta_entrevistador_max = 14, use_cache = FALSE)
  ag <- fixture$agencias |>
    dplyr::mutate(agencia_nome = paste("Ag", agencia_codigo),
                  municipio_codigo = substr(agencia_codigo, 1, 7),
                  municipio_nome = paste("Mun", substr(agencia_codigo, 1, 7)))
  uc <- fixture$ucs |>
    dplyr::mutate(municipio_nome = paste("Mun", municipio_codigo),
                  entrevistadores_por_uc = 1)
  out <- withr::local_tempfile(fileext = ".xlsx")
  orce_excel_whatif(r, fixture$dists, uc, ag, out)
  wb <- openxlsx2::wb_load(out)
  upas_df <- openxlsx2::wb_to_df(wb, sheet = "UPAs")
  n_upas <- dplyr::n_distinct(uc$uc)
  expect_equal(nrow(upas_df), n_upas)
  expected_headers <- c("UPA", "Cód. Município", "Município", "Dias coleta",
                        "Viagens", "Entrevistadores", "Valor diária (R$)",
                        "Ag. jurisdição", "Ag. otimizada", "Ag. selecionada")
  for (h in expected_headers) {
    expect_true(h %in% names(upas_df), info = paste("Missing header:", h))
  }
  expect_equal(upas_df[["Ag. selecionada"]], upas_df[["Ag. otimizada"]])
})

test_that("UPAs sheet contains formulas in cost columns", {
  r <- orce(ucs = fixture$ucs, agencias = fixture$agencias,
            distancias_ucs = fixture$dists,
            dias_coleta_entrevistador_max = 14, use_cache = FALSE)
  ag <- fixture$agencias |>
    dplyr::mutate(agencia_nome = paste("Ag", agencia_codigo),
                  municipio_codigo = substr(agencia_codigo, 1, 7),
                  municipio_nome = paste("Mun", substr(agencia_codigo, 1, 7)))
  uc <- fixture$ucs |>
    dplyr::mutate(municipio_nome = paste("Mun", municipio_codigo),
                  entrevistadores_por_uc = 1)
  out <- withr::local_tempfile(fileext = ".xlsx")
  orce_excel_whatif(r, fixture$dists, uc, ag, out)
  wb <- openxlsx2::wb_load(out)
  upas_formulas <- openxlsx2::wb_to_df(wb, sheet = "UPAs", show_formula = TRUE)
  cost_jur <- upas_formulas[["Custo desloc. jurisdição (R$)"]]
  expect_true(all(grepl("\\+", cost_jur)), info = "Jur cost should have addition formulas")
  cost_sel <- upas_formulas[["Custo desloc. selecionada (R$)"]]
  expect_true(all(grepl("\\+", cost_sel)), info = "Sel cost should have addition formulas")
  realocada <- upas_formulas[["Realocada"]]
  expect_true(all(grepl("<>", realocada)), info = "Realocada should compare agencies")
})

test_that("Parâmetros sheet has correct named ranges and values", {
  r <- orce(ucs = fixture$ucs, agencias = fixture$agencias,
            distancias_ucs = fixture$dists, dias_coleta_entrevistador_max = 14,
            use_cache = FALSE)
  ag <- fixture$agencias |>
    dplyr::mutate(agencia_nome = paste("Ag", agencia_codigo),
                  municipio_codigo = substr(agencia_codigo, 1, 7),
                  municipio_nome = paste("Mun", substr(agencia_codigo, 1, 7)))
  uc <- fixture$ucs |>
    dplyr::mutate(municipio_nome = paste("Mun", municipio_codigo),
                  entrevistadores_por_uc = 1)
  out <- withr::local_tempfile(fileext = ".xlsx")
  orce_excel_whatif(r, fixture$dists, uc, ag, out,
                    params = list(custo_litro_combustivel = 7, kml = 12, custo_hora_viagem = 15))
  wb <- openxlsx2::wb_load(out)
  params_df <- openxlsx2::wb_to_df(wb, sheet = "Parâmetros", col_names = TRUE)
  vals <- stats::setNames(as.numeric(params_df[["Valor"]]), params_df[["Parâmetro"]])
  expect_equal(vals[["Custo litro combustível (R$/L)"]], 7)
  expect_equal(vals[["Km por litro (km/L)"]], 12)
  expect_equal(vals[["Custo hora viagem (R$/h)"]], 15)
})
