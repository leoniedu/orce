#' Construtor do MILP para otimização conjunta masculino/feminino
#'
#' Variante de [orce_model_milp()] que otimiza a atribuição de entrevistadores
#' de ambos os gêneros simultaneamente, eliminando as infeasibilidades que surgem
#' na abordagem sequencial quando `remuneracao_entrevistador` é baixo. Não
#' suporta TSP (`peso_tsp` é ignorado).
#'
#' O modelo usa variáveis separadas por gênero: `xm[i,jm]` / `xf[i,jf]` para
#' atribuição, `wm[jm]` / `wf[jf]` para número de entrevistadores e
#' `ym[jm]` / `yf[jf]` para ativação de agências. Para agências com ambos os
#' gêneros, `ya[jb]` garante que o custo fixo seja pago uma única vez, e
#' `s[i,jb]` captura o compartilhamento de veículo (economia de combustível).
#'
#' @section Variáveis do ambiente `env`:
#'
#' Além dos parâmetros escalares do modelo (`n_entrevistadores_min`,
#' `dias_coleta_entrevistador_max`, `diarias_entrevistador_max`,
#' `remuneracao_entrevistador`, `n_entrevistadores_tipo`), `env` deve conter:
#'
#' - `n`, `m_m`, `m_f`, `m_b`, `p`: dimensões.
#' - `transport_m` (`n × m_m`), `transport_f` (`n × m_f`): custo total de
#'   deslocamento por UC-agência (todos os períodos).
#' - `fuel_saving` (`n × m_b`): economia de combustível por UC-agência
#'   bilateral = `(fuel_m + fuel_f) / 2`.
#' - `dias_arr` (`n × p`): dias de coleta por UC e período.
#' - `diarias_m` (`n × m_m`), `diarias_f` (`n × m_f`): total de diárias.
#' - `n_max_m` (`m_m`), `n_max_f` (`m_f`): capacidade por agência e gênero.
#' - `fixed_cost_m_coef` (`m_m`): custo fixo para agências masculinas; 0 para
#'   agências com ambos os gêneros (cobrado via `custo_fixo_full`).
#' - `fixed_cost_f_coef` (`m_f`): idem para agências femininas.
#' - `custo_fixo_full` (`m_b`): custo fixo das agências com ambos os gêneros.
#' - `training_m` (`m_m`), `training_f` (`m_f`): custo de treinamento por
#'   entrevistador.
#' - `full_jm` (`m_b`), `full_jf` (`m_b`): índices jm e jf das agências com
#'   ambos os gêneros.
#' - `fix_m`, `fix_f`: listas com `$fix` e `$blk` (data.frames `i`/`j`) com
#'   atribuições forçadas e bloqueadas para cada gênero.
#'
#' @param env Ambiente com todos os objetos acima.
#' @return Um `ompr::MILPModel` pronto para ser resolvido.
#' @export
orce_model_milp_joint <- function(env) {
  with(env, {
    checkmate::assert_choice(n_entrevistadores_tipo, c("continuous", "integer"))

    tm   <- function(i, jm) transport_m[cbind(i, jm)]
    tf   <- function(i, jf) transport_f[cbind(i, jf)]
    fs   <- function(i, jb) fuel_saving[cbind(i, jb)]
    da   <- function(i, t)  dias_arr[cbind(i, t)]
    diam <- function(i, jm) diarias_m[cbind(i, jm)]
    diaf <- function(i, jf) diarias_f[cbind(i, jf)]

    model <- ompr::MILPModel() |>
      ompr::add_variable(xm[i, jm], i = 1:n, jm = 1:m_m, type = "binary") |>
      ompr::add_variable(xf[i, jf], i = 1:n, jf = 1:m_f, type = "binary") |>
      ompr::add_variable(wm[jm], jm = 1:m_m,
                         type = n_entrevistadores_tipo, lb = 0, ub = Inf) |>
      ompr::add_variable(wf[jf], jf = 1:m_f,
                         type = n_entrevistadores_tipo, lb = 0, ub = Inf) |>
      ompr::add_variable(ym[jm], jm = 1:m_m, type = "binary") |>
      ompr::add_variable(yf[jf], jf = 1:m_f, type = "binary")

    if (m_b > 0) {
      model <- model |>
        # ya[jb] = 1 iff agency jb used by at least one gender
        ompr::add_variable(ya[jb], jb = 1:m_b, type = "binary") |>
        # s[i,jb] = 1 iff both genders visit UC i from agency jb (fuel sharing)
        ompr::add_variable(s[i, jb], i = 1:n, jb = 1:m_b, type = "binary")
    }

    # ── Objective ─────────────────────────────────────────────────────────────
    # sum_expr must be inlined into set_objective — it cannot be pre-computed.
    if (m_b > 0) {
      model <- model |> ompr::set_objective(
        ompr::sum_expr(ompr::colwise(tm(i, jm)) * xm[i, jm], i = 1:n, jm = 1:m_m) +
        ompr::sum_expr(ompr::colwise(tf(i, jf)) * xf[i, jf], i = 1:n, jf = 1:m_f) +
        remuneracao_entrevistador * ompr::sum_expr(wm[jm], jm = 1:m_m) +
        remuneracao_entrevistador * ompr::sum_expr(wf[jf], jf = 1:m_f) +
        ompr::sum_expr(ompr::colwise(training_m[jm]) * wm[jm], jm = 1:m_m) +
        ompr::sum_expr(ompr::colwise(training_f[jf]) * wf[jf], jf = 1:m_f) +
        ompr::sum_expr(ompr::colwise(fixed_cost_m_coef[jm]) * ym[jm], jm = 1:m_m) +
        ompr::sum_expr(ompr::colwise(fixed_cost_f_coef[jf]) * yf[jf], jf = 1:m_f) +
        ompr::sum_expr(ompr::colwise(custo_fixo_full[jb]) * ya[jb], jb = 1:m_b) -
        ompr::sum_expr(ompr::colwise(fs(i, jb)) * s[i, jb], i = 1:n, jb = 1:m_b),
        sense = "min"
      )
    } else {
      model <- model |> ompr::set_objective(
        ompr::sum_expr(ompr::colwise(tm(i, jm)) * xm[i, jm], i = 1:n, jm = 1:m_m) +
        ompr::sum_expr(ompr::colwise(tf(i, jf)) * xf[i, jf], i = 1:n, jf = 1:m_f) +
        remuneracao_entrevistador * ompr::sum_expr(wm[jm], jm = 1:m_m) +
        remuneracao_entrevistador * ompr::sum_expr(wf[jf], jf = 1:m_f) +
        ompr::sum_expr(ompr::colwise(training_m[jm]) * wm[jm], jm = 1:m_m) +
        ompr::sum_expr(ompr::colwise(training_f[jf]) * wf[jf], jf = 1:m_f) +
        ompr::sum_expr(ompr::colwise(fixed_cost_m_coef[jm]) * ym[jm], jm = 1:m_m) +
        ompr::sum_expr(ompr::colwise(fixed_cost_f_coef[jf]) * yf[jf], jf = 1:m_f),
        sense = "min"
      )
    }

    # ── Constraints ───────────────────────────────────────────────────────────
    model <- model |>
      ompr::add_constraint(ompr::sum_expr(xm[i, jm], jm = 1:m_m) == 1, i = 1:n) |>
      ompr::add_constraint(ompr::sum_expr(xf[i, jf], jf = 1:m_f) == 1, i = 1:n) |>
      ompr::add_constraint(xm[i, jm] <= ym[jm], i = 1:n, jm = 1:m_m) |>
      ompr::add_constraint(xf[i, jf] <= yf[jf], i = 1:n, jf = 1:m_f) |>
      ompr::add_constraint(ym[jm] * n_entrevistadores_min <= wm[jm], jm = 1:m_m) |>
      ompr::add_constraint(yf[jf] * n_entrevistadores_min <= wf[jf], jf = 1:m_f) |>
      ompr::add_constraint(
        ompr::sum_expr(ompr::colwise(da(i, t)) * xm[i, jm], i = 1:n) <=
          wm[jm] * dias_coleta_entrevistador_max,
        jm = 1:m_m, t = 1:p
      ) |>
      ompr::add_constraint(
        ompr::sum_expr(ompr::colwise(da(i, t)) * xf[i, jf], i = 1:n) <=
          wf[jf] * dias_coleta_entrevistador_max,
        jf = 1:m_f, t = 1:p
      )

    if (any(is.finite(n_max_m))) {
      model <- model |>
        ompr::add_constraint(wm[jm] <= ompr::colwise(n_max_m[jm]), jm = 1:m_m)
    }
    if (any(is.finite(n_max_f))) {
      model <- model |>
        ompr::add_constraint(wf[jf] <= ompr::colwise(n_max_f[jf]), jf = 1:m_f)
    }
    if (is.finite(diarias_entrevistador_max)) {
      model <- model |>
        ompr::add_constraint(
          ompr::sum_expr(ompr::colwise(diam(i, jm)) * xm[i, jm], i = 1:n) <=
            diarias_entrevistador_max * wm[jm],
          jm = 1:m_m
        ) |>
        ompr::add_constraint(
          ompr::sum_expr(ompr::colwise(diaf(i, jf)) * xf[i, jf], i = 1:n) <=
            diarias_entrevistador_max * wf[jf],
          jf = 1:m_f
        )
    }

    if (m_b > 0) {
      # ompr does not support colwise as a variable subscript, so we add
      # bilateral constraints using concrete integer indices in a for loop.
      for (jb_val in seq_len(m_b)) {
        jm_val <- full_jm[jb_val]
        jf_val <- full_jf[jb_val]
        model <- model |>
          ompr::add_constraint(ya[jb_val] >= ym[jm_val]) |>
          ompr::add_constraint(ya[jb_val] >= yf[jf_val]) |>
          ompr::add_constraint(ya[jb_val] <= ym[jm_val] + yf[jf_val]) |>
          ompr::add_constraint(
            s[i, jb_val] >= xm[i, jm_val] + xf[i, jf_val] - 1, i = 1:n
          ) |>
          ompr::add_constraint(s[i, jb_val] <= xm[i, jm_val], i = 1:n) |>
          ompr::add_constraint(s[i, jb_val] <= xf[i, jf_val], i = 1:n)
      }
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
