#' Construtor do modelo OMPR usando MILPModel (vetorizado)
#'
#' Esta função constrói o modelo equivalente a `orce_model_mip()` porém
#' utilizando a backend vetorizada `MILPModel`, com `sum_expr()` e `colwise()`.
#'
#' Ela recebe um ambiente com todos os objetos preparados por `.orce_impl`
#' (por exemplo: `n`, `m`, `p`, `n_uc`, `N`, `agencias_t`, `ucs_i`,
#' `transport_cost_i_j`, `diarias_i_j`, `dias_coleta_ijt`, `distancias_ucs_ucs`,
#' `peso_tsp`, `kml`, `custo_litro_combustivel`, `remuneracao_entrevistador`,
#' `n_entrevistadores_min`, `dias_coleta_entrevistador_max`, etc.) e retorna um
#' `ompr::MILPModel` pronto para ser resolvido.
#'
#' @param env Ambiente contendo todos os objetos necessários ao modelo.
#' @return Um objeto `ompr::MILPModel` com variáveis, restrições e objetivo definidos.
#' @export
orce_model_milp <- function(env) {
  with(env, {
    stopifnot((agencias_t$j) == (seq_len(nrow(agencias_t))))

    # pressupõe que distancias_ucs_ucs já está em formato matriz N x N (preprocessado em .orce_impl)
    tsp <- peso_tsp > 0

    # função vetorizada para dias_coleta_ijt(i,j,t) usada em sum_expr(colwise(...))
    dct <- function(i, j, t) {
      vapply(seq_along(i), function(k) dias_coleta_ijt(i[k], j[k], t[k]), numeric(1))
    }

    # Modelo MILP
    model <- ompr::MILPModel() |>
      # 1 sse uc i vai para a agencia j
      ompr::add_variable(x[i, j], i = 1:n, j = 1:m, type = "binary") |>
      # 1 sse agencia j ativada
      ompr::add_variable(y[j], j = 1:m, type = "binary") |>
      # trabalhadores na agencia j
      ompr::add_variable(w[j], j = 1:m, type = n_entrevistadores_tipo, lb = 0, ub = Inf)

    if (tsp) {
      model <- model |>
        # route[i,k,j] = 1 se o vendedor j percorre o arco i->k (multi-depósito)
        ompr::add_variable(route[i, k, j], i = 1:N, k = 1:N, j = 1:m, type = "binary") |>
        # variável auxiliar MTZ apenas para nós de UCs (indexadas 1..n_uc)
        ompr::add_variable(u[q, j], q = 1:n_uc, j = 1:m, lb = 1, ub = n_uc) |>
        # proibir auto-loop em qualquer nó (ub = 0 em route[i,i,j])
        ompr::set_bounds(route[i, i, j], ub = 0, i = 1:N, j = 1:m) |>
        # conservação de fluxo apenas nos nós de UCs: sum_in == sum_out
        ompr::add_constraint(
          ompr::sum_expr(route[f, m + q, j], f = 1:N) -
            ompr::sum_expr(route[m + q, t, j], t = 1:N) == 0,
          q = 1:n_uc, j = 1:m
        ) |>
        # acoplamento com a atribuição x: uma saída e uma entrada por UC
        ompr::add_constraint(ompr::sum_expr(route[m + i, t, j], t = 1:N) == x[i, j], i = 1:n, j = 1:m) |>
        ompr::add_constraint(ompr::sum_expr(route[f, m + i, j], f = 1:N) == x[i, j], i = 1:n, j = 1:m) |>
        # cada vendedor j sai de sua própria base j exatamente uma vez se ativo
        ompr::add_constraint(ompr::sum_expr(route[j, t, j], t = (m + 1):N) == y[j], j = 1:m) |>
        # e retorna para sua base j exatamente uma vez se ativo
        ompr::add_constraint(ompr::sum_expr(route[f, j, j], f = (m + 1):N) == y[j], j = 1:m) |>
        # proibir arcos base->base
        ompr::add_constraint(route[a, b, j] == 0, a = 1:m, b = 1:m, j = 1:m) |>
        # proibir uso de base j por vendedor r != j
        ompr::add_constraint(ompr::sum_expr(route[j, t, r], t = 1:N) == 0, j = 1:m, r = 1:m, r != j) |>
        ompr::add_constraint(ompr::sum_expr(route[t, j, r], t = 1:N) == 0, j = 1:m, r = 1:m, r != j) |>
        # MTZ apenas sobre nós de UCs (evita subtours) para q != r
        ompr::add_constraint(
          u[q, j] - u[r, j] + 1 <= (n_uc) * (1 - route[m + q, m + r, j]),
          q = 1:n_uc, r = 1:n_uc, j = 1:m, q != r
        )
    }

    # Objetivo
    if (tsp) {
      model <- model |>
        ompr::set_objective(
          # custo de rota TSP ponderado
          (custo_litro_combustivel * peso_tsp / kml) *
            ompr::sum_expr(ompr::colwise(distancias_ucs_ucs[i, k]) * route[i, k, j], i = 1:N, k = 1:N, j = 1:m) +
            # custos de transporte (alocação)
            ompr::sum_expr(ompr::colwise(transport_cost_i_j[i, j]) * x[i, j], i = 1:n, j = 1:m) +
            # custos fixos e de entrevistadores
            ompr::sum_expr(ompr::colwise(agencias_t$custo_fixo[j]) * y[j], j = 1:m) +
            remuneracao_entrevistador * ompr::sum_expr(w[j], j = 1:m) +
            ompr::sum_expr(ompr::colwise(agencias_t$custo_treinamento_por_entrevistador[j]) * w[j], j = 1:m),
          sense = "min"
        )
    } else {
      model <- model |>
        ompr::set_objective(
          ompr::sum_expr(ompr::colwise(transport_cost_i_j[i, j]) * x[i, j], i = 1:n, j = 1:m) +
            ompr::sum_expr(ompr::colwise(agencias_t$custo_fixo[j]) * y[j], j = 1:m) +
            remuneracao_entrevistador * ompr::sum_expr(w[j], j = 1:m) +
            ompr::sum_expr(ompr::colwise(agencias_t$custo_treinamento_por_entrevistador[j]) * w[j], j = 1:m),
          sense = "min"
        )
    }

    # Restrições gerais
    model <- model |>
      # toda UC precisa estar associada a uma agencia
      ompr::add_constraint(ompr::sum_expr(x[i, j], j = 1:m) == 1, i = 1:n) |>
      # se uma UC está designada a uma agencia, a agencia tem que ficar ativa
      ompr::add_constraint(x[i, j] <= y[j], i = 1:n, j = 1:m) |>
      # se agencia está ativa, w tem que ser >= n_entrevistadores_min
      ompr::add_constraint((y[j] * n_entrevistadores_min) <= w[j], j = 1:m) |>
      # w tem que ser suficiente para dar conta das ucs para todos os períodos
      ompr::add_constraint(
        ompr::sum_expr(ompr::colwise(dct(i, j, t)) * x[i, j], i = 1:n) <= w[j] * dias_coleta_entrevistador_max,
        j = 1:m, t = 1:p
      )

    # Respeitar o máximo de entrevistadores por agencia
    if (any(is.finite(agencias_t$n_entrevistadores_agencia_max))) {
      model <- model |>
        ompr::add_constraint(w[j] <= ompr::colwise(agencias_t$n_entrevistadores_agencia_max[j]), j = 1:m)
    }
    # Respeitar o máximo de diárias por entrevistador
    if (any(is.finite(diarias_entrevistador_max))) {
      model <- model |>
        ompr::add_constraint(
          ompr::sum_expr(ompr::colwise(diarias_i_j[i, j]) * x[i, j], i = 1:n) <= diarias_entrevistador_max * w[j],
          j = 1:m
        )
    }

    model
  })
}
