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

test_that("custo_litro_combustivel por agência substitui o valor global", {
  f <- function(...) orce(..., use_cache = FALSE)

  r_global <- do.call(f, modifyList(params_0, list(custo_litro_combustivel = 6)))

  # Per-agency fuel cost = 3 (half of global) should halve custo_combustivel
  r_agencia <- do.call(f, modifyList(params_0, list(
    custo_litro_combustivel = 6,
    agencias = params_0$agencias |> dplyr::mutate(custo_litro_combustivel = 3)
  )))

  # jurisdicao is deterministic (no optimization) — same assignments, different cost
  expect_equal(
    r_agencia$resultado_agencias_jurisdicao$custo_combustivel,
    r_global$resultado_agencias_jurisdicao$custo_combustivel / 2
  )

  # Without column, global parameter is used
  r_no_col <- do.call(f, modifyList(params_0, list(custo_litro_combustivel = 6)))
  expect_equal(
    r_no_col$resultado_agencias_jurisdicao$custo_combustivel,
    r_global$resultado_agencias_jurisdicao$custo_combustivel
  )
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

test_that("fixar_atribuicoes com valor=0 impede atribuição ao par bloqueado", {
  f <- function(...) orce(..., use_cache = FALSE)

  r_base <- do.call(f, params_0)

  # Pick a UC and its current agency to block
  alocacao <- r_base$resultado_ucs_otimo |>
    dplyr::distinct(uc, agencia_codigo) |>
    utils::head(1)

  bloquear <- data.frame(
    uc = alocacao$uc,
    agencia_codigo = alocacao$agencia_codigo,
    valor = 0L,
    stringsAsFactors = FALSE
  )

  r_blk <- do.call(f, c(params_0, list(fixar_atribuicoes = bloquear)))

  # UC must NOT be assigned to blocked agency
  alocacao_blk <- r_blk$resultado_ucs_otimo |>
    dplyr::filter(uc == bloquear$uc) |>
    dplyr::distinct(agencia_codigo)
  expect_false(bloquear$agencia_codigo %in% alocacao_blk$agencia_codigo)
})

test_that("fixar_atribuicoes com valor 0 e 1 para mesmo par gera erro", {
  f <- function(...) orce(..., use_cache = FALSE)

  r_base <- do.call(f, params_0)
  alocacao <- r_base$resultado_ucs_otimo |>
    dplyr::distinct(uc, agencia_codigo) |>
    utils::head(1)

  conflito <- data.frame(
    uc = rep(alocacao$uc, 2),
    agencia_codigo = rep(alocacao$agencia_codigo, 2),
    valor = c(1L, 0L),
    stringsAsFactors = FALSE
  )

  expect_error(
    do.call(f, c(params_0, list(fixar_atribuicoes = conflito))),
    "Conflito"
  )
})

test_that("alocar_por with multiagency group succeeds via majority jurisdiction", {
  f <- function(...) orce(..., use_cache = FALSE)

  # Each UC has a unique municipio_codigo in the fixture. Create a multiagency

  # scenario by forcing two UCs into the same municipality with different agencies.
  orig_ag <- agencias$agencia_codigo[1]
  fake_ag <- paste0(substr(orig_ag, 1, 7), "99")
  shared_mun <- "SHARED1"

  ucs_multi <- ucs_municipios |>
    dplyr::mutate(municipio_codigo = substr(uc, 1, 7))
  # Put first two UCs in the same municipality, with different agencies
  ucs_multi$municipio_codigo[1] <- shared_mun
  ucs_multi$municipio_codigo[2] <- shared_mun
  ucs_multi$agencia_codigo[2] <- fake_ag

  agencias_multi <- dplyr::bind_rows(
    agencias,
    data.frame(agencia_codigo = fake_ag, custo_fixo = 0,
               n_entrevistadores_agencia_max = Inf, diaria_valor = 335)
  )

  # Copy distances from original agency for the fake one
  dists_multi <- dplyr::bind_rows(
    dists,
    dists |> dplyr::filter(agencia_codigo == orig_ag) |>
      dplyr::mutate(agencia_codigo = fake_ag)
  )

  # Without fix this would fail (conflicting x[i,j1]==1 and x[i,j2]==1).
  # options(warn=2) is set globally, so cli_warn becomes an error — temporarily reset.
  withr::local_options(warn = 0)
  expect_warning(
    result <- f(
      ucs = ucs_multi, agencias = agencias_multi, distancias_ucs = dists_multi,
      alocar_por = "municipio_codigo", dias_coleta_entrevistador_max = 14
    ),
    "Multiagency"
  )

  expect_true(!is.null(result$resultado_agencias_otimo))
  expect_true(!is.null(result$resultado_agencias_jurisdicao))
  expect_equal(sum(result$resultado_agencias_otimo$n_ucs), nrow(ucs_multi))

  # Original per-UC jurisdiction is preserved in output
  ucs_jur <- result$resultado_ucs_jurisdicao
  uc2_jur <- ucs_jur$agencia_codigo_jurisdicao[ucs_jur$uc == ucs_multi$uc[2]]
  expect_equal(unique(uc2_jur), fake_ag)
})
