library(testthat)
library(orce)

# Dados mínimos para testar restrições (sem precisar de orcedata)
agencias_test <- data.frame(
  agencia_codigo = c("AG01", "AG02", "AG03"),
  n_entrevistadores_agencia_max = Inf,
  custo_fixo = 0,
  diaria_valor = 100,
  stringsAsFactors = FALSE
)

ucs_test <- data.frame(
  uc = c("UC01", "UC02", "UC03", "UC04"),
  agencia_codigo = c("AG01", "AG01", "AG02", "AG03"),
  dias_coleta = 5,
  viagens = 1,
  data = "2024-01",
  diaria_valor = 100,
  stringsAsFactors = FALSE
)

distancias_test <- tidyr::expand_grid(
  uc = ucs_test$uc,
  agencia_codigo = agencias_test$agencia_codigo
) |>
  dplyr::mutate(
    distancia_km = runif(dplyr::n(), 10, 200),
    duracao_horas = distancia_km / 60,
    diaria_municipio = distancia_km > 50,
    diaria_pernoite = distancia_km > 150
  )

# --- orce_aplicar_restricoes ---

test_that("restricoes vazia retorna dados inalterados", {
  res <- orce_aplicar_restricoes(ucs_test, agencias_test, distancias_test,
                                 restricoes = list())
  expect_identical(res$ucs, ucs_test)
  expect_identical(res$agencias, agencias_test)
  expect_identical(res$distancias_ucs, distancias_test)
  expect_null(res$agencias_treinamento)
})

test_that("bloquear define custos proibitivos para par UC-agencia", {
  restricoes <- list(
    list(tipo = "bloquear", uc = "UC01", agencia_codigo = "AG02")
  )
  res <- orce_aplicar_restricoes(ucs_test, agencias_test, distancias_test,
                                 restricoes = restricoes)

  bloqueado <- res$distancias_ucs |>
    dplyr::filter(uc == "UC01", agencia_codigo == "AG02")
  expect_equal(bloqueado$distancia_km, 1e6)
  expect_equal(bloqueado$duracao_horas, 1e6)

  # Outros pares não afetados
  outros <- res$distancias_ucs |>
    dplyr::filter(!(uc == "UC01" & agencia_codigo == "AG02"))
  expect_true(all(outros$distancia_km < 1e6))
})

test_that("bloquear aceita múltiplas UCs", {
  restricoes <- list(
    list(tipo = "bloquear", uc = c("UC01", "UC02"), agencia_codigo = "AG03")
  )
  res <- orce_aplicar_restricoes(ucs_test, agencias_test, distancias_test,
                                 restricoes = restricoes)

  bloqueados <- res$distancias_ucs |>
    dplyr::filter(uc %in% c("UC01", "UC02"), agencia_codigo == "AG03")
  expect_true(all(bloqueados$distancia_km == 1e6))
})

test_that("forcar define custos proibitivos para todas OUTRAS agencias", {
  restricoes <- list(
    list(tipo = "forcar", uc = "UC01", agencia_codigo = "AG01")
  )
  res <- orce_aplicar_restricoes(ucs_test, agencias_test, distancias_test,
                                 restricoes = restricoes)

  # Agência forçada mantém custo original
  forcado <- res$distancias_ucs |>
    dplyr::filter(uc == "UC01", agencia_codigo == "AG01")
  expect_true(forcado$distancia_km < 1e6)


  # Outras agências recebem custo proibitivo
  outros <- res$distancias_ucs |>
    dplyr::filter(uc == "UC01", agencia_codigo != "AG01")
  expect_true(all(outros$distancia_km == 1e6))
  expect_true(all(outros$duracao_horas == 1e6))
})

test_that("desativar_agencia remove de agencias e distancias_ucs", {
  restricoes <- list(
    list(tipo = "desativar_agencia", agencia_codigo = "AG03")
  )
  res <- orce_aplicar_restricoes(ucs_test, agencias_test, distancias_test,
                                 restricoes = restricoes)

  expect_false("AG03" %in% res$agencias$agencia_codigo)
  expect_false("AG03" %in% res$distancias_ucs$agencia_codigo)
  expect_equal(nrow(res$agencias), 2)
})

test_that("agencias_treinamento atualiza o vetor", {
  restricoes <- list(
    list(tipo = "agencias_treinamento",
         agencias_treinamento = c("AG01", "AG02"))
  )
  res <- orce_aplicar_restricoes(ucs_test, agencias_test, distancias_test,
                                 agencias_treinamento = "AG01",
                                 restricoes = restricoes)
  expect_equal(res$agencias_treinamento, c("AG01", "AG02"))
})

