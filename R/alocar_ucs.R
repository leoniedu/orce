#' Alocação Otimizada de Unidades de Coleta (UCs) a Agências
#'
#' Esta função realiza a alocação otimizada de Unidades de Coleta (UCs) a agências, com o objetivo de minimizar os custos totais de deslocamento e operação. A alocação leva em consideração restrições de capacidade das agências, custos de deslocamento (combustível, tempo de viagem e diárias), custos fixos das agências e custos de treinamento.
#'
#' @param ucs Um `tibble` ou `data.frame` contendo informações sobre as UCs, incluindo:
#'   * `uc`: Código único da UC.
#'   * `agencia_codigo`: Código da agência à qual a UC está atualmente alocada.
#'   * `dias_coleta`: Número de dias de coleta na UC.
#'   * `viagens`: Número de viagens necessárias para a coleta na UC.
#' @param agencias Um `tibble` ou `data.frame` contendo informações sobre as agências selecionáveis, incluindo:
#'   * `agencia_codigo`: Código único da agência.
#' @param custo_litro_combustivel Custo do combustível por litro (em R$). Padrão: 6.
#' @param custo_hora_viagem Custo de cada hora de viagem (em R$). Padrão: 10.
#' @param kml Consumo médio de combustível do veículo (em km/l). Padrão: 10.
#' @param valor_diaria Valor da diária para deslocamentos (em R$). Padrão: 335.
#' @param custo_fixo Custo fixo mensal da agência, como salário do entrevistador, custo de monitoramento, etc. (em R$). Padrão: 500.
#' @param dias_treinamento Número de dias/diárias para treinamento. Padrão: 5.5
#' @param dist_diaria_km Distância mínima (em km) para que seja paga uma diária, no caso de UC na jurisdição da agência. No caso da UC fora da jurisdição da agência, quando a distância for menor do que `dist_diaria_km`, se paga meia diária, calculada como 1/2 do valor das diárias inteiras. Padrão 100
#' @param min_uc_agencia Número mínimo de UCs por agência. Só válido para agências não treinadas. Padrão: 1.
#' @param max_uc_agencia Número máximo de UCs por agência. Padrão: NULL (ilimitado).
#' @param semi_centralizada (Opcional) Um vetor de caracteres com os códigos das agências que não terão limite máximo de UCs alocadas. Padrão: NULL.
#' @param agencias_treinadas (Opcional) Um vetor de caracteres com os códigos das agências que já foram treinadas e não terão custo de treinamento. O custo dos APMs contratados nessas agências ainda será incluído no plano de otimização. Padrão: NULL.
#' @param agencias_treinamento Código da(s) agência(s) onde o treinamento será realizado.
#' @param adicional_troca_jurisdicao Custo adicional quando há troca de agência de coleta. Padrão 0
#' @param distancias_ucs Um `tibble` ou `data.frame` com as distâncias entre UCs e agências, incluindo:
#'   * `uc`: Código da UC.
#'   * `agencia_codigo`: Código da agência.
#'   * `distancia_km`: Distância em quilômetros entre a UC e a agência.
#'   * `duracao_horas`: Duração da viagem em horas entre a UC e a agência
#'   * `diaria_municipio`: Indica se é necessária uma diária para deslocamento entre a UC e a agência, considerando o município da UC
#' @param distancias_agencias Um `tibble` ou `data.frame` com as distâncias entre as agências, incluindo:
#'   * `agencia_codigo_orig`: Código da agência de origem
#'   * `agencia_codigo_dest`: Código da agência de destino
#'   * `distancia_km`: Distância em quilômetros entre a agência de origem e a de destino
#'   * `duracao_horas`: Duração da viagem em horas entre a agência de origem e a de destino
#' @param resultado_completo (Opcional) Um valor lógico indicando se deve ser retornado um resultado mais completo, incluindo informações sobre todas as combinações de UCs e agências. Padrão: FALSE.
#'
#' @return Uma lista contendo:
#' * `resultado_ucs_otimo`: Um `tibble` com as UCs e suas alocações otimizadas, incluindo custos de deslocamento.
#' * `resultado_ucs_jurisdicao`: Um `tibble` com as UCs e suas alocações originais (jurisdição), incluindo custos de deslocamento.
#' * `resultado_agencias_otimo`: Um `tibble` com as agências e suas alocações otimizadas, incluindo custos fixos, custos de deslocamento e número de UCs alocadas.
#' * `resultado_agencias_jurisdicao`: Um `tibble` com as agências e suas alocações originais (jurisdição), incluindo custos fixos, custos de deslocamento e número de UCs alocadas.
#' * `ucs_agencias_todas` (opcional): Um `tibble` com todas as combinações de UCs e agências, incluindo distâncias, custos e informações sobre diárias (retornado apenas se `resultado_completo` for TRUE).
#'
#' @import dplyr ompr magrittr ompr.roi ROI.plugin.glpk checkmate
#' @export
alocar_ucs <- function(ucs,
                       agencias=NULL,
                       custo_litro_combustivel = 6,
                       custo_hora_viagem = 10,
                       kml = 10,
                       valor_diaria = 335,
                       custo_fixo = 500,
                       dias_treinamento = 5.5,
                       dist_diaria_km = 100,
                       agencias_treinadas = NULL,
                       agencias_treinamento = NULL,
                       distancias_ucs,
                       distancias_agencias,
                       min_uc_agencia = 1,
                       max_uc_agencia = NULL,
                       semi_centralizada = NULL,
                       adicional_troca_jurisdicao = 0,
                       resultado_completo = FALSE
) {
  # Import required libraries explicitly
  requireNamespace("dplyr")
  require("ompr")
  require("ompr.roi")
  require("ROI.plugin.glpk")
  # Verificação dos Argumentos
  checkmate::assertTRUE(!anyDuplicated(agencias[['agencia_codigo']]))
  checkmate::assertTRUE(!anyDuplicated(ucs[['uc']]))
  checkmate::assert_number(custo_litro_combustivel, lower = 0)
  checkmate::assert_number(kml, lower = 0)
  checkmate::assert_number(valor_diaria, lower = 0)
  checkmate::assert_number(custo_fixo, lower = 0)
  checkmate::assert_number(dias_treinamento, lower = 0)
  checkmate::assert_number(dist_diaria_km, lower = 0)
  checkmate::assert_integerish(min_uc_agencia, lower = 1)
  checkmate::assert_number(max_uc_agencia, lower = 1, null.ok = TRUE)
  checkmate::assert_character(semi_centralizada, null.ok = TRUE)
  checkmate::assert_character(agencias_treinadas, null.ok = TRUE)
  checkmate::assert_character(agencias_treinamento)
  checkmate::assertTRUE(all(c('diaria_municipio', 'uc')%in%names(distancias_ucs)))
  checkmate::assertTRUE(all(c('dias_coleta', 'viagens')%in%names(ucs)))
  # Setting max_uc_agencia to infinity if not provided
  if (is.null(max_uc_agencia)) {
    max_uc_agencia <- Inf
  }



  # Creating jurisdiction allocation
  agencias_jurisdicao <- tibble::tibble(agencia_codigo=unique(ucs$agencia_codigo))

  if (is.null(agencias)) {
    agencias <- agencias_jurisdicao
  }
  agencias_sel <- tibble::tibble(agencia_codigo=unique(agencias$agencia_codigo))|>
    dplyr::mutate(j=1:n())

  # Seleciona agência de treinamento mais próxima das agências de coleta
  agencias_t <- agencias_jurisdicao |>
    sf::st_drop_geometry()|>
    dplyr::ungroup() |>
    dplyr::left_join(distancias_agencias |>
                       dplyr::select(agencia_codigo_orig, agencia_codigo_dest, distancia_km, duracao_horas)|>
                       dplyr::filter(agencia_codigo_dest %in% agencias_treinamento) |>
                       dplyr::rename(agencia_codigo_treinamento=agencia_codigo_dest),
                     by = c("agencia_codigo" = "agencia_codigo_orig")) |>
    dplyr::group_by(agencia_codigo) |>
    dplyr::arrange(distancia_km) |>
    dplyr::slice(1) |>
    dplyr::rename(
      distancia_km_agencia_treinamento = distancia_km,
      duracao_horas_agencia_treinamento_km = duracao_horas
    ) |>
    dplyr::ungroup()


  # No minimum UCs required for trained agencies
  #if (length(min_uc_agencia) == nrow(agencias_1)) {
  #  min_uc_agencia[agencias_1$agencia_codigo %in% agencias_treinadas] <- 1
  #}

  if (dias_treinamento==0) {
    custo_treinamento <- rep(0, nrow(agencias_t))
  } else {
    # Training costs based on distance and whether the agency is trained
    treinamento_com_diaria <- !substr(agencias_t$agencia_codigo, 1, 7) %in% substr(agencias_treinamento, 1, 7)
    custo_treinamento <- round(
      dplyr::if_else(treinamento_com_diaria, 2, dias_treinamento) *
        (agencias_t$distancia_km_agencia_treinamento / kml) *
        custo_litro_combustivel
    ) + {{valor_diaria}}*{{dias_treinamento}}*treinamento_com_diaria
    custo_treinamento[agencias_t$agencia_codigo %in% agencias_treinadas] <- 0
  }
  agencias_t$fixed_cost <- custo_fixo + custo_treinamento


  # Maximum UCs per agency
  agencias_sel <- agencias_sel|>
    dplyr::inner_join(agencias_t, by="agencia_codigo")|>
    dplyr::mutate(max_uc_agencia=rep(max_uc_agencia, dplyr::n()))
  if (length(semi_centralizada) > 0) {
    agencias_sel <- agencias_sel|>dplyr::mutate(z=if_else(agencia_codigo%in% semi_centralizada, Inf, z))
  }

  # Combining UC and agency information
  ucs_i <- ucs |>
    sf::st_drop_geometry()|>
    dplyr::ungroup()|>
    dplyr::arrange(uc)|>
    dplyr::transmute(i=1:n(), uc, municipio_codigo, agencia_codigo_jurisdicao=agencia_codigo, dias_coleta, viagens)
  ag_mun_grid <- tidyr::expand_grid(
    agencias_t|>
      transmute(municipio_codigo_agencia = substr(agencia_codigo, 1, 7), agencia_codigo),
    ucs_i
  )
  distancias_ucs_1 <- ag_mun_grid |>
    dplyr::left_join(distancias_ucs, by = c('uc', 'agencia_codigo'))|>
    dplyr::ungroup()|>
    sf::st_drop_geometry()|>
    dplyr::select(i,uc, agencia_codigo, agencia_codigo_jurisdicao,
                  viagens, dias_coleta, distancia_km, duracao_horas, diaria_municipio)

  # Ensure there are no missing values in distances
  stopifnot(sum(is.na(distancias_ucs_1$distancia_km)) == 0)
  stopifnot(nrow(distancias_ucs_1) == (nrow(ucs_i) * nrow(agencias_t)))

  # Compute transport costs
  dist_uc_agencias <- distancias_ucs_1 |>
    dplyr::left_join(agencias_sel, by="agencia_codigo")|>
    dplyr::transmute(
      i, uc,
      j, agencia_codigo,
      agencia_codigo_jurisdicao,
      distancia_km, duracao_horas,
      diaria=diaria_municipio,
      diaria=dplyr::if_else(distancia_km > dist_diaria_km, TRUE, diaria),
      meia_diaria=(distancia_km < dist_diaria_km) & diaria,
      ## se com diaria inteira
      trechos=dplyr::if_else(diaria&(!meia_diaria),
                             # é uma ida e uma volta por viagem
                             viagens*2,
                             # sem diária ou com meia diária
                             dias_coleta * 2),
      total_diarias=dplyr::if_else(diaria, calcula_diarias(dias_coleta, meia_diaria),0),
      custo_diarias=total_diarias * valor_diaria,
      distancia_total_km=trechos * distancia_km,
      custo_combustivel=((distancia_total_km / kml) * custo_litro_combustivel),
      custo_horas_viagem=(trechos * duracao_horas) * custo_hora_viagem,
      custo_troca_jurisdicao=if_else(agencia_codigo!=agencia_codigo_jurisdicao, adicional_troca_jurisdicao, 0),
      custo_deslocamento= custo_combustivel + custo_horas_viagem + custo_diarias
    )

  stopifnot(all(!is.na(dist_uc_agencias$distancia_km)))

  # Set default min_uc_agencia if it is a single value
  if (length(min_uc_agencia) == 1) {
    min_uc_agencia <- rep(min_uc_agencia, nrow(agencias_sel))
  }
  transport_cost <- function(i,j) {
    stopifnot(length(i) == length(j))
    tibble::tibble(i=i,j=j)|>dplyr::left_join(dist_uc_agencias, by=c("i", "j"))|>
      mutate(custo_deslocamento_com_troca=custo_deslocamento+custo_troca_jurisdicao)|>
      dplyr::pull(custo_deslocamento_com_troca)
  }
  # Create optimization model using ompr package
  n <- nrow(ucs_i)
  m <- nrow(agencias_sel)
  stopifnot((agencias_sel$j)==(1:nrow(agencias_sel)))
  model <- MIPModel() |>
    # 1 iff i gets assigned to agencia j
    add_variable(x[i, j], i = 1:n, j = 1:m, type = "binary") |>
    # 1 iff agencia j is included
    add_variable(y[j], j = 1:m, type = "binary") |>
    # maximize the preferences
    set_objective(sum_over(
      transport_cost(i, j)* x[i, j] , i = 1:n, j = 1:m)
      + sum_over(agencias_sel$fixed_cost[j] * y[j], j = 1:m)
      ##fix: termo com o número de entrevistadores por agência
      ## nao é fixo. depende do número de UCs na agência
      ## nao funciona (está somando o estado todo em vez de agencias)
      #  + (sum_over(x[i,j], i=1:n, j = 1:m)/
      , "min") |>
    # toda UC precisa estar associada a uma agencia
    add_constraint(sum_over(x[i, j], j = 1:m) == 1, i = 1:n) |>
    # se uma UC está designada a uma agencia, a agencia tem que ficar ativa
    add_constraint(x[i,j] <= y[j], i = 1:n, j = 1:m)
  if(any({{min_uc_agencia}}>1)) {
    model <- model|>
      # constraint com número mínimo de UCs por agência que for incluída
      # multiplica por y[j] por que só vale pra agencias incluídas, se não é >=0
      add_constraint(sum_over(x[i, j], i = 1:n) >= (min_uc_agencia[j]*y[j]), j = 1:m)
  }
  if(is.finite({{max_uc_agencia}})) {
    model <- model|>
      # constraint com número máximo de UCs por agência
      add_constraint(sum_over(x[i, j], i = 1:n) <= z[j], j = 1:m)
  }

  # Solve the model using GLPK solver
  result <- ompr::solve_model(model, ompr.roi::with_ROI(solver = "glpk", verbose = TRUE))
  stopifnot(result$status != "error")

  # Extract the solution
  matching <- result |>
    ompr::get_solution(x[i, j]) |>
    dplyr::filter(value > .9) |>
    dplyr::select(i, j)
  resultado_ucs_otimo <- matching|>
    dplyr::left_join(dist_uc_agencias|>select(-agencia_codigo_jurisdicao), by=c('i', 'j'))|>
    dplyr::select(-i, -j)
  resultado_ucs_jurisdicao <- dist_uc_agencias|>
    dplyr::filter(agencia_codigo_jurisdicao==agencia_codigo)|>
    dplyr::select(-agencia_codigo_jurisdicao, -i, -j, -custo_troca_jurisdicao)

  resultado_agencias_otimo <- agencias_sel|>
    dplyr::inner_join(resultado_ucs_otimo, by = c('agencia_codigo'))|>
    dplyr::group_by(agencia_codigo)|>
    dplyr::summarise(dplyr::across(where(is.numeric), sum), n_ucs=dplyr::n_distinct(uc, na.rm=TRUE))|>
    dplyr::ungroup()|>
    dplyr::select(-j)

  resultado_agencias_jurisdicao <- agencias_t|>
    dplyr::inner_join(resultado_ucs_jurisdicao, by = c('agencia_codigo'))|>
    dplyr::group_by(agencia_codigo)|>
    dplyr::summarise(dplyr::across(where(is.numeric), sum), n_ucs=dplyr::n_distinct(uc, na.rm=TRUE))|>
    dplyr::ungroup()

  resultado <- list()
  resultado$resultado_ucs_otimo <- resultado_ucs_otimo
  resultado$resultado_ucs_jurisdicao <- resultado_ucs_jurisdicao
  resultado$resultado_agencias_otimo <- resultado_agencias_otimo
  resultado$resultado_agencias_jurisdicao <- resultado_agencias_jurisdicao
  if(resultado_completo) {
    resultado$ucs_agencias_todas <- dist_uc_agencias
  }
  resultado
}
