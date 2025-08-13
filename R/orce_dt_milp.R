#' Alocação Otimizada de Unidades de Coleta (UCs) a Agências usando data.table e MILP
#'
#' Esta função realiza a alocação otimizada de Unidades de Coleta (UCs) a agências, com o objetivo de minimizar os custos totais de deslocamento e operação, considerando múltiplos períodos de coleta. A alocação leva em consideração restrições de capacidade das agências (em número de dias de coleta por período), custos de deslocamento (combustível, tempo de viagem e diárias), custos fixos das agências e custos de treinamento. Quando `use_cache = TRUE`, os resultados são armazenados em cache no disco e reutilizados para entradas idênticas, o que pode acelerar significativamente cálculos repetidos. A função `limpar_cache_ucs` auxilia na limpeza desse cache em disco. A função procede utilizando apenas as colunas requeridas para o processamento.
#'
#' As distâncias são calculadas com idas e voltas separadas até as unidades de coleta. Ou seja, não são avaliados `roteiros` de coleta. Essa possibilidade será implementada em uma futura versão.
#'
#' @param ucs Um `data.table` ou `data.frame` contendo informações sobre as UCs, incluindo:
#' \itemize{
#'   \item `uc`: Código único da UC.
#'   \item `agencia_codigo`: Código da agência à qual a UC está atualmente alocada.
#'   \item `dias_coleta`: Número de dias de coleta na UC, por período.
#'   \item `viagens`: Número de viagens necessárias para a coleta na UC, por período.
#'   \item `data`: Um identificador único para o período de coleta (e.g., "2024-01", "2024-02").
#'   \item `diaria_valor`: Valor da diária para a UC.
#'   \item `alocar_por`: Uma coluna adicional para agrupar as UCs antes da alocação (e.g., "setor", "municipio").
#' }
#' @param agencias Um `data.table` ou `data.frame` contendo informações sobre as agências selecionáveis, incluindo:
#' \itemize{
#'   \item `agencia_codigo`: Código único da agência.
#'   \item `n_entrevistadores_agencia_max`: Número máximo de entrevistadores por agência. Junto com `dias_coleta_entrevistador_max`,
#'         determina o número máximo de dias de coleta que a agência pode realizar (n_entrevistadores_agencia_max * dias_coleta_entrevistador_max).
#'   \item `custo_fixo`: Custo fixo associado à agência (soma de todos os períodos).
#' }
#' @param alocar_por Uma string especificando como alocar as UCs: "uc" para alocar cada UC individualmente, ou o nome de uma coluna em `ucs` para agrupar as UCs antes da alocação (e.g., "setor", "municipio"). Padrão: "uc".
#' @param custo_litro_combustivel Custo do combustível por litro (em R$). Padrão: 6.
#' @param custo_hora_viagem Custo de cada hora de viagem (em R$). Padrão: 10.
#' @param kml Consumo médio de combustível do veículo (em km/l). Padrão: 10.
#' @param diarias_entrevistador_max Total máximo de diárias que um entrevistador pode receber, somando todos os períodos. Padrão: `Inf`.
#' @param remuneracao_entrevistador Remuneração total por entrevistador para todos os períodos. Padrão: 0.
#' @param n_entrevistadores_min Número mínimo de entrevistadores por agência. Padrão: 1.
#' @param dias_coleta_entrevistador_max Número máximo de dias de coleta por entrevistador por período.
#' @param dias_treinamento Número de dias/diárias para treinamento. Padrão: 0 (nenhum treinamento).
#' @param agencias_treinadas (Opcional) Um vetor de caracteres com os códigos das agências que já foram treinadas e não terão custo de treinamento. Padrão: NULL.
#' @param agencias_treinamento Código da(s) agência(s) onde o treinamento será realizado.
#' @param distancias_ucs Um `data.table` ou `data.frame` com as distâncias entre UCs e agências, incluindo:
#' \itemize{
#'   \item `uc`: Código da UC.
#'   \item `agencia_codigo`: Código da agência.
#'   \item `distancia_km`: Distância em quilômetros entre a UC e a agência.
#'   \item `duracao_horas`: Duração da viagem em horas entre a UC e a agência.
#'   \item `diaria_municipio`: Indica se é necessária uma diária para deslocamento entre a UC e a agência, considerando o município da UC.
#'   \item `diaria_pernoite`: Indica se é necessária uma diária com pernoite para deslocamento entre a UC e a agência.
#' }
#' @param distancias_ucs_ucs (Opcional) Um `data.table` ou `data.frame` com as distâncias diretas entre UCs para otimização de rotas TSP, incluindo:
#' \itemize{
#'   \item `uc_orig`: Código da UC de origem.
#'   \item `uc_dest`: Código da UC de destino.
#'   \item `distancia_km`: Distância em quilômetros entre as UCs.
#' }
#' @param distancias_agencias Um `data.table` ou `data.frame` com as distâncias entre as agências, incluindo:
#' \itemize{
#'   \item `agencia_codigo_orig`: Código da agência de origem.
#'   \item `agencia_codigo_dest`: Código da agência de destino.
#'   \item `distancia_km`: Distância em quilômetros entre a agência de origem e a de destino.
#'   \item `duracao_horas`: Duração da viagem em horas entre a agência de origem e a de destino.
#' }
#' @param peso_tsp Peso para balancear custos de roteamento: 0 = apenas round-trips, 1 = apenas TSP. Padrão: 0 (sem TSP).
#' @param adicional_troca_jurisdicao Custo adicional quando há troca de agência de coleta. Padrão: 0.
#' @param resultado_completo (Opcional) Um valor lógico indicando se deve ser retornado um resultado mais completo, incluindo informações sobre todas as combinações de UCs e agências. Padrão: FALSE.
#' @param solver Qual ferramenta para solução do modelo de otimização utilizar. Padrão: "cbc". Outras opções: "glpk", "symphony" (instalação manual).
#' @param rel_tol Tolerância relativa para a otimização. Valores menores levam a soluções mais precisas, mas podem aumentar o tempo de execução. Padrão: 0.005.
#' @param max_time Tempo máximo de execução (em segundos) permitido para o solver. Padrão: 30*60 (30 minutos).
#' @param use_cache Lógico indicando se deve usar resultados em cache. Quando TRUE,
#'   resultados para entradas idênticas serão recuperados do cache em disco em vez
#'   de recalcular. Isso pode acelerar cálculos repetidos mas usa espaço em disco.
#'   O padrão é TRUE.
#'
#' @param ... Opções adicionais para o solver.
#'
#' @return Uma lista contendo:
#' \itemize{
#'   \item `resultado_ucs_jurisdicao`: Um `data.table` com as UCs e suas alocações originais (jurisdição), incluindo custos de deslocamento.
#'   \item `resultado_agencias_jurisdicao`: Um `data.table` com as agências e suas alocações originais (jurisdição), incluindo custos fixos, custos de deslocamento e número de UCs alocadas.
#'   \item `resultado_ucs_otimo`: Um `data.table` com as UCs e suas alocações otimizadas, incluindo custos de deslocamento.
#'   \item `resultado_agencias_otimo`: Um `data.table` com as agências e suas alocações otimizadas, incluindo custos fixos, custos de deslocamento, número de UCs alocadas e número de entrevistadores.
#'   \item `rotas_tsp` (opcional): Um `data.table` com as rotas TSP otimizadas por agência e período, incluindo UCs de origem/destino, distâncias e durações (retornado apenas se `peso_tsp` > 0).
#'   \item `ucs_agencias_todas` (opcional): Um `data.table` com todas as combinações de UCs e agências, incluindo distâncias, custos e informações sobre diárias (retornado apenas se `resultado_completo` for TRUE).
#'   \item `otimizacao` (opcional): O resultado completo da otimização (retornado apenas se `resultado_completo` for TRUE).
#'   \item `log` (opcional): últimas 100 linhas do log de execução do solver.
#' }
#'
#' @importFrom data.table as.data.table setDT setorder setnames CJ uniqueN fifelse
#' @export
orce_dt_milp <- function(ucs,
                       agencias = data.frame(agencia_codigo = unique(ucs$agencia_codigo),
                                             n_entrevistadores_agencia_max = Inf,
                                             custo_fixo = 0,
                                             diaria_valor=diaria_valor_get(unique(ucs$agencia_codigo))),
                       alocar_por = "uc",
                       custo_litro_combustivel = 6,
                       custo_hora_viagem = 10,
                       kml = 10,
                       diarias_entrevistador_max = Inf,
                       remuneracao_entrevistador = 0,
                       n_entrevistadores_min = 1,
                       n_entrevistadores_tipo = "integer",
                       dias_coleta_entrevistador_max,
                       dias_treinamento = 0,
                       agencias_treinadas = NULL,
                       agencias_treinamento = NULL,
                       distancias_ucs,
                       distancias_ucs_ucs = NULL,
                       distancias_agencias = NULL,
                       peso_tsp = 0,
                       adicional_troca_jurisdicao = 0,
                       resultado_completo = FALSE,
                       solver = "cbc",
                       rel_tol = .005,
                       max_time = 30 * 60,
                       use_cache = TRUE,
                       use_milp = TRUE,
                       ...) {

  # List of all arguments to pass
  args <- list(
    ucs = ucs,
    agencias = agencias,
    alocar_por = alocar_por,
    custo_litro_combustivel = custo_litro_combustivel,
    custo_hora_viagem = custo_hora_viagem,
    kml = kml,
    diarias_entrevistador_max = diarias_entrevistador_max,
    remuneracao_entrevistador = remuneracao_entrevistador,
    n_entrevistadores_min = n_entrevistadores_min,
    n_entrevistadores_tipo = n_entrevistadores_tipo,
    dias_coleta_entrevistador_max = dias_coleta_entrevistador_max,
    dias_treinamento = dias_treinamento,
    agencias_treinadas = agencias_treinadas,
    agencias_treinamento = agencias_treinamento,
    distancias_ucs = distancias_ucs,
    distancias_ucs_ucs = distancias_ucs_ucs,
    distancias_agencias = distancias_agencias,
    peso_tsp = peso_tsp,
    adicional_troca_jurisdicao = adicional_troca_jurisdicao,
    resultado_completo = resultado_completo,
    solver = solver,
    rel_tol = rel_tol,
    max_time = max_time
  )

  # Add any additional arguments
  args <- c(args, list(...))

  if (use_cache) {
    # Verifica se existe cache para esses argumentos
    is_cached <- do.call(memoise::has_cache(orce_dt_milp_mem), args)

    if (is_cached) {
      cli::cli_alert_success("Usando resultado em cache para estes parâmetros.")
    } else {
      cli::cli_alert_info("Calculando e armazenando resultado em cache.")
    }
    do.call(orce_dt_milp_mem, args)
  } else {
    cli::cli_alert_info("Calculando sem usar cache.")
    do.call(.orce_dt_milp_impl, args)
  }
}

