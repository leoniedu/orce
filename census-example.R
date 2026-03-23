## ----setup, include=FALSE--------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment  = "#>",
  eval     = TRUE
)


## ----libraries-------------------------------------------------------------------
library(censobr)      # 2022 Census tract list
library(cnefetools)   # CNEFE household addresses (IBGE)
library(surveyzones)
library(dplyr)
library(sf)
library(ggplot2)
library(mapgl)

set.seed(2022)


## ----tracts----------------------------------------------------------------------
tracts_rj <- read_tracts(year = 2022, dataset = "Preliminares") |>
  collect() |>
  filter(code_muni == 3304557) |>
  select(code_tract, code_muni, name_muni, V0001) |>  # V0001 = population
  filter(V0001 > 0)

# Tract code structure (15 chars): muni(7) + district(2) + subdistrict(2) + sector(4)
# Rio de Janeiro city has a single district, so use subdistrict (chars 1–11) as strata
tracts_rj <- tracts_rj |>
  mutate(subdistrict = substr(code_tract, 1, 11))

glimpse(tracts_rj)


## ----sample----------------------------------------------------------------------
n_per_stratum <- 20L
set.seed(20091975)
sampled_tracts <- tracts_rj |>
  group_by(subdistrict) |>
  slice_sample(n = n_per_stratum) |>
  ungroup()

cat(
  "Sampled", nrow(sampled_tracts), "tracts across",
  n_distinct(sampled_tracts$subdistrict), "subdistricts\n"
)


## ----tract-chars-----------------------------------------------------------------
tract_chars <- read_tracts(year = 2022, dataset = "ResponsavelRenda") |>
  collect() |>
  filter(code_muni == 3304557) |>
  select(code_tract, code_favela, avg_income = V06004)

income_median <- median(tract_chars$avg_income, na.rm = TRUE)

sampled_tracts <- sampled_tracts |>
  left_join(tract_chars, by = "code_tract") |>
  mutate(
    partition_id = case_when(
      !is.na(code_favela)          ~ "comunidade",
      avg_income < income_median   ~ "regular_low",
      TRUE                         ~ "regular_high"
    )
  )

cat("Partition distribution:\n")
print(table(sampled_tracts$partition_id, useNA = "always"))


## ----cnefe-----------------------------------------------------------------------
# Downloads ~3 million addresses for Rio de Janeiro city (cached after first run)
cnefe_rj <- read_cnefe(code_muni = 3304557) |> collect()

# COD_SETOR in cnefetools has a trailing species letter (e.g. "330455705060002P")
# censobr code_tract is the 15-digit numeric prefix — strip before joining
cnefe_sample <- cnefe_rj |>
  mutate(code_tract = substr(COD_SETOR, 1, 15)) |>
  filter(code_tract %in% sampled_tracts$code_tract)

cat(
  nrow(cnefe_sample), "addresses across",
  n_distinct(cnefe_sample$code_tract), "tracts\n"
)


## ----repr-points-----------------------------------------------------------------
access_pts <- surveyzones_representative_points(
  cnefe_sample,
  tract_col = "code_tract"
)

# Add subdistrict, population, and partition from the sample frame
access_pts <- access_pts |>
  left_join(
    sampled_tracts |> select(tract_id = code_tract, subdistrict, V0001, partition_id),
    by = "tract_id"
  )

print(access_pts)


## ----distances-------------------------------------------------------------------
distances <- surveyzones_compute_sparse_distances(
  access_points = access_pts,
  engine        = surveyzones_engine_haversine(units = "km")
)


## ----zones-----------------------------------------------------------------------
plan <- surveyzones_build_zones(
  sparse_distances      = distances,
  tracts                = st_drop_geometry(access_pts) |>
                            mutate(expected_service_time = 1L),
  D_max                 = 3,    # max 3 km from tract to zone center
  max_workload_per_zone = 5L,   # max 5 tracts per zone
  enforce_partition     = TRUE, # comunidade / regular_low / regular_high solved separately
  solver                = "highs", # HiGHS handles large MILPs much faster than GLPK
  strategy              = "auto"   # solves uncapacitated first (fast), then splits oversized zones
)

print(plan)


## ----stats, fig.width=8, fig.height=4, out.width="100%"--------------------------
surveyzones_plot_statistics(plan, type = "all")


## ----map-data--------------------------------------------------------------------
color_by <- function(x, palette = "Set2", seed = 42) {
  lvls <- unique(x)
  pal  <- grDevices::hcl.colors(length(lvls), palette = palette)
  withr::with_seed(seed, pal <- sample(pal))
  pal[match(x, lvls)]
}

map_pts <- access_pts |>
  left_join(plan$assignments, by = "tract_id") |>
  mutate(
    color      = color_by(zone_id),
    zone_label = paste("Zone:", zone_id)
  ) |>
  st_transform(5880L)

map_hulls <- map_pts |>
  group_by(zone_id, color, zone_label) |>
  summarise(
    geometry = st_buffer(st_convex_hull(st_union(geometry)), dist = 300),
    .groups  = "drop"
  )

m <- maplibre(bounds = map_pts, style = carto_style("positron")) |>
  add_fill_layer(
    id                 = "hulls",
    source             = map_hulls,
    fill_color         = list("get", "color"),
    fill_outline_color = "black",
    fill_opacity       = 0.3,
    tooltip            = "zone_label"
  ) |>
  add_circle_layer(
    id             = "tracts",
    source         = map_pts,
    circle_color   = list("get", "color"),
    circle_radius  = 5,
    circle_opacity = 0.9,
    tooltip        = "tract_id"
  )


## ----map-screenshot, echo=FALSE, eval=knitr::pandoc_to() != "html"---------------
png_path <- "map_census.png"
tmp <- tempfile(fileext = ".html")
htmlwidgets::saveWidget(m, tmp, selfcontained = TRUE)
invisible(webshot2::webshot(
  tmp, file = png_path,
  delay = 3, zoom = 2, vwidth = 1200, vheight = 800
))


## ----map-html, eval=knitr::pandoc_to() == "html"---------------------------------
m


## ----map-static, echo=FALSE, eval=knitr::pandoc_to() != "html"-------------------
knitr::include_graphics("map_census.png")


## ----sequence, eval=FALSE--------------------------------------------------------
# # Optimal visit order within each zone (nearest-neighbour TSP)
# plan <- surveyzones_sequence(plan, distances, method = "nn")
# 
# # Visit order between zones within each district
# plan <- surveyzones_sequence_zones(plan, distances)
# 
# # Export to Parquet for handoff to field coordinators
# surveyzones_export_plan(plan, path = "output/rj_zones")

