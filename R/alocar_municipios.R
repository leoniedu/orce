#' Alocação Otimizada de Unidades de Coleta (UCs) a Agências
#'
#' Esta função realiza a alocação otimizada de Unidades de Coleta (UCs) a agências, com o objetivo de minimizar os custos totais de deslocamento e operação. A alocação leva em consideração restrições de capacidade das agências, custos de deslocamento (combustível, tempo de viagem e diárias), custos fixos das agências e custos de treinamento.
#'
#' @param ucs Um `tibble` ou `data.frame` contendo informações sobre as UCs, incluindo:
#' \itemize{
#'   \item `uc`: Código único da UC.
#'   \item `municipio_codigo`: Código único do município.
#'   \item `agencia_codigo`: Código da agência à qual a UC está atualmente alocada.
#'   \item `dias_coleta`: Número de dias de coleta na UC.
#'   \item `viagens`: Número de viagens necessárias para a coleta na UC.
#' }
#' @param agencias Um `tibble` ou `data.frame` contendo informações sobre as agências selecionáveis, incluindo:
#' \itemize{
#'   \item `agencia_codigo`: Código único da agência.
#'   \item `uc_agencia_max`: Número máximo de UCs que a agência pode atender.
#'   \item `custo_fixo`: Custo fixo associado à agência.
#' }
#' @param custo_litro_combustivel Custo do combustível por litro (em R$). Padrão: 6.
#' @param custo_hora_viagem Custo de cada hora de viagem (em R$). Padrão: 10.
#' @param kml Consumo médio de combustível do veículo (em km/l). Padrão: 10.
#' @param valor_diaria Valor da diária para deslocamentos (em R$). Padrão: 335.
#' @param diarias_entrevistador_max Máximo de diárias que um entrevistador pode receber no período de referência. Padrão: `Inf`.
#' @param remuneracao_entrevistador Remuneração por entrevistador para todo o período de referência. Padrão: 0.
#' @param n_entrevistadores_min Número mínimo de entrevistadores por agência. Padrão: 1.
#' @param dias_coleta_entrevistador_max Número de dias de coleta por entrevistador.
#' @param dias_treinamento Número de dias/diárias para treinamento. Padrão: 0 (nenhum treinamento).
#' @param agencias_treinadas (Opcional) Um vetor de caracteres com os códigos das agências que já foram treinadas e não terão custo de treinamento. Padrão: NULL.
#' @param agencias_treinamento Código da(s) agência(s) onde o treinamento será realizado.
#' @param distancias_ucs Um `tibble` ou `data.frame` com as distâncias entre UCs e agências, incluindo:
#' \itemize{
#'   \item `uc`: Código da UC.
#'   \item `agencia_codigo`: Código da agência.
#'   \item `distancia_km`: Distância em quilômetros entre a UC e a agência.
#'   \item `duracao_horas`: Duração da viagem em horas entre a UC e a agência.
#'   \item `diaria_municipio`: Indica se é necessária uma diária para deslocamento entre a UC e a agência, considerando o município da UC.
#'   \item `diaria_pernoite`: Indica se é necessária uma diária com pernoite para deslocamento entre a UC e a agência.
#' }
#' @param distancias_agencias Um `tibble` ou `data.frame` com as distâncias entre as agências, incluindo:
#' \itemize{
#'   \item `agencia_codigo_orig`: Código da agência de origem.
#'   \item `agencia_codigo_dest`: Código da agência de destino.
#'   \item `distancia_km`: Distância em quilômetros entre a agência de origem e a de destino.
#'   \item `duracao_horas`: Duração da viagem em horas entre a agência de origem e a de destino.
#' }
#' @param uc_agencia_min Número mínimo de UCs por agência ativa. Padrão: 1.
#' @param adicional_troca_jurisdicao Custo adicional quando há troca de agência de coleta. Padrão: 0.
#' @param resultado_completo (Opcional) Um valor lógico indicando se deve ser retornado um resultado mais completo, incluindo informações sobre todas as combinações de UCs e agências. Padrão: FALSE.
#' @param solver Qual ferramenta para solução do modelo de otimização utilizar. Padrão: "symphony". Outras opções: "glpk", "cbc" (instalação manual).
#' @param ... Opções adicionais para o solver.
#'
#' @return Uma lista contendo:
#' \itemize{
#' * `resultado_municipios_jurisdicao`: Um `tibble` com os municipios e suas alocações originais (jurisdição), incluindo custos de deslocamento.
#' * `resultado_agencias_jurisdicao`: Um `tibble` com as agências e suas alocações originais (jurisdição), incluindo custos fixos, custos de deslocamento e número de UCs alocadas.
#'   \item `resultado_municipios_otimo`: Um `tibble` com os municípios e suas alocações otimizadas, incluindo custos de deslocamento.
#'   \item `resultado_agencias_otimo`: Um `tibble` com as agências e suas alocações otimizadas, incluindo custos fixos, custos de deslocamento, número de UCs alocadas e número de entrevistadores.
#'   \item `ucs_agencias_todas` (opcional): Um `tibble` com todas as combinações de UCs e agências, incluindo distâncias, custos e informações sobre diárias (retornado apenas se `resultado_completo` for TRUE).
#'   \item `otimizacao` (opcional): O resultado completo da otimização (retornado apenas se `resultado_completo` for TRUE).
#' }
#'
#' @import dplyr ompr ompr.roi ROI.plugin.glpk ROI.plugin.symphony checkmate sf tibble tidyr
#' @export
alocar_municipios <- function(ucs,
                       agencias=data.frame(agencia_codigo=unique(ucs$agencia_codigo), uc_agencia_max=Inf, custo_fixo=0),
                       #custo_fixo=0,
                       custo_litro_combustivel = 6,
                       custo_hora_viagem = 10,
                       kml = 10,
                       valor_diaria = 335,
                       diarias_entrevistador_max=Inf,
                       remuneracao_entrevistador = 0,
                       n_entrevistadores_min=1,
                       dias_coleta_entrevistador_max,
                       dias_treinamento = 0,
                       agencias_treinadas = NULL,
                       agencias_treinamento = NULL,
                       distancias_ucs,
                       distancias_agencias=NULL,
                       uc_agencia_min = 1,
                       adicional_troca_jurisdicao = 0,
                       resultado_completo = FALSE, solver="cbc", ...) {
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
  checkmate::assert_integerish(uc_agencia_min, lower = 1)
  checkmate::assert_number(dias_coleta_entrevistador_max, lower = 1)
  checkmate::assert_number(remuneracao_entrevistador, lower = 0)
  checkmate::assert_character(agencias_treinadas, null.ok = TRUE)
  checkmate::assertTRUE(all(c('diaria_municipio', 'uc', 'diaria_pernoite')%in%names(distancias_ucs)))
  checkmate::assertTRUE(all(c('dias_coleta', 'viagens'
                              , 'municipio_codigo'
                              )%in%names(ucs)))
  checkmate::assertTRUE(all(c('uc_agencia_max', 'custo_fixo', 'dias_coleta_agencia_max')%in%names(agencias)))
  # Creating jurisdiction allocation
  agencias_jurisdicao <- tibble::tibble(agencia_codigo=unique(ucs$agencia_codigo))
  if (is.null(agencias)) {
    agencias <- agencias_jurisdicao|>mutate(uc_agencia_max=Inf, custo_fixo=0)
  }
  agencias <- agencias|>
    dplyr::ungroup()|>
    dplyr::select(agencia_codigo, uc_agencia_max, custo_fixo, dias_coleta_agencia_max)

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
    dplyr::transmute(#i=1:n(),
                     uc, municipio_codigo,
                     agencia_codigo_jurisdicao=agencia_codigo, dias_coleta, viagens)
  agencias_i <- ucs_i|>
    dplyr::group_by(agencia_codigo=agencia_codigo_jurisdicao)|>
    dplyr::summarise(dias_coleta_agencia_jurisdicao=sum(dias_coleta))
  agencias_check <- agencias_i|>
    dplyr::inner_join(agencias_t, by="agencia_codigo")

  with(agencias_check, stopifnot(dias_coleta_agencia_max>=dias_coleta_agencia_jurisdicao))

  ag_mun_grid <- tidyr::expand_grid(
    agencias_t|>
      transmute(municipio_codigo_agencia = substr(agencia_codigo, 1, 7), agencia_codigo),
    ucs_i
  )
  distancias_ucs_1 <- ag_mun_grid |>
    dplyr::left_join(distancias_ucs, by = c('uc', 'municipio_codigo', 'agencia_codigo'))|>
    dplyr::ungroup()|>
    sf::st_drop_geometry()|>
    dplyr::select(uc, municipio_codigo, agencia_codigo, agencia_codigo_jurisdicao,
                  viagens, dias_coleta, distancia_km, duracao_horas, diaria_municipio, diaria_pernoite)

  # Ensure there are no missing values in distances
  stopifnot(sum(is.na(distancias_ucs_1$distancia_km)) == 0)
  stopifnot(nrow(distancias_ucs_1) == (nrow(ucs_i) * nrow(agencias_t)))

  # Compute transport costs
  dist_uc_agencias <- distancias_ucs_1 |>
    dplyr::left_join(agencias_sel, by="agencia_codigo")|>
    dplyr::transmute(
      uc, municipio_codigo,
      j, agencia_codigo,
      agencia_codigo_jurisdicao,
      distancia_km, duracao_horas, dias_coleta,
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
  municipios_agencias <- ucs|>
    dplyr::ungroup()|>
    dplyr::distinct(municipio_codigo, agencia_codigo_jurisdicao=agencia_codigo)|>
    dplyr::mutate(i=1:dplyr::n())
  dist_municipios_agencias <- municipios_agencias|>
    dplyr::left_join(dist_uc_agencias, by=c("agencia_codigo_jurisdicao", "municipio_codigo"))|>
    dplyr::group_by(municipio_codigo,i, j, agencia_codigo, agencia_codigo_jurisdicao)|>
    dplyr::summarise(across(where(is.numeric), sum))|>
    dplyr::ungroup()

  stopifnot(all(!is.na(dist_municipios_agencias$distancia_km)))

  # Set default uc_agencia_min if it is a single value
  if (length(uc_agencia_min) == 1) {
    uc_agencia_min <- rep(uc_agencia_min, nrow(agencias_sel))
  }
  diarias_ij <- function(i,j) {
    stopifnot(length(i) == length(j))
    tibble::tibble(i=i,j=j)|>
      dplyr::left_join(dist_municipios_agencias, by=c("i", "j"))|>
      dplyr::pull(total_diarias)
  }
  dias_coleta_ij <- function(i,j) {
    ## poderia usar base de dados de municipios (somente i) aqui
    stopifnot(length(i) == length(j))
    tibble::tibble(i=i,j=j)|>
      dplyr::left_join(dist_municipios_agencias, by=c("i", "j"))|>
      dplyr::pull(dias_coleta)
  }
  transport_cost <- function(i,j) {
    stopifnot(length(i) == length(j))
    tibble::tibble(i=i,j=j)|>
      dplyr::left_join(dist_municipios_agencias, by=c("i", "j"))|>
      mutate(custo_deslocamento_com_troca=custo_deslocamento+custo_troca_jurisdicao)|>
      dplyr::pull(custo_deslocamento_com_troca)
  }
  # Create optimization model using ompr package
  n <- max(dist_municipios_agencias$i)
  m <- nrow(agencias_sel)
  stopifnot((agencias_sel$j)==(1:nrow(agencias_sel)))
  # alocar_ucs_model <- function(agencias_sel, n,m, transport_cost, remuneracao_entrevistador, n_entrevistadores_min, uc_agencia_min, diarias_entrevistador_max, diarias_ij) {
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
        #{custo_fixo} * y[j]+
        (agencias_sel$custo_fixo[j]) * y[j]+
        #(agencias_sel$custo_fixo[1]) * y[j]+
        w[j]*({remuneracao_entrevistador}+agencias_sel$custo_treinamento_por_entrevistador[j]), j = 1:m), "min") |>
    # toda UC precisa estar associada a uma agencia
    add_constraint(sum_over(x[i, j], j = 1:m) == 1, i = 1:n) |>
    # se uma UC está designada a uma agencia, a agencia tem que ficar ativa
    add_constraint(x[i,j] <= y[j], i = 1:n, j = 1:m)|>
    # se agencia está ativa, w tem que ser >= n_entrevistadores_min
    add_constraint((y[j]*{n_entrevistadores_min}) <= w[j], i = 1:n, j = 1:m)|>
    # w tem que ser o suficiente para dar conta das ucs
    add_constraint((sum_over(x[i,j]*dias_coleta_ij(i,j), i=1:n)/{dias_coleta_entrevistador_max}) <= w[j], j = 1:m)
  ## respeitar o máximo de dias de coleta por agencia
  if(any(is.finite(agencias_sel$dias_coleta_agencia_max))) {
    model <- model|>
      # constraint com número máximo de UCs por agência
      add_constraint(sum_over(x[i, j]*dias_coleta_ij(i,j), i = 1:n) <= agencias_sel$dias_coleta_agencia_max[j], j = 1:m)
  }
  if (any(is.finite({diarias_entrevistador_max}))) {
    model <- model|>
      add_constraint(sum_over(x[i, j]*diarias_ij(i,j), i = 1:n) <= (diarias_entrevistador_max*w[j]), j = 1:m)
  }
  # Solve the model using solver
  ##browser()
  result <- ompr::solve_model(model,ompr.roi::with_ROI(solver = {solver}, ...))
  if ({solver}=="symphony") {
    if (result$additional_solver_output$ROI$status$msg$code%in%c(231L, 232L)) result$status <- result$additional_solver_output$ROI$status$msg$message
  }
  if ({solver}=="cbc") {
    result$status <- result$additional_solver_output$ROI$status$msg$message
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
  resultado_municipios_otimo <- matching|>
    dplyr::left_join(dist_municipios_agencias
                     ## |>select(-agencia_codigo_jurisdicao)
                     , by=c('i', 'j'))|>
    dplyr::select(-i, -j)
  resultado_municipios_jurisdicao <- dist_municipios_agencias|>
    dplyr::filter(agencia_codigo_jurisdicao==agencia_codigo)|>
    dplyr::select(-agencia_codigo_jurisdicao, -i, -j, -custo_troca_jurisdicao)
  ags_group_vars <- c(names(agencias_sel),  'entrevistadores')
  resultado_agencias_otimo <- agencias_sel|>
    dplyr::inner_join(resultado_municipios_otimo, by = c('agencia_codigo'))|>
    ##heredplyr::left_join(ucs_i|>dplyr::select(uc, agencia_codigo_jurisdicao), by = c('uc'))|>
    dplyr::group_by(pick(any_of(ags_group_vars)))|>
    dplyr::summarise(dplyr::across(where(is.numeric), sum), n_municipios=dplyr::n_distinct(municipio_codigo, na.rm=TRUE), n_trocas_jurisdicao=sum(agencia_codigo!=agencia_codigo_jurisdicao))|>
    dplyr::ungroup()|>
    dplyr::left_join(workers, by=c('j'))|>
    dplyr::select(-j)|>
    dplyr::mutate(custo_total_entrevistadores=entrevistadores*{remuneracao_entrevistador}+entrevistadores*custo_treinamento_por_entrevistador)

  resultado_agencias_jurisdicao <- agencias_t|>
    dplyr::inner_join(resultado_municipios_jurisdicao, by = c('agencia_codigo'))|>
    dplyr::group_by(pick(any_of(ags_group_vars)))|>
    dplyr::summarise(dplyr::across(where(is.numeric), sum),
                     n_municipios=dplyr::n_distinct(municipio_codigo, na.rm=TRUE))|>
    dplyr::mutate(entrevistadores=pmax(
      ceiling(dias_coleta/dias_coleta_entrevistador_max),
      ceiling(total_diarias/diarias_entrevistador_max),
      n_entrevistadores_min),
      custo_total_entrevistadores=entrevistadores*{remuneracao_entrevistador}+entrevistadores*custo_treinamento_por_entrevistador)|>
    dplyr::ungroup()
  resultado <- list()
  resultado$resultado_municipios_otimo <- resultado_municipios_otimo
  resultado$resultado_municipios_jurisdicao <- resultado_municipios_jurisdicao
  resultado$resultado_agencias_otimo <- resultado_agencias_otimo
  resultado$resultado_agencias_jurisdicao <- resultado_agencias_jurisdicao
  attr(resultado, "solucao_status") <- result$status
  if(resultado_completo) {
    resultado$municipios_agencias_todas <- dist_municipios_agencias
    resultado$otimizacao <- result
  }
  resultado
}
