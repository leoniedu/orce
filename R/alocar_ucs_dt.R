#' Alocação Otimizada de Unidades de Coleta (UCs) a Agências
#'
#' Esta função (e sua versão memoizada `orce_mem`) realiza a alocação otimizada de Unidades de Coleta (UCs) a agências, com o objetivo de minimizar os custos totais de deslocamento e operação, considerando múltiplos períodos de coleta. A alocação leva em consideração restrições de capacidade das agências (em número de dias de coleta por período), custos de deslocamento (combustível, tempo de viagem e diárias), custos fixos das agências e custos de treinamento.
#'
#' @param ucs Um `tibble` ou `data.frame` contendo informações sobre as UCs, incluindo:
#' \itemize{
#'   \item `uc`: Código único da UC.
#'   \item `agencia_codigo`: Código da agência à qual a UC está atualmente alocada.
#'   \item `dias_coleta`: Número de dias de coleta na UC, por período.
#'   \item `viagens`: Número de viagens necessárias para a coleta na UC, por período.
#'   \item `data`: Um identificador único para o período de coleta (e.g., "2024-01", "2024-02").
#' }
#' @param agencias Um `tibble` ou `data.frame` contendo informações sobre as agências selecionáveis, incluindo:
#' \itemize{
#'   \item `agencia_codigo`: Código único da agência.
#'   \item `dias_coleta_agencia_max`: Número máximo de dias de coleta que a agência pode realizar (soma de todos os períodos).
#'   \item `custo_fixo`: Custo fixo associado à agência (soma de todos os períodos).
#' }
#' @param alocar_por Uma string especificando como alocar as UCs: "uc" para alocar cada UC individualmente, ou o nome de uma coluna em `ucs` para agrupar as UCs antes da alocação (e.g., "setor", "municipio"). Padrão: "uc".
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
#' @param rel_tol Tolerância relativa para a otimização. Valores menores levam a soluções mais precisas, mas podem aumentar o tempo de execução. Padrão: 0.005.
#' @param max_time Tempo máximo de execução (em segundos) permitido para o solver. Padrão: 30*60 (30 minutos).
#' @param ... Opções adicionais para o solver.
#'
#' @return Uma lista contendo:
#' \itemize{
#'   \item `resultado_ucs_jurisdicao`: Um `tibble` com as UCs e suas alocações originais (jurisdição), incluindo custos de deslocamento.
#'   \item `resultado_agencias_jurisdicao`: Um `tibble` com as agências e suas alocações originais (jurisdição), incluindo custos fixos, custos de deslocamento e número de UCs alocadas.
#'   \item `resultado_ucs_otimo`: Um `tibble` com as UCs e suas alocações otimizadas, incluindo custos de deslocamento.
#'   \item `resultado_agencias_otimo`: Um `tibble` com as agências e suas alocações otimizadas, incluindo custos fixos, custos de deslocamento, número de UCs alocadas e número de entrevistadores.
#'   \item `ucs_agencias_todas` (opcional): Um `tibble` com todas as combinações de UCs e agências, incluindo distâncias, custos e informações sobre diárias (retornado apenas se `resultado_completo` for TRUE).
#'   \item `otimizacao` (opcional): O resultado completo da otimização (retornado apenas se `resultado_completo` for TRUE).
#'   \item `log` (opcional): últimas 100 linhas do log de execução do solver.
#' }
#'
#' @details
#'  A função `orce_dt_mem` é a versão memoizada de `orce_dt`, com cache em disco.
#'  Como `orce` pode levar um tempo considerável para executar, a memoização
#'  evita o recálculo com os mesmos parâmetros, economizando tempo em execuções
#'  subsequentes com os mesmos dados de entrada.
#'
#' @export
orce_dt <- function(ucs,
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

  cli::cli_progress_step("Preparando os dados")
  # Importar pacotes necessários explicitamente
  require("data.table")
  #require("ompr")
  #require("ompr.roi")
  #require(paste0("ROI.plugin.", solver), character.only = TRUE)
  # Verificação dos Argumentos
  checkmate::assertTRUE(!anyDuplicated(agencias[['agencia_codigo']]))
  checkmate::assertTRUE(!anyDuplicated(ucs[['uc']]))
  checkmate::assert_number(custo_litro_combustivel, lower = 0)
  checkmate::assert_number(kml, lower = 0)
  checkmate::assert_number(valor_diaria, lower = 0)
  checkmate::assert_number(rel_tol, lower = 0, upper = 1)
  checkmate::assert_number(dias_treinamento, lower = 0)
  checkmate::assert_character(agencias_treinamento, null.ok = dias_treinamento == 0)
  checkmate::assert_data_frame(distancias_agencias, null.ok = dias_treinamento == 0)
  checkmate::assert_number(dias_coleta_entrevistador_max, lower = 1)
  checkmate::assert_number(remuneracao_entrevistador, lower = 0)
  checkmate::assert_character(agencias_treinadas, null.ok = TRUE)
  checkmate::check_string(alocar_por, null.ok = FALSE)
  checkmate::assertTRUE(all(c('diaria_municipio', 'uc', 'diaria_pernoite') %in% names(distancias_ucs)))
  checkmate::assertTRUE(all(c('dias_coleta', 'viagens', 'data') %in% names(ucs)))
  checkmate::assertTRUE(all(c('dias_coleta_agencia_max', 'custo_fixo') %in% names(agencias)))
  stopifnot(alocar_por!="agencia_codigo")
  # Converter dataframes para data.tables
  #setDT(ucs)
  #setDT(agencias)
  #setDT(distancias_ucs)
  if (!is.null(distancias_agencias)) setDT(distancias_agencias)

  # Pré-processamento dos dados
  ucs[, i := .GRP, by = alocar_por]
  n_ucs <- nrow(ucs)

  stopifnot(uniqueN(ucs$uc) == n_ucs)

  agencias <- agencias[, .(agencia_codigo, dias_coleta_agencia_max, custo_fixo)]
  agencias[, j := .I]

  stopifnot(uniqueN(agencias$agencia_codigo) == nrow(agencias))

  dcount <- distancias_ucs[, .N, by = .(agencia_codigo, uc)]
  stopifnot(all(dcount$N == 1))

  if (alocar_por != "uc") {
    if (!alocar_por %in% names(ucs)) {
      stop(paste("alocar_por:", alocar_por, "não encontrado nos dados: ucs"))
    }
    # Ajustar distancias_ucs para a nova agregação
    distancias_ucs <- merge(distancias_ucs, ucs[, c("uc", alocar_por), with = FALSE], by = "uc")
  }

  # Selecionar agência de treinamento mais próxima das agências de coleta
  if (dias_treinamento > 0) {
    agencias_t <- merge(
      agencias,
      distancias_agencias[agencia_codigo_dest %in% agencias_treinamento,
                          .(agencia_codigo_orig, agencia_codigo_treinamento = agencia_codigo_dest, distancia_km, duracao_horas)],
      by.x = "agencia_codigo", by.y = "agencia_codigo_orig"
    )
    agencias_t <- agencias_t[order(distancia_km), .SD[1], by = agencia_codigo]
    setnames(agencias_t, c("distancia_km", "duracao_horas"), c("distancia_km_agencia_treinamento", "duracao_horas_agencia_treinamento_km"))
    agencias_t <- agencias_t[order(j)]
  } else {
    agencias_t <- agencias[, `:=`(distancia_km_agencia_treinamento = NA_real_,
                                  duracao_horas_agencia_treinamento_km = NA_real_)]
  }

  # Calcular custo de treinamento
  if (dias_treinamento == 0) {
    custo_treinamento <- rep(0, nrow(agencias_t))
  } else {
    # Custos de treinamento com base na distância e se a agência já foi treinada
    agencias_t[, treinamento_com_diaria := !substr(agencia_codigo, 1, 7) %in% substr(agencias_treinamento, 1, 7)]
    agencias_t[, custo_treinamento_por_entrevistador := round(
      fifelse(treinamento_com_diaria, 2, dias_treinamento) *
        (distancia_km_agencia_treinamento / kml) *
        custo_litro_combustivel
    ) + valor_diaria * dias_treinamento * treinamento_com_diaria]
    agencias_t[agencia_codigo %in% agencias_treinadas, custo_treinamento_por_entrevistador := 0]
  }

  # Criar índice para datas
  indice_t <- ucs[, .(data)]
  indice_t <- unique(indice_t[order(data)])[, t := .I]

  # Combinar informações de UCs e datas
  ucs_i <- ucs[order(uc)][, .(i, data, uc, agencia_codigo_jurisdicao = agencia_codigo,
                              dias_coleta, viagens)]
  ucs_i <- merge(ucs_i, indice_t, by = "data")

  # Criar grid de agências e UCs
  ag_mun_grid <- CJ(
    municipio_codigo_agencia = substr(agencias_t$agencia_codigo, 1, 7),
    agencias_t$agencia_codigo,
    ucs_i$i,
    ucs_i$t,
    ucs_i$uc,
    ucs_i$agencia_codigo_jurisdicao,
    ucs_i$dias_coleta,
    ucs_i$viagens
  )
  setnames(ag_mun_grid, c("V2", "V3", "V4", "V5", "V6", "V7", "V8"), c("agencia_codigo", "i", "t", "uc", "agencia_codigo_jurisdicao", "dias_coleta", "viagens"))

  # Combinar informações de distâncias com o grid
  distancias_ucs_1 <- merge(ag_mun_grid, distancias_ucs, by = c('uc', 'agencia_codigo'))
  distancias_ucs_1 <- distancias_ucs_1[, .(i, t, uc, agencia_codigo, agencia_codigo_jurisdicao,
                                           viagens, dias_coleta, distancia_km, duracao_horas,
                                           diaria_municipio,
                                           diaria_pernoite)]

  # Ensure there are no missing values in distances
  stopifnot(sum(is.na(distancias_ucs_1$distancia_km)) == 0)
  stopifnot(nrow(distancias_ucs_1) == (nrow(ucs_i) * nrow(agencias_t)))

  # Compute transport costs
  dist_uc_agencias <- merge(distancias_ucs_1, agencias_t, by = "agencia_codigo")
  dist_uc_agencias[, `:=`(
    diaria = diaria_municipio,
    diaria = fifelse(diaria_pernoite, TRUE, diaria),
    meia_diaria = (!diaria_pernoite) & diaria,
    ## se com diaria inteira
    trechos = fifelse(diaria & (!meia_diaria),
                      # é uma ida e uma volta por viagem
                      viagens * 2,
                      # sem diária ou com meia diária
                      dias_coleta * 2
    ),
    total_diarias = fifelse(diaria, calcula_diarias(dias_coleta, meia_diaria), 0),
    custo_diarias = total_diarias * valor_diaria,
    distancia_total_km = trechos * distancia_km,
    duracao_total_horas = trechos * duracao_horas,
    custo_combustivel = ((distancia_total_km / kml) * custo_litro_combustivel),
    custo_horas_viagem = (trechos * duracao_horas) * custo_hora_viagem,
    custo_troca_jurisdicao = fifelse(agencia_codigo != agencia_codigo_jurisdicao, adicional_troca_jurisdicao, 0),
    custo_deslocamento = custo_combustivel + custo_horas_viagem + custo_diarias,
    custo_deslocamento_com_troca = custo_deslocamento + custo_troca_jurisdicao
  )]

  # Agregar custos por i e j
  dist_i_agencias <- dist_uc_agencias[, lapply(.SD, sum), by = .(i, j, agencia_codigo, agencia_codigo_jurisdicao), .SDcols = is.numeric]
  dist_i_agencias[, n_ucs := .N, by = .(i, j, agencia_codigo, agencia_codigo_jurisdicao)]

  stopifnot(all(!is.na(dist_i_agencias$distancia_km)))

  # Verificar se há apenas um valor para cada par i,j
  u_dist_i_agencias <- dist_i_agencias[, .N, by = .(i, j)]
  stopifnot(all(u_dist_i_agencias$N == 1))

  # Função auxiliar para criar matriz de custos (adaptada para data.table)
  make_i_j_dt <- function(x, col) {
    x <- dcast(x, i ~ j, value.var = col)
    x[, i := NULL]
    as.matrix(x)
  }

  # Criar matrizes de custos
  transport_cost_i_j <- make_i_j_dt(x = dist_i_agencias, col = "custo_deslocamento_com_troca")
  diarias_i_j <- make_i_j_dt(x = dist_i_agencias, col = "total_diarias")
  dias_coleta_i_j <- make_i_j_dt(x = dist_i_agencias, col = "dias_coleta")

  dias_coleta_ijt_df <- dist_uc_agencias[, .(dias_coleta = sum(dias_coleta, na.rm = TRUE)), by = .(i, j, t)]
  dias_coleta_ijt <- function(i, j, t) {
    x <- dias_coleta_ijt_df
    sum(x[(x$i == i) & (x$j == j) & (x$t == t), "dias_coleta"], na.rm = TRUE)
  }

  cli::cli_progress_step("Preparando a otimização")
  n <- max(ucs$i)
  m <- max(agencias_t$j)
  p <- max(indice_t$t)

  stopifnot((agencias_t$j) == (1:nrow(agencias_t)))

  model <- MIPModel() |>
    # 1 sse uc i vai para a agencia j
    add_variable(x[i, j], i = 1:n, j = 1:m, type = "binary") |>
    # 1 sse agencia j ativada
    add_variable(y[j], j = 1:m, type = "binary") |>
    # trabalhadores na agencia j
    add_variable(w[j], j = 1:m, type = "integer", lb = 0) |>
    # minimizar custos
    set_objective(
      sum_over(transport_cost_i_j[i, j] * x[i, j], i = 1:n, j = 1:m) +
        sum_over((agencias_t$custo_fixo[j]) * y[j] +
                   w[j] * ({remuneracao_entrevistador} + agencias_t$custo_treinamento_por_entrevistador[j]),
                 j = 1:m),
      "min"
    ) |>
    # toda UC precisa estar associada a uma agencia
    add_constraint(sum_over(x[i, j], j = 1:m) == 1, i = 1:n) |>
    # se uma UC está designada a uma agencia, a agencia tem que ficar ativa
    add_constraint(x[i, j] <= y[j], i = 1:n, j = 1:m) |>
    # se agencia está ativa, w tem que ser >= n_entrevistadores_min
    add_constraint((y[j] * {n_entrevistadores_min}) <= w[j], i = 1:n, j = 1:m) |>
    # w tem que ser suficiente para dar conta das ucs para todos os períodos
    add_constraint(sum_over(x[i, j] * dias_coleta_ijt(i, j, t), i = 1:n) <= (w[j]*dias_coleta_entrevistador_max), j = 1:m, t = 1:p)
  # Respeitar o máximo de dias de coleta por agencia
  if (any(is.finite(agencias_t$dias_coleta_agencia_max))) {
    model <- model |>
      add_constraint(sum_over(x[i, j] * dias_coleta_i_j[i, j], i = 1:n) <= agencias_t$dias_coleta_agencia_max[j], j = 1:m)
  }

  # Respeitar o máximo de diárias por entrevistador
  if (any(is.finite({diarias_entrevistador_max}))) {
    model <- model |>
      add_constraint(sum_over(x[i, j] * diarias_i_j[i, j], i = 1:n) <= (diarias_entrevistador_max *
                                                                          w[j]), j = 1:m)
  }

  cli::cli_progress_step("Otimizando...")

  # Resolver o modelo de otimização
  if ({solver} == "symphony") {
    log <- utils::capture.output(
      result <- ompr::solve_model(
        model,
        ompr.roi::with_ROI(solver = {solver},
                           max_time = as.numeric({max_time}),
                           gap_limit = {rel_tol} * 100, ...)
      )
    )
  } else {
    log <- utils::capture.output(
      result <- ompr::solve_model(
        model,
        ompr.roi::with_ROI(solver = {solver},
                           max_time = as.numeric({max_time}),
                           rel_tol = {rel_tol}, ...)
      )
    )
  }

  if ({solver} == "symphony") {
    if (result$additional_solver_output$ROI$status$msg$code %in% c(231L, 232L)) {
      result$status <- result$additional_solver_output$ROI$status$msg$message
    }
  }

  stopifnot(result$status != "error")
  cli::cli_progress_step("Otimização concluída")

  # Extrair a solução (adaptado para data.table)
  dist_i_agencias[, custo_deslocamento_com_troca := NULL]

  matching <- result %>%
    ompr::get_solution(x[i, j]) %>%
    .[value > .9, .(i, j)]

  workers <- result %>%
    ompr::get_solution(w[j]) %>%
    .[value > .9, .(j, entrevistadores = value)]

  # Criar resultados para alocação ótima
  resultado_ucs_otimo <- merge(dist_uc_agencias, matching, by = c("i", "j"))
  resultado_ucs_otimo <- merge(resultado_ucs_otimo, ucs[, c("i", alocar_por), with = FALSE], by = "i")
  resultado_ucs_otimo <- merge(resultado_ucs_otimo, indice_t, by = "t")
  resultado_ucs_otimo[, `:=`(i = NULL, j = NULL, t = NULL, custo_deslocamento_com_troca = NULL)]

  # Criar resultados para jurisdição
  resultado_ucs_jurisdicao <- dist_uc_agencias[agencia_codigo_jurisdicao == agencia_codigo]
  resultado_ucs_jurisdicao[, `:=`(agencia_codigo_jurisdicao = NULL, j = NULL, custo_troca_jurisdicao = NULL)]
  resultado_ucs_jurisdicao <- merge(resultado_ucs_jurisdicao, ucs[, c("i", alocar_por), with = FALSE], by = "i")
  resultado_ucs_jurisdicao <- merge(resultado_ucs_jurisdicao, indice_t, by = "t")
  resultado_ucs_jurisdicao[, `:=`(i = NULL, t = NULL)]

  ags_group_vars <- c(names(agencias_t), 'entrevistadores')

  if (!all(resultado_ucs_jurisdicao$uc %in% (resultado_ucs_otimo$uc))) stop("Solução não encontrada!")

  # Criar resultados para agências - alocação ótima
  resultado_agencias_otimo <- merge(agencias_t, resultado_ucs_otimo, by = c('agencia_codigo'))
  resultado_agencias_otimo <- resultado_agencias_otimo[, lapply(.SD, sum), by = ags_group_vars, .SDcols = is.numeric]
  resultado_agencias_otimo[, `:=`(n_trocas_jurisdicao = sum(agencia_codigo != agencia_codigo_jurisdicao), n_ucs = .N), by = ags_group_vars]
  resultado_agencias_otimo <- merge(resultado_agencias_otimo, workers, by = c('j'))
  resultado_agencias_otimo[, `:=`(j = NULL, custo_total_entrevistadores = entrevistadores * remuneracao_entrevistador + entrevistadores * custo_treinamento_por_entrevistador)]

  ## dias de coleta por período máximo  por agencia de jurisdicao
  dias_coleta_j <- ucs_i[, .(dias_coleta = sum(dias_coleta)), by = .(agencia_codigo = agencia_codigo_jurisdicao, data)]
  dias_coleta_j <- dias_coleta_j[order(-dias_coleta), .SD[1], by = agencia_codigo]
  dias_coleta_j <- dias_coleta_j[, .(agencia_codigo, dias_coleta_max_data = dias_coleta)]

  # Criar resultados para agências - jurisdição
  resultado_agencias_jurisdicao <- merge(agencias_t, resultado_ucs_jurisdicao, by = "agencia_codigo")
  resultado_agencias_jurisdicao[, `:=`(j = NULL, custo_deslocamento_com_troca = NULL)]
  resultado_agencias_jurisdicao <- resultado_agencias_jurisdicao[, lapply(.SD, sum), by = ags_group_vars, .SDcols = is.numeric]
  resultado_agencias_jurisdicao[, n_ucs := .N, by = ags_group_vars]
  resultado_agencias_jurisdicao <- merge(resultado_agencias_jurisdicao, dias_coleta_j, by = "agencia_codigo")
  resultado_agencias_jurisdicao[, `:=`(
    entrevistadores = pmax(
      ceiling(dias_coleta_max_data / dias_coleta_entrevistador_max),
      ceiling(total_diarias / diarias_entrevistador_max),
      n_entrevistadores_min
    ),
    custo_total_entrevistadores = entrevistadores * remuneracao_entrevistador + entrevistadores * custo_treinamento_por_entrevistador
  )]
  # Preparar resultados finais
  resultado <- list()
  resultado$resultado_ucs_otimo <- resultado_ucs_otimo
  resultado$resultado_ucs_jurisdicao <- resultado_ucs_jurisdicao
  resultado$resultado_agencias_otimo <- resultado_agencias_otimo
  resultado$resultado_agencias_jurisdicao <- resultado_agencias_jurisdicao
  attr(resultado, "solucao_status") <- result$additional_solver_output$ROI$status$msg$message
  attr(resultado, "valor") <- objective_value(result)
  if (resultado_completo) {
    resultado$ucs_agencias_todas <- dist_i_agencias
    resultado$otimizacao <- result
  }
  resultado$log <- tail(log, 100)
  cli::cli_progress_step("Sucesso")
  return(resultado)
}
