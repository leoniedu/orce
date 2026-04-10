library(testthat)
library(orce)

set.seed(42)
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
  expect_null(res$fixar_atribuicoes)
})

test_that("bloquear acumula em fixar_atribuicoes com valor=0 sem alterar distancias", {
  restricoes <- list(
    list(tipo = "bloquear", uc = "UC01", agencia_codigo = "AG02")
  )
  res <- orce_aplicar_restricoes(ucs_test, agencias_test, distancias_test,
                                 restricoes = restricoes)

  # distancias_ucs inalteradas
  expect_identical(res$distancias_ucs, distancias_test)

  # fixar_atribuicoes contém o par com valor=0
  expect_equal(nrow(res$fixar_atribuicoes), 1)
  expect_equal(res$fixar_atribuicoes$uc, "UC01")
  expect_equal(res$fixar_atribuicoes$agencia_codigo, "AG02")
  expect_equal(res$fixar_atribuicoes$valor, 0L)
})

test_that("bloquear aceita múltiplas UCs", {
  restricoes <- list(
    list(tipo = "bloquear", uc = c("UC01", "UC02"), agencia_codigo = "AG03")
  )
  res <- orce_aplicar_restricoes(ucs_test, agencias_test, distancias_test,
                                 restricoes = restricoes)

  blk <- res$fixar_atribuicoes[res$fixar_atribuicoes$valor == 0, ]
  expect_equal(nrow(blk), 2)
  expect_equal(sort(blk$uc), c("UC01", "UC02"))
  expect_true(all(blk$agencia_codigo == "AG03"))
})

