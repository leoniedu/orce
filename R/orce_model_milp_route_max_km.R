#' Construtor MILP com poda de arcos UC-UC por distância
#'
#' Gera uma função construtora de modelo (compatível com `orce_function`)
#' baseada em `orce_model_milp()`, que mantém todos os arcos base↔UC para
#' todas as bases e vendedores e restringe apenas arcos UC↔UC acima de um
#' limite de distância `route_max_km`. A implementação usa `MILPModel` com
#' limites superiores vetorizados por variável para reduzir o tamanho do
#' modelo e acelerar o presolve.
#'
#' @param route_max_km Limite máximo de distância para permitir arcos UC↔UC.
#'   Padrão: `Inf` (sem poda). Use, por exemplo, 200–400 para podar arcos longos.
#'
#' @return Uma função `function(env) {...}` que constrói e retorna um
#'   `ompr::MILPModel` usando o limite informado.
#' @export
orce_model_milp_route_max_km <- function(route_max_km = Inf) {
  force(route_max_km)
  function(env) {
    # Torna o cutoff acessível dentro de with(env, { ... })
    env$route_max_km <- route_max_km
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
        # Vetorizar limites superiores por variável para reduzir o modelo:
        # - Sempre permitir arcos base↔UC (para todas as bases e vendedores),
        # - Proibir arcos UC↔UC cuja distância excede route_max_km,
        # - Proibir auto-loops e base↔base.
        grid_route <- expand.grid(i = 1:N, k = 1:N, j = 1:m)
        is_base_i <- grid_route$i <= m
        is_base_k <- grid_route$k <= m
        no_self   <- grid_route$i != grid_route$k
        d_ik <- distancias_ucs_ucs[cbind(grid_route$i, grid_route$k)]
        allow_uc_uc <- (!is_base_i & !is_base_k) & (d_ik <= route_max_km)
        allow_base_uc <- xor(is_base_i, is_base_k)
        allow <- no_self & !(is_base_i & is_base_k) & (allow_base_uc | allow_uc_uc)
        ub_vec <- as.numeric(allow)
        model <- model |>
          # route[i,k,j] = 1 se o vendedor j percorre o arco i->k (multi-depósito)
          ompr::add_variable(route[grid_route$i, grid_route$k, grid_route$j], type = "integer", lb = 0, ub = ub_vec) |>
          # variável auxiliar MTZ apenas para nós de UCs (indexadas 1..n_uc)
          ompr::add_variable(u[q, j], q = 1:n_uc, j = 1:m, lb = 1, ub = n_uc) |>
          ## start comment
          ## proibir auto-loop em qualquer nó (ub = 0 em route[i,i,j])
          # ompr::set_bounds(route[i, i, j], ub = 0, i = 1:N, j = 1:m) |>
          # # proibir arcos base->base
          # ompr::add_constraint(route[a, b, j] == 0, a = 1:m, b = 1:m, j = 1:m) |>
          # # proibir uso de base j por vendedor r != j
          # ompr::add_constraint(ompr::sum_expr(route[j, t, r], t = 1:N) == 0, j = 1:m, r = 1:m, r != j) |>
          # ompr::add_constraint(ompr::sum_expr(route[t, j, r], t = 1:N) == 0, j = 1:m, r = 1:m, r != j) |>
          ## end comment
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
}
