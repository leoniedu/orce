#' Calcula o Ponto de Densidade de Unidades Espaciais
#'
#' Esta função calcula a unidade com maior densidade populacional para cada unidade espacial
#' (e.g., setor censitário, município) em um objeto `sf`, com base no número de
#' estabelecimentos (ou outro tipo de ponto) em cada unidade.
#'
#' @param cnefe Um objeto `sf` contendo a geometria das unidades espaciais e o número de
#'   estabelecimentos em cada unidade. Deve conter uma coluna chamada `n` com o número
#'   de estabelecimentos e uma coluna com o código da unidade espacial, cujo nome é
#'   especificado no argumento `geoid`.
#' @param geoid O nome da coluna em `cnefe` que contém o código único da unidade espacial
#'   (e.g., "cod_setor", "cod_municipio").
#'
#' @return Um `data.frame` com o código da unidade espacial (`geoid`) e as coordenadas
#'   do ponto de maior densidade (latitude e longitude) para cada unidade.
#'
#' @details
#' A função utiliza o pacote `spatstat` para calcular a densidade de pontos em cada
#' unidade espacial. O ponto de densidade é definido como o ponto com a maior
#' densidade de pontos dentro da unidade. A densidade é calculada usando um kernel
#' gaussiano com largura de banda `sigma` definida como o máximo entre 10% da
#' amplitude da unidade espacial e 30 metros.
#'
#' @export
ponto_densidade <- function(cnefe, geoid) {
  stopifnot(all(c("geometry", "n")%in%names(cnefe)))
  cnefe_0 <- cnefe|>dplyr::select({{geoid}}, n)
  #st_crs(cnefe) <- st_crs(m)
  get1 <- function(geoid_now) {
    cnefe_u <- cnefe_0|>
      dplyr::filter({{geoid}}==geoid_now)
    cnefe_flat <- cnefe_u|>
      ## coordenadas planares UTM Brasil = 5875
      sf::st_transform(crs = 5875)
    cnefe_xy <- cnefe_flat |>
      sf::st_coordinates()
    window <- dplyr::tibble(xrange=range(cnefe_xy[,1], na.rm=TRUE), yrange=range(cnefe_xy[,2], na.rm=TRUE))
    cnefe_ppp <- spatstat.geom::ppp(x = cnefe_xy[, 1], y = cnefe_xy[, 2], window = spatstat.geom::owin(xrange=window$xrange, yrange=window$yrange))
    sigma_calc <- pmax(diff(window$xrange/10),diff(window$yrange/10),30)
    dp <- spatstat.explore::density.ppp(cnefe_ppp, sigma = sigma_calc, weights = cnefe_u$n, at = "points")
    dpmax <- which(dp == max(dp, na.rm=TRUE))
    cnefe_u|>dplyr::slice(dpmax)|>dplyr::select({{geoid}})|>orce::add_coordinates()|>sf::st_drop_geometry()
  }
  geoids <- cnefe_0|>
    sf::st_drop_geometry()|>
    dplyr::ungroup()|>
    dplyr::count({{geoid}})
  res1 <- purrr::map(geoids|>
                       dplyr::filter(n>1)|>
                       dplyr::pull({{geoid}}), get1)
  res2 <- res1|>
    dplyr::bind_rows()
  res0 <- cnefe_0|>
    dplyr::group_by({{geoid}})|>
    dplyr::filter(n()<=1)|>
    dplyr::select({{geoid}})|>
    orce::add_coordinates()|>
    sf::st_drop_geometry()
  if (nrow(res2)>0) {
    if (nrow(res0)>0) {
      dplyr::bind_rows(res2,res0)
    } else {
      res2
    }
  } else {
    res0
  }
}
