library(testthat)
library(orce)

# Carregar dados de teste
data(agencias_bdo_mun)
data(agencias_bdo)
data(distancias_agencias_municipios_osrm)
data(agencias_municipios_diaria)

# Criar dados de teste
ucs_municipios <- agencias_bdo_mun |>
  dplyr::filter(uf_codigo == 29) |>
  dplyr::filter(agencia_codigo %in% unique(agencia_codigo)) |>
  dplyr::group_by(agencia_codigo) |>
  dplyr::slice(1:2) |>
  dplyr::ungroup() |>
  ## uma agencia por municipio
  dplyr::distinct(municipio_codigo, .keep_all = TRUE) |>
  dplyr::transmute(uc = municipio_codigo, municipio_codigo, agencia_codigo, dias_coleta = 10, viagens = 1, data = 1)

agencias <- agencias_bdo |>
  dplyr::semi_join(ucs_municipios,by = dplyr::join_by(agencia_codigo)) |>
  dplyr::transmute(agencia_codigo, dias_coleta_agencia_max = Inf, custo_fixo = 0) |>
  sf::st_drop_geometry()

dists <- distancias_agencias_municipios_osrm |>
  dplyr::left_join(agencias_municipios_diaria, by = dplyr::join_by(agencia_codigo, municipio_codigo)) |>
  dplyr::semi_join(ucs_municipios, by = "municipio_codigo") |>
  dplyr::semi_join(agencias, by = "agencia_codigo") |>
  dplyr::mutate(diaria_pernoite = duracao_horas > 1.5, uc = municipio_codigo)

params_0 <- list(ucs = ucs_municipios, agencias = agencias, dias_coleta_entrevistador_max = 14, distancias_ucs = dists, remuneracao_entrevistador = 0, rel_tol = 0.01)

# Testes unitários
test_that("Alocação de UCs com períodos de coleta", {
  f <- alocar_ucs

  # Teste 1: Comparação com alocação sem períodos
  r_t <- do.call(f, modifyList(params_0, list(use_cache=FALSE)))
  expect_equal(r_t$resultado_agencias_otimo$custo_deslocamento, c(486.72, 1596.88, 3415.552, 3866.176, 26.84, 637.28, 797.84, 21.92, 673.12, 717.92, 9083.32, 842.4, 2681.64, 641.56, 948.28, 791.04, 2517.84, 1237.6, 3252.48, 1534.12, 1071, 995.6, 1536.2, 1188, 2434.96, 9997.184, 1585.92, 3484.152, 1102.16, 3336.74,4445.504, 1480.56, 2029.32, 123.44, 246.24, 7519.5, 6762.72,5, 2108.56, 765.48, 4082.292, 985, 876.44, 4863.24, 1891.84,4515.508, 4653.08))

  # Teste 2: Alocação por grupo
  params_1 <- modifyList(params_0, list(ucs = params_0$ucs |> dplyr::mutate(g = agencia_codigo), alocar_por = "g"))
  r_t_i <- do.call(f, params_1)
  expect_lt(nrow(r_t_i$resultado_agencias_otimo), nrow(r_t_i$resultado_agencias_jurisdicao))

  # Teste 3: Aumento do custo fixo
  params_2 <- modifyList(params_1, list(agencias = params_1$agencias |> dplyr::mutate(custo_fixo = 10000)))
  r_t_if <- do.call(f, params_2)
  expect_lt(nrow(r_t_if$resultado_agencias_otimo), nrow(r_t_i$resultado_agencias_otimo))

  # Teste 4: Períodos de coleta
  n_periodos <- 2
  params_3 <- modifyList(params_2, list(ucs = params_2$ucs |> dplyr::mutate(data = rep(1:n_periodos, length = dplyr::n()))))
  r_t_if_d <- do.call(f, params_3)
  expect_lt(sum(r_t_if_d$resultado_agencias_otimo$entrevistadores), sum(r_t_if$resultado_agencias_otimo$entrevistadores))

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


  # Teste: número de entrevistadores como variável contínua
  params_c <- modifyList(params_5, list(n_entrevistadores_tipo = "continuous"))
  r_i <- do.call(f, params_5)
  r_c <- do.call(f, params_c)


})
