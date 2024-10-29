# package global variables
package <- new.env(parent = emptyenv())

.onLoad <- function(libname, pkgname){
  try({
    ROI::ROI_plugin_register_solver_control("cbc",
                                          "ratio", "rel_tol")
  }, silent = TRUE)
  try({
    ROI::ROI_plugin_register_solver_control("highs",
                                            "mip_rel_gap", "rel_tol")
  }, silent = TRUE)
  # data release
  package$name <- "orce"
  # local cache dir
  package$cache_dir <- tools::R_user_dir(package$name, which = 'cache')
  dir.create(file.path(package$cache_dir, "alocar_ucs"), showWarnings = FALSE, recursive = TRUE)
  dir.create(file.path(package$cache_dir, "get_map"), showWarnings = FALSE, recursive = TRUE)
  alocar_ucs_mem <<- memoise::memoise(.alocar_ucs_impl, cache = cachem::cache_disk(dir = file.path(package$cache_dir, "alocar_ucs")))
  get_map_mem <<- memoise::memoise(ggmap::get_map, cache = cachem::cache_disk(dir = file.path(package$cache_dir, "get_map")))
}

