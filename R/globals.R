#' @importFrom utils globalVariables
NULL

# data.table NSE symbols used in package code
# This silences R CMD check "no visible binding for global variable" notes
# See: data.table vignette "Importing data.table"
utils::globalVariables(c(
  ".N", ".I", ".GRP",
  # column names used via NSE in data.table expressions
  "i", "j", "t",
  "uc", "uc_orig", "uc_dest",
  "agencia_codigo", "agencia_codigo_orig", "agencia_codigo_dest",
  "agencia_codigo_jurisdicao",
  "data", "viagens", "dias_coleta", "diaria_valor",
  "distancia_km", "duracao_horas",
  "diaria_municipio", "diaria_pernoite",
  "distancia_km_agencia_treinamento", "duracao_horas_agencia_treinamento_km",
  "treinamento_com_diaria", "custo_treinamento_por_entrevistador",
  "n_ucs", "value", "i_next",
  "n_entrevistadores_agencia_max", "custo_fixo",
  # computed columns in cost pipeline
  "diaria", "meia_diaria", "trechos", "total_diarias",
  "distancia_total_km", "duracao_total_horas",
  "custo_combustivel", "custo_horas_viagem",
  "custo_troca_jurisdicao", "custo_deslocamento",
  "custo_deslocamento_com_troca"
))
