
#. cnefe2022 output: pontos_setores, pontos_municipios

# geobrcache.R input: pontos_municipios output: pontos_setores, ufs, municipios_22

#. download manually from bdo "data-raw/bdo_agencias/agencia.csv" "data-raw/bdo_agencias/grid-export.csv"

#. agencias.R input: from download bdo;  output: agencias_bdo,  municipios_codigos (rms, etc), agencias_mun (rms, etc)

#. distancias_agencias_osrm.R input: agencias_bdo, agencias_mun, municipios_22 output: distancias_agencias_osrm

#. distancias_agencias_municipios_osrm input: agencias_bdo, agencias_mun, municipios_22, pontos_municipios  output: distancias_agencias_municipios_osrm, agencias_municipios_diaria








#. distancias_agencias_municipios_osrm input:


