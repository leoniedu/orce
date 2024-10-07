library(dplyr)
library(sf)
source(here::here("R/rename_ibge.R"))
source(here::here("R/calcula_distancias.R"))
#source(here::here("R/add_coordinates.R"))
load(here::here("data/agencias_bdo.rda"))
load(here::here("data/pontos_setores.rda"))
load(here::here("data/municipios_22.rda"))
amostra_mestra <- readRDS("~/gitlab/pof2024ba/data-raw/amostra_mestra.rds")
amostra_pof <- readxl::read_excel("~/gitlab/pof2024ba/data-raw/Alocação_trimestre_POF2425_1907.xls")%>%
  rename_ibge()
amostra_uf <- amostra_mestra%>%
  filter(uf_codigo==29)%>%
  mutate(ano_mes=lubridate::make_date(ano,mes_codigo))%>%
  filter((ano_mes>="2024-07-01" & ano_mes<="2025-06-1")|(upa%in%amostra_pof$upa))%>%
  distinct(setor=controle, upa, agencia_codigo)

agencias_uf <- agencias_bdo%>%
  semi_join(amostra_uf, by="agencia_codigo")

distancias_amostra_toget_1 <- pontos_setores%>%
  inner_join(amostra_uf, by=c("setor"))
distancias_amostra_toget_2 <- municipios_22%>%
  inner_join(amostra_uf%>%
               anti_join(distancias_amostra_toget_1,by=c("setor"))%>%
               mutate(municipio_codigo=substr(upa,1,7)))

distancias_amostra_toget <- rbind(
  distancias_amostra_toget_1%>%
    transmute(setor,ponto_origem="pontos_setores", setor_lat=setor_cnefe_lat, setor_lon=setor_cnefe_lon),
  ##FIX! Distancias até municipios quando nao sabemos onde é o setor
  distancias_amostra_toget_2%>%
    transmute(setor,ponto_origem="municipios_22", setor_lat=municipio_sede_lat,setor_lon=municipio_sede_lon)
)

distancias_amostra_1 <- calcula_distancias(distancias_amostra_toget, agencias_uf, nmax = 5000)

distancias_agencias_setores_osrm <- bind_rows(distancias_amostra_1)%>%
  select(setor,agencia_codigo,distancia_km, duracao_horas, agencia_lat, agencia_lon)%>%
  left_join(distancias_amostra_toget%>%sf::st_drop_geometry())

distancias_agencias_setores_osrm%>%anti_join(amostra_uf, by="setor")
amostra_uf%>%anti_join(distancias_agencias_setores_osrm, by="setor")
readr::write_rds(distancias_agencias_setores_osrm, "data-raw/distancias_agencias_setores_osrm.rds")
