#' Create a MILP Model for Warehouse TSP Optimization
#'
#' This function creates a Mixed Integer Linear Programming (MILP) model for optimizing
#' warehouse collection unit assignments to agencies with optional TSP routing.
#' This is the high-performance backend (~1000x faster than MIPModel) with the same
#' optimization logic but different internal implementation.
#'
#' @param n Integer. Number of collection units (UCs)
#' @param m Integer. Number of agencies
#' @param p Integer. Number of time periods
#' @param peso_tsp Numeric. TSP weight factor between 0 and 1. When 0, uses
#'   simple round-trip costs. When > 0, enables TSP routing optimization
#' @param n_entrevistadores_tipo Character. Variable type for number of interviewers:
#'   "continuous", "binary", or "integer"
#' @param transport_cost_i_j Matrix. Transportation cost from UC i to agency j (n x m)
#' @param dist_uc_uc Matrix. Distance matrix between UCs (n x n). Used when peso_tsp > 0
#' @param duracao_uc_uc Matrix. Duration matrix between UCs (n x n). Used when peso_tsp > 0
#' @param kml Numeric. Kilometers per liter fuel efficiency
#' @param custo_litro_combustivel Numeric. Cost per liter of fuel
#' @param custo_hora_viagem Numeric. Cost per hour of travel time
#' @param dias_coleta_ijt Function. Returns collection days for UC i at agency j in period t
#' @param agencias_t Data.frame. Agency data with columns: custo_fixo,
#'   custo_treinamento_por_entrevistador, n_entrevistadores_agencia_max
#' @param remuneracao_entrevistador Numeric. Base salary per interviewer
#' @param n_entrevistadores_min Integer. Minimum number of interviewers per active agency
#' @param dias_coleta_entrevistador_max Integer. Maximum collection days per interviewer
#' @param ti Matrix. Time indicator matrix (n x p) indicating if UC i is active in period t
#' @param diarias_entrevistador_max Numeric. Maximum daily allowance per interviewer
#' @param diarias_i_j Matrix. Daily allowance matrix from UC i to agency j (n x m)
#' @param ... Additional arguments (reserved for future use)
#'
#' @return An OMPR MILPModel object ready for solving
#'
#' @details
#' This function creates the same optimization model as \code{\link{model_mip}} but uses
#' the experimental MILP backend which is approximately 1000x faster. The model formulation
#' is identical, but internal representations use vectorized operations and \code{colwise}
#' wrappers for efficiency.
#'
#' The model includes:
#' - Assignment variables: x[i,j] = 1 if UC i assigned to agency j
#' - Agency activation: y[j] = 1 if agency j is active
#' - Interviewer allocation: w[j] = number of interviewers at agency j
#' - TSP routing (if peso_tsp > 0): route[i,k,j,t] and subtour elimination variables
#'
#' **Performance Note**: Always validate results against \code{model_mip} with small
#' test cases to ensure correctness, as the MILP backend is experimental.
#'
#' @export
#' @seealso \code{\link{model_mip}} for the standard MIP backend
#' @examples
#' \dontrun{
#' # Example with TSP optimization (high-performance backend)
#' model <- model_milp(
#'   n = 100, m = 5, p = 4, peso_tsp = 0.3,
#'   n_entrevistadores_tipo = "integer",
#'   transport_cost_i_j = matrix(runif(500), 100, 5),
#'   # ... other parameters
#' )
#' }
model_milp <- function(n, m, p, peso_tsp, n_entrevistadores_tipo, transport_cost_i_j, dist_uc_uc,
                       duracao_uc_uc, kml, custo_litro_combustivel,
                       custo_hora_viagem, dias_coleta_ijt, agencias_t,
                       remuneracao_entrevistador, n_entrevistadores_min,
                       dias_coleta_entrevistador_max, ti, diarias_entrevistador_max,
                       diarias_i_j, ...) {
  transport_cost_fun <- function(i, j) {
    result <- vapply(seq_along(i), function(k) {
      value <-  transport_cost_i_j[i[k], j[k]]
      value
    }, numeric(1L))
    result
  }

  transport_cost_simple_fun <- function(i, j) {
    result <- vapply(seq_along(i), function(k) {
      value <- transport_cost_i_j[i[k], j[k]]
      value
    }, numeric(1L))
    result
  }

  fixed_cost_fun <- function(j) {
    result <- vapply(seq_along(j), function(k) {
      value <- agencias_t$custo_fixo[j[k]]
      value
    }, numeric(1L))
    result
  }

  training_cost_fun <- function(j) {
    result <- vapply(seq_along(j), function(k) {
      base_cost <- remuneracao_entrevistador
      training_cost <- agencias_t$custo_treinamento_por_entrevistador[j[k]]
      value <- base_cost + training_cost
      value
    }, numeric(1L))
    result
  }

  tsp_cost_fun <- function(i, k, j, t) {
    result <- vapply(seq_along(i), function(idx) {
      dist_cost <- dist_uc_uc[i[idx], k[idx]] / kml * custo_litro_combustivel
      time_cost <- duracao_uc_uc[i[idx], k[idx]] * custo_hora_viagem
      collection_indicator <- dias_coleta_ijt(i[idx], j[idx], t[idx]) > 0
      value <-  (dist_cost + time_cost) * collection_indicator
      value
    }, numeric(1L))
    result
  }

  dias_coleta_fun <- function(i, j, t) {
    result <- vapply(seq_along(i), function(k) {
      value <- dias_coleta_ijt(i[k], j[k], t[k])
      value
    }, numeric(1L))
    result
  }

  ti_fun <- function(i, t) {
    result <- vapply(seq_along(i), function(k) {
      value <- ti[i[k], t[k]]
      value
    }, numeric(1L))
    result
  }

  max_entrevistadores_fun <- function(j) {
    result <- vapply(seq_along(j), function(k) {
      value <- agencias_t$n_entrevistadores_agencia_max[j[k]]
      value
    }, numeric(1L))
    result
  }

  diarias_fun <- function(i, j) {
    result <- vapply(seq_along(i), function(k) {
      value <- diarias_i_j[i[k], j[k]]
      value
    }, numeric(1L))
    result
  }

  model <- ompr::MILPModel() |>
    # 1 sse uc i vai para a agencia j
    ompr::add_variable(x[i, j], i = 1:n, j = 1:m, type = "binary") |>
    # 1 sse agencia j ativada
    ompr::add_variable(y[j], j = 1:m, type = "binary") |>
    # trabalhadores na agencia j
    ompr::add_variable(w[j], j = 1:m, type = n_entrevistadores_tipo, lb = 0, ub = Inf)


  # Adicionar variáveis TSP somente se peso_tsp > 0
  if (peso_tsp > 0) {
    model <- model |>
      # TSP routing: 1 sse rota vai de uc i para uc k dentro da agencia j no período t
      ompr::add_variable(route[i, k, j, t], i = 1:n, k = 1:n, j = 1:m, t = 1:p, type = "binary") |>
      # TSP subtour elimination auxiliar por período
      ompr::add_variable(u[i, j, t], i = 1:n, j = 1:m, t = 1:p, type = "continuous", lb = 1, ub = n)
  }


  # Definir objetivo condicionalmente
  if (peso_tsp > 0) {
    model <- model |>
      # minimizar custos com blend de round-trip e TSP
      ompr::set_objective(
        # Custos de transporte com ponderação TSP
        sum_expr(colwise(transport_cost_fun(i, j)) * x[i, j], i = 1:n, j = 1:m) +
          # Custos de roteamento TSP por período (peso peso_tsp)
          sum_expr(peso_tsp*colwise(tsp_cost_fun(i, k, j, t)) * route[i, k, j, t], i = 1:n, k = 1:n, j = 1:m, t = 1:p) +
          # Custos fixos e entrevistadores
          sum_expr(agencias_t$custo_fixo[j] * y[j] +
                     (remuneracao_entrevistador + agencias_t$custo_treinamento_por_entrevistador[j]) * w[j],
                   j = 1:m),
        "min"
      )
  } else {
    model <- model |>
      # minimizar custos sem TSP
      ompr::set_objective(
        # Custos de transporte completos
        sum_expr(colwise(transport_cost_simple_fun(i, j)) * x[i, j], i = 1:n, j = 1:m) +
          # Custos fixos e entrevistadores
          sum_expr(agencias_t$custo_fixo[j] * y[j] +
                     (remuneracao_entrevistador + agencias_t$custo_treinamento_por_entrevistador[j]) * w[j],
                   j = 1:m),
        "min"
      )
  }

  model <- model |>
    # toda UC precisa estar associada a uma agencia
    ompr::add_constraint(sum_expr(x[i, j], j = 1:m) == 1, i = 1:n) |>
    # se uma UC está designada a uma agencia, a agencia tem que ficar ativa
    ompr::add_constraint(x[i, j] <= y[j], i = 1:n, j = 1:m) |>
    # se agencia está ativa, w tem que ser >= n_entrevistadores_min
    ompr::add_constraint((y[j] * n_entrevistadores_min) <= w[j], j = 1:m) |>
    # w tem que ser suficiente para dar conta das ucs para todos os períodos
    ompr::add_constraint(sum_expr(x[i, j] * colwise(dias_coleta_fun(i, j, t)), i = 1:n) <=
                           (w[j] * dias_coleta_entrevistador_max), j = 1:m, t = 1:p)

  # Adicionar constraints TSP somente se peso_tsp > 0
  if (peso_tsp > 0) {
    model <- model |>
      # TSP constraints: route só existe se ambas UCs estão na mesma agência e mesmo período
      ompr::add_constraint(route[i, k, j, t] <= (x[i, j] * colwise(ti_fun(i, t))),
                           i = 1:n, k = 1:n, j = 1:m, t = 1:p) |>
      ompr::add_constraint(route[i, k, j, t] <= (x[k, j] * colwise(ti_fun(k, t))),
                           i = 1:n, k = 1:n, j = 1:m, t = 1:p) |>
      # TSP: cada UC sai para exatamente uma outra UC na mesma agência por período (ciclo fechado)
      ompr::add_constraint(sum_expr(route[i, k, j, t], k = 1:n) == x[i, j] * colwise(ti_fun(i, t)),
                           i = 1:n, j = 1:m, t = 1:p) |>
      # TSP: cada UC recebe de exatamente uma outra UC na mesma agência por período (ciclo fechado)
      ompr::add_constraint(sum_expr(route[i, k, j, t], i = 1:n) == x[k, j] * colwise(ti_fun(k, t)),
                           k = 1:n, j = 1:m, t = 1:p) |>
      # you cannot go to the same city
      set_bounds(route[i, i,j,t], ub = 0, i = 1:n,j=1:m, t=1:p) |>
      # TSP: subtour elimination (Miller-Tucker-Zemlin) por período
      # Primeiro garantimos que u[i,j,t] >= 2 para i >= 2
      ompr::add_constraint(u[i, j, t] >= 2, i = 2:n, j = 1:m, t = 1:p) |>
      # Depois aplicamos a restrição MTZ para eliminar subciclos
      ompr::add_constraint(u[i, j, t] - u[k, j, t] + 1 <= ((n - 1) * (1 - route[i, k, j, t])),
                           i = 2:n, k = 2:n, j = 1:m, t = 1:p)
  }
  # Respeitar o máximo de entrevistadores por agencia
  if (any(is.finite(agencias_t$n_entrevistadores_agencia_max))) {
    model <- model |>
      ompr::add_constraint(w[j] <= colwise(max_entrevistadores_fun(j)), j = 1:m)
  }
  # Respeitar o máximo de diárias por entrevistador
  if (any(is.finite(diarias_entrevistador_max))) {
    model <- model |>
      ompr::add_constraint(sum_expr(x[i, j] * colwise(diarias_fun(i, j)), i = 1:n) <=
                           (diarias_entrevistador_max * w[j]), j = 1:m)
  }

  model
}
