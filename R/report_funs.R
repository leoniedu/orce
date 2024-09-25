#' @export
capitalizar <- function(..., locale="pt") ToTitleCasePT(..., abbreviations=c("ibge", "pof"))

#' @export
nomear_colunas <- function(x) capitalizar(gsub("_", " ", x))|>gsub(pattern = "\\bnome\\b", replacement = "", ignore.case=TRUE)

#' @export
fmt_nums <- function(x, decimal_pct=1, decimal_currency=0, decimal_num=2) {
  x|>
    gt::fmt_number(decimals=decimal_num, dec_mark = ",", sep_mark = ".", drop_trailing_zeros = TRUE)|>
    gt::fmt_currency(currency="BRL", decimals = decimal_currency, columns = starts_with("custo_"), dec_mark = ",", sep_mark=".")|>
    gt::fmt_percent(decimals = decimal_pct, columns = ends_with("_pct"),dec_mark = ",", sep_mark="." )
}

#' @export
print_gt <- function(x, ..., processar_nomes_colunas=TRUE) {
  x <- x|>
    fmt_nums(...)
  if (processar_nomes_colunas)
    x <- x|>
    gt::cols_label_with(fn="nomear_colunas")
  x <- x|>
    gt::sub_missing(
      missing_text = "-"
    )
  output_type <- knitr::opts_knit$get("rmarkdown.pandoc.to")
  if (interactive()|(length(output_type)==0)) return(x)
  if (output_type=="markdown") {
    html_content <- gt::as_raw_html(x, inline_css = FALSE)
    # Handle HTML output using XML tools
    xml_doc <- xml2::read_html(html_content)
    # Find and remove all <style> elements
    style_nodes <- xml2::xml_find_all(xml_doc, "//style")
    xml2::xml_remove(style_nodes)
    # Convert the modified XML back to HTML and print
    return(htmltools::HTML(as.character(xml_doc)))
  }
  return(x)
}

#' @export
gt1 <- function(..., decimal_pct=1, decimal_currency=0, decimal_num=2) gt::gt(...)|>print_gt(decimal_pct=decimal_pct, decimal_currency=decimal_currency, decimal_num=decimal_num)


#' @export
plano_municipios <- function(r) {
  vs <- c("municipio_nome", 'agencia_nome',
          'n_ucs', 'total_diarias', 'custo_diarias', 'custo_combustivel', 'distancia_total_km', 'custo_deslocamento',  'custo_fixo', 'entrevistadores', 'custo_total', "agencia_codigo")
  r1 <- r$resultado_municipios_otimo|>
    dplyr::full_join(r$resultado_municipios_jurisdicao, by=c("municipio_codigo", "agencia_codigo_jurisdicao"="agencia_codigo"), suffix=c("", "_jurisdicao"))|>
    dplyr::left_join(agencias_bdo, by="agencia_codigo")|>
    dplyr::left_join(agencias_bdo|>select(agencia_codigo, agencia_nome), by=c("agencia_codigo_jurisdicao"="agencia_codigo"), suffix=c("", "_jurisdicao"))|>
    dplyr::left_join(municipios_22, by="municipio_codigo")|>
    dplyr::transmute(troca=agencia_codigo!=agencia_codigo_jurisdicao,
                     dplyr::pick(starts_with(vs)))
  r1
}


#' @export
report_plans <- function(r) {
  vs <- c('agencia_nome', 'n_ucs', 'total_diarias', 'custo_diarias', 'custo_combustivel', 'distancia_total_km', 'custo_deslocamento',  'custo_fixo', 'entrevistadores', 'custo_total')
  r1 <- r$resultado_agencias_otimo|>
    dplyr::left_join(agencias_bdo, by="agencia_codigo")|>
    dplyr::transmute(n_agencias=1, custo_total=custo_fixo+custo_deslocamento+custo_total_entrevistadores,
                     dplyr::pick(any_of(vs)))
  r2 <- r$resultado_agencias_jurisdicao|>
    dplyr::left_join(agencias_bdo, by="agencia_codigo")|>
    dplyr::transmute(n_agencias=1, custo_total=custo_fixo+custo_deslocamento+custo_total_entrevistadores, dplyr::pick(any_of(vs)))
  rr <- r1|>
    dplyr::full_join(r2, by="agencia_nome", suffix=c("_otimo","_jurisdicao"))|>
    dplyr::ungroup()|>
    dplyr::select(any_of(matches(vs)))|>
    dplyr::mutate(agencia_nome=if_else(agencia_nome%in%r1$agencia_nome, capitalizar(agencia_nome), "Demais agências"))|>
    dplyr::group_by(agencia_nome)|>
    dplyr::summarise(across(where(is.numeric), sum))|>
    dplyr::arrange(agencia_nome)
  gt::gt(rr|>sf::st_drop_geometry(), rowname_col = "agencia_nome" )|>gt::grand_summary_rows(fns=list(fn='sum', label="Total Superintendência"), columns = where(is.numeric),fmt = ~fmt_nums(.x, decimal_num = 0, decimal_currency = 0))|>print_gt(decimal_num = 0, decimal_currency = 0)
}
