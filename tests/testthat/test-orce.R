library(testthat)
library(orce)
options(warn = 2)

# Load frozen test data (independent of orcedata version)
fixture <- readRDS(test_path("fixtures", "test-orce-data.rds"))
ucs_municipios <- fixture$ucs
agencias <- fixture$agencias
dists <- fixture$dists

# Use GLPK for deterministic results
params_0 <- list(ucs = ucs_municipios, agencias = agencias, dias_coleta_entrevistador_max = 14, distancias_ucs = dists, remuneracao_entrevistador = 0, rel_tol = 0.01)

# Testes unitários
test_that("Alocação de UCs com períodos de coleta", {
  f <- function(...) orce(..., use_cache = FALSE)

  # Teste 1: Snapshot regression test (GLPK, frozen data)
  r_t <- do.call(f, params_0)
  expect_equal(r_t$resultado_agencias_otimo$custo_deslocamento, c(483.28, 1673.04, 3418.148, 3879.476, 28.96, 646.36, 22.04, 1422.2, 735.36, 9099.648, 859.96, 1623.16, 644.16, 3353.788, 3365.824, 1598.88, 793.28, 1979.6, 772.12, 2009.52, 1589.96, 1084.72, 2275.2, 4267.904, 1841.8, 2470.72, 10000.82, 1602.08, 3439.784, 1002.32, 3306.88, 4449.476, 1500.6, 1948.28, 127.8, 252.6, 7552.392, 6761.408, 483.52, 1380.88, 776.8, 4263.676, 989.6, 1234.28, 4876.24, 1906.72, 1274.04, 4655.412))

  # Optimized must beat jurisdiction
  expect_lt(sum(r_t$resultado_agencias_otimo$custo_deslocamento),
            sum(r_t$resultado_agencias_jurisdicao$custo_deslocamento))

  # Teste 2: Alocação por grupo
  params_1 <- modifyList(params_0, list(ucs = params_0$ucs |> dplyr::mutate(g = agencia_codigo), alocar_por = "g"))
  r_t_i <- do.call(f, params_1)
  expect_lt(nrow(r_t_i$resultado_agencias_otimo), nrow(r_t_i$resultado_agencias_jurisdicao))

  # Teste 3: Aumento do custo fixo
  params_2 <- modifyList(params_1, list(agencias = params_1$agencias |> dplyr::mutate(custo_fixo = 10000, remuneracao_entrevistador=2000)))
  r_t_if <- do.call(f, params_2)
  expect_lt(nrow(r_t_if$resultado_agencias_otimo), nrow(r_t_i$resultado_agencias_otimo))

  # Teste 4: Períodos de coleta
  n_periodos <- 2
  params_3 <- modifyList(params_2,
                         list(ucs = params_2$ucs |> dplyr::mutate(data = rep(1:n_periodos, length = dplyr::n()))))
  r_t_if_d <- do.call(f, params_3)
  ## Mais periodos
  expect_lt(sum(r_t_if_d$resultado_agencias_otimo$entrevistadores),
            sum(r_t_if$resultado_agencias_otimo$entrevistadores))

  # Teste 5: Ajuste do número de dias de coleta por entrevistador
  params_4 <- modifyList(params_3, list(dias_coleta_entrevistador_max = params_3$dias_coleta_entrevistador_max / dplyr::n_distinct(params_3$ucs$data)))
  r_t_if_d2 <- do.call(f, params_4)

  # Teste 6: Verificação do número de entrevistadores
  verifica_entrevistadores <- function(result, result_type = "otimo", params) {
    result[[paste0("resultado_ucs_", result_type)]] |>
      dplyr::group_by(agencia_codigo, data) |>
      dplyr::summarise(dias_coleta = sum(dias_coleta)) |>
      dplyr::group_by(agencia_codigo) |>
      dplyr::arrange(desc(dias_coleta)) |>
      dplyr::slice(1) |>
      dplyr::mutate(entrevistadores_necessarios = ceiling(dias_coleta / (params$dias_coleta_entrevistador_max))) |>
      dplyr::left_join(result[[paste0("resultado_agencias_", result_type)]] |>
                         dplyr::select(agencia_codigo, entrevistadores_modelo = entrevistadores)) |>
      dplyr::mutate(d = entrevistadores_modelo - entrevistadores_necessarios, data = NULL)
  }
  expect_gte(min(verifica_entrevistadores(r_t_if_d2, params = params_4)$d), 0)

  # Teste 7: Aumento da remuneração dos entrevistadores
  params_5 <- modifyList(params_4, list(remuneracao_entrevistador = 1000))
  r_t_if_d2_r <- do.call(f, params_5)
  expect_equal(max(verifica_entrevistadores(r_t_if_d2_r, params = params_5, result_type = "otimo")$d), 0)

  # Teste: número de entrevistadores máximo
  nmax <- 2
  params_n_e_max <- modifyList(params_5, list(agencias=dplyr::mutate(params_0$agencias,n_entrevistadores_agencia_max=nmax)))
  r_n_e_max <- do.call(f, params_n_e_max)
  expect_lte(max(r_n_e_max$resultado_agencias_otimo$entrevistadores), nmax)


  # Teste 8: Máximo de diárias
  params_6 <- modifyList(params_5, list(diarias_entrevistador_max=7))
  r_t_diarias <- do.call(f, params_6)
  # Tem que ser mais que o "necessário" sem essa restrição
  expect_gte(max(verifica_entrevistadores(r_t_diarias, params = params_5, result_type = "otimo")$d), 1)

  # Teste 9: Máximo de dias de coleta por agencia
  params_7 <- modifyList(params_6, list(agencias=params_6$agencias|>dplyr::mutate(dias_coleta_agencia_max=120)))
  r_t_max_agencia <- do.call(f, params_7)

  expect_gte(nrow(r_t_max_agencia$resultado_agencias_otimo), nrow(r_t_diarias$resultado_agencias_otimo))

  # Teste 10: Mínimo de entrevistadores por agência n_entrevistadores_min
  params_8 <- modifyList(params_7, list(n_entrevistadores_min=9))
  r_t_min_entrevistadores <- do.call(f, params_8)

  expect_gte(min(r_t_min_entrevistadores$resultado_agencias_otimo$entrevistadores), 9)
  expect_gte(min(r_t_min_entrevistadores$resultado_agencias_jurisdicao$entrevistadores), 9)

  ## Teste : sem dados por agência
  params_9 <- modifyList(params_8, list(agencias=NULL))

  # Teste: número de entrevistadores como variável contínua
  params_c <- modifyList(params_5, list(n_entrevistadores_tipo = "continuous"))
  r_i <- do.call(f, params_5)
  r_c <- do.call(f, params_c)


})

