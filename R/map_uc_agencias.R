#' Mapeia Unidades de Coleta (UCs) e Agências
#'
#' Esta função cria um mapa exibindo a localização das unidades de coleta (UCs) e agências.
#' Ela utiliza o pacote `ggmap` para obter um mapa de uma fonte especificada (por exemplo, Google Maps)
#' e sobrepõe as UCs e agências nele.
#'
#' @param data Um `data.frame` contendo as coordenadas das UCs e agências. Deve possuir colunas
#'   chamadas `uc_lat`, `uc_lon`, `agencia_lat` e `agencia_lon`.
#' @param f Um valor numérico especificando a fração pela qual expandir a caixa delimitadora em
#'   torno das UCs e agências. Padrão: 0.05.
#' @param source Uma string de caracteres especificando a fonte do mapa (e.g., "google", "osm", "stamen").
#'   Veja a documentação do `ggmap` para mais detalhes. Padrão: "google".
#' @param maptype Uma string de caracteres especificando o tipo de mapa (e.g., "terrain", "toner", "watercolor").
#'   Veja a documentação do `ggmap` para mais detalhes. Padrão: "roadmap".
#' @param zoom Um número inteiro ou a string "auto" especificando o nível de zoom. Se "auto", o
#'   nível de zoom é calculado automaticamente para ajustar todas as UCs e agências no mapa.
#'
#' @return Um objeto `ggmap` representando o mapa com as UCs e agências sobrepostas.
#'
#' @export
map_uc_agencias <- function(data, f = 0.05, source = "google", maptype = "roadmap", zoom = "auto") {
  lats <- c(data$uc_lat, data$agencia_lat)
  lons <- c(data$uc_lon, data$agencia_lon)
  bb <- ggmap::make_bbox(lat = lats, lon = lons, f = {{f}})
  if (zoom == "auto") {
    zoom <- min(
      ggmap::calc_zoom(lon = range(lons), lat = range(lons)),
      ggmap::calc_zoom(lon = range(lats), lat = range(lats))
    ) - 1
  }
  p <- get_map_mem(location = bb, source = {source}, maptype = {maptype}, zoom = {zoom})
  ggmap::ggmap(p)
}
