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
  dir.create(file.path(package$cache_dir, "orce"), showWarnings = FALSE, recursive = TRUE)
  dir.create(file.path(package$cache_dir, "get_map"), showWarnings = FALSE, recursive = TRUE)
  orce_mem <<- memoise::memoise(.orce_impl, cache = cachem::cache_disk(dir = file.path(package$cache_dir, "orce")))
  get_map_mem <<- memoise::memoise(ggmap::get_map, cache = cachem::cache_disk(dir = file.path(package$cache_dir, "get_map")))
}

