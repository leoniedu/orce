#' @export
ponto_grid_densidade <- function(cnefe,geoid) {
  stopifnot(all(c("longitude", "latitude")%in%names(cnefe)))
  # 1. Preprocess CNEFE data
  if (!"n"%in%names(cnefe)) {
    stop("set n")
  } else {

  }
  t1 <- cnefe
  # |>
  #   dplyr::ungroup()|>
  #   dplyr::count({{geoid}}, latitude, longitude, nv_geo_coord, wt = n)
  # 2. Define the helper function
  get1 <- function(geoid_now) {
    x <- t1|>
      dplyr::filter({{geoid}}==geoid_now)|>
      dplyr::ungroup()|>
      dplyr::collect()|>
      sf::st_as_sf(coords=c("longitude", "latitude"), remove=FALSE)
    coords <- sf::st_coordinates(x)|>unique()
    if (nrow(coords) < 10) {
      pts <- x |>
        sf::st_drop_geometry() |>
        dplyr::mutate(n_addr_grid=sum(n), grid_id=1)
    } else {
      k <- round(sqrt(x%>%distinct({{geoid}})%>%nrow()))
      print(k)
      if (k<3) k <- 3
      print(k)
      pts <- x |>
        sf::st_make_grid(n = c(k,k)) |>
        sf::st_as_sf() |>
        dplyr::mutate(grid_id = row_number()) |>
        sf::st_join(x) |>
        sf::st_drop_geometry() |>
        group_by(grid_id)|>
        dplyr::mutate(n_addr_grid=sum(n))
    }
    pts |>
      dplyr::group_by(latitude, longitude, nv_geo_coord) |>
      dplyr::mutate(n_lat_lon=sum(n))|>
      dplyr::ungroup()|>
      dplyr::arrange(dplyr::desc(n_addr_grid), nv_geo_coord, dplyr::desc(n_lat_lon)) |>
      dplyr::slice_head(n = 1)|>
      sf::st_drop_geometry() |>
      select({{geoid}}, latitude, longitude, n_addr_grid, n_lat_lon, nv_geo_coord)
  }
  geoids <- unique(t1%>%ungroup%>%distinct({{geoid}})%>%collect()%>%pull({{geoid}}))
  #browser()
  # 3. Apply the function and post-process
  res <- purrr::map(geoids, get1, .progress = TRUE)|> dplyr::bind_rows()
  res
}
