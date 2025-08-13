#' Create a MIP Model for Warehouse TSP Optimization
#'
#' This function creates a Mixed Integer Programming (MIP) model for optimizing
#' warehouse collection unit assignments to agencies with optional TSP routing.
#' The model minimizes total costs including transportation, fixed costs, and
#' interviewer expenses.
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
#' @return An OMPR MIPModel object ready for solving
#'
#' @details
#' The model includes:
#' - Assignment variables: x[i,j] = 1 if UC i assigned to agency j
#' - Agency activation: y[j] = 1 if agency j is active
#' - Interviewer allocation: w[j] = number of interviewers at agency j
#' - TSP routing (if peso_tsp > 0): route[i,k,j,t] and subtour elimination variables
#'
#' Constraints ensure:
#' - Each UC assigned to exactly one agency
#' - Agency activation requirements
#' - Minimum interviewer requirements
#' - Capacity constraints
#' - TSP constraints (if enabled)
#' - Optional limits on interviewers and daily allowances
#'
#' @export
#' @examples
#' \dontrun{
#' # Example with simple round-trip optimization (no TSP)
#' model <- model_mip(
#'   n = 10, m = 3, p = 2, peso_tsp = 0,
#'   n_entrevistadores_tipo = "integer",
#'   transport_cost_i_j = matrix(runif(30), 10, 3),
#'   # ... other parameters
#' )
#' }
model_mip <- function(n, m, p, peso_tsp, n_entrevistadores_tipo, transport_cost_i_j,
                      dist_uc_uc, duracao_uc_uc, kml, custo_litro_combustivel,
                      custo_hora_viagem, dias_coleta_ijt, agencias_t,
                      remuneracao_entrevistador, n_entrevistadores_min,
                      dias_coleta_entrevistador_max, ti, diarias_entrevistador_max,
                      diarias_i_j, ...) {

  # Validate inputs
  validate_dimensions(n, m, p)
  validate_peso_tsp(peso_tsp)
  validate_matrix_dimensions(transport_cost_i_j, n, m)

  # Create base model
  model <- create_mip_base_model(n, m, n_entrevistadores_tipo)

  # Add TSP components if needed
  if (peso_tsp > 0) {
    model <-    model |>
      # TSP routing: 1 sse rota vai de uc i para uc k dentro da agencia j no período t
      ompr::add_variable(route[i, k, j, t], i = 1:n, k = 1:n, j = 1:m, t = 1:p, type = "binary") |>
      # TSP subtour elimination auxiliar por período
      ompr::add_variable(u[i, j, t], i = 1:n, j = 1:m, t = 1:p, type = "continuous", lb = 1, ub = n)

    model <-   model |>
      ompr::set_objective(
        # Custos de transporte com ponderação TSP
        ompr::sum_over(transport_cost_i_j[i, j] * x[i, j], i = 1:n, j = 1:m) +
          # Custos de roteamento TSP por período (peso peso_tsp)
          ompr::sum_over(
            (dist_uc_uc[i, k] / kml * custo_litro_combustivel +
              duracao_uc_uc[i, k] * custo_hora_viagem) * (dias_coleta_ijt(i, j, t) > 0) * route[i, k, j, t], i = 1:n, k = 1:n, j = 1:m, t = 1:p) +
          # Custos fixos e entrevistadores
          ompr::sum_over(agencias_t$custo_fixo[j] * y[j] +
                           w[j] * agencias_t$custo_treinamento_por_entrevistador[j],
                         j = 1:m),
        "min"
      )


  } else {
    model <- set_simple_objective(model, n, m, transport_cost_i_j, agencias_t, remuneracao_entrevistador)
  }

  # Add common constraints
  model <- add_common_constraints(model, n, m, p, n_entrevistadores_min, dias_coleta_ijt,
                                  dias_coleta_entrevistador_max)

  # Add TSP constraints if needed
  if (peso_tsp > 0) {
    model |>
      # TSP constraints: route só existe se ambas UCs estão na mesma agência e mesmo período
      ompr::add_constraint(route[i, k, j, t] <= (x[i, j] * ti[i, t]), i = 1:n, k = 1:n, j = 1:m, t = 1:p) |>
      ompr::add_constraint(route[i, k, j, t] <= (x[k, j] * ti[i, t]), i = 1:n, k = 1:n, j = 1:m, t = 1:p) |>
      # TSP: cada UC sai para exatamente uma outra UC na mesma agência por período (ciclo fechado)
      ompr::add_constraint(ompr::sum_over(route[i, k, j, t], k = 1:n) == (x[i, j] * ti[i, t]), i = 1:n, j = 1:m, t = 1:p) |>
      # TSP: cada UC recebe de exatamente uma outra UC na mesma agência por período (ciclo fechado)
      #ompr::add_constraint(ompr::sum_over(route[i, k, j, t], i = 1:n) == (x[k, j] * ti[k, t]), k = 1:n, j = 1:m, t = 1:p) |>
      # you cannot go to the same city
      set_bounds(route[i, i,j,t], ub = 0, i = 1:n,j=1:m, t=1:p) %>%
      # TSP: subtour elimination (Miller-Tucker-Zemlin) por período
      # Primeiro garantimos que u[i,j,t] >= 2 para i >= 2
      ompr::add_constraint(u[i, j, t] >= 2, i = 2:n, j = 1:m, t = 1:p) |>
      # Depois aplicamos a restrição MTZ para eliminar subciclos
      ompr::add_constraint(u[i, j, t] - u[k, j, t] + 1 <= (n - 1) * (1 - route[i, k, j, t]),
                           i = 2:n, k = 2:n, j = 1:m, t = 1:p)
  }

  # Add optional constraints
  model <- add_optional_constraints(model, n, m, agencias_t, diarias_entrevistador_max, diarias_i_j)

  model
}