#' @keywords internal
.orce_dt_milp_impl <- function(ucs,
                             agencias,
                             alocar_por,
                             custo_litro_combustivel,
                             custo_hora_viagem,
                             kml,
                             diarias_entrevistador_max,
                             remuneracao_entrevistador,
                             n_entrevistadores_min,
                             n_entrevistadores_tipo,
                             dias_coleta_entrevistador_max,
                             dias_treinamento,
                             agencias_treinadas,
                             agencias_treinamento,
                             distancias_ucs,
                             distancias_ucs_ucs,
                             distancias_agencias,
                             peso_tsp,
                             adicional_troca_jurisdicao,
                             resultado_completo,
                             solver,
                             rel_tol,
                             max_time,
                             ...) {
  tictoc::tic.clearlog()
  tictoc::tic("Tempo total da otimização", log=TRUE)
  cli::cli_progress_step("Preparando os dados")

  # Importar pacotes necessários explicitamente
  requireNamespace("data.table")
  require("ompr")
  require("ompr.roi")
  require(paste0("ROI.plugin.", solver), character.only = TRUE)

  # Verificação dos Argumentos
  checkmate::assertTRUE(!anyDuplicated(agencias[['agencia_codigo']]))
  checkmate::assertTRUE(!anyDuplicated(ucs[['uc']]))
  checkmate::assert_number(custo_litro_combustivel, lower = 0)
  checkmate::assert_number(kml, lower = 0)
  checkmate::assert_number(rel_tol, lower = 0, upper = 1)
  checkmate::assert_number(dias_treinamento, lower = 0)
  checkmate::assert_character(agencias_treinamento, null.ok = dias_treinamento == 0)
  checkmate::assert_data_frame(distancias_agencias, null.ok = dias_treinamento == 0)
  checkmate::assert_number(dias_coleta_entrevistador_max, lower = 1)
  checkmate::assert_number(remuneracao_entrevistador, lower = 0)
  checkmate::assert_character(agencias_treinadas, null.ok = TRUE)
  checkmate::check_string(alocar_por, null.ok = FALSE)
  checkmate::assertTRUE(all(c('diaria_municipio', 'uc', 'diaria_pernoite') %in% names(distancias_ucs)))
  checkmate::assertTRUE(all(c('dias_coleta', 'viagens', 'data', 'diaria_valor') %in% names(ucs)))
  checkmate::assertTRUE(all(c('n_entrevistadores_agencia_max', 'custo_fixo', 'diaria_valor') %in% names(agencias)))

  stopifnot(alocar_por!="agencia_codigo")

  # TSP routing não é suportado com agregação
  if (alocar_por != "uc" && peso_tsp > 0) {
    cli::cli_abort("TSP routing (peso_tsp > 0) não é suportado com agregação.")
  }

  # Converter entradas para data.table sem mutar objetos do usuário
  ucs <- if (data.table::is.data.table(ucs)) data.table::copy(ucs) else data.table::as.data.table(ucs)
  agencias <- if (data.table::is.data.table(agencias)) data.table::copy(agencias) else data.table::as.data.table(agencias)
  distancias_ucs <- if (data.table::is.data.table(distancias_ucs)) data.table::copy(distancias_ucs) else data.table::as.data.table(distancias_ucs)
  if (!is.null(distancias_ucs_ucs)) {
    distancias_ucs_ucs <- if (data.table::is.data.table(distancias_ucs_ucs)) data.table::copy(distancias_ucs_ucs) else data.table::as.data.table(distancias_ucs_ucs)
  }
  if (!is.null(distancias_agencias)) {
    distancias_agencias <- if (data.table::is.data.table(distancias_agencias)) data.table::copy(distancias_agencias) else data.table::as.data.table(distancias_agencias)
  }

  # Pré-processamento dos dados
  required_cols <- c("uc", "agencia_codigo", "dias_coleta", "viagens", "data", "diaria_valor")
  if (alocar_por != "uc") {
    required_cols <- c(required_cols, alocar_por)
  }

  # Selecionar apenas as colunas necessárias
  ucs <- ucs[, required_cols, with=FALSE]
  distancias_ucs <- distancias_ucs[, list(uc, agencia_codigo, distancia_km, duracao_horas, diaria_municipio, diaria_pernoite)]

  if (!is.null(distancias_agencias)) {
    distancias_agencias <- distancias_agencias[, list(agencia_codigo_orig, agencia_codigo_dest, distancia_km, duracao_horas)]
  }

  # Remover geometria se existir e adicionar índice i
  if (inherits(ucs, "sf")) {
    ucs <- sf::st_drop_geometry(ucs)
  }

  # Agrupar por coluna indicada em alocar_por e criar índice i
  ucs[, i := .GRP, by = c(alocar_por)]
  n_ucs <- nrow(ucs)

  stopifnot(data.table::uniqueN(ucs$uc) == n_ucs)

  # Processar agências
  if (inherits(agencias, "sf")) {
    agencias <- sf::st_drop_geometry(agencias)
  }

  agencias <- agencias[, list(agencia_codigo, n_entrevistadores_agencia_max, custo_fixo)]
  agencias[, j := .I]

  stopifnot(data.table::uniqueN(agencias$agencia_codigo) == nrow(agencias))

  # Verificar se há duplicatas nas distâncias
  dcount <- distancias_ucs[, .N, by = list(agencia_codigo, uc)]
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
                         list(agencia_codigo_orig, agencia_codigo_dest, distancia_km, duracao_horas)],
      by.x = "agencia_codigo", by.y = "agencia_codigo_orig"
    )

    # Renomear para consistência
    data.table::setnames(agencias_t, "agencia_codigo_dest", "agencia_codigo_treinamento")

    # Pegar a agência de treinamento mais próxima para cada agência
    agencias_t <- agencias_t[order(distancia_km), .SD[1], by = agencia_codigo]

    # Renomear colunas de distância e duração
    data.table::setnames(agencias_t,
             c("distancia_km", "duracao_horas"),
             c("distancia_km_agencia_treinamento", "duracao_horas_agencia_treinamento_km"))

    # Ordenar por j
    data.table::setorder(agencias_t, j)
  } else {
    agencias_t <- data.table::copy(agencias)
    agencias_t[, `:=`(
      distancia_km_agencia_treinamento = NA_real_,
      duracao_horas_agencia_treinamento_km = NA_real_
    )]
  }

  # Calcular custo de treinamento
  if (dias_treinamento == 0) {
    agencias_t[, custo_treinamento_por_entrevistador := 0]
  } else {
    # Custos de treinamento com base na distância e se a agência já foi treinada
    agencias_t[, treinamento_com_diaria := !substr(agencia_codigo, 1, 7) %in% substr(agencias_treinamento, 1, 7)]

    agencias_t[, custo_treinamento_por_entrevistador := round(
      data.table::fifelse(treinamento_com_diaria, 2, dias_treinamento) *
        (distancia_km_agencia_treinamento / kml) *
        custo_litro_combustivel
    ) + diaria_valor * dias_treinamento * treinamento_com_diaria]

    # Zerar custo para agências já treinadas
    agencias_t[agencia_codigo %in% agencias_treinadas, custo_treinamento_por_entrevistador := 0]
  }

  # Criar índice para datas
  indice_t <- unique(ucs[, list(data)])
  data.table::setorder(indice_t, data)
  indice_t[, t := .I]

  # Combinar informações de UCs e datas
  ucs_i <- ucs[order(uc), list(i, data, uc, agencia_codigo_jurisdicao = agencia_codigo, dias_coleta, viagens, diaria_valor)]
  ucs_i <- merge(ucs_i, indice_t, by = "data")

  # Criar grid de agências e UCs usando CJ (cross join)
  ag_mun_grid <- data.table::CJ(
    agencia_codigo = agencias_t$agencia_codigo,
    i = ucs_i$i
  )

  # Adicionar informações de UCs ao grid
  ag_mun_grid <- merge(ag_mun_grid, ucs_i, by = "i", allow.cartesian = TRUE)

  # Combinar informações de distâncias com o grid
  distancias_ucs_1 <- merge(ag_mun_grid, distancias_ucs, by = c('uc', 'agencia_codigo'))
  distancias_ucs_1 <- distancias_ucs_1[, list(i, t, uc, agencia_codigo, agencia_codigo_jurisdicao,
                                          viagens, dias_coleta, distancia_km, duracao_horas,
                                          diaria_municipio, diaria_pernoite, diaria_valor)]

  # Ensure there are no missing values in distances
  stopifnot(sum(is.na(distancias_ucs_1$distancia_km)) == 0)
  stopifnot(nrow(distancias_ucs_1) == (nrow(ucs_i) * nrow(agencias_t)))

  # Compute transport costs
  dist_uc_agencias <- merge(distancias_ucs_1, agencias_t, by = "agencia_codigo")
  # sanity check: duplicated names after merge
  if (anyDuplicated(names(dist_uc_agencias))) {
    stop(sprintf(
      "duplicated columns in dist_uc_agencias: %s",
      paste(names(dist_uc_agencias)[duplicated(names(dist_uc_agencias))], collapse = ", ")
    ))
  }
  # sequential assignments to avoid referencing columns before creation
  dist_uc_agencias[, diaria := diaria_municipio]
  dist_uc_agencias[, diaria := data.table::fifelse(diaria_pernoite, TRUE, diaria)]
  dist_uc_agencias[, meia_diaria := (!diaria_pernoite) & diaria]
  # se com diaria inteira, define trechos
  dist_uc_agencias[, trechos := data.table::fifelse(diaria & (!meia_diaria), viagens * 2, dias_coleta * 2)]
  # compute total_diarias and dependent costs sequentially
  dist_uc_agencias[, total_diarias := data.table::fifelse(diaria, calcula_diarias_dt(dias_coleta, meia_diaria), 0)]
  dist_uc_agencias[, custo_diarias := total_diarias * diaria_valor]
  dist_uc_agencias[, distancia_total_km := trechos * distancia_km]
  dist_uc_agencias[, duracao_total_horas := trechos * duracao_horas]
  dist_uc_agencias[, custo_combustivel := (distancia_total_km / kml) * custo_litro_combustivel]
  dist_uc_agencias[, custo_horas_viagem := (trechos * duracao_horas) * custo_hora_viagem]
  dist_uc_agencias[, custo_troca_jurisdicao := data.table::fifelse(agencia_codigo != agencia_codigo_jurisdicao, adicional_troca_jurisdicao, 0)]
  dist_uc_agencias[, custo_deslocamento := custo_combustivel + custo_horas_viagem + custo_diarias]
  dist_uc_agencias[, custo_deslocamento_com_troca := custo_deslocamento + custo_troca_jurisdicao]

  # Agregar custos por i e j
  # aggregate numeric columns by i and j, excluding the key columns themselves
  numeric_cols <- names(dist_uc_agencias)[sapply(dist_uc_agencias, is.numeric)]
  numeric_cols <- setdiff(numeric_cols, c("i", "j"))
  dist_i_agencias <- dist_uc_agencias[, lapply(.SD, sum),
                                     by = list(i, j, agencia_codigo, agencia_codigo_jurisdicao),
                                     .SDcols = numeric_cols]
  if (anyDuplicated(names(dist_i_agencias))) {
    stop(sprintf(
      "duplicated columns in dist_i_agencias: %s",
      paste(names(dist_i_agencias)[duplicated(names(dist_i_agencias))], collapse = ", ")
    ))
  }
  dist_i_agencias[, n_ucs := .N, by = list(i, j, agencia_codigo, agencia_codigo_jurisdicao)]

  stopifnot(all(!is.na(dist_i_agencias$distancia_km)))

  # Verificar se há apenas um valor para cada par i,j
  u_dist_i_agencias <- dist_i_agencias[, .N, by = list(i, j)]
  stopifnot(all(u_dist_i_agencias$N == 1))

  # Função auxiliar para criar matriz de custos
  make_i_j_dt <- function(x, col) {
    result <- data.table::dcast(x, i ~ j, value.var = col)
    result[, i := NULL]
    as.matrix(result)
  }

  # Criar matrizes de custos separadas
  transport_cost_i_j <- make_i_j_dt(x = dist_i_agencias, col = "custo_deslocamento_com_troca")
  diarias_i_j <- make_i_j_dt(x = dist_i_agencias, col = "total_diarias")
  dias_coleta_i_j <- make_i_j_dt(x = dist_i_agencias, col = "dias_coleta")
  custo_combustivel_i_j <- make_i_j_dt(x = dist_i_agencias, col = "custo_combustivel")
  custo_horas_viagem_i_j <- make_i_j_dt(x = dist_i_agencias, col = "custo_horas_viagem")
  custo_diarias_i_j <- make_i_j_dt(x = dist_i_agencias, col = "custo_diarias")
  custo_troca_jurisdicao_i_j <- make_i_j_dt(x = dist_i_agencias, col = "custo_troca_jurisdicao")

  # Preparar dados para o modelo
  n_i <- nrow(ucs_i)
  n_j <- nrow(agencias_t)

  # Verificar se há UCs sem distâncias
  ucs_sem_distancias <- ucs_i[!i %in% unique(dist_i_agencias$i)]
  if (nrow(ucs_sem_distancias) > 0) {
    cli::cli_alert_warning("Existem UCs sem distâncias calculadas. Elas serão ignoradas.")
    cli::cli_alert_warning(paste("UCs sem distâncias:", paste(ucs_sem_distancias$uc, collapse = ", ")))
  }

  # Iniciar construção do modelo
  cli::cli_progress_step("Construindo o modelo de otimização")
  tictoc::tic("Construção do modelo", log = TRUE)

  # Usar MILPModel em vez de MIPModel
  model <- ompr::MILPModel() |>
    # Variável x_ij: 1 se a UC i é alocada para a agência j, 0 caso contrário
    ompr::add_variable(x[i, j], i = 1:n_i, j = 1:n_j, type = "binary") |>
    # Variável y_j: 1 se a agência j é utilizada, 0 caso contrário
    ompr::add_variable(y[j], j = 1:n_j, type = "binary") |>
    # Variável n_j: número de entrevistadores na agência j
    ompr::add_variable(n[j], j = 1:n_j, type = n_entrevistadores_tipo, lb = 0) |>
    # Restrição: cada UC deve ser alocada a exatamente uma agência
    ompr::add_constraint(sum_expr(x[i, j], j = 1:n_j) == 1, i = 1:n_i) |>
    # Restrição: se uma UC é alocada a uma agência, então a agência deve estar ativa
    ompr::add_constraint(x[i, j] <= y[j], i = 1:n_i, j = 1:n_j) |>
    # Restrição: número mínimo de entrevistadores por agência ativa
    ompr::add_constraint(n[j] >= n_entrevistadores_min * y[j], j = 1:n_j) |>
    # Restrição: número máximo de entrevistadores por agência
    ompr::add_constraint(n[j] <= agencias_t$n_entrevistadores_agencia_max[j], j = 1:n_j) |>
    # Restrição: dias de coleta por entrevistador não pode exceder o máximo
    ompr::add_constraint(
      sum_expr(dias_coleta_i_j[i, j] * x[i, j], i = 1:n_i) <= dias_coleta_entrevistador_max * n[j],
      j = 1:n_j
    ) |>
    # Restrição: diárias por entrevistador não pode exceder o máximo
    ompr::add_constraint(
      sum_expr(diarias_i_j[i, j] * x[i, j], i = 1:n_i) <= diarias_entrevistador_max * n[j],
      j = 1:n_j
    )

  # Adicionar variáveis e restrições para TSP se peso_tsp > 0
  if (peso_tsp > 0) {
    cli::cli_alert_info("Adicionando variáveis e restrições para TSP routing")

    # Verificar se distancias_ucs_ucs está disponível
    if (is.null(distancias_ucs_ucs)) {
      cli::cli_abort("Para usar TSP routing (peso_tsp > 0), é necessário fornecer distancias_ucs_ucs.")
    }

    # Preparar dados para TSP
    distancias_ucs_ucs <- distancias_ucs_ucs[, list(uc_orig, uc_dest, distancia_km)]

    # Adicionar índices i para origem e destino
    distancias_ucs_ucs <- merge(distancias_ucs_ucs,
                              ucs_i[, list(uc, i_orig = i)],
                              by.x = "uc_orig", by.y = "uc")

    distancias_ucs_ucs <- merge(distancias_ucs_ucs,
                              ucs_i[, list(uc, i_dest = i)],
                              by.x = "uc_dest", by.y = "uc")

    # Criar matriz de distâncias entre UCs
    dist_ucs_ucs <- data.table::dcast(distancias_ucs_ucs, i_orig ~ i_dest, value.var = "distancia_km")
    dist_ucs_ucs[, i_orig := NULL]
    dist_ucs_ucs_matrix <- as.matrix(dist_ucs_ucs)

    # Adicionar variáveis e restrições para TSP (ciclo fechado - closed TSP)
    model <- model |>
      # Variável u_ij: 1 se a UC i é visitada imediatamente após a UC j, 0 caso contrário
      ompr::add_variable(u[i, i_next],
                       i = 1:n_i,
                       i_next = 1:n_i,
                       type = "binary",
                       lb = 0,
                       ub = ifelse(i == i_next, 0, 1)) |>
      # Variável v_i: ordem de visita da UC i (para eliminar subciclos)
      ompr::add_variable(v[i], i = 1:n_i, type = "integer", lb = 1, ub = n_i) |>
      # Restrição: cada UC tem exatamente um sucessor (sai de cada cidade)
      ompr::add_constraint(sum_expr(u[i, i_next], i_next = 1:n_i) == 1, i = 1:n_i) |>
      # Restrição: cada UC tem exatamente um predecessor (entra em cada cidade)
      ompr::add_constraint(sum_expr(u[i_prev, i], i_prev = 1:n_i) == 1, i = 1:n_i) |>
      # Restrição: UCs alocadas a agências diferentes não podem ser conectadas
      ompr::add_constraint(
        u[i, i_next] <= sum_expr(x[i, j] * x[i_next, j], j = 1:n_j),
        i = 1:n_i, i_next = 1:n_i, i != i_next
      ) |>
      # Restrição: eliminação de subciclos (MTZ)
      ompr::add_constraint(v[i] >= 2, i = 2:n_i) |>
      ompr::add_constraint(
        v[i] - v[i_next] + 1 <= (n_i - 1) * (1 - u[i, i_next]),
        i = 2:n_i, i_next = 2:n_i, i != i_next
      )
  }

  # Definir função objetivo
  objective_expr <- sum_expr(
    # Custo de deslocamento
    transport_cost_i_j[i, j] * x[i, j], i = 1:n_i, j = 1:n_j
  ) +
  sum_expr(
    # Custo fixo das agências
    agencias_t$custo_fixo[j] * y[j], j = 1:n_j
  ) +
  sum_expr(
    # Custo de treinamento
    agencias_t$custo_treinamento_por_entrevistador[j] * n[j], j = 1:n_j
  ) +
  sum_expr(
    # Remuneração dos entrevistadores
    remuneracao_entrevistador * n[j], j = 1:n_j
  )

  # Adicionar custo de TSP se aplicável
  if (peso_tsp > 0) {
    tsp_cost_expr <- sum_expr(
      dist_ucs_ucs_matrix[i, i_next] * u[i, i_next],
      i = 1:n_i, i_next = 1:n_i, i != i_next
    )

    objective_expr <- objective_expr + peso_tsp * tsp_cost_expr
  }

  # Finalizar modelo com função objetivo
  model <- model |> ompr::set_objective(objective_expr, "min")

  tictoc::toc(log = TRUE)

  # Resolver o modelo
  cli::cli_progress_step("Resolvendo o modelo de otimização")
  tictoc::tic("Solução do modelo", log = TRUE)

  result <- ompr::solve_model(
    model,
    ompr.roi::with_ROI(solver = solver, verbosity = 1, gap_limit = rel_tol, time_limit = max_time)
  )

  tictoc::toc(log = TRUE)

  # Verificar se o modelo foi resolvido com sucesso
  if (result$status != "optimal" && result$status != "relaxed") {
    cli::cli_abort(paste("Falha ao resolver o modelo:", result$status))
  }

  # Extrair resultados
  cli::cli_progress_step("Extraindo resultados")

  # Extrair variáveis x_ij (alocação de UCs para agências)
  x_sol <- result |>
    ompr::get_solution(x[i, j]) |>
    data.table::as.data.table()
  data.table::setnames(x_sol, c("i", "j", "value"))

  # Filtrar apenas alocações positivas
  x_sol <- x_sol[value > 0.5]

  # Extrair variáveis y_j (agências utilizadas)
  y_sol <- result |>
    ompr::get_solution(y[j]) |>
    data.table::as.data.table()
  data.table::setnames(y_sol, c("j", "value"))

  # Filtrar apenas agências utilizadas
  y_sol <- y_sol[value > 0.5]

  # Extrair variáveis n_j (número de entrevistadores)
  n_sol <- result |>
    ompr::get_solution(n[j]) |>
    data.table::as.data.table()
  data.table::setnames(n_sol, c("j", "value"))

  # Arredondar número de entrevistadores para inteiro
  n_sol[, value := round(value)]

  # Extrair variáveis u_ij (rotas TSP) se aplicável
  if (peso_tsp > 0) {
    u_sol <- result |>
      ompr::get_solution(u[i, i_next]) |>
      data.table::as.data.table()
    data.table::setnames(u_sol, c("i", "i_next", "value"))

    # Filtrar apenas conexões positivas
    u_sol <- u_sol[value > 0.5]
  } else {
    u_sol <- NULL
  }

  # Combinar resultados com dados originais
  alocacao <- merge(x_sol, ucs_i[, list(i, uc)], by = "i")
  alocacao <- merge(alocacao, agencias_t[, list(j, agencia_codigo)], by = "j")

  # Adicionar informações de custos
  alocacao <- merge(alocacao, dist_i_agencias, by = c("i", "j"))

  # Adicionar número de entrevistadores
  agencias_result <- merge(y_sol, n_sol, by = "j")
  agencias_result <- merge(agencias_result, agencias_t, by = "j")
  data.table::setnames(agencias_result, c("value.x", "value.y"), c("utilizada", "n_entrevistadores"))

  # Calcular custos totais
  custo_total <- sum(alocacao$custo_deslocamento_com_troca) +
                sum(agencias_result$custo_fixo * agencias_result$utilizada) +
                sum(agencias_result$custo_treinamento_por_entrevistador * agencias_result$n_entrevistadores) +
                sum(remuneracao_entrevistador * agencias_result$n_entrevistadores)

  # Adicionar custo de TSP se aplicável
  if (peso_tsp > 0) {
    custo_tsp <- sum(u_sol$value * dist_ucs_ucs_matrix[cbind(u_sol$i, u_sol$i_next)])
    custo_total <- custo_total + peso_tsp * custo_tsp
  } else {
    custo_tsp <- 0
  }

  # Preparar resultado final
  resultado <- list(
    alocacao = alocacao,
    agencias = agencias_result,
    custo_total = custo_total,
    custo_deslocamento = sum(alocacao$custo_deslocamento),
    custo_troca_jurisdicao = sum(alocacao$custo_troca_jurisdicao),
    custo_fixo = sum(agencias_result$custo_fixo * agencias_result$utilizada),
    custo_treinamento = sum(agencias_result$custo_treinamento_por_entrevistador * agencias_result$n_entrevistadores),
    custo_remuneracao = sum(remuneracao_entrevistador * agencias_result$n_entrevistadores),
    custo_tsp = custo_tsp,
    n_entrevistadores = sum(agencias_result$n_entrevistadores),
    n_agencias = nrow(agencias_result),
    status = result$status,
    objective_value = result$objective_value,
    solver = solver,
    rel_tol = rel_tol,
    max_time = max_time
  )

  # Adicionar logs de tempo
  resultado$logs <- tictoc::tic.log(format = TRUE)
  tictoc::toc(log = TRUE)

  # Adicionar resultado completo se solicitado
  if (resultado_completo) {
    resultado$result_completo <- result
    if (peso_tsp > 0) {
      resultado$rotas_tsp <- u_sol
    }
  }

  cli::cli_progress_step("Finalizado")
  return(resultado)
}
