% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/rename_ibge.R
\name{rename_ibge}
\alias{rename_ibge}
\title{Padroniza Nomes de Colunas para o Formato IBGE}
\usage{
rename_ibge(x)
}
\arguments{
\item{x}{Um \code{data.frame} com colunas a serem renomeadas.}
}
\value{
O \code{data.frame} com os nomes das colunas padronizados.
}
\description{
Esta função padroniza os nomes das colunas de um \code{data.frame} para o formato utilizado pelo IBGE,
utilizando um dicionário de nomes comuns e seus equivalentes padronizados.
}
\details{
A função realiza as seguintes etapas:
\enumerate{
\item Padroniza os nomes das colunas para minúsculas e remove caracteres especiais
usando \code{janitor::clean_names()}.
\item Renomeia as colunas usando um dicionário pré-definido de nomes comuns e seus
equivalentes padronizados.
\item Substitui "longitude" por "lon" e "latitude" por "lat" nos nomes das colunas.
\item Converte as colunas que contêm códigos (e.g., \code{cod_setor}, \code{cod_uf}) para o tipo \code{character}.
}
}
\examples{
df <- data.frame(
  COD_SETOR = c("1234567", "8901234"),
  NOME_muni = c("São Paulo", "Rio de Janeiro"),
  abbrev_state = c("SP", "RJ")
)

df_padronizado <- rename_ibge(df)
print(df_padronizado)
#   setor        municipio_nome uf_sigla
# 1 1234567        São Paulo       SP
# 2 8901234 Rio de Janeiro       RJ

}
