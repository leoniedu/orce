# Compare orce_model_mip (MIPModel / sum_over) with
# orce_model_milp (MILPModel / sum_expr + colwise).
# Both must produce the same optimal cost and assignments.

# Synthetic problem: 2 agencies (A1, A2), 4 UCs laid out on a line.
# Coordinates (km): A1=0, A2=100, U1=10, U2=20, U3=80, U4=90
# Optimal: U1+U2 -> A1, U3+U4 -> A2.

make_backend_data <- function() {
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

  # One-dimensional layout: positions A1=0, A2=100, U1=10, U2=20, U3=80, U4=90
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

  # N x N distance matrix for TSP: nodes A1(1), A2(2), U1(3), U2(4), U3(5), U4(6)
  node_pos <- c(0, 100, 10, 20, 80, 90)
  N <- length(node_pos)
  distancias_nos <- outer(node_pos, node_pos, FUN = function(a, b) abs(a - b))

  list(
    ucs            = ucs,
    agencias       = agencias,
    distancias_ucs = distancias_ucs,
    distancias_nos = distancias_nos
  )
}

test_that("orce_model_mip and orce_model_milp agree: no TSP", {
  d <- make_backend_data()

  base_params <- list(
    ucs                          = d$ucs,
    agencias                     = d$agencias,
    distancias_ucs               = d$distancias_ucs,
    dias_coleta_entrevistador_max = 20,
    remuneracao_entrevistador    = 0,
    use_cache                    = FALSE,
    rel_tol                      = 0.001
  )

  r_mip  <- do.call(orce, c(base_params, list(orce_function = orce_model_mip)))
  r_milp <- do.call(orce, c(base_params, list(orce_function = orce_model_milp)))

  expect_equal(
    sum(r_mip$resultado_agencias_otimo$custo_deslocamento),
    sum(r_milp$resultado_agencias_otimo$custo_deslocamento),
    tolerance = 1e-3
  )

  asg <- function(r) {
    r$resultado_ucs_otimo |>
      dplyr::select(uc, agencia_codigo) |>
      dplyr::arrange(uc)
  }
  expect_equal(asg(r_mip), asg(r_milp))
})

test_that("orce_model_mip and orce_model_milp agree: with TSP", {
  d <- make_backend_data()

  base_params <- list(
    ucs                          = d$ucs,
    agencias                     = d$agencias,
    distancias_ucs               = d$distancias_ucs,
    dias_coleta_entrevistador_max = 20,
    remuneracao_entrevistador    = 0,
    use_cache                    = FALSE,
    rel_tol                      = 0.001,
    peso_tsp                     = 0.1,
    distancias_nos               = d$distancias_nos
  )

  r_mip  <- do.call(orce, c(base_params, list(orce_function = orce_model_mip)))
  r_milp <- do.call(orce, c(base_params, list(orce_function = orce_model_milp)))

  expect_equal(
    sum(r_mip$resultado_agencias_otimo$custo_deslocamento),
    sum(r_milp$resultado_agencias_otimo$custo_deslocamento),
    tolerance = 1e-3
  )
})
