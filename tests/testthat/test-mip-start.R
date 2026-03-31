# Test MIP start with jurisdiction assignment

test_that("mip_start = TRUE produces valid results with HiGHS", {
  ucs <- tibble::tibble(
    uc             = c("U1", "U2", "U3", "U4"),
    agencia_codigo = c("A1", "A1", "A2", "A2"),
    dias_coleta    = 5L,
    viagens        = 1L,
    data           = 1L,
    diaria_valor   = 0
  )
  agencias <- tibble::tibble(
    agencia_codigo             = c("A1", "A2"),
    custo_fixo                 = 0,
    n_entrevistadores_agencia_max = Inf,
    diaria_valor               = 0
  )
  pos <- c(A1 = 0, A2 = 100, U1 = 10, U2 = 20, U3 = 80, U4 = 90)
  distancias_ucs <- tidyr::expand_grid(
    uc             = c("U1", "U2", "U3", "U4"),
    agencia_codigo = c("A1", "A2")
  ) |>
    dplyr::mutate(
      distancia_km    = abs(pos[uc] - pos[agencia_codigo]),
      duracao_horas   = distancia_km / 80,
      diaria_municipio = FALSE,
      diaria_pernoite  = FALSE
    )

  base_params <- list(
    ucs                          = ucs,
    agencias                     = agencias,
    distancias_ucs               = distancias_ucs,
    dias_coleta_entrevistador_max = 20,
    remuneracao_entrevistador    = 0,
    use_cache                    = FALSE,
    rel_tol                      = 0.005
  )

  r_no_start <- do.call(orce, c(base_params, list(mip_start = FALSE)))
  r_start    <- do.call(orce, c(base_params, list(mip_start = TRUE)))

  # Both should produce valid results
  expect_true(nrow(r_start$resultado_ucs_otimo) > 0)
  expect_true(nrow(r_start$resultado_agencias_otimo) > 0)

  # Objective values should be within tolerance
  cost_no_start <- sum(r_no_start$resultado_agencias_otimo$custo_deslocamento)
  cost_start    <- sum(r_start$resultado_agencias_otimo$custo_deslocamento)
  expect_equal(cost_start, cost_no_start, tolerance = 0.01)
})

test_that(".build_mip_start_sol generates correct file format", {
  ucs_i <- tibble::tibble(
    i = c(1L, 2L, 3L, 4L),
    agencia_codigo_jurisdicao = c("A1", "A1", "A2", "A2")
  )
  agencias_t <- tibble::tibble(
    agencia_codigo = c("A1", "A2"),
    j = 1:2
  )

  n <- 4L
  m <- 2L

  model <- ompr::MILPModel() |>
    ompr::add_variable(x[i, j], i = 1:n, j = 1:m, type = "binary") |>
    ompr::add_variable(y[j], j = 1:m, type = "binary") |>
    ompr::add_variable(w[j], j = 1:m, type = "continuous", lb = 0) |>
    ompr::set_objective(ompr::sum_expr(x[i, j], i = 1:n, j = 1:m), sense = "min")

  sol_file <- orce:::.build_mip_start_sol(model, ucs_i, agencias_t)
  on.exit(unlink(sol_file))

  expect_true(file.exists(sol_file))

  lines <- readLines(sol_file)
  ncols <- length(ompr::variable_keys(model))
  expect_equal(lines[1], "Model status")
  expect_equal(lines[6], "Objective 0")
  expect_equal(lines[7], paste("#", "Columns", ncols))
  expect_equal(length(lines), ncols + 7L)

  # Parse values and check that x[i, j_juris] = 1 for each UC
  vals <- as.numeric(sub("^C\\d+ ", "", lines[-(1:7)]))
  keys <- ompr::variable_keys(model)
  x_mask <- grepl("^x\\[", keys)
  x_vals <- vals[x_mask]

  # Should have exactly n ones (one per UC)
  expect_equal(sum(x_vals), n)
})

test_that(".build_mip_start_sol returns NULL when jurisdiction agency missing", {
  ucs_i <- tibble::tibble(i = 1:2, agencia_codigo_jurisdicao = c("A1", "MISSING"))
  agencias_t <- tibble::tibble(agencia_codigo = c("A1", "A2"), j = 1:2)

  model <- ompr::MILPModel() |>
    ompr::add_variable(x[i, j], i = 1:2, j = 1:2, type = "binary") |>
    ompr::add_variable(y[j], j = 1:2, type = "binary") |>
    ompr::add_variable(w[j], j = 1:2, type = "continuous", lb = 0) |>
    ompr::set_objective(ompr::sum_expr(x[i, j], i = 1:2, j = 1:2), sense = "min")

  result <- orce:::.build_mip_start_sol(model, ucs_i, agencias_t)
  expect_null(result)
})
