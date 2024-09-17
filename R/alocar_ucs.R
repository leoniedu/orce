#' Alocação Otimizada de Unidades de Coleta (UCs) a Agências
#'
#' Esta função realiza a alocação otimizada de Unidades de Coleta (UCs) a agências, com o objetivo de minimizar os custos totais de deslocamento e operação. A alocação leva em consideração restrições de capacidade das agências, custos de deslocamento (combustível, tempo de viagem e diárias), custos fixos das agências e custos de treinamento.
#'
#' @param ucs Um `tibble` ou `data.frame` contendo informações sobre as UCs, incluindo:
#' \itemize{
#'   \item `uc`: Código único da UC.
#'   \item `agencia_codigo`: Código da agência à qual a UC está atualmente alocada.
#'   \item `dias_coleta`: Número de dias de coleta na UC.
#'   \item `viagens`: Número de viagens necessárias para a coleta na UC.
#' }
#' @param agencias Um `tibble` ou `data.frame` contendo informações sobre as agências selecionáveis, incluindo:
#' \itemize{
#'   \item `agencia_codigo`: Código único da agência.
#'   \item `max_uc_agencia`: (Opcional) Número máximo de UCs que a agência pode atender. Padrão: `Inf` (ilimitado).
#'   \item `custo_fixo`: (Opcional) Custo fixo associado à agência (além do custo de treinamento e salários). Padrão: 0.
#' }
#' @param custo_litro_combustivel Custo do combustível por litro (em R$). Padrão: 6.
#' @param custo_hora_viagem Custo de cada hora de viagem (em R$). Padrão: 10.
#' @param kml Consumo médio de combustível do veículo (em km/l). Padrão: 10.
#' @param valor_diaria Valor da diária para deslocamentos (em R$). Padrão: 335.
#' @param max_diarias_entrevistador Máximo de diárias que um entrevistador pode receber no período de referência. Padrão `Inf`.
#' @param remuneracao_entrevistador Remuneração por entrevistador para todo o período de referência. Padrão 0
#' @param n_entrevistadores_min Número mínimo de entrevistadores por agência. Padrão: 1
#' @param ucs_por_entrevistador Número de UCs coletadas por entrevistador durante todo o período de referência. Padrão: 1
#' @param dias_treinamento Número de dias/diárias para treinamento. Padrão: 0 (nenhum treinamento).
#' @param min_uc_agencia Número mínimo de UCs por agência ativa. Padrão: 1.
#' @param agencias_treinadas (Opcional) Um vetor de caracteres com os códigos das agências que já foram treinadas e não terão custo de treinamento. O custo dos APMs contratados nessas agências ainda será incluído no plano de otimização. Padrão: NULL.
#' @param agencias_treinamento Código da(s) agência(s) onde o treinamento será realizado.
#' @param adicional_troca_jurisdicao Custo adicional quando há troca de agência de coleta. Padrão 0
#' @param distancias_ucs Um `tibble` ou `data.frame` com as distâncias entre UCs e agências, incluindo:
#' \itemize{
#'   \item `uc`: Código da UC.
#'   \item `agencia_codigo`: Código da agência.
#'   \item `distancia_km`: Distância em quilômetros entre a UC e a agência.
#'   \item `duracao_horas`: Duração da viagem em horas entre a UC e a agência
#'   \item `diaria_municipio`: Indica se é necessária uma diária para deslocamento entre a UC e a agência, considerando o município da UC
#'   \item `diaria_pernoite`: Indica se é necessária uma diária com pernoite para deslocamento entre a UC e a agência
#' }
#' @param distancias_agencias Um `tibble` ou `data.frame` com as distâncias entre as agências, incluindo:
#' \itemize{
#'   \item `agencia_codigo_orig`: Código da agência de origem
#'   \item `agencia_codigo_dest`: Código da agência de destino
#'   \item `distancia_km`: Distância em quilômetros entre a agência de origem e a de destino
#'   \item `duracao_horas`: Duração da viagem em horas entre a agência de origem e a de destino
#' }
#' @param resultado_completo (Opcional) Um valor lógico indicando se deve ser retornado um resultado mais completo, incluindo informações sobre todas as combinações de UCs e agências. Padrão: FALSE.
#' @param solver Qual ferramenta para solução do modelo de otimização utilizar. Padrão: glpk. Outras opções: cbc (instalação manual)
#' @param ... Opções para o solver.
#'
#' @return Uma lista contendo:
#' \itemize{
#' * `resultado_ucs_otimo`: Um `tibble` com as UCs e suas alocações otimizadas, incluindo custos de deslocamento.
#' * `resultado_ucs_jurisdicao`: Um `tibble` com as UCs e suas alocações originais (jurisdição), incluindo custos de deslocamento.
#' * `resultado_agencias_otimo`: Um `tibble` com as agências e suas alocações otimizadas, incluindo custos fixos, custos de deslocamento e número de UCs alocadas.
#' * `resultado_agencias_jurisdicao`: Um `tibble` com as agências e suas alocações originais (jurisdição), incluindo custos fixos, custos de deslocamento e número de UCs alocadas.
#' * `ucs_agencias_todas` (opcional): Um `tibble` com todas as combinações de UCs e agências, incluindo distâncias, custos e informações sobre diárias (retornado apenas se `resultado_completo` for TRUE).
#' }
#'
#' @import dplyr ompr magrittr ompr.roi ROI.plugin.glpk checkmate
#' @export
alocar_ucs <- function(ucs,
                       agencias=data.frame(agencia_codigo=unique(ucs$agencia_codigo), max_uc_agencia=Inf, custo_fixo=0),
                       custo_litro_combustivel = 6,
                       custo_hora_viagem = 10,
                       kml = 10,
                       valor_diaria = 335,
                       max_diarias_entrevistador=Inf,
                       remuneracao_entrevistador = 0,
                       n_entrevistadores_min=1,
                       ucs_por_entrevistador=1,
                       dias_treinamento = 0,
                       agencias_treinadas = NULL,
                       agencias_treinamento = NULL,
                       distancias_ucs,
                       distancias_agencias=NULL,
                       min_uc_agencia = 1,
                       adicional_troca_jurisdicao = 0,
                       resultado_completo = FALSE, solver="symphony", ...) {
  # Import required libraries explicitly
  requireNamespace("dplyr")
  require("ompr")
  require("ompr.roi")
  require(paste0("ROI.plugin.",solver),character.only = TRUE)
  # Verificação dos Argumentos
  checkmate::assertTRUE(!anyDuplicated(agencias[['agencia_codigo']]))
  checkmate::assertTRUE(!anyDuplicated(ucs[['uc']]))
  checkmate::assert_number(custo_litro_combustivel, lower = 0)
  checkmate::assert_number(kml, lower = 0)
  checkmate::assert_number(valor_diaria, lower = 0)
  checkmate::assert_number(dias_treinamento, lower = 0)
  checkmate::assert_character(agencias_treinamento, null.ok=dias_treinamento == 0)
  checkmate::assert_data_frame(distancias_agencias, null.ok=dias_treinamento == 0)
  checkmate::assert_integerish(min_uc_agencia, lower = 1)
  checkmate::assert_number(ucs_por_entrevistador, lower = 1)
  checkmate::assert_number(remuneracao_entrevistador, lower = 0)
  checkmate::assert_character(agencias_treinadas, null.ok = TRUE)
  checkmate::assertTRUE(all(c('diaria_municipio', 'uc', 'diaria_pernoite')%in%names(distancias_ucs)))
  checkmate::assertTRUE(all(c('dias_coleta', 'viagens'
                              #, 'municipio_codigo'
                              )%in%names(ucs)))
  checkmate::assertTRUE(all(c('max_uc_agencia', 'custo_fixo')%in%names(agencias)))
  agencias <- agencias|>
    dplyr::ungroup()|>
    dplyr::select(agencia_codigo, max_uc_agencia, custo_fixo)
  # Creating jurisdiction allocation
  agencias_jurisdicao <- tibble::tibble(agencia_codigo=unique(ucs$agencia_codigo))

  if (is.null(agencias)) {
    agencias <- agencias_jurisdicao
  }
  agencias_sel <- tibble::tibble(agencia_codigo=unique(agencias$agencia_codigo))|>
    dplyr::mutate(j=1:n())

    # Seleciona agência de treinamento mais próxima das agências de coleta
  agencias_t <- agencias |>
    sf::st_drop_geometry()|>
    dplyr::ungroup()
  if (dias_treinamento>0) {
    agencias_t <- agencias_t|>
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
  } else {
    agencias_t <- agencias_t |>
      dplyr::mutate(distancia_km_agencia_treinamento=NA_real_, duracao_horas_agencia_treinamento_km=NA_real_)
  }
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

  agencias_t$custo_treinamento_por_entrevistador <- custo_treinamento


  # Maximum UCs per agency
  agencias_sel <- agencias_sel|>
    dplyr::inner_join(agencias_t, by="agencia_codigo")
  # Combining UC and agency information
  ucs_i <- ucs |>
    sf::st_drop_geometry()|>
    dplyr::ungroup()|>
    dplyr::arrange(uc)|>
    dplyr::transmute(i=1:n(), uc, #municipio_codigo,
                     agencia_codigo_jurisdicao=agencia_codigo, dias_coleta, viagens)
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
                  viagens, dias_coleta, distancia_km, duracao_horas, diaria_municipio, diaria_pernoite)

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
      diaria=dplyr::if_else(diaria_pernoite, TRUE, diaria),
      meia_diaria=(!diaria_pernoite) & diaria,
      ## se com diaria inteira
      trechos=dplyr::if_else(diaria&(!meia_diaria),
                             # é uma ida e uma volta por viagem
                             viagens*2,
                             # sem diária ou com meia diária
                             dias_coleta * 2),
      total_diarias=dplyr::if_else(diaria, calcula_diarias(dias_coleta, meia_diaria),0),
      custo_diarias=total_diarias * valor_diaria,
      distancia_total_km=trechos * distancia_km,
      duracao_total_horas=trechos * duracao_horas,
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
  diarias_ij <- function(i,j) {
    stopifnot(length(i) == length(j))
    tibble::tibble(i=i,j=j)|>
      dplyr::left_join(dist_uc_agencias, by=c("i", "j"))|>
      dplyr::pull(total_diarias)
  }
  transport_cost <- function(i,j) {
    stopifnot(length(i) == length(j))
    tibble::tibble(i=i,j=j)|>
      dplyr::left_join(dist_uc_agencias, by=c("i", "j"))|>
      mutate(custo_deslocamento_com_troca=custo_deslocamento+custo_troca_jurisdicao)|>
      dplyr::pull(custo_deslocamento_com_troca)
  }
  # Create optimization model using ompr package
  n <- nrow(ucs_i)
  m <- nrow(agencias_sel)
  stopifnot((agencias_sel$j)==(1:nrow(agencias_sel)))
  # alocar_ucs_model <- function(agencias_sel, n,m, transport_cost, remuneracao_entrevistador, n_entrevistadores_min, min_uc_agencia, max_diarias_entrevistador, diarias_ij) {
  # }
  model <- MIPModel() |>
    # 1 iff (se e somente se) uc i vai para a agencia j
    add_variable(x[i, j], i = 1:n, j = 1:m, type = "binary") |>
    # 1 iff (se e somente se) agencia j ativada
    add_variable(y[j], j = 1:m, type = "binary") |>
    # trabalhadores na agencia j
    add_variable(w[j], j = 1:m, type = "integer", lb=0) |>
    # maximize the preferences
    set_objective(sum_over(
      transport_cost(i, j)* x[i, j] , i = 1:n, j = 1:m)
      + sum_over(
        (agencias_sel$custo_fixo[j]) * y[j]+w[j]*({remuneracao_entrevistador}+agencias_sel$custo_treinamento_por_entrevistador[j]), j = 1:m), "min") |>
    # toda UC precisa estar associada a uma agencia
    add_constraint(sum_over(x[i, j], j = 1:m) == 1, i = 1:n) |>
    # se uma UC está designada a uma agencia, a agencia tem que ficar ativa
    add_constraint(x[i,j] <= y[j], i = 1:n, j = 1:m)|>
    # se agencia está ativa, w tem que ser >= n_entrevistadores_min
    add_constraint((y[j]*{n_entrevistadores_min}) <= w[j], i = 1:n, j = 1:m)|>
    # w tem que ser o suficiente para dar conta das ucs
    add_constraint((sum_over(x[i,j], i=1:n)/{ucs_por_entrevistador}) <= w[j], j = 1:m)
  if(any({{min_uc_agencia}}>1)) {
    model <- model|>
      # constraint com número mínimo de UCs por agência que for incluída
      # multiplica por y[j] por que só vale pra agencias incluídas, se não é >=0
      add_constraint(sum_over(x[i, j], i = 1:n) >= (min_uc_agencia[j]*y[j]), j = 1:m)
  }
  if(any(is.finite(agencias_sel$max_uc_agencia))) {
    model <- model|>
      # constraint com número máximo de UCs por agência
      add_constraint(sum_over(x[i, j], i = 1:n) <= agencias_sel$max_uc_agencia[j], j = 1:m)
  }
  if (any(is.finite({max_diarias_entrevistador}))) {
    model <- model|>
      add_constraint(sum_over(x[i, j]*diarias_ij(i,j), i = 1:n) <= (max_diarias_entrevistador*w[j]), j = 1:m)
  }
  # Solve the model using solver
  result <- ompr::solve_model(model, ompr.roi::with_ROI(solver = {solver}, ...))
  if ({solver}=="symphony") {
    if (result$additional_solver_output$ROI$status$msg$code%in%c(231L, 232L)) result$status <- result$additional_solver_output$ROI$status$msg$message
  }
  stopifnot(result$status != "error")
  # Extract the solution
  matching <- result |>
    ompr::get_solution(x[i, j]) |>
    dplyr::filter(value > .9) |>
    dplyr::select(i, j)
  workers <- result |>
    ompr::get_solution(w[j]) |>
    dplyr::filter(value > .9) |>
    dplyr::select(j, entrevistadores=value)
  resultado_ucs_otimo <- matching|>
    dplyr::left_join(dist_uc_agencias|>select(-agencia_codigo_jurisdicao), by=c('i', 'j'))|>
    dplyr::select(-i, -j)
  resultado_ucs_jurisdicao <- dist_uc_agencias|>
    dplyr::filter(agencia_codigo_jurisdicao==agencia_codigo)|>
    dplyr::select(-agencia_codigo_jurisdicao, -i, -j, -custo_troca_jurisdicao)
  ags_group_vars <- c(names(agencias_sel),  'entrevistadores')
  resultado_agencias_otimo <- agencias_sel|>
    dplyr::inner_join(resultado_ucs_otimo, by = c('agencia_codigo'))|>
    dplyr::left_join(resultado_ucs_jurisdicao|>dplyr::select(uc, agencia_codigo_jurisdicao=agencia_codigo), by = c('uc'))|>
    dplyr::group_by(pick(any_of(ags_group_vars)))|>
    dplyr::summarise(dplyr::across(where(is.numeric), sum), n_ucs=dplyr::n_distinct(uc, na.rm=TRUE), n_trocas_jurisdicao=sum(agencia_codigo!=agencia_codigo_jurisdicao))|>
    dplyr::ungroup()|>
    dplyr::left_join(workers, by=c('j'))|>
    dplyr::select(-j)|>
    dplyr::mutate(custo_total_entrevistadores=entrevistadores*{remuneracao_entrevistador}+entrevistadores*custo_treinamento_por_entrevistador)
  resultado_agencias_jurisdicao <- agencias_t|>
    dplyr::inner_join(resultado_ucs_jurisdicao, by = c('agencia_codigo'))|>
    dplyr::group_by(pick(any_of(ags_group_vars)))|>
    dplyr::summarise(dplyr::across(where(is.numeric), sum), n_ucs=dplyr::n_distinct(uc, na.rm=TRUE))|>
    dplyr::mutate(entrevistadores=pmax(ceiling(n_ucs/{ucs_por_entrevistador}), n_entrevistadores_min),
                  custo_total_entrevistadores=entrevistadores*{remuneracao_entrevistador}+entrevistadores*custo_treinamento_por_entrevistador)|>
    dplyr::ungroup()
  resultado <- list()
  resultado$resultado_ucs_otimo <- resultado_ucs_otimo
  resultado$resultado_ucs_jurisdicao <- resultado_ucs_jurisdicao
  resultado$resultado_agencias_otimo <- resultado_agencias_otimo
  resultado$resultado_agencias_jurisdicao <- resultado_agencias_jurisdicao
  if(resultado_completo) {
    resultado$ucs_agencias_todas <- dist_uc_agencias
    resultado$otimizacao <- result
  }
  resultado
}
