#' Construtor do modelo OMPR usando MILPModel (vetorizado)
#'
#' Esta função constrói o modelo equivalente a `orce_model_mip()` porém
#' utilizando a backend vetorizada `MILPModel`, com `sum_expr()` e `colwise()`.
#'
#' Ela recebe um ambiente com todos os objetos preparados por `.orce_impl`
#' (por exemplo: `n`, `m`, `p`, `n_uc`, `N`, `agencias_t`, `ucs_i`,
#' `transport_cost_i_j`, `diarias_i_j`, `dias_coleta_ijt`, `distancias_nos`,
#' `peso_tsp`, `kml`, `custo_litro_combustivel`, `remuneracao_entrevistador`,
#' `n_entrevistadores_min`, `dias_coleta_entrevistador_max`, etc.) e retorna um
#' `ompr::MILPModel` pronto para ser resolvido.
#'
#' ## Papel do TSP (`peso_tsp`)
#'
#' Quando `peso_tsp > 0`, o modelo adiciona variáveis de roteamento
#' (`route[i, k, j]`) e restrições MTZ para eliminar sub-rotas. O objetivo
#' inclui, além dos custos operacionais habituais (`transport_cost_i_j`), uma
#' penalidade proporcional ao comprimento da rota TSP de cada agência:
#'
#' ```
#' (custo_litro_combustivel * peso_tsp / kml) * Σ distancias_nos[i,k] * route[i,k,j]
#' ```
#'
#' O propósito **não** é substituir o custo real de deslocamento, mas sim
#' desincentivar atribuições geograficamente dispersas: UCs próximas entre si
#' tendem a ser agrupadas na mesma agência porque a rota conjunta é mais curta.
#' O parâmetro `peso_tsp` funciona como peso de coerência geográfica — valores
#' maiores penalizam mais fortemente a fragmentação territorial.
#'
#' A matriz `distancias_nos` é N × N (N = m agências + n UCs), cobrindo todos
#' os pares nó↔nó necessários para a rota: base→UC, UC→UC e UC→base.
#'
#' ## Distância máxima entre UCs na rota (`route_max_km`)
#'
#' O TSP modela um entrevistador saindo da base, visitando UCs em sequência e
#' retornando — uma única saída de campo. Quando duas UCs estão muito distantes
#' entre si, esse modelo não é realista: o entrevistador voltaria à base entre
#' as visitas (custo já capturado por `transport_cost_i_j`), em vez de ir
#' diretamente de uma à outra.
#'
#' `route_max_km` reflete essa lógica operacional: arcos UC↔UC com distância
#' acima do limite recebem upper bound = 0, impedindo que o modelo conecte UCs
#' distantes em uma mesma rota. Arcos base↔UC nunca são limitados.
#' Como efeito colateral, isso também reduz o número de variáveis e acelera
#' o solver. Um valor de 200–400 km é uma boa faixa de partida.
#'
#' @param env Ambiente contendo todos os objetos necessários ao modelo.
#' @param route_max_km Distância máxima (km) entre UCs consecutivas na rota.
#'   UCs mais distantes que esse valor não serão conectadas diretamente —
#'   o entrevistador retorna à base entre as visitas. Padrão: `Inf`
#'   (sem restrição). Ignorado quando `peso_tsp == 0`.
#' @return Um objeto `ompr::MILPModel` com variáveis, restrições e objetivo definidos.
#' @export
orce_model_milp <- function(env, route_max_km = Inf) {
  env$route_max_km <- route_max_km
  with(env, {
    if (!identical(agencias_t$j, seq_len(nrow(agencias_t)))) {
      cli::cli_abort(
        c("{.arg agencias_t$j} must equal {.code seq_len(nrow(agencias_t))}",
          "i" = "Mismatches at rows: {which(agencias_t$j != seq_len(nrow(agencias_t)))}"),
        call = NULL
      )
    }

    checkmate::assert_choice(n_entrevistadores_tipo, c("continuous", "integer"))

    # pressupõe que distancias_nos já está em formato matriz N x N (preprocessado em .orce_impl)
    tsp <- peso_tsp > 0

    # função vetorizada para dias_coleta(i,j,t) usada em sum_expr(colwise(...))
    dct <- function(i, j, t) dias_coleta_arr[cbind(i, j, t)]

    # Modelo MILP
    model <- ompr::MILPModel() |>
      # 1 sse uc i vai para a agencia j
      ompr::add_variable(x[i, j], i = 1:n, j = 1:m, type = "binary") |>
      # 1 sse agencia j ativada
      ompr::add_variable(y[j], j = 1:m, type = "binary") |>
      # trabalhadores na agencia j
      ompr::add_variable(w[j], j = 1:m, type = n_entrevistadores_tipo, lb = 0, ub = Inf)

    if (tsp) {
      # Identificar arcos proibidos (serão fixados em 0 via restrição):
      #   - auto-loops, base->base, uso de base por agência errada, UC->UC > route_max_km
      grid_route  <- expand.grid(i = 1:N, k = 1:N, j = 1:m)
      is_base_i   <- grid_route$i <= m
      is_base_k   <- grid_route$k <= m
      no_self     <- grid_route$i != grid_route$k
      own_depot_i <- !is_base_i | (grid_route$i == grid_route$j)
      own_depot_k <- !is_base_k | (grid_route$k == grid_route$j)
      d_ik        <- distancias_nos[cbind(grid_route$i, grid_route$k)]
      allow_uc_uc   <- !is_base_i & !is_base_k & (d_ik <= route_max_km)
      allow_base_uc <- xor(is_base_i, is_base_k)
      allowed     <- no_self & own_depot_i & own_depot_k & (allow_base_uc | allow_uc_uc)
      forbidden   <- grid_route[!allowed, ]

      model <- model |>
        # route[i,k,j] = 1 se o vendedor j percorre o arco i->k (multi-depósito)
        ompr::add_variable(route[grid_route$i, grid_route$k, grid_route$j],
                           type = "binary", lb = 0, ub = 1L) |>
        # fixar arcos proibidos em 0
        ompr::add_constraint(
          route[forbidden$i, forbidden$k, forbidden$j] == 0
        ) |>
        # variável auxiliar MTZ apenas para nós de UCs (indexadas 1..n_uc)
        ompr::add_variable(u[q, j], q = 1:n_uc, j = 1:m, lb = 1, ub = n_uc) |>
        # conservação de fluxo apenas nos nós de UCs: sum_in == sum_out
        ompr::add_constraint(
          ompr::sum_expr(route[f, m + q, j], f = 1:N) -
            ompr::sum_expr(route[m + q, node, j], node = 1:N) == 0,
          q = 1:n_uc, j = 1:m
        ) |>
        # acoplamento com a atribuição x: uma saída e uma entrada por UC
        ompr::add_constraint(ompr::sum_expr(route[m + i, node, j], node = 1:N) == x[i, j], i = 1:n, j = 1:m) |>
        ompr::add_constraint(ompr::sum_expr(route[f, m + i, j], f = 1:N) == x[i, j], i = 1:n, j = 1:m) |>
        # cada vendedor j sai de sua própria base j exatamente uma vez se ativo
        ompr::add_constraint(ompr::sum_expr(route[j, node, j], node = (m + 1):N) == y[j], j = 1:m) |>
        # e retorna para sua base j exatamente uma vez se ativo
        ompr::add_constraint(ompr::sum_expr(route[f, j, j], f = (m + 1):N) == y[j], j = 1:m) |>
        # MTZ apenas sobre nós de UCs (evita subtours) para q != r
        ompr::add_constraint(
          u[q, j] - u[r, j] + 1 <= (n_uc) * (1 - route[m + q, m + r, j]),
          q = 1:n_uc, r = 1:n_uc, j = 1:m, q != r
        )
    }

    # Objetivo: sum_expr must be inlined into set_objective (not pre-computed),
    # because MILPModel resolves model variables lazily inside the pipe.
    if (tsp) {
      model <- model |>
        ompr::set_objective(
          (custo_litro_combustivel * peso_tsp / kml) *
            ompr::sum_expr(ompr::colwise(distancias_nos[cbind(i, k)]) * route[i, k, j], i = 1:N, k = 1:N, j = 1:m) +
            ompr::sum_expr(ompr::colwise(transport_cost_i_j[cbind(i, j)]) * x[i, j], i = 1:n, j = 1:m) +
            ompr::sum_expr(ompr::colwise(agencias_t$custo_fixo[j]) * y[j], j = 1:m) +
            remuneracao_entrevistador * ompr::sum_expr(w[j], j = 1:m) +
            ompr::sum_expr(ompr::colwise(agencias_t$custo_treinamento_por_entrevistador[j]) * w[j], j = 1:m),
          sense = "min"
        )
    } else {
      model <- model |>
        ompr::set_objective(
          ompr::sum_expr(ompr::colwise(transport_cost_i_j[cbind(i, j)]) * x[i, j], i = 1:n, j = 1:m) +
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
          ompr::sum_expr(ompr::colwise(diarias_i_j[cbind(i, j)]) * x[i, j], i = 1:n) <= diarias_entrevistador_max * w[j],
          j = 1:m
        )
    }

    model
  })
}