test_that("forcar acumula em fixar_atribuicoes com valor=1 sem alterar distancias", {
  restricoes <- list(
    list(tipo = "forcar", uc = "UC01", agencia_codigo = "AG01")
  )
  res <- orce_aplicar_restricoes(ucs_test, agencias_test, distancias_test,
                                 restricoes = restricoes)

  # distancias_ucs inalteradas
  expect_identical(res$distancias_ucs, distancias_test)

  # fixar_atribuicoes contém o par com valor=1
  expect_equal(nrow(res$fixar_atribuicoes), 1)
  expect_equal(res$fixar_atribuicoes$uc, "UC01")
  expect_equal(res$fixar_atribuicoes$agencia_codigo, "AG01")
  expect_equal(res$fixar_atribuicoes$valor, 1L)
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

  # UC01 forçada para AG01 (valor=1)
  fix <- res$fixar_atribuicoes[res$fixar_atribuicoes$valor == 1, ]
  expect_equal(nrow(fix), 1)
  expect_equal(fix$uc, "UC01")
  expect_equal(fix$agencia_codigo, "AG01")

  # UC02 bloqueada de AG01 (valor=0)
  blk <- res$fixar_atribuicoes[res$fixar_atribuicoes$valor == 0, ]
  expect_equal(nrow(blk), 1)
  expect_equal(blk$uc, "UC02")
  expect_equal(blk$agencia_codigo, "AG01")
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

# --- orce_ucs_afetadas ---

resultado_ucs_test <- data.frame(
  uc = c("UC01", "UC02", "UC03", "UC04"),
  agencia_codigo = c("AG01", "AG01", "AG02", "AG03"),
  stringsAsFactors = FALSE
)

test_that("orce_ucs_afetadas retorna vazio para restricoes vazias", {
  expect_equal(orce_ucs_afetadas(list()), character(0))
})

test_that("orce_ucs_afetadas identifica UCs de bloquear", {
  restricoes <- list(
    list(tipo = "bloquear", uc = "UC01", agencia_codigo = "AG02")
  )
  expect_equal(orce_ucs_afetadas(restricoes), "UC01")
})

test_that("orce_ucs_afetadas identifica UCs de forcar", {
  restricoes <- list(
    list(tipo = "forcar", uc = c("UC01", "UC02"), agencia_codigo = "AG01")
  )
  expect_equal(orce_ucs_afetadas(restricoes), c("UC01", "UC02"))
})

test_that("orce_ucs_afetadas identifica UCs de agencia desativada", {
  restricoes <- list(
    list(tipo = "desativar_agencia", agencia_codigo = "AG01")
  )
  res <- orce_ucs_afetadas(restricoes, resultado_ucs_test)
  expect_equal(sort(res), c("UC01", "UC02"))
})

test_that("orce_ucs_afetadas combina tipos e deduplica", {
  restricoes <- list(
    list(tipo = "forcar", uc = "UC01", agencia_codigo = "AG01"),
    list(tipo = "bloquear", uc = "UC01", agencia_codigo = "AG02"),
    list(tipo = "desativar_agencia", agencia_codigo = "AG03")
  )
  res <- orce_ucs_afetadas(restricoes, resultado_ucs_test)
  expect_equal(sort(res), c("UC01", "UC04"))
})

test_that("orce_ucs_afetadas ignora agencias_treinamento", {
  restricoes <- list(
    list(tipo = "agencias_treinamento", agencias_treinamento = c("AG01"))
  )
  expect_equal(orce_ucs_afetadas(restricoes), character(0))
})

test_that("orce_ucs_afetadas expande para grupo alocar_por", {
  ucs_grupo <- data.frame(
    uc = c("UC01", "UC02", "UC03", "UC04"),
    municipio = c("M1", "M1", "M2", "M2"),
    stringsAsFactors = FALSE
  )
  restricoes <- list(
    list(tipo = "bloquear", uc = "UC01", agencia_codigo = "AG02")
  )
  # Sem agrupamento: só UC01
  expect_equal(orce_ucs_afetadas(restricoes), "UC01")
  # Com agrupamento: UC01 e UC02 (mesmo município M1)
  res <- orce_ucs_afetadas(restricoes, ucs = ucs_grupo, alocar_por = "municipio")
  expect_equal(sort(res), c("UC01", "UC02"))
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
  expect_match(codigo, "bloquear")
  expect_match(codigo, "UC01")
  expect_match(codigo, "AG01")
  expect_match(codigo, "orce_aplicar_restricoes")
})

test_that("gerar_codigo produz código para forcar", {
  restricoes <- list(
    list(tipo = "forcar", uc = "UC01", agencia_codigo = "AG02")
  )
  codigo <- orce_gerar_codigo(restricoes)
  expect_match(codigo, "forcar")
  expect_match(codigo, "UC01")
  expect_match(codigo, "AG02")
})

test_that("gerar_codigo produz código para desativar_agencia", {
  restricoes <- list(
    list(tipo = "desativar_agencia", agencia_codigo = "AG03")
  )
  codigo <- orce_gerar_codigo(restricoes)
  expect_match(codigo, "desativar_agencia")
  expect_match(codigo, "AG03")
  expect_match(codigo, "orce_aplicar_restricoes")
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

test_that("gerar_codigo inclui params_alterados na chamada orce()", {
  codigo <- orce_gerar_codigo(
    params_alterados = list(rel_tol = 0.01, dias_treinamento = 4, solver = "glpk")
  )
  expect_match(codigo, "rel_tol = 0.01")
  expect_match(codigo, "dias_treinamento = 4")
  expect_match(codigo, 'solver = "glpk"')
  expect_match(codigo, "resultado_completo = TRUE")
})

test_that("gerar_codigo inclui params_fixos na chamada orce()", {
  codigo <- orce_gerar_codigo(
    params_alterados = list(rel_tol = 0.01),
    params_fixos = list(alocar_por = "municipio_codigo", kml = 12)
  )
  expect_match(codigo, 'alocar_por = "municipio_codigo"')
  expect_match(codigo, "kml = 12")
  expect_match(codigo, "rel_tol = 0.01")
})

test_that("gerar_codigo inclui agencias_treinamento na chamada orce()", {
  restricoes <- list(
    list(tipo = "agencias_treinamento",
         agencias_treinamento = c("AG01"))
  )
  codigo <- orce_gerar_codigo(restricoes)
  expect_match(codigo, "agencias_treinamento")
  expect_match(codigo, "AG01")
  expect_match(codigo, "dados\\$agencias_treinamento")
})

test_that("gerar_codigo com Inf gera valor correto", {
  codigo <- orce_gerar_codigo(
    params_alterados = list(diarias_entrevistador_max = Inf)
  )
  expect_match(codigo, "diarias_entrevistador_max = Inf")
})

test_that("gerar_codigo inclui valor na fixar_atribuicoes quando há bloqueios", {
  fixar <- data.frame(uc = c("UC01", "UC02"),
                      agencia_codigo = c("AG01", "AG03"),
                      valor = c(1L, 0L),
                      stringsAsFactors = FALSE)
  codigo <- orce_gerar_codigo(fixar_atribuicoes = fixar)
  expect_match(codigo, "Fixar 1")
  expect_match(codigo, "Bloquear 1")
  expect_match(codigo, "fixar_atribuicoes")
  expect_match(codigo, "valor")
  expect_match(codigo, "UC01")
  expect_match(codigo, "AG03")
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

  # Criar ambiente com acesso ao pacote orce
  env <- new.env(parent = asNamespace("orce"))
  env$ucs <- ucs_test
  env$distancias_ucs <- distancias_test
  env$agencias <- agencias_test
  env$agencias_treinamento <- NULL

  # Avaliar apenas a parte de restrições (sem a chamada orce())
  linhas <- strsplit(codigo, "\n")[[1]]
  idx_orce <- grep("^resultado <- orce", linhas)
  if (length(idx_orce) > 0) {
    linhas <- linhas[seq_len(idx_orce[1] - 1)]
  }
  eval(parse(text = paste(linhas, collapse = "\n")), envir = env)

  # Verificar que o código aplicou as restrições via orce_aplicar_restricoes
  # bloquear gera fixar_atribuicoes com valor=0 (distancias inalteradas)
  blk <- env$dados$fixar_atribuicoes[env$dados$fixar_atribuicoes$valor == 0, ]
  expect_equal(nrow(blk), 1)
  expect_equal(blk$uc, "UC01")
  expect_equal(blk$agencia_codigo, "AG02")

  expect_false("AG03" %in% env$dados$agencias$agencia_codigo)
})
