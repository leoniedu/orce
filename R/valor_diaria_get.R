#' Obtém o Valor da Diária por Código do Município
#'
#' Recupera o valor da diária com base no código do município brasileiro. A função
#' categoriza os municípios em três níveis com valores correspondentes.
#'
#' @param municipio_codigo Vetor numérico ou caractere contendo código(s) de
#'   município brasileiro (7 dígitos).
#' @param valores_diarias Vetor numérico de comprimento 3 especificando os valores
#'   das diárias para cada nível. Padrão é c(425, 380, 335).
#'
#' @return Vetor numérico com os valores das diárias para os municípios especificados.
#'
#' @details
#' A função categoriza os municípios em três níveis:
#' - Nível 1 (425): Capitais principais
#' - Nível 2 (380): Outras capitais
#' - Nível 3 (335): Demais municípios
#'
#' @examples
#' # Único município (Brasília)
#' valor_diaria_get("5300108")  # Retorna 425
#'
#' # Múltiplos municípios
#' valor_diaria_get(c("5300108", "1302603", "1200013"))  # Retorna c(425, 380, 335)
#'
#' # Usando valores personalizados
#' valor_diaria_get("5300108", c(500, 450, 400))  # Retorna 500
#'
#' # Vetor de municípios com valores personalizados
#' valor_diaria_get(
#'   c("5300108", "1302603", "1200013"),
#'   c(500, 450, 400)
#' )  # Retorna c(500, 450, 400)
#'
#' @export
valor_diaria_get <- function(municipio_codigo, valores_diarias = c(425, 380, 335)) {
  # Validação dos parâmetros
  if (!is.numeric(municipio_codigo) && !is.character(municipio_codigo)) {
    stop("municipio_codigo deve ser numérico ou caractere")
  }

  if (length(valores_diarias) != 3) {
    stop("valores_diarias deve ser um vetor de comprimento 3")
  }

  if (!is.numeric(valores_diarias)) {
    stop("valores_diarias deve ser numérico")
  }

  if (any(valores_diarias < 0)) {
    stop("valores_diarias deve ser não-negativo")
  }

  # Converte e padroniza os códigos dos municípios
  municipio_codigo <- substr(as.character(municipio_codigo), 1, 7)

  # Valida o formato dos códigos
  invalid_codes <- nchar(municipio_codigo) != 7 | !grepl("^[0-9]+$", municipio_codigo)
  if (any(invalid_codes)) {
    stop("Todos os códigos de município devem ter 7 dígitos numéricos")
  }

  # Lógica principal
  dplyr::case_match(
    municipio_codigo,
    # Nível 1: capitais e regiões metropolitanas
    c("5300108", "1400100", "3304557", "3550308") ~ valores_diarias[1],

    # Nível 2: centros regionais e cidades de médio porte
    c("1100205", "1302603", "1200401", "5002704", "1600303",
      "5103403", "1721000", "2211001", "1501402", "5208707",
      "2927408", "4205407", "2111300", "2704302", "4314902",
      "4106902", "3106200", "2304400", "2611606", "2507507",
      "2800308", "2408102", "3205309") ~ valores_diarias[2],

    # Nível 3: demais municípios
    .default = valores_diarias[3]
  )
}
