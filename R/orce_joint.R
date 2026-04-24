#' Otimização conjunta masculino/feminino com um único MILP
#'
#' Variante de [orce_hibrido()] que elimina as infeasibilidades do método
#' sequencial ao otimizar a alocação de entrevistadores de ambos os gêneros
#' simultaneamente em um único modelo MILP. Retorna estrutura compatível com
#' [pns.zonas::orce_hibrido()].
#'
#' @param ucs `tibble` com colunas requeridas por [orce()].
#' @param agencias `tibble` com colunas requeridas por [orce()] mais
#'   `n_masculino` e `n_feminino` (número de entrevistadores por gênero).
#' @param distancias_ucs `tibble` com distâncias UC-agência.
#' @param distancias_agencias `tibble` com distâncias agência-agência (para treinamento).
#' @param alocar_por Coluna de agrupamento de UCs. Padrão: `"uc"`.
#' @param custo_litro_combustivel Custo do litro de combustível (R$). Padrão: 6.
#' @param kml Consumo do veículo (km/l). Padrão: 10.
#' @param custo_hora_viagem Custo por hora de viagem (R$). Padrão: 10.
#' @param diarias_entrevistador_max Máximo de diárias por entrevistador. Padrão: `Inf`.
#' @param remuneracao_entrevistador Remuneração mensal por entrevistador (R$). Padrão: 3000.
#' @param n_entrevistadores_min Mínimo de entrevistadores por agência ativa. Padrão: 1.
#' @param n_entrevistadores_tipo `"continuous"` ou `"integer"`. Padrão: `"continuous"`.
#' @param dias_coleta_entrevistador_max Máximo de dias de coleta por entrevistador por período. Padrão: 100.
#' @param dias_treinamento Dias de treinamento. Padrão: 0.
#' @param agencias_treinadas Vetor de agências já treinadas.
#' @param agencias_treinamento Vetor de agências de treinamento.
#' @param entrevistadores_por_uc Entrevistadores necessários por UC. Padrão: 1.
#' @param adicional_troca_jurisdicao Custo adicional por troca de jurisdição (R$). Padrão: 0.
#' @param fixar_atribuicoes_masculino `data.frame` com `uc`, `agencia_codigo` e
#'   opcionalmente `valor` (1=forçar, 0=bloquear) para o sub-problema masculino.
#' @param fixar_atribuicoes_feminino Idem para o sub-problema feminino.
#' @param solver Nome do solver ROI. Padrão: `"highs"`.
#' @param rel_tol Tolerância relativa de otimalidade. Padrão: `1e-4`.
#' @param max_time Tempo máximo de solver (segundos). Padrão: 3600.
#' @param seed Semente aleatória opcional.
#' @param resultado_completo Se `TRUE`, inclui `ucs_agencias_todas` em cada resultado.
#' @param ... Argumentos adicionais passados ao solver.
#'
#' @return Lista com `alocacao`, `res_masculino`, `res_feminino` e `res_base`,
#'   compatível com a saída de [pns.zonas::orce_hibrido()].
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

  # ── Prepare agency subsets ───────────────────────────────────────────────────
  agencias_full <- agencias |>
    dplyr::filter(.data$n_masculino > 0 | .data$n_feminino > 0)

  agencias_m <- agencias_full |>
    dplyr::filter(.data$n_masculino > 0) |>
    dplyr::mutate(n_entrevistadores_agencia_max = .data$n_masculino)

  agencias_f <- agencias_full |>
    dplyr::filter(.data$n_feminino > 0) |>
    dplyr::mutate(n_entrevistadores_agencia_max = .data$n_feminino)

  dist_m <- distancias_ucs |>
    dplyr::filter(.data$agencia_codigo %in% agencias_m$agencia_codigo)
  dist_f <- distancias_ucs |>
    dplyr::filter(.data$agencia_codigo %in% agencias_f$agencia_codigo)

  shared_args <- list(
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

  # ── 1. Cost matrices (no solver) ─────────────────────────────────────────────
  cli::cli_progress_step("Preparando matrizes de custo (masculino)")
  prep_m <- do.call(.orce_costs, c(
    list(ucs = ucs, agencias = agencias_m, distancias_ucs = dist_m),
    shared_args
  ))

  cli::cli_progress_step("Preparando matrizes de custo (feminino)")
  prep_f <- do.call(.orce_costs, c(
    list(ucs = ucs, agencias = agencias_f, distancias_ucs = dist_f),
    shared_args
  ))

  n   <- prep_m$n      # same UCs for both
  m_m <- prep_m$m
  m_f <- prep_f$m
  p   <- prep_m$p

  # days per UC per period (constant across agencies)
  dias_arr <- prep_m$dias_coleta_arr[, 1L, ]

  # ── 2. Bilateral agencies (both genders) ─────────────────────────────────────
  ag_m   <- prep_m$agencias_t$agencia_codigo
  ag_f   <- prep_f$agencias_t$agencia_codigo
  both   <- intersect(ag_m, ag_f)
  m_b    <- length(both)
  full_jm <- match(both, ag_m)
  full_jf <- match(both, ag_f)

  # ── 3. Assemble MILP environment ─────────────────────────────────────────────
  transport_m <- prep_m$transport_cost_i_j
  transport_f <- prep_f$transport_cost_i_j
  diarias_m   <- prep_m$diarias_i_j
  diarias_f   <- prep_f$diarias_i_j

  fixed_cost_m_coef <- prep_m$agencias_t$custo_fixo
  fixed_cost_f_coef <- prep_f$agencias_t$custo_fixo
  if (m_b > 0L) {
    fuel_saving       <- (prep_m$fuel_cost_i_j[, full_jm, drop = FALSE] +
                          prep_f$fuel_cost_i_j[, full_jf, drop = FALSE]) / 2
    custo_fixo_full   <- prep_m$agencias_t$custo_fixo[full_jm]
    fixed_cost_m_coef[full_jm] <- 0
    fixed_cost_f_coef[full_jf] <- 0
  } else {
    fuel_saving     <- matrix(0, nrow = n, ncol = 0)
    custo_fixo_full <- numeric(0)
  }

  fix_m <- .joint_translate_fixar(fixar_atribuicoes_masculino,
                                   prep_m$ucs_i, prep_m$agencias_t)
  fix_f <- .joint_translate_fixar(fixar_atribuicoes_feminino,
                                   prep_f$ucs_i, prep_f$agencias_t)

  env <- list2env(list(
    n = n, m_m = m_m, m_f = m_f, m_b = m_b, p = p,
    transport_m          = transport_m,
    transport_f          = transport_f,
    fuel_saving          = fuel_saving,
    dias_arr             = dias_arr,
    diarias_m            = diarias_m,
    diarias_f            = diarias_f,
    n_max_m              = prep_m$agencias_t$n_entrevistadores_agencia_max,
    n_max_f              = prep_f$agencias_t$n_entrevistadores_agencia_max,
    fixed_cost_m_coef    = fixed_cost_m_coef,
    fixed_cost_f_coef    = fixed_cost_f_coef,
    custo_fixo_full      = custo_fixo_full,
    training_m           = prep_m$agencias_t$custo_treinamento_por_entrevistador,
    training_f           = prep_f$agencias_t$custo_treinamento_por_entrevistador,
    full_jm              = full_jm,
    full_jf              = full_jf,
    fix_m                = fix_m,
    fix_f                = fix_f,
    n_entrevistadores_min          = n_entrevistadores_min,
    dias_coleta_entrevistador_max  = dias_coleta_entrevistador_max,
    diarias_entrevistador_max      = diarias_entrevistador_max,
    remuneracao_entrevistador      = remuneracao_entrevistador,
    n_entrevistadores_tipo         = n_entrevistadores_tipo
  ), parent = emptyenv())

  # ── 4. Build and solve joint MILP ────────────────────────────────────────────
  cli::cli_progress_step("Construindo modelo MILP conjunto")
  model <- orce_model_milp_joint(env)

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

  # ── 5. Extract assignments ────────────────────────────────────────────────────
  xm_sol <- ompr::get_solution(result, xm[i, jm]) |>
    dplyr::filter(.data$value > 0.5) |>
    dplyr::select(i, j = "jm")
  xf_sol <- ompr::get_solution(result, xf[i, jf]) |>
    dplyr::filter(.data$value > 0.5) |>
    dplyr::select(i, j = "jf")
  wm_sol <- ompr::get_solution(result, wm[jm]) |>
    dplyr::select(j = "jm", entrevistadores = "value")
  wf_sol <- ompr::get_solution(result, wf[jf]) |>
    dplyr::select(j = "jf", entrevistadores = "value")

  # ── 6. Build per-gender orce-compatible results ───────────────────────────────
  ucs_alocar <- ucs |>
    dplyr::ungroup() |>
    sf::st_drop_geometry() |>
    dplyr::distinct(dplyr::pick(dplyr::all_of(
      unique(c("uc", alocar_por))
    )))

  res_masculino <- .joint_build_resultado(
    xij = xm_sol, workers = wm_sol,
    prep = prep_m, ucs_alocar = ucs_alocar,
    remuneracao_entrevistador = remuneracao_entrevistador,
    resultado_completo = resultado_completo
  )
  res_feminino <- .joint_build_resultado(
    xij = xf_sol, workers = wf_sol,
    prep = prep_f, ucs_alocar = ucs_alocar,
    remuneracao_entrevistador = remuneracao_entrevistador,
    resultado_completo = resultado_completo
  )

  # ── 7. alocacao table ─────────────────────────────────────────────────────────
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

  # ── 8. res_base: jurisdiction baseline ───────────────────────────────────────
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
    entrevistadores_por_uc     = 2L,
    n_entrevistadores_min      = 2L,
    adicional_troca_jurisdicao = adicional_troca_jurisdicao,
    resultado_completo         = TRUE,
    solver                     = solver,
    rel_tol                    = rel_tol,
    max_time                   = max_time
  )

  list(
    alocacao      = alocacao,
    res_masculino = res_masculino,
    res_feminino  = res_feminino,
    res_base      = res_base
  )
}

