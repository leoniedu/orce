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
