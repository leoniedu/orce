#' @export
rename_ibge <- function(x) {
  lookup <- c(setor='cod_setor',
              setor='code_tract',
              setor="controle",
              uf_codigo='cod_uf',
              uf_codigo='code_state',
              uf_sigla='abbrev_state',
              uf_sigla='sigla_uf',
              aglomeracao_codigo='cod_catau',
              aglomeracao_nome='nome_catau',
              municipio_codigo="cod_mun",
              municipio_codigo="cod_municipio",
              municipio_codigo="code_muni",
              micro_codigo="code_micro",
              micro_nome="name_micro",
              meso_codigo="code_meso",
              meso_nome="name_meso",
              municipio_nome="name_muni",
              uf_nome="name_state",
              distrito_codigo='code_district',
              distrito_nome='name_district',
              subdistrito_codigo="code_subdistrict",
              subdistrito_nome='name_subdistrict',
              municipio_nome="municipio",
              municipio_nome="nome_mun",
              agencia_codigo='cod_ag',
              agencia_codigo='cod_agenci',
              agencia_codigo='cod_agencia',
              agencia_nome='agencia',
              regiao_codigo='code_region',
              regiao_nome='name_region',
              ano='year',
              agencia_nome='nome_agenc',
              situacao_tipo='tipo_sit')
  newx <- x |>
    janitor::clean_names() |>
    dplyr::rename(dplyr::any_of(lookup)) |>
    dplyr::rename_with(.fn = function(x) {
      x <- gsub("longitude", "lon", x)
      gsub("latitude", "lat", x)
      }) |>
    dplyr::mutate(across(dplyr::any_of(tidyselect::matches("_codigo|^upa$|^setor$")), as.character))
  newx
}
