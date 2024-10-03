library(furrr)
plan("future::multisession", workers=4)

library(dplyr)
library(arrow)
library(orce)
fname <- here::here("data/pontos_setores.rda")
if (file.exists(fname)) {
  load(fname)
} else {
  pontos_setores <- tibble(setor=as.character())
}
out_dir <- here::here(file.path("data-raw","cnefe", "2022"))

get_ponto_setor <- function(setor_now) {
  ufnow <- as.numeric(substr(setor_now,1,2))
  setor_now <- as.character(setor_now)
  cnefe <- open_dataset(file.path(out_dir,"arrow"))%>%
    filter(uf_codigo==ufnow)%>%
    dplyr::filter(especie_codigo==1) ## 1=Domicílio particular
  cnefe_setor_0 <- cnefe%>%
    dplyr::filter(setor=={{setor_now}})%>%
    dplyr::count(setor,latitude,longitude)%>%
    collect()
  if (nrow(cnefe_setor_0)==0) return()
  cnefe_setor <- cnefe_setor_0%>%
    sf::st_as_sf(crs=sf::st_crs("EPSG:4674"), coords=c("longitude", "latitude"))
  ponto_setor <- ponto_densidade(cnefe_setor, setor)
  ponto_setor
}



setores <- open_dataset(file.path(out_dir,"arrow"))%>%
  ungroup%>%
  distinct(setor)%>%
  collect()%>%
  arrange(setor)%>%
  anti_join(pontos_setores%>%sf::st_drop_geometry(), by="setor")%>%
  head(100e3)%>%
  pull(setor)
print("done")
print(nrow(pontos_setores))
print("doing")
print(length(setores))

tmp <- furrr::future_map(setores, get_ponto_setor, .progress = TRUE)
#tmp <- purrr::map(setores, get_ponto_setor, .progress = TRUE)
pontos_setores_new <- bind_rows(tmp)%>%
  sf::st_as_sf(coords=c("lon", "lat"), remove=FALSE, crs=sf::st_crs("EPSG:4674"))%>%
  dplyr::rename("setor_cnefe_lon"=lon, 'setor_cnefe_lat'=lat)

if (nrow(pontos_setores)>0) {
  pontos_setores <- pontos_setores%>%
    anti_join(pontos_setores_new%>%sf::st_drop_geometry(), by="setor")%>%
    bind_rows(pontos_setores_new)
} else {
  pontos_setores <- pontos_setores_new
}

usethis::use_data(pontos_setores, overwrite = TRUE)
