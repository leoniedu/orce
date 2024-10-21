#' Alocação Otimizada de Unidades de Coleta (UCs) a Agências com períodos de coleta
#'
#' Esta função realiza a alocação otimizada de Unidades de Coleta (UCs) a agências, com o objetivo de minimizar os custos totais de deslocamento e operação. A alocação leva em consideração restrições de capacidade das agências (em número de dias de coleta), custos de deslocamento (combustível, tempo de viagem e diárias), custos fixos das agências e custos de treinamento.
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
#'   \item `dias_coleta_agencia_max`: Número máximo de dias de coleta que a agência pode realizar.
#'   \item `custo_fixo`: Custo fixo associado à agência.
#' }
#' @param custo_litro_combustivel Custo do combustível por litro (em R$). Padrão: 6.
#' @param custo_hora_viagem Custo de cada hora de viagem (em R$). Padrão: 10.
#' @param kml Consumo médio de combustível do veículo (em km/l). Padrão: 10.
#' @param valor_diaria Valor da diária para deslocamentos (em R$). Padrão: 335.
#' @param diarias_entrevistador_max Total máximo de diárias que um entrevistador pode receber, somando todos os períodos. Padrão: `Inf`.
#' @param remuneracao_entrevistador Remuneração total por entrevistador para todos os períodos. Padrão: 0.
#' @param n_entrevistadores_min Número mínimo de entrevistadores por agência. Padrão: 1.
#' @param dias_coleta_entrevistador_max Número máximo de dias de coleta por entrevistador por período.
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
#' @param adicional_troca_jurisdicao Custo adicional quando há troca de agência de coleta. Padrão: 0.
#' @param resultado_completo (Opcional) Um valor lógico indicando se deve ser retornado um resultado mais completo, incluindo informações sobre todas as combinações de UCs e agências. Padrão: FALSE.
#' @param solver Qual ferramenta para solução do modelo de otimização utilizar. Padrão: "cbc". Outras opções: "glpk", "symphony" (instalação manual).
#' @param ... Opções adicionais para o solver.
#'
#' @return Uma lista contendo:
#' \itemize{
#' * `resultado_ucs_jurisdicao`: Um `tibble` com as UCs e suas alocações originais (jurisdição), incluindo custos de deslocamento.
#' * `resultado_agencias_jurisdicao`: Um `tibble` com as agências e suas alocações originais (jurisdição), incluindo custos fixos, custos de deslocamento e número de UCs alocadas.
#'   \item `resultado_ucs_otimo`: Um `tibble` com as UCs e suas alocações otimizadas, incluindo custos de deslocamento.
#'   \item `resultado_agencias_otimo`: Um `tibble` com as agências e suas alocações otimizadas, incluindo custos fixos, custos de deslocamento, número de UCs alocadas e número de entrevistadores.
#'   \item `ucs_agencias_todas` (opcional): Um `tibble` com todas as combinações de UCs e agências, incluindo distâncias, custos e informações sobre diárias (retornado apenas se `resultado_completo` for TRUE).
#'   \item `otimizacao` (opcional): O resultado completo da otimização (retornado apenas se `resultado_completo` for TRUE).
#' }
#'
#' @export
alocar_ucs_t <- function(ucs,
                         agencias = data.frame(agencia_codigo = unique(ucs$agencia_codigo), dias_coleta_agencia_max = Inf, custo_fixo = 0),
                         alocar_por = "uc",
                         custo_litro_combustivel = 6,
                         custo_hora_viagem = 10,
                         kml = 10,
                         valor_diaria = 335,
                         diarias_entrevistador_max = Inf,
                         remuneracao_entrevistador = 0,
                         n_entrevistadores_min = 1,
                         dias_coleta_entrevistador_max,
                         dias_treinamento = 0,
                         agencias_treinadas = NULL,
                         agencias_treinamento = NULL,
                         distancias_ucs,
                         distancias_agencias = NULL,
                         adicional_troca_jurisdicao = 0,
                         resultado_completo = FALSE,
                         solver = "cbc",
                         rel_tol = .005,
                         max_time = 30 * 60,
                         ...) {
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
  checkmate::assert_number(rel_tol, lower = 0, upper = 1)
  checkmate::assert_number(dias_treinamento, lower = 0)
  checkmate::assert_character(agencias_treinamento, null.ok=dias_treinamento == 0)
  checkmate::assert_data_frame(distancias_agencias, null.ok=dias_treinamento == 0)
  checkmate::assert_number(dias_coleta_entrevistador_max, lower = 1)
  checkmate::assert_number(remuneracao_entrevistador, lower = 0)
  checkmate::assert_character(agencias_treinadas, null.ok = TRUE)
  checkmate::check_string(alocar_por, null.ok = FALSE)
  checkmate::assertTRUE(all(c('diaria_municipio', 'uc', 'diaria_pernoite')%in%names(distancias_ucs)))
  checkmate::assertTRUE(all(c('dias_coleta', 'viagens', 'data')%in%names(ucs)))
  checkmate::assertTRUE(all(c('dias_coleta_agencia_max', 'custo_fixo')%in%names(agencias)))
  ## sanitize
  ucs <- ucs|>
    dplyr::ungroup()|>
    sf::st_drop_geometry()|>
    dplyr::mutate(i=vctrs::vec_group_id(!!rlang::sym(alocar_por)))
  stopifnot(n_distinct(ucs$uc)==nrow(ucs))
  agencias <- agencias|>
    dplyr::ungroup()|>
    dplyr::select(agencia_codigo, dias_coleta_agencia_max, custo_fixo)|>
    dplyr::mutate(j=1:n())
  stopifnot(n_distinct(agencias$agencia_codigo)==nrow(agencias))
  distancias_ucs <- distancias_ucs|>
    dplyr::ungroup()|>
    sf::st_drop_geometry()
  dcount <- distancias_ucs|>
    count(agencia_codigo,uc)
  stopifnot(all(dcount$n==1))
  #browser()
  if (alocar_por!="uc") {
    if (!alocar_por %in% names(ucs)) {
      stop(paste("alocar_por:", alocar_por, "não encontrado nos dados: ucs"))
    }
    # Adjust distancias_ucs for the new aggregation
    distancias_ucs <- distancias_ucs |>
      dplyr::left_join(ucs|>dplyr::select(uc, !!rlang::sym(alocar_por)))
  }

  # Seleciona agência de treinamento mais próxima das agências de coleta
  if (dias_treinamento>0) {
    agencias_t <- agencias|>
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
      dplyr::ungroup()|>
      dplyr::arrange(j)
  } else {
    agencias_t <- agencias |>
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
  #browser()
  # Combining UC and agency information
  indice_t <- ucs|>dplyr::ungroup()|>
    dplyr::distinct(data)|>
    dplyr::arrange(data)|>
    dplyr::mutate(t=1:dplyr::n())
  ucs_i <- ucs |>
    dplyr::arrange(uc)|>
    dplyr::transmute(i,
                     data,
                     uc,
                     agencia_codigo_jurisdicao=agencia_codigo, dias_coleta, viagens)|>
    dplyr::left_join(indice_t, by="data")

  agencias_i <- ucs_i|>
    dplyr::group_by(agencia_codigo=agencia_codigo_jurisdicao)|>
    dplyr::summarise(dias_coleta_agencia_jurisdicao=sum(dias_coleta))
  agencias_check <- agencias_i|>
    dplyr::inner_join(agencias_t, by="agencia_codigo")
  ag_mun_grid <- tidyr::expand_grid(
    agencias_t|>
      transmute(municipio_codigo_agencia = substr(agencia_codigo, 1, 7), agencia_codigo),
    ucs_i
  )
  distancias_ucs_1 <- ag_mun_grid |>
    dplyr::left_join(distancias_ucs, by = c('uc', 'agencia_codigo'))|>
    dplyr::select(i,t,uc, agencia_codigo, agencia_codigo_jurisdicao,
                  viagens, dias_coleta, distancia_km, duracao_horas, diaria_municipio, diaria_pernoite)

  # Ensure there are no missing values in distances
  stopifnot(sum(is.na(distancias_ucs_1$distancia_km)) == 0)
  stopifnot(nrow(distancias_ucs_1) == (nrow(ucs_i) * nrow(agencias_t)))

  # Compute transport costs
  dist_uc_agencias <- distancias_ucs_1 |>
    dplyr::left_join(agencias_t, by="agencia_codigo")|>
    dplyr::transmute(
      i, t, uc,
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
      custo_deslocamento= custo_combustivel + custo_horas_viagem + custo_diarias,
      custo_deslocamento_com_troca=custo_deslocamento+custo_troca_jurisdicao
    )

  stopifnot(all(!is.na(dist_uc_agencias$distancia_km)))
  ## check i,j
  u_dist_uc_agencias <- dist_uc_agencias|>
    dplyr::ungroup()|>
    dplyr::count(i,j)
  stopifnot(all(u_dist_uc_agencias$n==1))
  make_i_j <- function(x,col) {
    x|>
      dplyr::ungroup()|>
      dplyr::select(all_of(c("i","j",col)))|>
      tidyr::pivot_wider(id_cols=i,names_from=j,values_from=col, names_sort = TRUE)|>
      dplyr::arrange(as.numeric(i))|>
      dplyr::select(-i)|>
      as.matrix()
  }
  transport_cost_i_j <- make_i_j(x=dist_uc_agencias, col="custo_deslocamento_com_troca")
  diarias_i_j <- make_i_j(x=dist_uc_agencias, col="total_diarias")
  dias_coleta_ijt_df <- dist_uc_agencias|>
      dplyr::ungroup()|>
      dplyr::select(all_of(c("i","j","t", "dias_coleta")))|>
      tidyr::pivot_wider(id_cols=c("i", "t"),names_from=j,values_from="dias_coleta", names_sort = TRUE)|>
      dplyr::arrange(i,t)
  tvec <- dias_coleta_ijt_df$t
  dias_coleta_ijt_mat <- dias_coleta_ijt_df|>
    dplyr::select(-i,-t)|>
    as.matrix()
  dias_coleta_ijt <- function(i,j,t) {
    if (tvec[i]==t) {
      dias_coleta_ijt_mat[i,j]
    } else {
      0
    }
  }
  # Create optimization model using ompr package
  n <- nrow(ucs_i)
  m <- nrow(agencias_t)
  p <- nrow(indice_t)
  stopifnot((agencias_t$j)==(1:nrow(agencias_t)))
  model <- MIPModel() |>
    # 1 iff (se e somente se) uc i vai para a agencia j
    add_variable(x[i, j], i = 1:n, j = 1:m, type = "binary") |>
    # 1 iff (se e somente se) agencia j ativada
    add_variable(y[j], j = 1:m, type = "binary") |>
    # trabalhadores na agencia j
    add_variable(w[j], j = 1:m, type = "integer", lb=0) |>
    # maximize the preferences
    set_objective(sum_over(
      transport_cost_i_j[i, j]* x[i, j] , i = 1:n, j = 1:m)
      + sum_over(
        (agencias_t$custo_fixo[j]) * y[j]+w[j]*({remuneracao_entrevistador}+agencias_t$custo_treinamento_por_entrevistador[j]), j = 1:m), "min") |>
    # toda UC precisa estar associada a uma agencia
    add_constraint(sum_over(x[i, j], j = 1:m) == 1, i = 1:n) |>
    # se uma UC está designada a uma agencia, a agencia tem que ficar ativa
    add_constraint(x[i,j] <= y[j], i = 1:n, j = 1:m)|>
    # se agencia está ativa, w tem que ser >= n_entrevistadores_min
    add_constraint((y[j]*{n_entrevistadores_min}) <= w[j], i = 1:n, j = 1:m)|>
    # w tem que ser o suficiente para dar conta das ucs para todos os
    # períodos
    add_constraint((sum_over(x[i,j]*dias_coleta_ijt(i,j,t), i=1:n)/{dias_coleta_entrevistador_max}) <= w[j], j = 1:m, t = 1:p)
  ## respeitar o máximo de dias de coleta por agencia
  ## Fix: recolocar com i,j,t
  if(any(is.finite(agencias_t$dias_coleta_agencia_max))) {
    model <- model|>
      # constraint com número máximo de UCs por agência
      add_constraint(sum_over(x[i, j]*dias_coleta_ijt_mat[i,j], i = 1:n) <= agencias_t$dias_coleta_agencia_max[j], j = 1:m)
  }
  if (any(is.finite({diarias_entrevistador_max}))) {
    model <- model|>
      add_constraint(sum_over(x[i, j]*diarias_i_j[i,j], i = 1:n) <= (diarias_entrevistador_max*w[j]), j = 1:m)
  }
  # Solve the model using solver
  if ({solver}=="symphony") {
    log <- utils::capture.output(result <- ompr::solve_model(model, ompr.roi::with_ROI(solver = {solver}, max_time=as.numeric({max_time}), gap_limit={rel_tol}*100, ...)))
  } else {
    log <- utils::capture.output(result <- ompr::solve_model(model, ompr.roi::with_ROI(solver = {solver}, max_time=as.numeric({max_time}), rel_tol={rel_tol}, ...)))
  }
  if ({solver}=="symphony") {## acrescentar highs aqui
    if (result$additional_solver_output$ROI$status$msg$code%in%c(231L, 232L)) result$status <- result$additional_solver_output$ROI$status$msg$message
  }
  stopifnot(result$status != "error")
  # Extract the solution
  #browser()
  dist_uc_agencias <- dist_uc_agencias|>
    dplyr::select(-custo_deslocamento_com_troca, -t)
  matching <- result |>
    ompr::get_solution(x[i, j]) |>
    dplyr::filter(value > .9) |>
    dplyr::select(i, j)
  workers <- result |>
    ompr::get_solution(w[j]) |>
    dplyr::filter(value > .9) |>
    dplyr::select(j, entrevistadores=value)
  resultado_i_otimo <- matching|>
    dplyr::left_join(dist_uc_agencias|>select(-agencia_codigo_jurisdicao), by=c('i', 'j'))|>
    dplyr::select(-j)
  resultado_i_jurisdicao <- dist_uc_agencias|>
    dplyr::filter(agencia_codigo_jurisdicao==agencia_codigo)|>
    dplyr::select(-agencia_codigo_jurisdicao, -j, -custo_troca_jurisdicao)
  ags_group_vars <- c(names(agencias_t),  'entrevistadores')
  if(!all(resultado_i_jurisdicao$i%in%(resultado_i_otimo$i))) stop("Solução não encontrada!")
  resultado_agencias_otimo <- agencias_t|>
    dplyr::inner_join(resultado_i_otimo, by = c('agencia_codigo'))|>
    dplyr::left_join(ucs_i|>dplyr::select(uc, agencia_codigo_jurisdicao), by = c('uc'))|>
    dplyr::group_by(pick(any_of(ags_group_vars)))|>
    dplyr::summarise(dplyr::across(where(is.numeric), sum), n_ucs=dplyr::n_distinct(uc, na.rm=TRUE), n_trocas_jurisdicao=sum(agencia_codigo!=agencia_codigo_jurisdicao))|>
    dplyr::ungroup()|>
    dplyr::left_join(workers, by=c('j'))|>
    dplyr::select(-j)|>
    dplyr::mutate(custo_total_entrevistadores=entrevistadores*{remuneracao_entrevistador}+entrevistadores*custo_treinamento_por_entrevistador)
  resultado_agencias_jurisdicao <- agencias_t|>
    dplyr::inner_join(resultado_i_jurisdicao, by = c('agencia_codigo'))|>
    dplyr::group_by(pick(any_of(ags_group_vars)))|>
    dplyr::summarise(dplyr::across(where(is.numeric), sum),
                     n_ucs=dplyr::n_distinct(uc, na.rm=TRUE))|>
    dplyr::mutate(entrevistadores=pmax(
      ceiling(dias_coleta/dias_coleta_entrevistador_max),
      ceiling(total_diarias/diarias_entrevistador_max),
      n_entrevistadores_min),
      custo_total_entrevistadores=entrevistadores*{remuneracao_entrevistador}+entrevistadores*custo_treinamento_por_entrevistador)|>
    dplyr::ungroup()
  #browser()
  resultado <- list()
  resultado$resultado_i_otimo <- resultado_i_otimo
  resultado$resultado_i_jurisdicao <- resultado_i_jurisdicao
  resultado$resultado_agencias_otimo <- resultado_agencias_otimo
  resultado$resultado_agencias_jurisdicao <- resultado_agencias_jurisdicao
  attr(resultado, "solucao_status") <- result$additional_solver_output$ROI$status$msg$message
  # if (alocar_por!='uc') {
  #   resultado$resultado_i_otimo <- resultado$resultado_i_otimo |>
  #     dplyr::rename(!!rlang::sym(alocar_por) := uc)
  #   resultado$resultado_i_jurisdicao <- resultado$resultado_i_jurisdicao |>
  #     dplyr::rename(!!rlang::sym(alocar_por) := uc)
  # }
  if(resultado_completo) {
    resultado$ucs_agencias_todas <- dist_uc_agencias
    resultado$otimizacao <- result
  }
  resultado$log <- tail(log,100)
  resultado
}