# Translate fixar_atribuicoes to {fix, blk} index lists for orce_model_milp_joint.
#' @keywords internal
.joint_translate_fixar <- function(fixar, ucs_i, agencias_t) {
  empty <- data.frame(i = integer(0), j = integer(0))
  if (is.null(fixar) || nrow(fixar) == 0L) {
    return(list(fix = empty, blk = empty))
  }
  if (!"valor" %in% names(fixar)) fixar$valor <- 1L
  fi <- match(fixar$uc,           ucs_i$uc)
  fj <- match(fixar$agencia_codigo, agencias_t$agencia_codigo)
  valid <- !is.na(fi) & !is.na(fj)
  if (!any(valid)) return(list(fix = empty, blk = empty))
  df <- data.frame(
    i     = ucs_i$i[fi[valid]],
    j     = agencias_t$j[fj[valid]],
    valor = fixar$valor[valid]
  ) |> unique()
  list(
    fix = df[df$valor == 1L, c("i", "j"), drop = FALSE],
    blk = df[df$valor == 0L, c("i", "j"), drop = FALSE]
  )
}

# Build orce-compatible resultado list from joint MILP solution for one gender.
#' @keywords internal
.joint_build_resultado <- function(xij, workers, prep, ucs_alocar,
                                    remuneracao_entrevistador,
                                    resultado_completo = FALSE) {
  ags_group_vars <- c(names(prep$agencias_t), "entrevistadores")

  resultado_ucs <- prep$dist_uc_agencias |>
    dplyr::inner_join(xij, by = c("i", "j")) |>
    dplyr::left_join(ucs_alocar, by = "uc") |>
    dplyr::left_join(prep$indice_t, by = "t") |>
    dplyr::select(-"i", -"j", -"t", -"custo_deslocamento_com_troca")

  resultado_agencias <- prep$agencias_t |>
    dplyr::inner_join(resultado_ucs, by = "agencia_codigo") |>
    dplyr::select(-"data") |>
    dplyr::group_by(dplyr::pick(dplyr::any_of(ags_group_vars))) |>
    dplyr::summarise(
      dplyr::across(dplyr::where(is.numeric), sum),
      n_trocas_jurisdicao = sum(.data$agencia_codigo != .data$agencia_codigo_jurisdicao),
      n_ucs = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::select(-dplyr::any_of("n_ucs")) |>
    dplyr::left_join(workers, by = "j") |>
    dplyr::select(-"j") |>
    dplyr::mutate(
      custo_total_entrevistadores =
        .data$entrevistadores * remuneracao_entrevistador +
        .data$entrevistadores * .data$custo_treinamento_por_entrevistador
    )

  # Jurisdiction assignment: each UC → its jurisdiction agency (if in the set)
  juris_matching <- prep$ucs_i |>
    dplyr::distinct(.data$i, .data$agencia_codigo_jurisdicao) |>
    dplyr::left_join(
      prep$agencias_t |> dplyr::select("agencia_codigo", j_juris = "j"),
      by = c("agencia_codigo_jurisdicao" = "agencia_codigo")
    ) |>
    dplyr::filter(!is.na(.data$j_juris)) |>
    dplyr::select(i = "i", j = "j_juris")

  resultado_ucs_juris <- prep$dist_uc_agencias |>
    dplyr::inner_join(juris_matching, by = c("i", "j")) |>
    dplyr::left_join(ucs_alocar, by = "uc") |>
    dplyr::left_join(prep$indice_t, by = "t") |>
    dplyr::select(-"i", -"j", -"t", -"custo_deslocamento_com_troca")

  resultado_agencias_juris <- prep$agencias_t |>
    dplyr::inner_join(resultado_ucs_juris, by = "agencia_codigo") |>
    dplyr::select(-"data") |>
    dplyr::group_by(dplyr::pick(dplyr::any_of(ags_group_vars))) |>
    dplyr::summarise(
      dplyr::across(dplyr::where(is.numeric), sum),
      n_trocas_jurisdicao = sum(.data$agencia_codigo != .data$agencia_codigo_jurisdicao),
      n_ucs = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::select(-dplyr::any_of("n_ucs")) |>
    dplyr::mutate(
      entrevistadores = NA_real_,
      custo_total_entrevistadores = NA_real_
    )

  res <- list(
    resultado_ucs_otimo          = resultado_ucs,
    resultado_ucs_jurisdicao     = resultado_ucs_juris,
    resultado_agencias_otimo     = resultado_agencias,
    resultado_agencias_jurisdicao = resultado_agencias_juris
  )
  if (resultado_completo) {
    res$ucs_agencias_todas <- prep$dist_uc_agencias
  }
  res
}
