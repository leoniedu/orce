#' Limpa o cache de alocações
#'
#' Remove todos os resultados em cache da função alocar_ucs.
#' Útil quando você quer liberar espaço em disco ou garantir
#' que novos cálculos sejam realizados do zero.
#'
#' @return NULL invisível. A função é chamada pelos seus efeitos colaterais
#'   (remoção dos arquivos de cache). Uma mensagem é impressa informando
#'   o espaço em disco liberado.
#' @export
#'
#' @examples
#' \dontrun{
#' # Limpa todo o cache de alocações anteriores
#' limpar_cache_alocar_ucs()
#' }
limpar_cache_alocar_ucs <- function(force = FALSE) {
  cache_dir <- file.path(package$cache_dir, "alocar_ucs")
  if (dir.exists(cache_dir)) {
    # Calcula o tamanho total dos arquivos antes de remover
    arquivos <- list.files(cache_dir, recursive = TRUE, full.names = TRUE)
    tamanho_bytes <- sum(file.size(arquivos))
    tamanho_fmt <- format(structure(tamanho_bytes, class = "object_size"),
                          units = "auto")
    message(sprintf("Espaço em disco a ser liberado: %s", tamanho_fmt))

    # Adiciona confirmação se force=FALSE
    if (!force) {
      resposta <- readline(sprintf("Deseja realmente limpar o cache (%s)? [s/N] ", tamanho_fmt))
      if (!tolower(resposta) %in% c("s", "sim", "y", "yes")) {
        message("Operação cancelada pelo usuário.")
        return(invisible(FALSE))
      }
    }

    # Apaga o cache
    memoise::forget(alocar_ucs)
    message(sprintf("Cache limpo. Espaço em disco liberado."))
    return(invisible(TRUE))
  } else {
    message("Diretório de cache não encontrado. Nenhum espaço liberado.")
    return(invisible(FALSE))
  }
}
