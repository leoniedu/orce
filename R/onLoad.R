# package global variables
package <- new.env(parent = emptyenv())

.onLoad <- function(libname, pkgname){
  # data release
  package$name <- "orce"
  # local cache dir
  package$cache_dir <- tools::R_user_dir(package$name, which = 'cache')
  dir.create(file.path(package$cache_dir, "alocar_ucs"), showWarnings = FALSE, recursive = TRUE)
  dir.create(file.path(package$cache_dir, "alocar_municipios"), showWarnings = FALSE, recursive = TRUE)
  dir.create(file.path(package$cache_dir, "get_map"), showWarnings = FALSE, recursive = TRUE)
  alocar_ucs <<- memoise::memoise(alocar_ucs, cache = cachem::cache_disk(dir = file.path(package$cache_dir, "alocar_ucs")))
  alocar_municipios <<- memoise::memoise(alocar_municipios, cache = cachem::cache_disk(dir = file.path(package$cache_dir, "alocar_municipios")))
  get_map_mem <<- memoise::memoise(ggmap::get_map, cache = cachem::cache_disk(dir = file.path(package$cache_dir, "get_map")))
}

