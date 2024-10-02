library(dplyr)
snow <- "292890110000045"
cnefe <- arrow::open_dataset("~/Library/Caches/org.R-project.R/R/censobr/data_release_v0.3.0.1/2022_cnefe_29_v0.3.0.1.parquet")%>%
  filter(code_tract==snow)%>%
  collect()%>%
  sf::st_as_sf(coords=c("longitude", "latitude"), #crs=sf::st_crs(m),
               remove=FALSE)



test_that("multiplication works", {
  expect_equal(2 * 2, 4)
})

