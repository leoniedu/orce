#' @keywords internal
#' Converte uma tabela longa de distâncias (orig, dest, distancia_km)
#' em uma matriz N x N na ordem: bases (agências) primeiro e depois UCs.
#' Se já for matriz, apenas valida e retorna.
.ensure_nos_matrix <- function(agencias_t, ucs_i, distancias_nos) {
  m <- nrow(agencias_t)
  n_uc <- nrow(ucs_i)
  N <- m + n_uc

  if (is.null(distancias_nos)) {
    stop("peso_tsp > 0 exige 'distancias_nos' (matriz N x N ou formato longo com colunas 'orig','dest','distancia_km')")
  }

  # Caso matriz: apenas validar dimensões e zerar diagonal
  if (is.matrix(distancias_nos)) {
    if (!(nrow(distancias_nos) == N && ncol(distancias_nos) == N)) {
      stop(sprintf("distancias_nos (matriz) deve ser %dx%d (m + n_uc)", N, N))
    }
    diag(distancias_nos) <- 0
    return(distancias_nos)
  }

  # Caso longo: construir matriz seguindo a ordem dos nós (agências, depois UCs)
  df <- distancias_nos
  required_cols <- c("orig", "dest", "distancia_km")
  if (!all(required_cols %in% names(df))) {
    stop("distancias_nos (longo) deve conter colunas: 'orig', 'dest', 'distancia_km'")
  }

  nodes <- c(agencias_t$agencia_codigo, ucs_i$uc)
  if (anyDuplicated(nodes)) {
    stop("Nós (agências + UCs) possuem duplicatas ao montar matriz N x N")
  }
  map <- tibble::tibble(node = nodes, idx = seq_along(nodes))
  df2 <- df |>
    dplyr::ungroup() |>
    dplyr::inner_join(map, by = c("orig" = "node")) |>
    dplyr::rename(i = idx) |>
    dplyr::inner_join(map, by = c("dest" = "node")) |>
    dplyr::rename(k = idx) |>
    dplyr::select(i, k, distancia_km)

  mat <- matrix(NA_real_, nrow = N, ncol = N)
  ok <- stats::complete.cases(df2$i, df2$k)
  if (!all(ok)) {
    stop("distancias_nos (longo) contém orig/dest que não existem em (agências ∪ UCs)")
  }
  mat[cbind(df2$i, df2$k)] <- df2$distancia_km
  diag(mat) <- 0
  if (any(is.na(mat))) {
    stop("distancias_nos (longo) não cobre todos os pares necessários (base↔base, base↔UC, UC↔UC)")
  }
  if (nrow(mat)!=length(nodes)) {
    stop("distancias_nos sem as dimensões corretas")
  }
  mat
}
