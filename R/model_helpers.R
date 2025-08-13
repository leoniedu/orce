# Shared helper functions for warehouse TSP optimization models

# ============================================================================
# SHARED COST CALCULATION FUNCTIONS
# ============================================================================

transport_cost_fun <- function(i, j, peso_tsp, transport_cost_i_j) {
  (1 - peso_tsp) * transport_cost_i_j[i, j]
}

transport_cost_simple_fun <- function(i, j, transport_cost_i_j) {
  transport_cost_i_j[i, j]
}

fixed_cost_fun <- function(j, agencias_t) {
  agencias_t$custo_fixo[j]
}

training_cost_fun <- function(j, remuneracao_entrevistador, agencias_t) {
  remuneracao_entrevistador + agencias_t$custo_treinamento_por_entrevistador[j]
}

tsp_cost_fun <- function(i, k, j, t, peso_tsp, dist_uc_uc, duracao_uc_uc, kml, 
                        custo_litro_combustivel, custo_hora_viagem, dias_coleta_ijt) {
  dist_cost <- dist_uc_uc[i, k] / kml * custo_litro_combustivel
  time_cost <- duracao_uc_uc[i, k] * custo_hora_viagem
  collection_indicator <- dias_coleta_ijt(i, j, t) > 0
  peso_tsp * (dist_cost + time_cost) * collection_indicator
}

dias_coleta_fun <- function(i, j, t, dias_coleta_ijt) {
  dias_coleta_ijt(i, j, t)
}

ti_fun <- function(i, t, ti) {
  ti[i, t]
}

max_entrevistadores_fun <- function(j, agencias_t) {
  agencias_t$n_entrevistadores_agencia_max[j]
}

diarias_fun <- function(i, j, diarias_i_j) {
  diarias_i_j[i, j]
}

# ============================================================================
# SHARED MODEL STRUCTURE FUNCTIONS
# ============================================================================

create_base_model <- function(n, m, n_entrevistadores_tipo, model_type = c("MIP", "MILP")) {
  model_type <- match.arg(model_type)
  
  if (model_type == "MIP") {
    ompr::MIPModel()
  } else {
    ompr::MILPModel()
  }
}

add_tsp_variables <- function(model, n, m, p) {
  model |>
    # TSP routing: 1 sse rota vai de uc i para uc k dentro da agencia j no período t
    ompr::add_variable(route[i, k, j, t], i = 1:n, k = 1:n, j = 1:m, t = 1:p, type = "binary") |>
    # TSP subtour elimination auxiliar por período
    ompr::add_variable(u[i, j, t], i = 1:n, j = 1:m, t = 1:p, type = "continuous", lb = 1, ub = n)
}

# ============================================================================
# VALIDATION HELPERS
# ============================================================================

validate_dimensions <- function(n, m, p) {
  if (!all(c(n, m, p) > 0) || !all(is.numeric(c(n, m, p)))) {
    stop("Dimensions n, m, p must be positive integers", call. = FALSE)
  }
}

validate_peso_tsp <- function(peso_tsp) {
  if (peso_tsp < 0 || peso_tsp > 1) {
    stop("peso_tsp must be between 0 and 1", call. = FALSE)
  }
}

validate_matrix_dimensions <- function(transport_cost_i_j, n, m) {
  if (nrow(transport_cost_i_j) != n || ncol(transport_cost_i_j) != m) {
    stop(sprintf("transport_cost_i_j dimensions (%d x %d) don't match expected (%d x %d)", 
                 nrow(transport_cost_i_j), ncol(transport_cost_i_j), n, m), call. = FALSE)
  }
}