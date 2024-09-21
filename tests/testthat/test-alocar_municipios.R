# Load necessary libraries
library(testthat)
library(orce)

set.seed(20091975)

# Simulate Fake Data
ucs <- tibble::tibble(
  uc = paste0("UC", 1:10),
  municipio_codigo = sample(1000:1005, 10, replace = TRUE), # Add municipio_codigo
  agencia_codigo = sample(LETTERS[1:3], 10, replace = TRUE),
  dias_coleta = sample(1:10, 10),
  viagens = dias_coleta / 2
)

agencias <- tibble::tibble(
  agencia_codigo = LETTERS[1:3],
  agencia_lon = runif(3, -50, -40),
  agencia_lat = runif(3, -20, -10),
  uc_agencia_max = Inf,
  custo_fixo = 500,
  dias_coleta_agencia_max = Inf  # Add if applicable
)

distancias_ucs <- tibble::tibble(
  uc = rep(ucs$uc, each = nrow(agencias)),
  municipio_codigo = rep(ucs$municipio_codigo, each = nrow(agencias)), # Include municipio_codigo
  agencia_codigo = rep(agencias$agencia_codigo, nrow(ucs)),
  distancia_km = runif(nrow(ucs) * nrow(agencias), 0, 200),
  duracao_horas = runif(nrow(ucs) * nrow(agencias), 0, 5)
) |>
  dplyr::mutate(
    diaria_municipio = sample(c(TRUE, FALSE), replace = TRUE, size = dplyr::n()),
    diaria_pernoite = sample(c(TRUE, FALSE), replace = TRUE, size = dplyr::n())
  )

distancias_agencias <- tibble::tibble(
  agencia_codigo_orig = rep(agencias$agencia_codigo, each = nrow(agencias)),
  agencia_codigo_dest = rep(agencias$agencia_codigo, nrow(agencias)),
  distancia_km = runif(nrow(agencias) * nrow(agencias), 0, 50),
  duracao_horas = runif(nrow(agencias) * nrow(agencias), 0, 2)
)

# Define the test cases
test_that("alocar_municipios returns expected structure", {
  # ... (Your test cases here, using alocar_municipios)

  result <- alocar_municipios(
    ucs = ucs,
    agencias = agencias,
    custo_litro_combustivel = 6,
    custo_hora_viagem = 10,
    kml = 10,
    valor_diaria = 335,
    dias_treinamento = 5.5,
    dias_coleta_entrevistador_max = 10,
    uc_agencia_min = 1,
    n_entrevistadores_min = 2,
    distancias_ucs = distancias_ucs,
    distancias_agencias = distancias_agencias,
    adicional_troca_jurisdicao = 10,
    agencias_treinamento = "A",
    resultado_completo = TRUE
  )

  # Check if result is a list
  expect_type(result, "list")

  # Check if the expected elements are present in the result
  expect_setequal(names(result), c("resultado_municipios_otimo", "resultado_municipios_jurisdicao", "resultado_agencias_otimo", "resultado_agencias_jurisdicao", "municipios_agencias_todas", "otimizacao"))

  # Check if all 'municipio_codigo' in 'resultado_municipios_otimo'
  expect_true(all(ucs$municipio_codigo %in% result$resultado_municipios_otimo$municipio_codigo))

})
