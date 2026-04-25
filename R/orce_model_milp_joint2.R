#' Construtor do MILP conjunto (espaço único de agências)
#'
#' Variante simplificada de [orce_model_milp_joint()] que usa um único espaço
#' de índices `j = 1..m` para todas as agências. O bloqueio de atribuições
#' inválidas (e.g. masculino numa agência só-feminina) emerge implicitamente da
#' restrição de capacidade: `wm[j] <= n_masculino[j]` → quando
#' `n_masculino[j] = 0`, `wm[j] = 0` → `ym[j] = 0` → `xm[i,j] = 0`.
#' Isso elimina o mapeamento de índices bilaterais (`full_jm`/`full_jf`/`ya`).
#'
#' Não suporta TSP.
#'
#' @section Variáveis do ambiente `env`:
#'
#' - `n`, `m`, `p`: dimensões (UCs, agências, períodos).
#' - `transport` (`n × m`): custo total de deslocamento UC-agência (igual para
#'   ambos os gêneros — mesma viagem).
#' - `fuel` (`n × m`): custo de combustível UC-agência (para economia de
#'   veículo compartilhado).
#' - `diarias` (`n × m`): total de diárias UC-agência.
#' - `dias_arr` (`n × p`): dias de coleta por UC e período.
#' - `n_masculino` (`m`): capacidade masculina por agência (0 = sem masculinos).
#' - `n_feminino` (`m`): capacidade feminina por agência (0 = sem femininas).
#' - `custo_fixo` (`m`): custo fixo por agência (cobrado via `y[j]` — uma vez).
#' - `training_m` (`m`), `training_f` (`m`): custo de treinamento por entrev.
#' - `fix_m`, `fix_f`: listas com `$fix` e `$blk` (data.frames `i`/`j`).
#' - Escalares: `n_entrevistadores_min`, `dias_coleta_entrevistador_max`,
#'   `diarias_entrevistador_max`, `remuneracao_entrevistador`,
#'   `n_entrevistadores_tipo`.
#'
#' @param env Ambiente com todos os objetos acima.
#' @return Um `ompr::MILPModel` pronto para ser resolvido.
#' @export
orce_model_milp_joint2 <- function(env) {
  with(env, {
    checkmate::assert_choice(n_entrevistadores_tipo, c("continuous", "integer"))

    tc  <- function(i, j) transport[cbind(i, j)]
    fc  <- function(i, j) fuel[cbind(i, j)]
    dia <- function(i, j) diarias[cbind(i, j)]
    da  <- function(i, t) dias_arr[cbind(i, t)]

    model <- ompr::MILPModel() |>
      ompr::add_variable(xm[i, j], i = 1:n, j = 1:m, type = "binary") |>
      ompr::add_variable(xf[i, j], i = 1:n, j = 1:m, type = "binary") |>
      ompr::add_variable(wm[j], j = 1:m,
                         type = n_entrevistadores_tipo, lb = 0, ub = Inf) |>
      ompr::add_variable(wf[j], j = 1:m,
                         type = n_entrevistadores_tipo, lb = 0, ub = Inf) |>
      ompr::add_variable(ym[j], j = 1:m, type = "binary") |>
      ompr::add_variable(yf[j], j = 1:m, type = "binary") |>
      ompr::add_variable(y[j],  j = 1:m, type = "binary") |>
      ompr::add_variable(s[i, j], i = 1:n, j = 1:m, type = "binary")

    # ── Objective ─────────────────────────────────────────────────────────────
    model <- model |>
      ompr::set_objective(
        ompr::sum_expr(ompr::colwise(tc(i, j)) * xm[i, j], i = 1:n, j = 1:m) +
        ompr::sum_expr(ompr::colwise(tc(i, j)) * xf[i, j], i = 1:n, j = 1:m) -
        ompr::sum_expr(ompr::colwise(fc(i, j)) * s[i, j],  i = 1:n, j = 1:m) +
        ompr::sum_expr(ompr::colwise(custo_fixo[j]) * y[j], j = 1:m) +
        remuneracao_entrevistador * ompr::sum_expr(wm[j], j = 1:m) +
        remuneracao_entrevistador * ompr::sum_expr(wf[j], j = 1:m) +
        ompr::sum_expr(ompr::colwise(training_m[j]) * wm[j], j = 1:m) +
        ompr::sum_expr(ompr::colwise(training_f[j]) * wf[j], j = 1:m),
        sense = "min"
      )

    # ── Constraints ───────────────────────────────────────────────────────────
    model <- model |>
      # Each UC assigned to exactly one agency per gender
      ompr::add_constraint(ompr::sum_expr(xm[i, j], j = 1:m) == 1, i = 1:n) |>
      ompr::add_constraint(ompr::sum_expr(xf[i, j], j = 1:m) == 1, i = 1:n) |>
      # Activation per gender
      ompr::add_constraint(xm[i, j] <= ym[j], i = 1:n, j = 1:m) |>
      ompr::add_constraint(xf[i, j] <= yf[j], i = 1:n, j = 1:m) |>
      # Shared activation: y[j] = 1 iff agency used by at least one gender
      ompr::add_constraint(y[j] >= ym[j], j = 1:m) |>
      ompr::add_constraint(y[j] >= yf[j], j = 1:m) |>
      ompr::add_constraint(y[j] <= ym[j] + yf[j], j = 1:m) |>
      # Min interviewers when active
      ompr::add_constraint(ym[j] * n_entrevistadores_min <= wm[j], j = 1:m) |>
      ompr::add_constraint(yf[j] * n_entrevistadores_min <= wf[j], j = 1:m) |>
      # Gender capacity bounds — implicitly block zero-capacity assignments
      ompr::add_constraint(wm[j] <= ompr::colwise(n_masculino[j]), j = 1:m) |>
      ompr::add_constraint(wf[j] <= ompr::colwise(n_feminino[j]),  j = 1:m) |>
      # Collection-days capacity per period
      ompr::add_constraint(
        ompr::sum_expr(ompr::colwise(da(i, t)) * xm[i, j], i = 1:n) <=
          wm[j] * dias_coleta_entrevistador_max,
        j = 1:m, t = 1:p
      ) |>
      ompr::add_constraint(
        ompr::sum_expr(ompr::colwise(da(i, t)) * xf[i, j], i = 1:n) <=
          wf[j] * dias_coleta_entrevistador_max,
        j = 1:m, t = 1:p
      ) |>
      # Fuel sharing: s[i,j] = xm[i,j] AND xf[i,j]
      ompr::add_constraint(
        s[i, j] >= xm[i, j] + xf[i, j] - 1, i = 1:n, j = 1:m
      ) |>
      ompr::add_constraint(s[i, j] <= xm[i, j], i = 1:n, j = 1:m) |>
      ompr::add_constraint(s[i, j] <= xf[i, j], i = 1:n, j = 1:m)

    if (is.finite(diarias_entrevistador_max)) {
      model <- model |>
        ompr::add_constraint(
          ompr::sum_expr(ompr::colwise(dia(i, j)) * xm[i, j], i = 1:n) <=
            diarias_entrevistador_max * wm[j],
          j = 1:m
        ) |>
        ompr::add_constraint(
          ompr::sum_expr(ompr::colwise(dia(i, j)) * xf[i, j], i = 1:n) <=
            diarias_entrevistador_max * wf[j],
          j = 1:m
        )
    }

    if (!is.null(fix_m$fix) && nrow(fix_m$fix) > 0)
      model <- model |>
        ompr::add_constraint(xm[fix_m$fix$i, fix_m$fix$j] == 1)
    if (!is.null(fix_m$blk) && nrow(fix_m$blk) > 0)
      model <- model |>
        ompr::add_constraint(xm[fix_m$blk$i, fix_m$blk$j] == 0)
    if (!is.null(fix_f$fix) && nrow(fix_f$fix) > 0)
      model <- model |>
        ompr::add_constraint(xf[fix_f$fix$i, fix_f$fix$j] == 1)
    if (!is.null(fix_f$blk) && nrow(fix_f$blk) > 0)
      model <- model |>
        ompr::add_constraint(xf[fix_f$blk$i, fix_f$blk$j] == 0)

    model
  })
}
