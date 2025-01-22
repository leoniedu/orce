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
  if (grepl("markdown", output_type)) {
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
relatorio_municipios <- function(r) {
  vs <- c("municipio_nome", 'agencia_nome','custo_total', 'n_ucs', 'total_diarias', 'custo_diarias', 'custo_combustivel', 'distancia_total_km', 'custo_deslocamento',  'custo_fixo', 'entrevistadores', "agencia_codigo", "municipio_codigo")
  r1 <- r$resultado_ucs_otimo|>
    dplyr::full_join(r$resultado_ucs_jurisdicao, by=c("uc", "agencia_codigo_jurisdicao"="agencia_codigo"), suffix=c("", "_jurisdicao"))|>
    dplyr::left_join(agencias_bdo, by="agencia_codigo")|>
    dplyr::left_join(agencias_bdo|>select(agencia_codigo, agencia_nome), by=c("agencia_codigo_jurisdicao"="agencia_codigo"), suffix=c("", "_jurisdicao"))|>
    dplyr::mutate(municipio_codigo=substr(uc,1,7))|>
    dplyr::left_join(municipios_22, by=c("municipio_codigo"))|>
    dplyr::transmute(troca=agencia_codigo!=agencia_codigo_jurisdicao,
                     dplyr::pick(starts_with(vs)))
  r1
}


#' @export
relatorio_planos <- function(r, level="uc") {
  levels <- dplyr::if_else(level=="uc", "ucs", "municipios")
  nlevels <- paste0("n_", levels)
  vs <- c('agencia_codigo', 'agencia_nome', 'custo_total',
          "n_otimo", "n_jurisdicao", "perde", "recebe",
          'total_diarias',
          'custo_combustivel',
          'entrevistadores',
          'custo_fixo', "n_agencias"
          #, 'dias_coleta'#,   'custo_diarias',  'distancia_total_km', 'custo_deslocamento',  'custo_troca_jurisdicao'
          )
  trocas_0 <- r[[paste0('resultado_',levels,'_otimo')]]|>
  dplyr::left_join(r[[paste0('resultado_',levels,'_jurisdicao')]]|>
                     dplyr::select(agencia_codigo, {level}), by=level,
                   suffix=c("_otimo", "_jurisdicao"))|>
    dplyr::mutate(troca=agencia_codigo_jurisdicao!=agencia_codigo_otimo)
  trocas_1 <- trocas_0|>
    dplyr::group_by(agencia_codigo=agencia_codigo_jurisdicao)|>
    dplyr::summarise(perde=sum(troca), n=dplyr::n())
  trocas_2 <- trocas_0|>
    dplyr::group_by(agencia_codigo=agencia_codigo_otimo)|>
    dplyr::summarise(recebe=sum(troca), n=dplyr::n())
  trocas <- trocas_1|>dplyr::full_join(trocas_2, by="agencia_codigo", suffix=c("_jurisdicao", "_otimo"))|>
    dplyr::mutate(across(everything(),  ~tidyr::replace_na(.x,0)))
  r1 <- r$resultado_agencias_otimo|>
    dplyr::transmute(n_agencias=1, custo_total=custo_fixo+custo_deslocamento+custo_total_entrevistadores,
                     dplyr::pick(any_of(vs)))
  r2 <- r$resultado_agencias_jurisdicao|>
    dplyr::transmute(n_agencias=1, custo_total=custo_fixo+custo_deslocamento+custo_total_entrevistadores, dplyr::pick(any_of(vs)))
  rr <- r1|>
    dplyr::full_join(r2, by="agencia_codigo", suffix=c("_otimo","_jurisdicao"))|>
    dplyr::ungroup()|>
    dplyr::full_join(trocas, by=c("agencia_codigo"="agencia_codigo"))|>
    dplyr::select(any_of(dplyr::matches(vs)))|>
    dplyr::left_join(agencias_bdo|>sf::st_drop_geometry()|>dplyr::select(agencia_codigo, agencia_nome))|>
    dplyr::mutate(
      n_otimo=dplyr::coalesce(n_otimo,0),
      sem_alteracao=(perde==0)&(recebe==0),
      agencia_nome=capitalizar(agencia_nome),
      agencia_nome_rec=dplyr::case_when(
      sem_alteracao&(sum(sem_alteracao)>1) ~ "Agências sem alteração*",
      (n_otimo==0)&(sum(n_otimo==0)>1) ~ "Agências excluídas**",
      TRUE ~ agencia_nome
    ), sem_alteracao=NULL)|>
    dplyr::group_by(agencia_nome_rec)|>
    dplyr::summarise(dplyr::across(dplyr::where(is.numeric), ~sum(.x, na.rm=TRUE)), agencias_nomes=paste(agencia_nome, collapse=", "))|>
    dplyr::arrange(grepl("\\*", agencia_nome_rec), agencia_nome_rec, desc(n_jurisdicao))|>
    dplyr::ungroup()|>
    dplyr::mutate(N=glue::glue("{n_otimo}<br>({n_jurisdicao}{
                               if_else((recebe>0) | (perde>0),
                               paste(' +', recebe, if_else(perde>0, paste0(' -', perde), '')), '')})"))|>
    dplyr::select(agencia_nome_rec, N, everything(), -n_otimo, -n_jurisdicao, -recebe, -perde)|>
    janitor::remove_constant()
  out <- gt::gt(rr|>sf::st_drop_geometry(), rowname_col = "agencia_nome_rec" )|>
    gt::grand_summary_rows(fns=list(fn='sum', label="Total Superintendência"), columns = where(is.numeric),fmt = ~fmt_nums(.x, decimal_num = 0, decimal_currency = 0))|>
    print_gt(decimal_num = 0, decimal_currency = 0)|>
    gt::cols_hide(agencias_nomes)
  if (any(grepl("sem alteração", rr$agencia_nome_rec))) {
    out <- out|>
      gt::tab_footnote(paste0("Agências sem alteração: ", rr|>dplyr::filter(grepl("sem alteração", agencia_nome_rec))|>dplyr::pull(agencias_nomes)))
  }
  if (any(grepl("excluídas", rr$agencia_nome_rec))) {
    out <- out|>gt::tab_footnote(paste0("Agências excluídas: ", rr|>dplyr::filter(grepl("excluídas", agencia_nome_rec))|>dplyr::pull(agencias_nomes)))
  }
  out|>
    gt::cols_label("N"="Unidades de Coleta")|>
    gt::fmt_markdown(N)
}
