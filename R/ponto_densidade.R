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
    sf::st_drop_geometry()%>%
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
