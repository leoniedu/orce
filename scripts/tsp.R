library(arrow)
library(dplyr)

dpath <- "~/github/dodgr/data-raw/ba_dists"
dists <- open_dataset(dpath)

set.seed(1)
s <- dists%>%distinct(from_id)%>%collect()

ss <- slice_sample(s, n=1000)

sdists <- dists%>%
  semi_join(ss, by=c("from_id"))%>%
  semi_join(ss%>%transmute(to_id=from_id), by=c("to_id"))%>%
  collect()


sdists_m <- sdists %>%
  arrange(from_id, to_id) %>%
  tidyr::pivot_wider(names_from = "to_id", values_from = "distance") %>%
  tibble::column_to_rownames(var = "from_id")%>%
  as.matrix()

library(TSP)
atsp <- ATSP(sdists_m)
ms <- c("nearest_insertion", "farthest_insertion", "cheapest_insertion", "arbitrary_insertion", "nn", "repetitive_nn", "two_opt")
tour <- purrr::map(ms, ~solve_TSP(atsp, method = .x), .progress = TRUE)
tour_l <- sapply(tour, tour_length)
ms[(tour_l/min(tour_l))<1.005]




