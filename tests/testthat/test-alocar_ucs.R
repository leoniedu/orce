# Load necessary libraries
library(testthat)
library(orce) # Replace 'your_package' with the actual package name
library(dplyr)

set.seed(20091975)
# Simulate Fake Data
ucs <- tibble::tibble(
  uc = paste0("UC", 1:10),
  #municipio_codigo = sample(1000:1005, 10, replace = TRUE),
  agencia_codigo = sample(LETTERS[1:3], 10, replace = TRUE),
  dias_coleta=sample(1:10, 10),
  viagens=dias_coleta/2
)

agencias <- tibble::tibble(
  agencia_codigo = LETTERS[1:3],
  agencia_lon = runif(3, -50, -40),
  agencia_lat = runif(3, -20, -10),
  dias_coleta_agencia_max=Inf,
  custo_fixo = 500
)

distancias_ucs <- tibble::tibble(
  uc = rep(ucs$uc, each = nrow(agencias)),
  agencia_codigo = rep(agencias$agencia_codigo, nrow(ucs)),
  distancia_km = runif(nrow(ucs) * nrow(agencias), 0, 200),
  duracao_horas = runif(nrow(ucs) * nrow(agencias), 0, 5)
)|>
  dplyr::mutate(diaria_municipio=sample(c(TRUE,FALSE), replace = TRUE, size=dplyr::n()),
                diaria_pernoite=sample(c(TRUE,FALSE), replace = TRUE, size=dplyr::n())
                )


distancias_agencias <- tibble::tibble(
  agencia_codigo_orig = rep(agencias$agencia_codigo, each = nrow(agencias)),
  agencia_codigo_dest = rep(agencias$agencia_codigo, nrow(agencias)),
  distancia_km = runif(nrow(agencias) * nrow(agencias), 0, 50),
  duracao_horas = runif(nrow(agencias) * nrow(agencias), 0, 2)
)