test_that("múltiplas restrições são aplicadas em sequência", {
  restricoes <- list(
    list(tipo = "desativar_agencia", agencia_codigo = "AG03"),
    list(tipo = "forcar", uc = "UC01", agencia_codigo = "AG01"),
    list(tipo = "bloquear", uc = "UC02", agencia_codigo = "AG01")
  )
  res <- orce_aplicar_restricoes(ucs_test, agencias_test, distancias_test,
                                 restricoes = restricoes)

  # AG03 removida
  expect_false("AG03" %in% res$agencias$agencia_codigo)

  # UC01 forçada para AG01 (AG02 proibitiva, AG03 já removida)
  uc01_ag02 <- res$distancias_ucs |>
    dplyr::filter(uc == "UC01", agencia_codigo == "AG02")
  expect_equal(uc01_ag02$distancia_km, 1e6)

  # UC02 bloqueada de AG01
  uc02_ag01 <- res$distancias_ucs |>
    dplyr::filter(uc == "UC02", agencia_codigo == "AG01")
  expect_equal(uc02_ag01$distancia_km, 1e6)
})

test_that("tipo inválido gera erro", {
  restricoes <- list(
    list(tipo = "invalido", uc = "UC01", agencia_codigo = "AG01")
  )
  expect_error(
    orce_aplicar_restricoes(ucs_test, agencias_test, distancias_test,
                            restricoes = restricoes),
    "inv.lido"
  )
})

# --- orce_gerar_codigo ---

test_that("gerar_codigo retorna string válida para restrições vazias", {
  codigo <- orce_gerar_codigo(list())
  expect_type(codigo, "character")
  expect_match(codigo, "Nenhuma")
})

test_that("gerar_codigo produz código para bloquear", {
  restricoes <- list(
    list(tipo = "bloquear", uc = "UC01", agencia_codigo = "AG01")
  )
  codigo <- orce_gerar_codigo(restricoes)
  expect_match(codigo, "Bloquear")
  expect_match(codigo, "UC01")
  expect_match(codigo, "AG01")
  expect_match(codigo, "1e6")
})

test_that("gerar_codigo produz código para forcar", {
  restricoes <- list(
    list(tipo = "forcar", uc = "UC01", agencia_codigo = "AG02")
  )
  codigo <- orce_gerar_codigo(restricoes)
  expect_match(codigo, "UC01")
  expect_match(codigo, "AG02")
  expect_match(codigo, "!=")
})

test_that("gerar_codigo produz código para desativar_agencia", {
  restricoes <- list(
    list(tipo = "desativar_agencia", agencia_codigo = "AG03")
  )
  codigo <- orce_gerar_codigo(restricoes)
  expect_match(codigo, "Desativar")
  expect_match(codigo, "AG03")
  expect_match(codigo, "filter")
})

test_that("gerar_codigo produz código para agencias_treinamento", {
  restricoes <- list(
    list(tipo = "agencias_treinamento",
         agencias_treinamento = c("AG01", "AG02"))
  )
  codigo <- orce_gerar_codigo(restricoes)
  expect_match(codigo, "treinamento")
  expect_match(codigo, "AG01")
  expect_match(codigo, "AG02")
})

test_that("gerar_codigo com múltiplas UCs usa c()", {
  restricoes <- list(
    list(tipo = "bloquear", uc = c("UC01", "UC02"), agencia_codigo = "AG01")
  )
  codigo <- orce_gerar_codigo(restricoes)
  expect_match(codigo, 'c\\("UC01", "UC02"\\)')
})

# --- Integração: código gerado é avaliável ---

test_that("código gerado por orce_gerar_codigo é avaliável", {
  restricoes <- list(
    list(tipo = "bloquear", uc = "UC01", agencia_codigo = "AG02"),
    list(tipo = "desativar_agencia", agencia_codigo = "AG03")
  )

  codigo <- orce_gerar_codigo(restricoes)

  # Criar ambiente com cópias dos dados originais
  env <- new.env(parent = baseenv())
  env$distancias_ucs <- distancias_test
  env$agencias <- agencias_test

  # Avaliar o código gerado
  eval(parse(text = codigo), envir = env)

  # Verificar que o código aplicou as restrições
  bloqueado <- env$distancias_ucs |>
    dplyr::filter(uc == "UC01", agencia_codigo == "AG02")
  expect_equal(bloqueado$distancia_km, 1e6)

  expect_false("AG03" %in% env$agencias$agencia_codigo)
})
