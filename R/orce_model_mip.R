#' Construtor padrão do modelo OMPR do ORCE
#'
#' Esta função recebe um ambiente com todos os objetos preparados por `.orce_impl`
#' (por exemplo: `n`, `m`, `p`, `n_uc`, `N`, `agencias_t`, `ucs_i`, `transport_cost_i_j`,
#' `diarias_i_j`, `dias_coleta_ijt`, `distancias_nos`, `peso_tsp`, `kml`,
#' `custo_litro_combustivel`, `remuneracao_entrevistador`, `n_entrevistadores_min`, etc.)
#' e retorna um `ompr::MIPModel` pronto para ser resolvido.
#'
#' @param env Ambiente contendo todos os objetos necessários ao modelo.
#' @return Um objeto `ompr::MIPModel` com variáveis, restrições e objetivo definidos.
#' @export
orce_model_mip <- function(env) {
  with(env, {
    # Índices básicos já devem estar definidos em env
    stopifnot((agencias_t$j) == (1:nrow(agencias_t)))
    model <- ompr::MIPModel() |>
      # 1 sse uc i vai para a agencia j
      ompr::add_variable(x[i, j], i = 1:n, j = 1:m, type = "binary") |>
      # 1 sse agencia j ativada
      ompr::add_variable(y[j], j = 1:m, type = "binary") |>
      # trabalhadores na agencia j
      ompr::add_variable(w[j], j = 1:m, type = n_entrevistadores_tipo, lb = 0, ub = Inf)

    tsp <- peso_tsp > 0
    if (tsp) {

      model <- model |>
        # route[i,k,j] = 1 se o vendedor j percorre o arco i->k (multi-depósito)
        ompr::add_variable(route[i, k, j], i = 1:N, k = 1:N, j = 1:m, type = "binary") |>

        # variável auxiliar MTZ apenas para nós de UCs (indexadas 1..n_uc)
        ompr::add_variable(u[q, j], q = 1:n_uc, j = 1:m, lb = 1, ub = n_uc) |>
        # proibir auto-loop em qualquer nó
        ompr::add_constraint(route[i, i, j] == 0, i = 1:N, j = 1:m) |>
        # conservação de fluxo apenas nos nós de UCs
        ompr::add_constraint(ompr::sum_over(route[f, m + q, j], f = 1:N) == ompr::sum_over(route[m + q, t, j], t = 1:N), q = 1:n_uc, j = 1:m) |>
        # acoplamento com a atribuição x: uma saída e uma entrada por UC e vendedor se x[i,j]==1
        ompr::add_constraint(ompr::sum_over(route[m + i, t, j], t = 1:N) == x[i, j], i = 1:n, j = 1:m) |>
        ompr::add_constraint(ompr::sum_over(route[f, m + i, j], f = 1:N) == x[i, j], i = 1:n, j = 1:m) |>

        # cada vendedor j sai de sua própria base j exatamente uma vez se ativo
        ompr::add_constraint(ompr::sum_over(route[j, t, j], t = (m + 1):N) == y[j], j = 1:m) |>
        # e retorna para sua base j exatamente uma vez se ativo
        ompr::add_constraint(ompr::sum_over(route[f, j, j], f = (m + 1):N) == y[j], j = 1:m) |>

        # proibir arcos base->base e uso de base por vendedor diferente
        ompr::add_constraint(route[a, b, j] == 0, a = 1:m, b = 1:m, j = 1:m) |>
        ompr::add_constraint(ompr::sum_over(route[j, t, r], t = 1:N) == 0, j = 1:m, r = 1:m, r != j) |>
        ompr::add_constraint(ompr::sum_over(route[t, j, r], t = 1:N) == 0, j = 1:m, r = 1:m, r != j) |>

        # MTZ apenas sobre nós de UCs
        ompr::add_constraint(u[q, j] >= 1, q = seq_along(1:n_uc), j = 1:m) |>
        ompr::add_constraint(u[q, j] - u[r, j] + 1 <= (n_uc) * (1 - route[m + q, m + r, j]), q = seq_along(1:n_uc), r = seq_along(1:n_uc), j = 1:m) |>

        # minimizar distância de rota + custos de alocação/ativação
        ompr::set_objective(
          custo_litro_combustivel * peso_tsp *
            (ompr::sum_over(distancias_nos[i, k] * route[i, k, j], i = 1:N, k = 1:N, j = 1:m)) / kml +
            ompr::sum_over(transport_cost_i_j[i, j] * x[i, j], i = 1:n, j = 1:m) +
            ompr::sum_over((agencias_t$custo_fixo[j]) * y[j] +
                             w[j] * (remuneracao_entrevistador + agencias_t$custo_treinamento_por_entrevistador[j]),
                           j = 1:m)
        , "min")
    } else {
      model <- model |>
        # minimizar custos
        ompr::set_objective(
          ompr::sum_over(transport_cost_i_j[i, j] * x[i, j], i = 1:n, j = 1:m) +
            ompr::sum_over((agencias_t$custo_fixo[j]) * y[j] +
                             w[j] * (remuneracao_entrevistador + agencias_t$custo_treinamento_por_entrevistador[j]),
                           j = 1:m),
          "min"
        )
    }

    # Restrições gerais (fora do bloco TSP)
    model <- model |>
      # toda UC precisa estar associada a uma agencia
      ompr::add_constraint(ompr::sum_over(x[i, j], j = 1:m) == 1, i = 1:n) |>
      # se uma UC está designada a uma agencia, a agencia tem que ficar ativa
      ompr::add_constraint(x[i, j] <= y[j], i = 1:n, j = 1:m) |>
      # se agencia está ativa, w tem que ser >= n_entrevistadores_min
      ompr::add_constraint((y[j] * n_entrevistadores_min) <= w[j], j = 1:m) |>
      # w tem que ser suficiente para dar conta das ucs para todos os períodos
      ompr::add_constraint(ompr::sum_over(x[i, j] * dias_coleta_ijt(i, j, t), i = 1:n) <= (w[j] * dias_coleta_entrevistador_max), j = 1:m, t = 1:p)

    # Respeitar o máximo de entrevistadores por agencia
    if (any(is.finite(agencias_t$n_entrevistadores_agencia_max))) {
      model <- model |>
        ompr::add_constraint(w[j] <= agencias_t$n_entrevistadores_agencia_max[j], j = 1:m)
    }
    # Respeitar o máximo de diárias por entrevistador
    if (any(is.finite(diarias_entrevistador_max))) {
      model <- model |>
        ompr::add_constraint(ompr::sum_over(x[i, j] * diarias_i_j[i, j], i = 1:n) <= (diarias_entrevistador_max * w[j]), j = 1:m)
    }

    model
  })
}
