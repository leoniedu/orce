#' Otimização conjunta masculino/feminino com um único MILP
#'
#' Resolve a alocação de entrevistadores de ambos os gêneros simultaneamente
#' em um único MILP, eliminando as inviabilidades da abordagem sequencial.
#' Usa um único espaço de índices `j` para todas as agências; o bloqueio
#' implícito via capacidade (`wm[j] <= n_masculino[j]`) dispensa mapeamentos
#' bilaterais. Retorna estrutura compatível com [pns.zonas::orce_hibrido()].
#'
#' @inheritParams orce_joint
#' @return Lista com `alocacao`, `res_masculino`, `res_feminino` e `res_base`.
#' @export
orce_joint <- function(
    ucs,
    agencias,
    distancias_ucs,
    distancias_agencias        = NULL,
    alocar_por                 = "uc",
    custo_litro_combustivel    = 6,
    kml                        = 10,
    custo_hora_viagem          = 10,
    diarias_entrevistador_max  = Inf,
    remuneracao_entrevistador  = 3000,
    n_entrevistadores_min      = 1L,
    n_entrevistadores_tipo     = "continuous",
    dias_coleta_entrevistador_max = 100,
    dias_treinamento           = 0,
    agencias_treinadas         = NULL,
    agencias_treinamento       = NULL,
    entrevistadores_por_uc     = 1L,
    adicional_troca_jurisdicao = 0,
    fixar_atribuicoes_masculino = NULL,
    fixar_atribuicoes_feminino  = NULL,
    solver                     = "highs",
    rel_tol                    = 1e-4,
    max_time                   = 3600,
    seed                       = NULL,
    resultado_completo         = FALSE,
    ...) {

  if (!is.null(seed)) set.seed(seed)

  required_cols <- c("n_masculino", "n_feminino")
  missing_cols <- setdiff(required_cols, names(agencias))
  if (length(missing_cols) > 0) {
    cli::cli_abort("{.arg agencias} está faltando a coluna{?s}: {.val {missing_cols}}.")
  }

  rlang::check_installed(paste0("ROI.plugin.", solver),
                         reason = "para usar o solver solicitado")

  tictoc::tic.clearlog()
  tictoc::tic("Tempo total da otimização", log = TRUE)
  on.exit({
    tictoc::toc(log = TRUE, quiet = TRUE)
    .tempo <- tictoc::tic.log(format = FALSE)
    if (length(.tempo) > 0) {
      with(.tempo[[1]], cli::cli_alert_success(
        paste0(msg, ": ", round(toc - tic), " segundos.")
      ))
    }
  }, add = TRUE)

  # ── All agencies with any capacity ───────────────────────────────────────────
  agencias_full <- agencias |>
    dplyr::filter(.data$n_masculino > 0 | .data$n_feminino > 0) |>
    dplyr::mutate(n_entrevistadores_agencia_max = .data$n_masculino + .data$n_feminino)

  dist_full <- distancias_ucs |>
    dplyr::filter(.data$agencia_codigo %in% agencias_full$agencia_codigo)

  # ── 1. Single cost computation ────────────────────────────────────────────────
  cli::cli_progress_step("Preparando matrizes de custo")
  prep <- .orce_costs(
    ucs = ucs, agencias = agencias_full, distancias_ucs = dist_full,
    distancias_agencias        = distancias_agencias,
    alocar_por                 = alocar_por,
    custo_litro_combustivel    = custo_litro_combustivel,
    kml                        = kml,
    custo_hora_viagem          = custo_hora_viagem,
    entrevistadores_por_uc     = entrevistadores_por_uc,
    adicional_troca_jurisdicao = adicional_troca_jurisdicao,
    dias_treinamento           = dias_treinamento,
    agencias_treinadas         = agencias_treinadas,
    agencias_treinamento       = agencias_treinamento
  )

  n <- prep$n
  m <- prep$m
  p <- prep$p

  # Gender capacities aligned to prep$agencias_t order
  ag_order <- match(prep$agencias_t$agencia_codigo, agencias_full$agencia_codigo)
  n_masculino <- agencias_full$n_masculino[ag_order]
  n_feminino  <- agencias_full$n_feminino[ag_order]

  # ── 2. Assemble MILP environment ─────────────────────────────────────────────
  fix_m <- .joint_translate_fixar(fixar_atribuicoes_masculino,
                                   prep$ucs_i, prep$agencias_t)
  fix_f <- .joint_translate_fixar(fixar_atribuicoes_feminino,
                                   prep$ucs_i, prep$agencias_t)

  transport  <- prep$transport_cost_i_j
  fuel       <- prep$fuel_cost_i_j
  diarias    <- prep$diarias_i_j
  dias_arr   <- matrix(prep$dias_coleta_arr[, 1L, ], nrow = n, ncol = p)
  custo_fixo <- prep$agencias_t$custo_fixo
  training_m <- prep$agencias_t$custo_treinamento_por_entrevistador
  training_f <- prep$agencias_t$custo_treinamento_por_entrevistador

  # ── 3. Build and solve ────────────────────────────────────────────────────────
  cli::cli_progress_step("Construindo modelo MILP conjunto")
  model <- orce_model_milp_joint(environment())

  cli::cli_progress_step("Otimizando...")
  if (solver == "symphony") {
    result <- ompr::solve_model(
      model,
      ompr.roi::with_ROI(solver = solver, max_time = as.numeric(max_time),
                         gap_limit = rel_tol * 100, ...)
    )
  } else {
    result <- ompr::solve_model(
      model,
      ompr.roi::with_ROI(solver = solver, max_time = as.numeric(max_time),
                         rel_tol = rel_tol, ...)
    )
  }
  if (result$status == "error") {
    cli::cli_abort("O solver retornou um erro. Verifique os parâmetros do modelo.")
  }

  # ── 4. Extract assignments ────────────────────────────────────────────────────
  xm_sol <- ompr::get_solution(result, xm[i, j]) |>
    dplyr::filter(.data$value > 0.5) |>
    dplyr::select("i", "j")
  xf_sol <- ompr::get_solution(result, xf[i, j]) |>
    dplyr::filter(.data$value > 0.5) |>
    dplyr::select("i", "j")
  wm_sol <- ompr::get_solution(result, wm[j]) |>
    dplyr::select("j", entrevistadores = "value")
  wf_sol <- ompr::get_solution(result, wf[j]) |>
    dplyr::select("j", entrevistadores = "value")

  # ── 5. Build per-gender orce-compatible results ───────────────────────────────
  ucs_alocar <- ucs |>
    dplyr::ungroup() |>
    sf::st_drop_geometry() |>
    dplyr::distinct(dplyr::pick(dplyr::all_of(unique(c("uc", alocar_por)))))

  res_masculino <- .joint_build_resultado(
    xij = xm_sol, workers = wm_sol,
    prep = prep, ucs_alocar = ucs_alocar,
    remuneracao_entrevistador = remuneracao_entrevistador,
    resultado_completo = resultado_completo
  )
  res_feminino <- .joint_build_resultado(
    xij = xf_sol, workers = wf_sol,
    prep = prep, ucs_alocar = ucs_alocar,
    remuneracao_entrevistador = remuneracao_entrevistador,
    resultado_completo = resultado_completo
  )

  # ── 6. alocacao ───────────────────────────────────────────────────────────────
  uc_cols_m <- res_masculino$resultado_ucs_otimo |>
    dplyr::select("uc",
                  custo_combustivel_m   = "custo_combustivel",
                  distancia_total_km_m  = "distancia_total_km",
                  duracao_total_horas_m = "duracao_total_horas",
                  trechos_m             = "trechos",
                  custo_horas_viagem_m  = "custo_horas_viagem",
                  total_diarias_m       = "total_diarias",
                  custo_diarias_m       = "custo_diarias")

  uc_cols_f <- res_feminino$resultado_ucs_otimo |>
    dplyr::select("uc",
                  custo_combustivel_f   = "custo_combustivel",
                  distancia_total_km_f  = "distancia_total_km",
                  duracao_total_horas_f = "duracao_total_horas",
                  trechos_f             = "trechos",
                  custo_horas_viagem_f  = "custo_horas_viagem",
                  total_diarias_f       = "total_diarias",
                  custo_diarias_f       = "custo_diarias")

  alocacao <- res_masculino$resultado_ucs_otimo |>
    dplyr::select("uc", agencia_codigo_m = "agencia_codigo") |>
    dplyr::inner_join(
      res_feminino$resultado_ucs_otimo |>
        dplyr::select("uc", agencia_codigo_f = "agencia_codigo"),
      by = "uc"
    ) |>
    dplyr::mutate(hibrido = .data$agencia_codigo_m != .data$agencia_codigo_f) |>
    dplyr::left_join(uc_cols_m, by = "uc") |>
    dplyr::left_join(uc_cols_f, by = "uc") |>
    dplyr::mutate(
      custo_combustivel = dplyr::if_else(.data$hibrido,
        .data$custo_combustivel_m + .data$custo_combustivel_f,
        (.data$custo_combustivel_m + .data$custo_combustivel_f) / 2),
      distancia_total_km = dplyr::if_else(.data$hibrido,
        .data$distancia_total_km_m + .data$distancia_total_km_f,
        (.data$distancia_total_km_m + .data$distancia_total_km_f) / 2),
      duracao_total_horas = dplyr::if_else(.data$hibrido,
        .data$duracao_total_horas_m + .data$duracao_total_horas_f,
        (.data$duracao_total_horas_m + .data$duracao_total_horas_f) / 2),
      trechos = dplyr::if_else(.data$hibrido,
        .data$trechos_m + .data$trechos_f,
        (.data$trechos_m + .data$trechos_f) / 2),
      custo_horas_viagem = .data$custo_horas_viagem_m + .data$custo_horas_viagem_f,
      total_diarias      = .data$total_diarias_m + .data$total_diarias_f,
      custo_diarias      = .data$custo_diarias_m + .data$custo_diarias_f,
      custo_deslocamento = .data$custo_combustivel + .data$custo_horas_viagem +
        .data$custo_diarias,
      economia_combustivel = dplyr::if_else(.data$hibrido, 0,
        (.data$custo_combustivel_m + .data$custo_combustivel_f) / 2),
      economia_km = dplyr::if_else(.data$hibrido, 0,
        (.data$distancia_total_km_m + .data$distancia_total_km_f) / 2)
    )

  # ── 7. res_base ───────────────────────────────────────────────────────────────
  agencias_base <- agencias_full |>
    dplyr::mutate(n_entrevistadores_agencia_max = Inf)

  res_base <- orce(
    ucs = ucs,
    agencias = agencias_base,
    distancias_ucs = distancias_ucs |>
      dplyr::filter(.data$agencia_codigo %in% agencias_base$agencia_codigo),
    distancias_agencias        = distancias_agencias,
    alocar_por                 = alocar_por,
    custo_litro_combustivel    = custo_litro_combustivel,
    kml                        = kml,
    custo_hora_viagem          = custo_hora_viagem,
    dias_treinamento           = dias_treinamento,
    agencias_treinadas         = agencias_treinadas,
    agencias_treinamento       = agencias_treinamento,
    entrevistadores_por_uc        = 2L,
    n_entrevistadores_min         = 2L,
    dias_coleta_entrevistador_max = dias_coleta_entrevistador_max,
    adicional_troca_jurisdicao    = adicional_troca_jurisdicao,
    resultado_completo            = TRUE,
    solver                        = solver,
    rel_tol                       = rel_tol,
    max_time                      = max_time
  )

  list(
    alocacao      = alocacao,
    res_masculino = res_masculino,
    res_feminino  = res_feminino,
    res_base      = res_base
  )
}
