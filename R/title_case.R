#' Convert to Title Case with Locale-Specific Exceptions
#'
#' This function converts a string to title case, respecting locale-specific exceptions
#' for words that should remain lowercase. It combines the functionality of
#' `stringi::stri_trans_totitle` with customizable exception lists for different locales.
#'
#' @param string The input string to be converted.
#' @param locale A string specifying the locale (e.g., "en", "pt_BR", "es", "fr"). Defaults to "en".
#' @param exception_lists A named list where names are locales and values are vectors
#' of exception words to be kept in lowercase. Defaults to a list containing exceptions
#' for English ("en"), Portuguese ("pt_BR"), Spanish ("es"), and French ("fr").
#'
#' @return The input string converted to title case with locale-specific exceptions applied.
#'
#' @import stringi
#'
#' @export
to_title_case <- function(string, locale = "en",
                          exceptions = NULL, ...) {
  locale_short <- stringr::str_split_fixed(locale,"_",2)[,1]
  if (is.null(exceptions)) {
    exceptions <- list(
      en = c("of", "the", "and", "a", "an"),
      pt = c("[n]?o[s]?", "a", "a[s]?", "abaixo", "acaso", "acima", "acolá",
             "agora", "ainda", "ali", "amanhã", "ante", "apesar", "após",
             "aqui", "assim", "até", "bem", "breve", "cá", "calmamente",
             "caso", "cedo", "com", "como", "conquanto", "conseguinte", "consoante",
             "contanto", "contra", "contudo", "d[a|o][s]?", "de[s]?", "dentro",
             "depressa", "desde", "devagar", "durante", "e", "em", "embora",
             "entre", "entretanto", "exceto", "fora", "isso", "já", "lá",
             "logo", "longe", "mal", "mas", "mediante", "melhor", "na[s]?",
             "não", "nem", "onde", "ontem", "ora", "ou", "para", "per", "perante",
             "perto", "pior", "pois", "por", "porém", "porquanto", "porque",
             "portanto", "porventura", "posto", "quando", "qu[eê]", "quer", "quiçá",
             "salvo", "se", "segundo", "seja", "sem", "senão", "sob", "sobre",
             "talvez", "tarde", "tirante", "todavia", "trás", "um[a]",
             "umas", "uns", "visto"),
      es = c("de", "la", "el", "los", "las", "y", "a", "en", "o", "u"),  # Spanish exceptions
      fr = c("de", "la", "le", "les", "et", "à", "au", "aux", "du", "des", "un", "une")  # French exceptions
    )
    # Check if the provided locale is supported
    checkmate::assert_choice(locale_short, names(exceptions))
    exceptions <- exceptions[[locale_short]]
  } else {
    checkmate::assert_string(exceptions)
  }
  #stringtitle <- stringr::str_to_title(string, locale={locale})
  stringtitle <- snakecase::to_title_case(string, ...)
  #exceptions <- c("de", "da", "do", "e", "o", "a", "os", "as")
  #stringtitle <- "Eduardo DE Leoni"

  result <- gsub(
    pattern = paste0("(?i)(?<!^|[.?!]\\s|[[:alpha:]])\\b(", paste0(exceptions, collapse = "|"), ")\\b(?![[:alpha:]])"),
    replacement = "\\L\\1",
    x = stringtitle,
    perl = TRUE
  )
  result
}