# Define the test cases
test_that("alocar_ucs returns expected structure", {

  result <- alocar_ucs(
    ucs = ucs,
    agencias = agencias,
    custo_litro_combustivel =  6,
    custo_hora_viagem = 10,
    kml = 10,
    valor_diaria = 335,
    dias_treinamento = 5.5,
    dias_coleta_entrevistador = 10,
    n_entrevistadores_min=2,
    distancias_ucs = distancias_ucs,
    distancias_agencias = distancias_agencias,
    adicional_troca_jurisdicao = 10,
    agencias_treinamento = "A",
    resultado_completo=TRUE
  )

  result <- alocar_ucs(
    ucs = ucs,
    #agencias = agencias,
    custo_litro_combustivel =  6,
    custo_hora_viagem = 10,
    kml = 10,
    valor_diaria = 335,
    dias_treinamento = 5.5,
    dias_coleta_entrevistador = 10,
    n_entrevistadores_min=2,
    distancias_ucs = distancias_ucs,
    distancias_agencias = distancias_agencias,
    adicional_troca_jurisdicao = 10,
    agencias_treinamento = "A",
    resultado_completo=TRUE,
    solver="highs"
  )

  result <- try({alocar_ucs(
    ucs = ucs,
    agencias = agencias%>%mutate(dias_coleta_agencia_max=10),
    custo_litro_combustivel =  6,
    custo_hora_viagem = 10,
    kml = 10,
    valor_diaria = 335,
    dias_treinamento = 5.5,
    dias_coleta_entrevistador = 3,
    n_entrevistadores_min=2,
    distancias_ucs = distancias_ucs,
    distancias_agencias = distancias_agencias,
    adicional_troca_jurisdicao = 10,
    agencias_treinamento = "A",
    resultado_completo=TRUE,
    solver="symphony"
  )})
  expect_s3_class(result, "try-error")


  result <- alocar_ucs(
    ucs = ucs,
    agencias = agencias,
    custo_litro_combustivel =  6,
    custo_hora_viagem = 10,
    kml = 10,
    valor_diaria = 335,
    dias_treinamento = 5.5,
    dias_coleta_entrevistador = 10,
    n_entrevistadores_min=2,
    distancias_ucs = distancias_ucs,
    distancias_agencias = distancias_agencias,
    agencias_treinamento = "A",
    resultado_completo=TRUE,
    adicional_troca_jurisdicao=1e6,
    solver="glpk"
  )

  result <- alocar_ucs(
    ucs = ucs,
    agencias = agencias,
    custo_litro_combustivel =  6,
    custo_hora_viagem = 10,
    kml = 10,
    valor_diaria = 335+runif(1),
    dias_treinamento = 5.5,
    dias_coleta_entrevistador = 2,
    n_entrevistadores_min=2,
    distancias_ucs = distancias_ucs,
    distancias_agencias = distancias_agencias,
    agencias_treinamento = "A",
    resultado_completo=TRUE,
    adicional_troca_jurisdicao=1e6,
    solver="symphony"
  )

  result <- alocar_ucs(
    ucs = ucs,
    agencias = agencias|>dplyr::mutate(max_uc_agencia=c(2,2,8)),
    custo_litro_combustivel =  6,
    custo_hora_viagem = 10,
    kml = 10,
    valor_diaria = 335,
    dias_treinamento = 5.5,
    distancias_ucs = distancias_ucs,
    distancias_agencias = distancias_agencias,
    dias_coleta_entrevistador=3,
    adicional_troca_jurisdicao = 1000,
    agencias_treinamento = "A",
    resultado_completo=TRUE
  )

  result <- alocar_ucs(
    ucs = ucs,
    dias_coleta_entrevistador=100,
    custo_litro_combustivel =  6,
    custo_hora_viagem = 10,
    kml = 10,
    valor_diaria = 335,
    dias_treinamento = 5.5,
    distancias_ucs = distancias_ucs,
    distancias_agencias = distancias_agencias,
    adicional_troca_jurisdicao = 1000,
    agencias_treinamento = "A",
    resultado_completo=TRUE
  )

  result <- alocar_ucs(
    ucs = ucs,
    agencias = agencias,
    custo_litro_combustivel =  6,
    custo_hora_viagem = 10,
    kml = 10,
    valor_diaria = 335,
    dias_treinamento = 0,
    distancias_ucs = distancias_ucs,
    distancias_agencias = distancias_agencias,
    adicional_troca_jurisdicao = 1000,
    agencias_treinamento = "A",
    resultado_completo=TRUE,
    dias_coleta_entrevistador = 3
  )

  result <- alocar_ucs(
    ucs = ucs,
    agencias = agencias,
    custo_litro_combustivel =  6,
    custo_hora_viagem = 10,
    kml = 10,
    valor_diaria = 335,
    dias_treinamento = 0,
    distancias_ucs = distancias_ucs,
    distancias_agencias = distancias_agencias,
    adicional_troca_jurisdicao = 1000,
    agencias_treinamento = "A",
    resultado_completo=FALSE,
    dias_coleta_entrevistador = 1.1
  )


  result <- alocar_ucs(
    ucs = ucs,
    agencias = agencias,
    custo_litro_combustivel =  6,
    custo_hora_viagem = 10,
    kml = 10,
    valor_diaria = 335,
    dias_treinamento = 0,
    distancias_ucs = distancias_ucs,
    distancias_agencias = distancias_agencias,
    adicional_troca_jurisdicao = 0,
    agencias_treinamento = "A",
    resultado_completo=TRUE,
    dias_coleta_entrevistador = 1.2
  )

  # Check if result is a list
  expect_type(result, "list")

  # Check if the 'ucs_alocadas' is a tibble/dataframe with expected columns
  expect_setequal(names(result), c("resultado_ucs_otimo", "resultado_ucs_jurisdicao", "resultado_agencias_otimo", "resultado_agencias_jurisdicao", "ucs_agencias_todas", "otimizacao", "log"))

  # Check if the all 'uc' in 'ucs_alocadas'
  expect_true(all(ucs$uc%in%result$resultado_ucs_otimo$uc))

})
