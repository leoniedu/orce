% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/calcula_diarias.R
\name{calcula_diarias}
\alias{calcula_diarias}
\title{Calcula o Número de Diárias}
\usage{
calcula_diarias(dias, meia_diaria)
}
\arguments{
\item{dias}{Número de dias do deslocamento.}

\item{meia_diaria}{Valor lógico indicando se a diária é de apenas meio dia (\code{TRUE}) ou dia inteiro (\code{FALSE}).}
}
\value{
O número de diárias a serem pagas.
}
\description{
Esta função calcula o número de diárias a serem pagas para um deslocamento, considerando o número de dias e se a diária inclui pernoite.
}
\examples{
calcula_diarias(dias = 2, meia_diaria = FALSE) # Retorna 1.5
calcula_diarias(dias = 2, meia_diaria = TRUE) # Retorna 1
calcula_diarias(dias = 5, meia_diaria = TRUE) # Retorna 2.5
calcula_diarias(dias = 5, meia_diaria = FALSE) # Retorna 4.5

}
