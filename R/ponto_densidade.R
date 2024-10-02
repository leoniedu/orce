#' @export
ponto_grid_densidade <- function(cnefe, geoid) {
  stopifnot(all(c("geometry")%in%names(cnefe)))
  #st_crs(cnefe) <- st_crs(m)
  cnefe_u <- cnefe|>
    dplyr::ungroup()|>
    dplyr::filter(code_especie==1)|> ## 1=Domicílio particular
    dplyr::select({{geoid}})|>
    orce::add_coordinates()|>
    dplyr::count({{geoid}}, lat, lon)
  cnefe_flat <- cnefe_u|>
    ## coordenadas planares UTM Brasil = 5875
    sf::st_transform(crs = 5875)
  get1 <- function(geoid_now) {
    cnefe_xy <- cnefe_flat |>
      dplyr::filter({{geoid}}==geoid_now)|>
      sf::st_coordinates()
    window <- dplyr::tibble(xrange=range(cnefe_xy[,1], na.rm=TRUE), yrange=range(cnefe_xy[,2], na.rm=TRUE))
    cnefe_ppp <- spatstat.geom::ppp(x = cnefe_xy[, 1], y = cnefe_xy[, 2], window = spatstat.geom::owin(xrange=window$xrange, yrange=window$yrange))
    sigma_calc <- pmax(diff(window$xrange/10),diff(window$yrange/10),30)
    dp <- spatstat.explore::density.ppp(cnefe_ppp, sigma = sigma_calc, weights = cnefe_u$n, at = "points")
    dpmax <- which(dp == max(dp, na.rm=TRUE))
    cnefe_u|>dplyr::slice(dpmax)|>dplyr::select({{geoid}})
  }
  geoids <- unique(cnefe_u|>dplyr::pull({{geoid}}))
  res <- purrr::map(geoids, get1, .progress = TRUE)|> dplyr::bind_rows()
  res
}
