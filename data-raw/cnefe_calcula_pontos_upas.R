## maior densidade de domicilios particulares, quando existem.
## se não, maior densidade dos endereços
library(dplyr)
library(arrow)
library(orce)
fname <- here::here("data-raw/pontos_upas.rds")
if (file.exists(fname)) {
  pontos_upas <- readr::read_rds(fname)
} else {
  pontos_upas <- tibble(upa=as.character())
}
pontos_upas_0 <- pontos_upas
out_dir <- here::here(file.path("data-raw","cnefe", "2022"))


amostra_mestra <- readRDS(here::here("data-raw/amostra_br_2024_01_2025_06.rds"))%>%
  mutate(trimestre=ceiling(as.numeric(mes_codigo)/3),
         upa_nova=upa,
         upa=coalesce(upa_antiga, upa_nova))


get_ponto_upa_0 <- function(upa, setores_now) {
  ufnow <- unique(as.numeric(substr(setores_now,1,2)))
  stopifnot(length(ufnow)==1)
  setores_now <- as.character(setores_now)
  cnefe <- open_dataset(file.path(out_dir,"arrow"))%>%
    dplyr::filter(uf_codigo==ufnow)%>%
    dplyr::filter(setor%in%{{setores_now}})%>%
    ## 1=Domicílio particular
    dplyr::count(dp=especie_codigo==1,latitude,longitude)%>%
    collect()
  cnefe_upa_0 <- cnefe%>%
    dplyr::filter(dp)
  if (nrow(cnefe_upa_0)==0) {
    ## nao tem domicilio particular no setor
    cnefe_upa_0 <- cnefe%>%
      dplyr::count(latitude,longitude)
  }
  cnefe_upa <- cnefe_upa_0%>%
    sf::st_as_sf(crs=sf::st_crs("EPSG:4674"), coords=c("longitude", "latitude"))
  ponto_upa <- ponto_densidade(cnefe_upa%>%mutate(upa={{upa}}), upa)
  ponto_upa
}
get_ponto_upa <- memoise::memoise(get_ponto_upa_0)

upas <- amostra_mestra%>%
  group_by(upa, ano, trimestre)%>%
  ## a partir do 2o trimestre de 2023 é utilizado o CNEFE do Censo
  ## obs, com a atualização dos setores o cálculo deverá ser refeito
  ## mas não se espera grandes alterações
  filter(ano_mes>="2023-04-01")%>%
  summarise(setores=list(setor))

upas_new <- upas%>%
  anti_join(pontos_upas)

pontos_upas_new <- purrr::pmap(upas_new, function(upa, setores, ano, trimestre) get_ponto_upa(upa, setores_now = setores)%>%mutate(ano={{ano}}, trimestre={{trimestre}}), .progress = TRUE)%>%
  bind_rows()%>%
  sf::st_as_sf(coords=c("lon", "lat"), remove=FALSE, crs=sf::st_crs("EPSG:4674"))%>%
  dplyr::rename("upa_cnefe_lon"=lon, 'upa_cnefe_lat'=lat)

## setores faltando
# upas%>%
#   tidyr::unnest(setores)%>%
#   rename(setor=setores)%>%
#   ungroup%>%
#   distinct(upa, setor)%>%
#   group_by(upa)%>%
#   reframe(n_setores=n_distinct(setor), setor=unique(setor))%>%
#   anti_join(cnefe%>%ungroup%>%distinct(setor)%>%collect(), by=c("setor"))%>%
#   filter(n_setores==1)
#
# ## upas faltando
# upas_faltando <- upas%>%
#   ungroup%>%
#   distinct(upa)%>%
#   anti_join(pontos_upas%>%sf::st_drop_geometry(), by="upa")
# stopifnot(nrow(upas_faltando)==0)

pontos_upas <- bind_rows(pontos_upas_0, pontos_upas_new)

readr::write_rds(pontos_upas, "data-raw/pontos_upas.rds")
stop()

setores2010_map <- readRDS("data-raw/setores2010_map.rds")
setores2022_map <- readRDS("data-raw/setores2022_map.rds")

upas_miss <- upas%>%anti_join(pontos_upas, by=c("ano", "trimestre", "upa"="upa"))%>%tidyr::unnest(setores)%>%rename(setor=setores)

upas_up_0 <- setores2022_map%>%
  mutate(setor=as.character(code_tract))%>%
  inner_join(upas_miss)%>%
  group_by(upa, ano, trimestre)%>%
  sf::st_centroid()%>%
  distinct(upa, ano, trimestre)

upas_up_1 <- setores2010_map%>%
  mutate(setor=as.character(code_tract))%>%
  inner_join(upas_miss)%>%
  group_by(upa, ano, trimestre)%>%
  sf::st_centroid()%>%
  distinct(upa, ano, trimestre)



upas_miss%>%anti_join(upas_up_0)