test_that("fixar_atribuicoes fixa UCs nas agências especificadas", {
  f <- function(...) orce(..., use_cache = FALSE)

  # Rodar otimização base
  r_base <- do.call(f, params_0)
  resultado_base <- r_base$resultado_ucs_otimo

  # Escolher 5 UCs e suas agências atuais para fixar
  fixar <- resultado_base |>
    dplyr::distinct(uc, agencia_codigo) |>
    utils::head(5)

  # Re-rodar com essas UCs fixas
  r_fix <- do.call(f, c(params_0, list(fixar_atribuicoes = fixar)))

  # Verificar que as UCs fixas mantiveram suas agências
  resultado_fix <- r_fix$resultado_ucs_otimo |>
    dplyr::filter(uc %in% fixar$uc) |>
    dplyr::distinct(uc, agencia_codigo)

  expect_equal(
    dplyr::arrange(resultado_fix, uc),
    dplyr::arrange(fixar, uc)
  )
})

test_that("fixar_atribuicoes com TODAS as UCs fixas não causa infeasibility", {
  f <- function(...) orce(..., use_cache = FALSE)

  r_base <- do.call(f, params_0)

  # Fixar TODAS as UCs (simula toggle ON sem restrições)
  fixar_todas <- r_base$resultado_ucs_otimo |>
    dplyr::distinct(uc, agencia_codigo)

  r_fix <- do.call(f, c(params_0, list(fixar_atribuicoes = fixar_todas)))
  expect_equal(
    dplyr::arrange(r_fix$resultado_ucs_otimo |> dplyr::distinct(uc, agencia_codigo), uc),
    dplyr::arrange(fixar_todas, uc)
  )
})

test_that("bloquear_atribuicoes impede atribuição ao par bloqueado", {
  f <- function(...) orce(..., use_cache = FALSE)

  r_base <- do.call(f, params_0)

  # Pick a UC and its current agency to block
  alocacao <- r_base$resultado_ucs_otimo |>
    dplyr::distinct(uc, agencia_codigo) |>
    utils::head(1)

  bloquear <- data.frame(
    uc = alocacao$uc,
    agencia_codigo = alocacao$agencia_codigo,
    stringsAsFactors = FALSE
  )

  r_blk <- do.call(f, c(params_0, list(bloquear_atribuicoes = bloquear)))

  # UC must NOT be assigned to blocked agency
  alocacao_blk <- r_blk$resultado_ucs_otimo |>
    dplyr::filter(uc == bloquear$uc) |>
    dplyr::distinct(agencia_codigo)
  expect_false(bloquear$agencia_codigo %in% alocacao_blk$agencia_codigo)
})

test_that("fixar + bloquear mesmo par gera erro", {
  f <- function(...) orce(..., use_cache = FALSE)

  par <- data.frame(uc = "UC_FAKE", agencia_codigo = "AG_FAKE",
                    stringsAsFactors = FALSE)

  # Won't match any real UC/agency but conflict check happens before matching

  # Use real data so we reach the conflict check
  r_base <- do.call(f, params_0)
  alocacao <- r_base$resultado_ucs_otimo |>
    dplyr::distinct(uc, agencia_codigo) |>
    utils::head(1)

  expect_error(
    do.call(f, c(params_0, list(
      fixar_atribuicoes = alocacao,
      bloquear_atribuicoes = alocacao
    ))),
    "Conflito"
  )
})