# MIP-specific model creation
create_mip_base_model <- function(n, m, n_entrevistadores_tipo) {
  ompr::MIPModel() |>
    # 1 sse uc i vai para a agencia j
    ompr::add_variable(x[i, j], i = 1:n, j = 1:m, type = "binary") |>
    # 1 sse agencia j ativada
    ompr::add_variable(y[j], j = 1:m, type = "binary") |>
    # trabalhadores na agencia j
    ompr::add_variable(w[j], j = 1:m, type = n_entrevistadores_tipo, lb = 0, ub = Inf)
}

# set_tsp_objective <- function(model, n, m, p, peso_tsp, transport_cost_i_j, dist_uc_uc, duracao_uc_uc,
#                              kml, custo_litro_combustivel, custo_hora_viagem, dias_coleta_ijt,
#                              agencias_t, remuneracao_entrevistador) {
# }

set_simple_objective <- function(model, n, m, transport_cost_i_j, agencias_t, remuneracao_entrevistador) {
  model |>
    ompr::set_objective(
      # Custos de transporte completos
      ompr::sum_over(transport_cost_i_j[i, j] * x[i, j], i = 1:n, j = 1:m) +
        # Custos fixos e entrevistadores
        ompr::sum_over(agencias_t$custo_fixo[j] * y[j] +
                       w[j] * (agencias_t$custo_treinamento_por_entrevistador[j]+remuneracao_entrevistador),
                       j = 1:m),
      "min"
    )
}

add_common_constraints <- function(model, n, m, p, n_entrevistadores_min, dias_coleta_ijt,
                                  dias_coleta_entrevistador_max) {
  model |>
    # toda UC precisa estar associada a uma agencia
    ompr::add_constraint(ompr::sum_over(x[i, j], j = 1:m) == 1, i = 1:n) |>
    # se uma UC está designada a uma agencia, a agencia tem que ficar ativa
    ompr::add_constraint(x[i, j] <= y[j], i = 1:n, j = 1:m) |>
    # se agencia está ativa, w tem que ser >= n_entrevistadores_min
    ompr::add_constraint((y[j] * n_entrevistadores_min) <= w[j], j = 1:m) |>
    # w tem que ser suficiente para dar conta das ucs para todos os períodos
    ompr::add_constraint(ompr::sum_over(x[i, j] * dias_coleta_ijt(i, j, t), i = 1:n) <=
                           (w[j] * dias_coleta_entrevistador_max), j = 1:m, t = 1:p)
}


add_optional_constraints <- function(model, n, m, agencias_t, diarias_entrevistador_max, diarias_i_j) {
  # Respeitar o máximo de entrevistadores por agencia
  if (any(is.finite(agencias_t$n_entrevistadores_agencia_max))) {
    model <- model |>
      ompr::add_constraint(w[j] <= agencias_t$n_entrevistadores_agencia_max[j], j = 1:m)
  }

  # Respeitar o máximo de diárias por entrevistador
  if (any(is.finite(diarias_entrevistador_max))) {
    model <- model |>
      ompr::add_constraint(ompr::sum_over(x[i, j] * diarias_fun(i, j, diarias_i_j), i = 1:n) <=
                             (diarias_entrevistador_max * w[j]), j = 1:m)
  }

  model
}

