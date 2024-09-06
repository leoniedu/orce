## code to prepare `geobrcache` dataset goes here
library(dplyr)
source("R/rename_ibge.R") ## needed rename_ibge
ufs <- geobr::read_state(year = 2020)%>%
  sf::st_centroid()%>%
  add_coordinates(latitude = "uf_lat", longitude = "uf_lon")%>%
  rename_ibge()
municipios2022 <- geobr::read_municipality(year=2022)%>%
  sf::st_centroid()%>%
  rename_ibge()
pop2022 <- censobr::read_tracts(year=2022, dataset = "Preliminares")%>%
  arrow::as_arrow_table()%>%
  rename_ibge()%>%
  group_by(municipio_codigo)%>%
  summarise(municipio_populacao=sum(v0001))%>%
  collect()
municipios_22 <- municipios2022%>%full_join(pop2022)%>%
  add_coordinates(longitude = "municipio_lon", latitude="municipio_lat")

load(here::here("data/pontos_municipios.rda"))
pontos_municipios_sede_0 <- geobr::read_municipal_seat(year = "2010")
pontos_municipios_sede_1 <- pontos_municipios_sede_0%>%
  transmute(municipio_codigo=as.character(code_muni))%>%
  dplyr::rename(geometry=geom)
## tem alguns faltando. usa base do cnefe
pontos_municipios_sede <- pontos_municipios_sede_1%>%
  bind_rows(
    pontos_municipios%>%
      select(municipio_codigo)%>%
      anti_join(pontos_municipios_sede_1%>%sf::st_drop_geometry(), by="municipio_codigo")
  )%>%
  add_coordinates(latitude = "municipio_sede_lat", longitude = "municipio_sede_lon")


usethis::use_data(pontos_municipios_sede, overwrite = TRUE)
usethis::use_data(ufs, overwrite = TRUE)
usethis::use_data(municipios_22, overwrite = TRUE)
