library(testthat)
library(dplyr)
library(orce)

# Carregar dados de teste
data(agencias_bdo_mun)
data(agencias_bdo)
data(distancias_agencias_municipios_osrm)
data(agencias_municipios_diaria)

# Criar dados de teste
ucs_municipios <- agencias_bdo_mun %>%
  filter(uf_codigo == 29) %>%
  filter(agencia_codigo %in% unique(agencia_codigo)) %>%
  group_by(agencia_codigo) %>%
  slice(1:2) %>%
  ungroup %>%
  ## uma agencia por municipio
  distinct(municipio_codigo, .keep_all = TRUE) %>%
  transmute(uc = municipio_codigo, municipio_codigo, agencia_codigo, dias_coleta = 10, viagens = 1, data = 1)

agencias <- agencias_bdo %>%
  semi_join(ucs_municipios,by = join_by(agencia_codigo)) %>%
  transmute(agencia_codigo, dias_coleta_agencia_max = Inf, custo_fixo = 0) %>%
  sf::st_drop_geometry()

dists <- distancias_agencias_municipios_osrm %>%
  left_join(agencias_municipios_diaria, by = join_by(agencia_codigo, municipio_codigo)) %>%
  semi_join(ucs_municipios, by = "municipio_codigo") %>%
  semi_join(agencias, by = "agencia_codigo") %>%
  mutate(diaria_pernoite = duracao_horas > 1.5, uc = municipio_codigo)

params_0 <- list(ucs = ucs_municipios, agencias = agencias, dias_coleta_entrevistador_max = 14, distancias_ucs = dists, remuneracao_entrevistador = 0, rel_tol = 0.01)

# Testes unitários
test_that("Alocação de UCs com períodos de coleta", {

  # Teste 1: Comparação com alocação sem períodos
  r_t <- do.call(alocar_ucs_t, params_0)
  r_uc <- do.call(alocar_ucs, params_0)
  expect_equal(nrow(r_uc$resultado_ucs_otimo %>% anti_join(r_t$resultado_i_otimo)), 0)

  # Teste 2: Alocação por grupo
  params_1 <- modifyList(params_0, list(ucs = params_0$ucs %>% mutate(g = agencia_codigo), alocar_por = "g"))
  r_t_i <- do.call(alocar_ucs_t, params_1)
  expect_lt(nrow(r_t_i$resultado_agencias_otimo), nrow(r_t_i$resultado_agencias_jurisdicao))

  # Teste 3: Aumento do custo fixo
  params_2 <- modifyList(params_1, list(agencias = params_1$agencias %>% mutate(custo_fixo = 10000)))
  r_t_if <- do.call(alocar_ucs_t, params_2)
  expect_lt(nrow(r_t_if$resultado_agencias_otimo), nrow(r_t_i$resultado_agencias_otimo))

  # Teste 4: Períodos de coleta
  n_periodos <- 2
  params_3 <- modifyList(params_2, list(ucs = params_2$ucs %>% mutate(data = rep(1:n_periodos, length = n()))))
  r_t_if_d <- do.call(alocar_ucs_t, params_3)
  expect_lt(sum(r_t_if_d$resultado_agencias_otimo$entrevistadores), sum(r_t_if$resultado_agencias_otimo$entrevistadores))

  # Teste 5: Ajuste do número de dias de coleta por entrevistador
  params_4 <- modifyList(params_3, list(dias_coleta_entrevistador_max = params_3$dias_coleta_entrevistador_max / n_distinct(params_3$ucs$data)))
  r_t_if_d2 <- do.call(alocar_ucs_t, params_4)

  # Teste 6: Verificação do número de entrevistadores
  verifica_entrevistadores <- function(result, result_type = "otimo", params) {
    ucs_municipios %>%
      transmute(g = agencia_codigo, data = rep(1:n_periodos, length = n()), agencia_codigo_jurisdicao = agencia_codigo, dias_coleta) %>%
      left_join(result[[paste0("resultado_i_", result_type)]] %>% distinct(agencia_codigo_otima = agencia_codigo, agencia_codigo_jurisdicao = g), by = c("agencia_codigo_jurisdicao"), suffix = c("_jurisdicao", "_otimo")) %>%
      group_by(agencia_codigo_otima, data) %>%
      summarise(dias_coleta = sum(dias_coleta)) %>%
      group_by(agencia_codigo_otima) %>%
      arrange(desc(dias_coleta)) %>%
      slice(1) %>%
      mutate(entrevistadores_necessarios = ceiling(dias_coleta / (params$dias_coleta_entrevistador_max))) %>%
      left_join(result[[paste0("resultado_agencias_", result_type)]] %>% select(agencia_codigo_otima = agencia_codigo, entrevistadores_modelo = entrevistadores)) %>%
      mutate(d = entrevistadores_modelo - entrevistadores_necessarios, data = NULL)
  }
  expect_gte(min(verifica_entrevistadores(r_t_if_d2, params = params_4)$d), 0)

  # Teste 7: Aumento da remuneração dos entrevistadores
  params_5 <- modifyList(params_4, list(remuneracao_entrevistador = 120001))
  r_t_if_d2_r <- do.call(alocar_ucs_t, params_5)
  expect_equal(max(verifica_entrevistadores(r_t_if_d2_r, params = params_5, result_type = "jurisdicao")$d), 0)
})
