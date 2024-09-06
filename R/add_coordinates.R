#' Add Coordinates to an sf Object
#'
#' This function extracts coordinates from an `sf` object's geometry and adds them as new columns to the object.
#'
#' @param sf_object An `sf` object containing spatial features.
#' @param lon A string specifying the name of the longitude column. Defaults to "lon".
#' @param lat A string specifying the name of the latitude column. Defaults to "lat".
#'
#' @return An `sf` object with the added coordinate columns.
#'
#' @examples
#' # Load necessary packages
#' library(sf)
#' library(dplyr)
#'
#' # Create a simple sf object
#' points <- data.frame(
#'   name = c("A", "B"),
#'   geometry = c("POINT(1 2)", "POINT(3 4)")
#' ) %>%
#'   st_as_sf(wkt = "geometry")
#'
#' # Add coordinates using default column names
#' points_with_coords <- add_coordinates(points)
#'
#' # Add coordinates using custom column names
#' points_with_coords_custom <- add_coordinates(points, lon = "longitude", lat = "latitude")
#'
#' @export
add_coordinates <- function(sf_object, lon = "lon", lat="lat") {
  col_names <- c(lon, lat)
  # Extract coordinates
  coordinates_df <- sf::st_coordinates(sf_object)

  # Set column names
  colnames(coordinates_df) <- col_names

  # Convert to tibble
  coordinates_tibble <- as_tibble(coordinates_df)

  # Join with original tibble
  enriched_tibble <- cbind(sf_object, coordinates_tibble)

  return(enriched_tibble)
}
