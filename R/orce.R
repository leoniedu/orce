#' Alocação Otimizada de Unidades de Coleta (UCs) a Agências
#'
#' Esta função realiza a alocação otimizada de Unidades de Coleta (UCs) a agências, com o objetivo de minimizar os custos totais de deslocamento e operação, considerando múltiplos períodos de coleta. A alocação leva em consideração restrições de capacidade das agências (em número de dias de coleta por período), custos de deslocamento (combustível, tempo de viagem e diárias), custos fixos das agências e custos de treinamento. Quando `use_cache = TRUE`, os resultados são armazenados em cache no disco e reutilizados para entradas idênticas, o que pode acelerar significativamente cálculos repetidos. A função `limpar_cache_ucs` auxilia na limpeza desse cache em disco. A função procede utilizando apenas as colunas requeridas para o processamento.
#'
#' As distâncias são calculadas com idas e voltas separadas até as unidades de coleta. Ou seja, não são avaliados `roteiros` de coleta. Essa possibilidade será implementada em uma futura versão.
#'
#' @param ucs Um `tibble` ou `data.frame` contendo informações sobre as UCs, incluindo:
#' \itemize{
#'   \item `uc`: Código único da UC.
#'   \item `agencia_codigo`: Código da agência à qual a UC está atualmente alocada.
#'   \item `dias_coleta`: Número de dias de coleta na UC, por período.
#'   \item `viagens`: Número de viagens necessárias para a coleta na UC, por período.
#'   \item `data`: Um identificador único para o período de coleta (e.g., "2024-01", "2024-02").
#'   \item `diaria_valor`: Valor da diária para a UC.
#'   \item `alocar_por`: Uma coluna adicional para agrupar as UCs antes da alocação (e.g., "setor", "municipio").
#' }
#' @param agencias Um `tibble` ou `data.frame` contendo informações sobre as agências selecionáveis, incluindo:
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
#' @param distancias_ucs Um `tibble` ou `data.frame` com as distâncias entre UCs e agências, incluindo:
#' \itemize{
#'   \item `uc`: Código da UC.
#'   \item `agencia_codigo`: Código da agência.
#'   \item `distancia_km`: Distância em quilômetros entre a UC e a agência.
#'   \item `duracao_horas`: Duração da viagem em horas entre a UC e a agência.
#'   \item `diaria_municipio`: Indica se é necessária uma diária para deslocamento entre a UC e a agência, considerando o município da UC.
#'   \item `diaria_pernoite`: Indica se é necessária uma diária com pernoite para deslocamento entre a UC e a agência.
#' }
#' @param distancias_ucs_ucs (Opcional) Um `tibble` ou `data.frame` com as distâncias diretas entre UCs para otimização de rotas TSP, incluindo:
#' \itemize{
#'   \item `uc_orig`: Código da UC de origem.
#'   \item `uc_dest`: Código da UC de destino.
#'   \item `distancia_km`: Distância em quilômetros entre as UCs.
#' }
#' @param distancias_agencias Um `tibble` ou `data.frame` com as distâncias entre as agências, incluindo:
#' \itemize{
#'   \item `agencia_codigo_orig`: Código da agência de origem.
#'   \item `agencia_codigo_dest`: Código da agência de destino.
#'   \item `distancia_km`: Distância em quilômetros entre a agência de origem e a de destino.
#'   \item `duracao_horas`: Duração da viagem em horas entre a agência de origem e a de destino.
#' }
#' @param peso_tsp Peso para balancear custos de roteamento: 0 = apenas round-trips, 1 = apenas TSP. Padrão: 0 (sem TSP).
#' @param distancia_tsp_min Distância mínima (em km) para aplicar TSP. UCs com distancia_km <= distancia_tsp_min usam custos round-trip puros, UCs com distancia_km > distancia_tsp_min usam roteamento TSP. Padrão: 0 (TSP aplicado a todas as UCs).
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
#'   \item `resultado_ucs_jurisdicao`: Um `tibble` com as UCs e suas alocações originais (jurisdição), incluindo custos de deslocamento.
#'   \item `resultado_agencias_jurisdicao`: Um `tibble` com as agências e suas alocações originais (jurisdição), incluindo custos fixos, custos de deslocamento e número de UCs alocadas.
#'   \item `resultado_ucs_otimo`: Um `tibble` com as UCs e suas alocações otimizadas, incluindo custos de deslocamento.
#'   \item `resultado_agencias_otimo`: Um `tibble` com as agências e suas alocações otimizadas, incluindo custos fixos, custos de deslocamento, número de UCs alocadas e número de entrevistadores.
#'   \item `rotas_tsp` (opcional): Um `tibble` com as rotas TSP otimizadas por agência e período, incluindo UCs de origem/destino, distâncias e durações (retornado apenas se `peso_tsp` > 0).
#'   \item `ucs_agencias_todas` (opcional): Um `tibble` com todas as combinações de UCs e agências, incluindo distâncias, custos e informações sobre diárias (retornado apenas se `resultado_completo` for TRUE).
#'   \item `otimizacao` (opcional): O resultado completo da otimização (retornado apenas se `resultado_completo` for TRUE).
#'   \item `log` (opcional): últimas 100 linhas do log de execução do solver.
#' }
#'
#' @export
orce <- function(ucs,
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
                       distancia_tsp_min = 0,
                       adicional_troca_jurisdicao = 0,
                       resultado_completo = FALSE,
                       solver = "cbc",
                       rel_tol = .005,
                       max_time = 30 * 60,
                       use_cache = TRUE,
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
    distancia_tsp_min = distancia_tsp_min,
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
    is_cached <- do.call(memoise::has_cache(orce_mem), args)

    if (is_cached) {
      cli::cli_alert_success("Usando resultado em cache para estes parâmetros.")
    } else {
      cli::cli_alert_info("Calculando e armazenando resultado em cache.")
    }
    do.call(orce_mem, args)
  } else {
    cli::cli_alert_info("Calculando sem usar cache.")
    do.call(.orce_impl, args)
  }
}


#' @keywords internal
.orce_impl <- function(ucs,
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
                             distancia_tsp_min,
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
  requireNamespace("dplyr")
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

  # Pré-processamento dos dados
  required_cols <- c("uc", "agencia_codigo", "dias_coleta", "viagens", "data", "diaria_valor")
  if (alocar_por != "uc") {
    required_cols <- c(required_cols, alocar_por)
  }
  ucs <- ucs |> dplyr::select(dplyr::all_of(required_cols))

  distancias_ucs <- distancias_ucs |> dplyr::select(uc, agencia_codigo, distancia_km, duracao_horas, diaria_municipio, diaria_pernoite)

  if (!is.null(distancias_agencias)) {
    distancias_agencias <- distancias_agencias |> dplyr::select(agencia_codigo_orig, agencia_codigo_dest, distancia_km, duracao_horas)
  }

  ucs <- ucs |>
    dplyr::ungroup() |>
    sf::st_drop_geometry() |>
    dplyr::mutate(i = vctrs::vec_group_id(!!rlang::sym(alocar_por)))
  n_ucs <- nrow(ucs)

  stopifnot(dplyr::n_distinct(ucs$uc) == n_ucs)

  agencias <- agencias |>
    dplyr::ungroup() |>
    sf::st_drop_geometry()|>
    dplyr::select(agencia_codigo, n_entrevistadores_agencia_max, custo_fixo) |>
    dplyr::mutate(j = 1:dplyr::n())

  stopifnot(dplyr::n_distinct(agencias$agencia_codigo) == nrow(agencias))
  distancias_ucs <- distancias_ucs |>
    dplyr::ungroup() |>
    sf::st_drop_geometry()

  dcount <- distancias_ucs |>
    dplyr::count(agencia_codigo, uc)

  stopifnot(all(dcount$n == 1))

  if (alocar_por != "uc") {
    if (!alocar_por %in% names(ucs)) {
      stop(paste("alocar_por:", alocar_por, "não encontrado nos dados: ucs"))
    }
    # Ajustar distancias_ucs para a nova agregação
    distancias_ucs <- distancias_ucs |>
      dplyr::left_join(ucs |> dplyr::select(dplyr::all_of(c("uc", alocar_por))), by = "uc")
  }

  # Selecionar agência de treinamento mais próxima das agências de coleta
  if (dias_treinamento > 0) {
    agencias_t <- agencias |>
      dplyr::left_join(
        distancias_agencias |>
          dplyr::select(agencia_codigo_orig, agencia_codigo_dest, distancia_km, duracao_horas) |>
          dplyr::filter(agencia_codigo_dest %in% agencias_treinamento) |>
          dplyr::rename(agencia_codigo_treinamento = agencia_codigo_dest),
        by = c("agencia_codigo" = "agencia_codigo_orig")
      ) |>
      dplyr::group_by(agencia_codigo) |>
      dplyr::arrange(distancia_km) |>
      dplyr::slice(1) |>
      dplyr::rename(
        distancia_km_agencia_treinamento = distancia_km,
        duracao_horas_agencia_treinamento_km = duracao_horas
      ) |>
      dplyr::ungroup() |>
      dplyr::arrange(j)
  } else {
    agencias_t <- agencias |>
      dplyr::mutate(distancia_km_agencia_treinamento = NA_real_,
                    duracao_horas_agencia_treinamento_km = NA_real_)
  }

  # Calcular custo de treinamento
  if (dias_treinamento == 0) {
    custo_treinamento <- rep(0, nrow(agencias_t))
  } else {
    # Custos de treinamento com base na distância e se a agência já foi treinada
    treinamento_com_diaria <- !substr(agencias_t$agencia_codigo, 1, 7) %in% substr(agencias_treinamento, 1, 7)
    custo_treinamento <- round(
      dplyr::if_else(treinamento_com_diaria, 2, dias_treinamento) *
        (agencias_t$distancia_km_agencia_treinamento / kml) *
        custo_litro_combustivel
    ) + agencias_t$diaria_valor * {{dias_treinamento}} * treinamento_com_diaria
    custo_treinamento[agencias_t$agencia_codigo %in% agencias_treinadas] <- 0
  }

  agencias_t$custo_treinamento_por_entrevistador <- custo_treinamento

  # Criar índice para datas
  indice_t <- ucs |>
    dplyr::ungroup() |>
    dplyr::distinct(data) |>
    dplyr::arrange(data) |>
    dplyr::mutate(t = 1:dplyr::n())

  # Combinar informações de UCs e datas
  ucs_i <- ucs |>
    dplyr::arrange(uc) |>
    dplyr::transmute(i, data, uc, agencia_codigo_jurisdicao = agencia_codigo,
                     dias_coleta, viagens, diaria_valor) |>
    dplyr::left_join(indice_t, by = "data")

  # Criar grid de agências e UCs
  ag_mun_grid <- tidyr::expand_grid(
    agencias_t |>
      dplyr::transmute(municipio_codigo_agencia = substr(agencia_codigo, 1, 7), agencia_codigo),
    ucs_i
  )

  # Combinar informações de distâncias com o grid
  distancias_ucs_1 <- ag_mun_grid |>
    dplyr::left_join(distancias_ucs, by = c('uc', 'agencia_codigo')) |>
    dplyr::select(i, t, uc, agencia_codigo, agencia_codigo_jurisdicao,
                  viagens, dias_coleta, distancia_km, duracao_horas,
                  diaria_municipio,
                  diaria_pernoite, diaria_valor)

  # Ensure there are no missing values in distances
  stopifnot(sum(is.na(distancias_ucs_1$distancia_km)) == 0)
  stopifnot(nrow(distancias_ucs_1) == (nrow(ucs_i) * nrow(agencias_t)))

  # Compute transport costs
  dist_uc_agencias <- distancias_ucs_1 |>
    dplyr::left_join(agencias_t, by = "agencia_codigo") |>
    dplyr::transmute(
      i, t, uc,
      j, agencia_codigo,
      agencia_codigo_jurisdicao,
      distancia_km, duracao_horas, dias_coleta,
      # Classify UCs as close or far based on distance threshold
      uc_proxima = distancia_km <= distancia_tsp_min,
      diaria = diaria_municipio,
      diaria = dplyr::if_else(diaria_pernoite, TRUE, diaria),
      meia_diaria = (!diaria_pernoite) & diaria,
      ## se com diaria inteira
      trechos = dplyr::if_else(diaria & (!meia_diaria),
                               # é uma ida e uma volta por viagem
                               viagens * 2,
                               # sem diária ou com meia diária
                               dias_coleta * 2
      ),
      total_diarias = dplyr::if_else(diaria, calcula_diarias(dias_coleta, meia_diaria), 0),
      custo_diarias = total_diarias * diaria_valor,
      distancia_total_km = trechos * distancia_km,
      duracao_total_horas = trechos * duracao_horas,
      custo_combustivel = ((distancia_total_km / kml) * custo_litro_combustivel),
      custo_horas_viagem = (trechos * duracao_horas) * custo_hora_viagem,
      custo_troca_jurisdicao = dplyr::if_else(agencia_codigo != agencia_codigo_jurisdicao, adicional_troca_jurisdicao, 0),
      custo_deslocamento = custo_combustivel + custo_horas_viagem + custo_diarias,
      custo_deslocamento_com_troca = custo_deslocamento + custo_troca_jurisdicao
    )

  # Agregar custos por i e j
  dist_i_agencias <- dist_uc_agencias |>
    dplyr::select(-t) |>
    dplyr::group_by(i, j, agencia_codigo, agencia_codigo_jurisdicao) |>
    dplyr::summarise(dplyr::across(dplyr::where(is.numeric), sum),
                     # Keep track of whether this is a close UC (all UCs in group must be close)
                     todas_ucs_proximas = all(uc_proxima),
                     n_ucs = dplyr::n()) |>
    dplyr::ungroup()

  stopifnot(all(!is.na(dist_i_agencias$distancia_km)))

  # Verificar se há apenas um valor para cada par i,j
  u_dist_i_agencias <- dist_i_agencias |>
    dplyr::ungroup() |>
    dplyr::count(i, j)

  stopifnot(all(u_dist_i_agencias$n == 1))

  # Função auxiliar para criar matriz de custos
  make_i_j <- function(x, col) {
    x |>
      dplyr::ungroup() |>
      dplyr::select(dplyr::all_of(c("i", "j", col)))|>
      tidyr::pivot_wider(id_cols = i, names_from = j, values_from = dplyr::all_of(col), names_sort = TRUE)|>
      dplyr::arrange(as.numeric(i)) |>
      dplyr::select(-i) |>
      as.matrix()
  }
  # Criar matrizes de custos separadas
  transport_cost_i_j <- make_i_j(x = dist_i_agencias, col = "custo_deslocamento_com_troca")
  diarias_i_j <- make_i_j(x = dist_i_agencias, col = "total_diarias")
  dias_coleta_i_j <- make_i_j(x = dist_i_agencias, col = "dias_coleta")
  custo_combustivel_i_j <- make_i_j(x = dist_i_agencias, col = "custo_combustivel")
  custo_horas_viagem_i_j <- make_i_j(x = dist_i_agencias, col = "custo_horas_viagem")
  custo_diarias_i_j <- make_i_j(x = dist_i_agencias, col = "custo_diarias")
  custo_troca_jurisdicao_i_j <- make_i_j(x = dist_i_agencias, col = "custo_troca_jurisdicao")

  dias_coleta_ijt_df <- dist_uc_agencias|>
    dplyr::group_by(i,j,t)|>
    dplyr::summarise(dias_coleta=sum(dias_coleta, na.rm=TRUE))
  dias_coleta_ijt <- function(i,j,t) {
    x <- dias_coleta_ijt_df
    sum(x[(x$i==i)& (x$j==j) &(x$t==t),"dias_coleta"], na.rm=TRUE)
  }
  cli::cli_progress_step("Preparando a otimização")
  # Criar modelo de otimização
  n <- max(ucs$i)
  m <- max(agencias_t$j)
  p <- max(indice_t$t)

  # Criar indicador ti: 1 se UC i pertence ao período t, 0 caso contrário
  ti <- matrix(0, nrow = n, ncol = p)
  for(i in 1:n) {
    t_for_uc_i <- ucs_i$t[ucs_i$i == i][1]
    if (!is.na(t_for_uc_i)) {
      ti[i, t_for_uc_i] <- 1
    }
  }

  stopifnot((agencias_t$j) == (1:nrow(agencias_t)))
  # Criar matrizes de distâncias e durações UC-UC para TSP (somente se peso_tsp > 0)
  if (peso_tsp > 0 && !is.null(distancias_ucs_ucs)) {
    dist_uc_uc <- matrix(0, nrow = n, ncol = n)
    duracao_uc_uc <- matrix(0, nrow = n, ncol = n)
    for (i in 1:n) {
      for (k in 1:n) {
        if (i != k) {
          uc_i <- ucs_i$uc[ucs_i$i == i][1]
          uc_k <- ucs_i$uc[ucs_i$i == k][1]

          dist_ik <- distancias_ucs_ucs |>
            dplyr::filter(uc_orig == uc_i, uc_dest == uc_k)

          if (nrow(dist_ik) > 0) {
            dist_uc_uc[i, k] <- dist_ik$distancia_km[1]
            duracao_uc_uc[i, k] <- dist_ik$duracao_horas[1]
          } else {
            dist_uc_uc[i, k] <- Inf
            duracao_uc_uc[i, k] <- Inf
          }
        }
      }
    }
  } else {
    dist_uc_uc <- matrix(0, nrow = n, ncol = n)
    duracao_uc_uc <- matrix(0, nrow = n, ncol = n)
  }

  model <- ompr::MIPModel() |>
    # 1 sse uc i vai para a agencia j
    ompr::add_variable(x[i, j], i = 1:n, j = 1:m, type = "binary") |>
    # 1 sse agencia j ativada
    ompr::add_variable(y[j], j = 1:m, type = "binary") |>
    # trabalhadores na agencia j
    ompr::add_variable(w[j], j = 1:m, type = n_entrevistadores_tipo, lb = 0, ub=Inf)

  # Create matrix to identify far UCs (eligible for TSP)
  uc_distante_ij <- matrix(FALSE, nrow = n, ncol = m)
  for(i in 1:n) {
    for(j in 1:m) {
      uc_info <- dist_i_agencias |> dplyr::filter(i == !!i, j == !!j)
      if(nrow(uc_info) > 0) {
        uc_distante_ij[i, j] <- !uc_info$todas_ucs_proximas[1]
      }
    }
  }

  # Adicionar variáveis TSP somente se peso_tsp > 0
  if (peso_tsp > 0) {
    model <- model |>
      # TSP routing: 1 sse rota vai de uc i para uc k dentro da agencia j no período t
      ompr::add_variable(route[i, k, j, t], i = 1:n, k = 1:n, j = 1:m, t = 1:p, type = "binary") |>
      # TSP subtour elimination auxiliar por período
      ompr::add_variable(u[i, j, t], i = 1:n, j = 1:m, t = 1:p, type = "continuous", lb = 1, ub = n)
  }

  # Create cost matrices that properly handle close vs far UCs
  transport_cost_close_ij <- matrix(0, nrow = n, ncol = m)
  transport_cost_far_ij <- matrix(0, nrow = n, ncol = m)

  # Fill the matrices properly based on UC proximity
  for(i in 1:n) {
    for(j in 1:m) {
      uc_info <- dist_i_agencias |> dplyr::filter(i == !!i, j == !!j)
      if(nrow(uc_info) > 0) {
        cost_value <- uc_info$custo_deslocamento_com_troca[1]
        if(is.na(cost_value)) cost_value <- 0

        if(uc_info$todas_ucs_proximas[1]) {
          # Close UC - gets full cost in close matrix
          transport_cost_close_ij[i, j] <- cost_value
          transport_cost_far_ij[i, j] <- 0
        } else {
          # Far UC - gets full cost in far matrix
          transport_cost_close_ij[i, j] <- 0
          transport_cost_far_ij[i, j] <- cost_value
        }
      }
    }
  }

  # Create TSP cost matrices that are zero for close UCs
  dist_uc_uc_tsp <- dist_uc_uc
  custo_combustivel_tsp_ij <- custo_combustivel_i_j
  custo_horas_viagem_tsp_ij <- custo_horas_viagem_i_j

  # Zero out costs for close UCs in TSP calculations
  for(i in 1:n) {
    for(j in 1:m) {
      if(uc_distante_ij[i, j] == FALSE) {  # UC is close
        custo_combustivel_tsp_ij[i, j] <- 0
        custo_horas_viagem_tsp_ij[i, j] <- 0
        # Zero out UC-UC distances from/to close UCs
        dist_uc_uc_tsp[i, ] <- 0
        dist_uc_uc_tsp[, i] <- 0
      }
    }
  }

  # Definir objetivo condicionalmente
  if (peso_tsp > 0) {
    model <- model |>
      # minimizar custos com blend de round-trip e TSP
      ompr::set_objective(
        # Custos para UCs próximas (sempre round-trip completo)
        ompr::sum_over(transport_cost_close_ij[i, j] * x[i, j], i = 1:n, j = 1:m) +
        # Custos para UCs distantes com ponderação TSP
        ompr::sum_over((1 - peso_tsp) * transport_cost_far_ij[i, j] * x[i, j], i = 1:n, j = 1:m) +
        # Custos de roteamento TSP por período (peso peso_tsp) - apenas para UCs distantes
        ompr::sum_over(peso_tsp * (dist_uc_uc_tsp[i, k] / kml * custo_litro_combustivel +
                                  duracao_uc_uc[i, k] * custo_hora_viagem) *
                       dias_coleta_ijt(i, j, t) * 2 * route[i, k, j, t], i = 1:n, k = 1:n, j = 1:m, t = 1:p) +
        # Custos TSP: agência para UC e UC para agência (uma vez por UC no período) - apenas UCs distantes
        ompr::sum_over(peso_tsp * (custo_combustivel_tsp_ij[i, j] + custo_horas_viagem_tsp_ij[i, j]) *
                       x[i, j] * ti[i, t], i = 1:n, j = 1:m, t = 1:p) +
        # Custos fixos e entrevistadores
        ompr::sum_over((agencias_t$custo_fixo[j]) * y[j] +
                     w[j] * ({remuneracao_entrevistador} + agencias_t$custo_treinamento_por_entrevistador[j]),
                   j = 1:m),
        "min"
      )
  } else {
    model <- model |>
      # minimizar custos sem TSP
      ompr::set_objective(
        # Custos não-ponderados (diárias e troca de jurisdição) - sempre presentes
        ompr::sum_over((custo_diarias_i_j[i, j] + custo_troca_jurisdicao_i_j[i, j]) * x[i, j], i = 1:n, j = 1:m) +
        # Custos de combustível e tempo - round-trip completo
        ompr::sum_over((custo_combustivel_i_j[i, j] + custo_horas_viagem_i_j[i, j]) * x[i, j], i = 1:n, j = 1:m) +
        # Custos fixos e entrevistadores
        ompr::sum_over((agencias_t$custo_fixo[j]) * y[j] +
                     w[j] * ({remuneracao_entrevistador} + agencias_t$custo_treinamento_por_entrevistador[j]),
                   j = 1:m),
        "min"
      )
  }

  model <- model |>
    # toda UC precisa estar associada a uma agencia
    ompr::add_constraint(ompr::sum_over(x[i, j], j = 1:m) == 1, i = 1:n) |>
    # se uma UC está designada a uma agencia, a agencia tem que ficar ativa
    ompr::add_constraint(x[i, j] <= y[j], i = 1:n, j = 1:m) |>
    # se agencia está ativa, w tem que ser >= n_entrevistadores_min
    ompr::add_constraint((y[j] * {n_entrevistadores_min}) <= w[j], j = 1:m) |>
    # w tem que ser suficiente para dar conta das ucs para todos os períodos
    ompr::add_constraint(ompr::sum_over(x[i, j] * dias_coleta_ijt(i, j, t), i = 1:n) <= (w[j]*dias_coleta_entrevistador_max), j = 1:m, t = 1:p)

  # Adicionar constraints TSP somente se peso_tsp > 0
  if (peso_tsp > 0) {
    model <- model |>
      # TSP constraints: route só existe se ambas UCs estão na mesma agência e mesmo período
      ompr::add_constraint(route[i, k, j, t] <= (x[i, j] * ti[i, t]), i = 1:n, k = 1:n, j = 1:m, t = 1:p) |>
      ompr::add_constraint(route[i, k, j, t] <= (x[k, j] * ti[k, t]), i = 1:n, k = 1:n, j = 1:m, t = 1:p) |>
      # TSP: cada UC sai para no máximo uma outra UC na mesma agência por período
      ompr::add_constraint(ompr::sum_over(route[i, k, j, t], k = 1:n) <= x[i, j] * ti[i, t], i = 1:n, j = 1:m, t = 1:p) |>
      # TSP: cada UC recebe de no máximo uma outra UC na mesma agência por período
      ompr::add_constraint(ompr::sum_over(route[i, k, j, t], i = 1:n) <= x[k, j] * ti[k, t], k = 1:n, j = 1:m, t = 1:p) |>
      # TSP: se há múltiplas UCs, deve haver pelo menos (n_ucs - 1) conexões por agência/período
      ompr::add_constraint(ompr::sum_over(route[i, k, j, t], i = 1:n, k = 1:n) >=
                          ompr::sum_over(x[i, j] * ti[i, t], i = 1:n) - 1, j = 1:m, t = 1:p) |>
      # TSP: subtour elimination (Miller-Tucker-Zemlin) por período
      ompr::add_constraint(u[i, j, t] - u[k, j, t] + n * route[i, k, j, t] <= n - 1, i = 1:n, k = 1:n, j = 1:m, t = 1:p)

    # Add explicit constraints to prevent routes involving close UCs
    for(i in 1:n) {
      for(j in 1:m) {
        if(uc_distante_ij[i, j] == FALSE) {  # UC i is close to agency j
          for(t in 1:p) {
            model <- model |>
              # Close UCs cannot be part of any route
              ompr::add_constraint(ompr::sum_over(route[i, k, j, t], k = 1:n) == 0) |>
              ompr::add_constraint(ompr::sum_over(route[k, i, j, t], k = 1:n) == 0)
          }
        }
      }
    }
  }
  # Respeitar o máximo de entrevistadores por agencia
  if (any(is.finite(agencias_t$n_entrevistadores_agencia_max))) {
    model <- model |>
      ompr::add_constraint(w[j] <= agencias_t$n_entrevistadores_agencia_max[j], j = 1:m)
  }
  # Respeitar o máximo de diárias por entrevistador
  if (any(is.finite({diarias_entrevistador_max}))) {
    model <- model |>
      ompr::add_constraint(ompr::sum_over(x[i, j] * diarias_i_j[i, j], i = 1:n) <= (diarias_entrevistador_max *
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

  # Extrair a solução
  dist_i_agencias <- dist_i_agencias |> dplyr::select(-custo_deslocamento_com_troca)

  matching <- result |>
    ompr::get_solution(x[i, j]) |>
    dplyr::filter(value > .9) |>
    dplyr::select(i, j)

  workers <- result |>
    ompr::get_solution(w[j]) |>
    dplyr::filter(value > .9) |>
    dplyr::select(j, entrevistadores = value)

  resultado <- list()

  # Extrair rotas TSP se peso_tsp > 0
  if (peso_tsp > 0) {
    # Obter segmentos de rota ativos
    segmentos_rota <- result |>
      ompr::get_solution(route[i, k, j, t]) |>
      dplyr::filter(value > .9) |>
      dplyr::left_join(ucs_i |> dplyr::select(i, uc_orig = uc), by = "i") |>
      dplyr::left_join(ucs_i |> dplyr::select(i , uc_dest = uc), by = c("k" = "i")) |>
      dplyr::left_join(agencias_t |> dplyr::select(j, agencia_codigo), by = "j") |>
      dplyr::left_join(indice_t |> dplyr::select(t, data), by = "t") |>
      dplyr::rowwise() |>
      dplyr::mutate(
        distancia_km = dist_uc_uc[i, k],
        duracao_horas = duracao_uc_uc[i, k]
      )

    # Reconstruir tours completos por agência/período
    rotas_tsp <- segmentos_rota |>
      dplyr::group_by(agencia_codigo, data) |>
      dplyr::summarise(
        n_segmentos = dplyr::n(),
        distancia_total_km = sum(distancia_km, na.rm = TRUE),
        duracao_total_horas = sum(duracao_horas, na.rm = TRUE),
        ucs_rota = paste(uc_orig, collapse = " -> "),
        .groups = "drop"
      ) |>
      dplyr::arrange(agencia_codigo, data)

    # Manter também segmentos individuais se resultado_completo
    if (resultado_completo) {
      resultado$segmentos_tsp <- segmentos_rota |>
        dplyr::select(agencia_codigo, data, uc_orig, uc_dest, distancia_km, duracao_horas) |>
        dplyr::arrange(agencia_codigo, data, uc_orig)
    }
  } else {
    rotas_tsp <- NULL
  }

  # Criar resultados para alocação ótima
  resultado_ucs_otimo <- dist_uc_agencias|>
    dplyr::inner_join(matching, by=c("i", "j"))|>
    dplyr::left_join(ucs |> dplyr::distinct(dplyr::pick(dplyr::all_of(c("uc", alocar_por)))), by = "uc")|>
    dplyr::left_join(indice_t, by="t")|>
    dplyr::select(-i,-j,-t, -custo_deslocamento_com_troca)

  # Calcular custos TSP ajustados por UC se peso_tsp > 0
  if (peso_tsp > 0 && !is.null(rotas_tsp)) {
    # Calcular custos totais por agência/período baseados nas rotas TSP
    custos_tsp_agencia_periodo <- rotas_tsp |>
      dplyr::mutate(
        custo_combustivel_tsp = distancia_total_km / kml * custo_litro_combustivel,
        custo_horas_tsp = duracao_total_horas * custo_hora_viagem,
        custo_rota_tsp_total = custo_combustivel_tsp + custo_horas_tsp
      ) |>
      dplyr::select(agencia_codigo, data, custo_rota_tsp_total)

    # Alocar custos TSP proporcionalmente aos custos round-trip
    resultado_ucs_otimo <- resultado_ucs_otimo |>
      dplyr::left_join(custos_tsp_agencia_periodo, by = c("agencia_codigo", "data")) |>
      dplyr::mutate(
        custo_roundtrip_transporte = custo_combustivel + custo_horas_viagem
      ) |>
      dplyr::group_by(agencia_codigo, data) |>
      dplyr::mutate(
        total_roundtrip_agencia_periodo = sum(custo_roundtrip_transporte, na.rm = TRUE),
        proporcao_roundtrip = custo_roundtrip_transporte / total_roundtrip_agencia_periodo,
        # Alocar custo TSP proporcionalmente
        custo_tsp_alocado = dplyr::if_else(!is.na(custo_rota_tsp_total),
                                          custo_rota_tsp_total * proporcao_roundtrip,
                                          custo_roundtrip_transporte),
        # Ajustar custos finais com blend TSP
        custo_combustivel_ajustado = (1 - peso_tsp) * custo_combustivel +
                                   peso_tsp * custo_tsp_alocado * (custo_combustivel / custo_roundtrip_transporte),
        custo_horas_ajustado = (1 - peso_tsp) * custo_horas_viagem +
                              peso_tsp * custo_tsp_alocado * (custo_horas_viagem / custo_roundtrip_transporte),
        custo_deslocamento_tsp_ajustado = custo_combustivel_ajustado + custo_horas_ajustado + custo_diarias + custo_troca_jurisdicao
      ) |>
      dplyr::ungroup() |>
      dplyr::select(-custo_rota_tsp_total, -custo_roundtrip_transporte,
                   -total_roundtrip_agencia_periodo, -proporcao_roundtrip, -custo_tsp_alocado)
  } else {
    # Sem TSP, manter custos originais
    resultado_ucs_otimo <- resultado_ucs_otimo |>
      dplyr::mutate(
        custo_combustivel_ajustado = custo_combustivel,
        custo_horas_ajustado = custo_horas_viagem,
        custo_deslocamento_tsp_ajustado = custo_deslocamento
      )
  }

  # Criar resultados para jurisdição
  resultado_ucs_jurisdicao <- dist_uc_agencias |>
    dplyr::filter(agencia_codigo_jurisdicao == agencia_codigo)|>
    dplyr::select(-agencia_codigo_jurisdicao, -j, -custo_troca_jurisdicao) |>
    dplyr::left_join(ucs |> dplyr::distinct(dplyr::pick(dplyr::all_of(c("uc", alocar_por)))), by = c("uc"))|>
    dplyr::left_join(indice_t, by="t")|>
    dplyr::select(-i,-t)

  ags_group_vars <- c(names(agencias_t), 'entrevistadores')

  if (!all(resultado_ucs_jurisdicao$uc %in% (resultado_ucs_otimo$uc))) stop("Solução não encontrada!")

  # Criar resultados para agências - alocação ótima
  resultado_agencias_otimo <- agencias_t |>
    dplyr::inner_join(resultado_ucs_otimo, by = c('agencia_codigo')) |>
    dplyr::select(-data)|>
    dplyr::group_by(dplyr::pick(dplyr::any_of(ags_group_vars))) |>
    dplyr::summarise(dplyr::across(where(is.numeric), sum), n_trocas_jurisdicao = sum(agencia_codigo != agencia_codigo_jurisdicao), n_ucs=dplyr::n())|>
    dplyr::ungroup() |>
    dplyr::left_join(workers, by = c('j')) |>
    dplyr::select(-j) |>
    dplyr::mutate(custo_total_entrevistadores = entrevistadores * {remuneracao_entrevistador} + entrevistadores * custo_treinamento_por_entrevistador)
  ## dias de coleta por período máximo  por agencia de jurisdicao
  dias_coleta_j <- ucs_i|>
    dplyr::group_by(agencia_codigo=agencia_codigo_jurisdicao,data)|>
    dplyr::summarise(dias_coleta=sum(dias_coleta))|>
    dplyr::group_by(agencia_codigo)|>
    dplyr::arrange(desc(dias_coleta))|>
    dplyr::slice(1)|>
    dplyr::transmute(agencia_codigo, dias_coleta_max_data=dias_coleta)
  # Criar resultados para agências - jurisdição
  resultado_agencias_jurisdicao <- agencias_t|>
    dplyr::left_join(resultado_ucs_jurisdicao, by="agencia_codigo")|>
    dplyr::select(-j, -custo_deslocamento_com_troca, -data)|>
    dplyr::group_by(dplyr::pick(dplyr::any_of(ags_group_vars)))|>
    dplyr::summarise(dplyr::across(where(is.numeric), sum), n_ucs = dplyr::n())|>
    dplyr::left_join(dias_coleta_j, by="agencia_codigo")|>
    dplyr::mutate(
      entrevistadores = pmax(
        ceiling(dias_coleta_max_data / dias_coleta_entrevistador_max),
        ceiling(total_diarias / diarias_entrevistador_max),
        n_entrevistadores_min
      ),
      custo_total_entrevistadores = entrevistadores * {remuneracao_entrevistador} + entrevistadores * custo_treinamento_por_entrevistador
    ) |>
    dplyr::ungroup()
  # Preparar resultados finais
  resultado$resultado_ucs_otimo <- resultado_ucs_otimo
  resultado$resultado_ucs_jurisdicao <- resultado_ucs_jurisdicao
  resultado$resultado_agencias_otimo <- resultado_agencias_otimo
  resultado$resultado_agencias_jurisdicao <- resultado_agencias_jurisdicao

  # Adicionar rotas TSP se foram calculadas
  if (!is.null(rotas_tsp)) {
    resultado$rotas_tsp <- rotas_tsp
  }

  attr(resultado, "solucao_status") <- result$additional_solver_output$ROI$status$msg$message
  attr(resultado, "valor") <- objective_value(result)
  if (resultado_completo) {
    resultado$ucs_agencias_todas <- dist_uc_agencias
  }
  resultado$log <- tail(log, 100)
  tictoc::toc(log=TRUE, quiet=TRUE)
  tempo_otimizacao <- tictoc::tic.log(format = FALSE)
  with(tempo_otimizacao[[1]], cli::cli_alert_success(paste0(msg, ": ", round(toc-tic),  " segundos.")))
  attr(resultado, "tempo_otimizacao") <- with(tempo_otimizacao[[1]], toc-tic)
  return(resultado)
}

#' @keywords internal
#' Teste da função orce com dados simulados incluindo TSP
#'
#' @param n_agencias Número de agências a criar. Padrão: 10.
#' @param n_ucs Número de UCs a criar. Padrão: 30.
#' @param n_periodos Número de períodos de coleta. Padrão: 2.
#' @param peso_tsp Peso TSP para o teste. Padrão: 0.5.\n#' @param distancia_tsp_min Distância mínima para aplicar TSP no teste. Padrão: 50.
#' @param solver Solver a usar. Padrão: "cbc".
#'
#' @return Resultado da função orce com dados simulados
#'
#' @export
teste_orce_tsp <- function(n_agencias = 10, n_ucs = 30, n_periodos = 2, peso_tsp = 0.5, distancia_tsp_min = 50, solver = "cbc", model="mip") {
  requireNamespace("dplyr")

  # Gerar agências aleatórias
  agencias <- tibble::tibble(
    agencia_codigo = sprintf("AG%04d", 1:n_agencias),
    n_entrevistadores_agencia_max = sample(5:15, n_agencias, replace = TRUE),
    custo_fixo = runif(n_agencias, 1000, 5000),
    diaria_valor = runif(n_agencias, 80, 120),
    lat = runif(n_agencias, -30, -20),
    lon = runif(n_agencias, -60, -40)
  )

  # Gerar UCs aleatórias com múltiplos períodos
  ucs_base <- tibble::tibble(
    uc = sprintf("UC%05d", 1:n_ucs),
    lat = runif(n_ucs, -30, -20),
    lon = runif(n_ucs, -60, -40)
  )

  ucs <- tidyr::expand_grid(
    ucs_base,
    data = sprintf("2024-%02d", 1:n_periodos)
  ) |>
    dplyr::mutate(
      uc = paste0(uc, "_", data),  # Tornar UCs únicos por período
      agencia_codigo = sample(agencias$agencia_codigo, dplyr::n(), replace = TRUE),
      dias_coleta = sample(1:5, dplyr::n(), replace = TRUE),
      viagens = sample(1:3, dplyr::n(), replace = TRUE),
      diaria_valor = sample(agencias$diaria_valor, dplyr::n(), replace = TRUE)
    )

  # Calcular distâncias UC-agência (Euclidiana simplificada)
  distancias_ucs <- tidyr::expand_grid(
    ucs |> dplyr::distinct(uc, lat, lon),
    agencias |> dplyr::select(agencia_codigo, ag_lat = lat, ag_lon = lon)
  ) |>
    dplyr::mutate(
      distancia_km = sqrt((lat - ag_lat)^2 + (lon - ag_lon)^2) * 111, # aprox km
      duracao_horas = distancia_km / 60, # 60 km/h média
      diaria_municipio = distancia_km > 50,
      diaria_pernoite = distancia_km > 150
    ) |>
    dplyr::select(uc, agencia_codigo, distancia_km, duracao_horas, diaria_municipio, diaria_pernoite)

  # Calcular distâncias UC-UC para TSP
  distancias_ucs_ucs <- NULL
  if (peso_tsp > 0) {
    ucs_coords <- ucs |> dplyr::distinct(uc, lat, lon)
    distancias_ucs_ucs <- tidyr::expand_grid(
      ucs_coords |> dplyr::select(uc_orig = uc, lat_orig = lat, lon_orig = lon),
      ucs_coords |> dplyr::select(uc_dest = uc, lat_dest = lat, lon_dest = lon)
    ) |>
      dplyr::filter(uc_orig != uc_dest) |>
      dplyr::mutate(
        distancia_km = sqrt((lat_orig - lat_dest)^2 + (lon_orig - lon_dest)^2) * 111,
        duracao_horas = distancia_km / 60
      ) |>
      dplyr::select(uc_orig, uc_dest, distancia_km, duracao_horas)
  }

  # Calcular distâncias agência-agência
  distancias_agencias <- tidyr::expand_grid(
    agencias |> dplyr::select(agencia_codigo_orig = agencia_codigo, lat_orig = lat, lon_orig = lon),
    agencias |> dplyr::select(agencia_codigo_dest = agencia_codigo, lat_dest = lat, lon_dest = lon)
  ) |>
    dplyr::filter(agencia_codigo_orig != agencia_codigo_dest) |>
    dplyr::mutate(
      distancia_km = sqrt((lat_orig - lat_dest)^2 + (lon_orig - lon_dest)^2) * 111,
      duracao_horas = distancia_km / 60
    ) |>
    dplyr::select(agencia_codigo_orig, agencia_codigo_dest, distancia_km, duracao_horas)

  cat("Testando orce com:", n_agencias, "agências,", n_ucs, "UCs,", n_periodos, "períodos\n")
  cat("peso_tsp =", peso_tsp, ", distancia_tsp_min =", distancia_tsp_min, "km\n")

  # Executar orce
  if (model=="mip") {
    orce_now <- orce
  } else if (model=="milp") {
    orce_now <- orce_milp
  } else {
    stop("model not known")
  }
  resultado <- orce_now(
    ucs = ucs,
    agencias = agencias,
    distancias_ucs = distancias_ucs,
    distancias_ucs_ucs = distancias_ucs_ucs,
    distancias_agencias = distancias_agencias,
    dias_coleta_entrevistador_max = 200,
    peso_tsp = peso_tsp,
    distancia_tsp_min = distancia_tsp_min,
    solver = solver,
    max_time = 300,
    use_cache = FALSE,
    resultado_completo = TRUE
  )

  # Mostrar resumo dos resultados
  cat("\n=== RESUMO DOS RESULTADOS ===\n")
  cat("Agências ativas:", nrow(resultado$resultado_agencias_otimo), "\n")
  cat("Custo total:", round(attr(resultado, "valor"), 2), "\n")
  cat("Status:", attr(resultado, "solucao_status"), "\n")

  if (!is.null(resultado$rotas_tsp)) {
    cat("\n=== ROTAS TSP ===\n")
    print(resultado$rotas_tsp)
  }

  return(resultado)
}

#' Alocação Otimizada com TSP usando MILP
#'
#' Versão alternativa usando MILP (Mixed Integer Linear Programming) ao invés de MIPModel
#'
#' @param ucs,agencias,distancias_ucs,distancias_ucs_ucs,peso_tsp Mesmos parâmetros da função orce principal
#' @param ... Outros parâmetros passados para orce
#'
#' @return Resultado similar à função orce principal
#' @export
orce_milp <- function(ucs, agencias, distancias_ucs, distancias_ucs_ucs = NULL, peso_tsp = 0, ...) {
  requireNamespace("dplyr")
  require("ompr")
  require("ROI")
  require("ompr.roi")

  # Pré-processamento similar à versão principal
  ucs <- ucs |>
    dplyr::ungroup() |>
    sf::st_drop_geometry() |>
    dplyr::mutate(i = 1:dplyr::n())

  agencias <- agencias |>
    dplyr::ungroup() |>
    sf::st_drop_geometry() |>
    dplyr::mutate(j = 1:dplyr::n())

  n <- nrow(ucs)
  m <- nrow(agencias)

  # Criar períodos
  periodos <- ucs |> dplyr::distinct(data) |> dplyr::mutate(t = 1:dplyr::n())
  p <- nrow(periodos)

  # Calcular custos de transporte (versão simplificada)
  custos_transport <- matrix(0, n, m)
  for(i in 1:n) {
    for(j in 1:m) {
      uc_code <- ucs$uc[i]
      ag_code <- agencias$agencia_codigo[j]

      dist_info <- distancias_ucs |>
        dplyr::filter(uc == uc_code, agencia_codigo == ag_code)

      if(nrow(dist_info) > 0) {
        custos_transport[i,j] <- dist_info$distancia_km[1] * 2 * 6/10 * ucs$dias_coleta[i] # custo simplificado
      } else {
        custos_transport[i,j] <- 9999
      }
    }
  }

  # Criar modelo MILP
  model <- MILPModel() |>
    # Variáveis de alocação UC-agência
    add_variable(x[i, j], i = 1:n, j = 1:m, type = "binary") |>
    # Variáveis de ativação de agência
    add_variable(y[j], j = 1:m, type = "binary")

  # Adicionar variáveis TSP se peso_tsp > 0
  if (peso_tsp > 0 && !is.null(distancias_ucs_ucs)) {
    # Criar matriz de distâncias UC-UC
    dist_uc_uc <- matrix(9999, n, n)
    for(i in 1:n) {
      for(k in 1:n) {
        if(i != k) {
          uc_i <- ucs$uc[i]
          uc_k <- ucs$uc[k]

          dist_info <- distancias_ucs_ucs |>
            dplyr::filter(uc_orig == uc_i, uc_dest == uc_k)

          if(nrow(dist_info) > 0) {
            dist_uc_uc[i,k] <- dist_info$distancia_km[1]
          }
        }
      }
    }

    model <- model |>
      # Variáveis de roteamento TSP por período
      add_variable(route[i, k, j, t], i = 1:n, k = 1:n, j = 1:m, t = 1:p, type = "binary") |>
      # Variáveis auxiliares para eliminação de subtours
      add_variable(u[i, j, t], i = 1:n, j = 1:m, t = 1:p, type = "continuous", lb = 1, ub = n)
  }

  # Definir função objetivo
  if (peso_tsp > 0 && !is.null(distancias_ucs_ucs)) {
    model <- model |>
      set_objective(
        # Custos de alocação ponderados
        sum_expr((1 - peso_tsp) * custos_transport[i,j] * x[i,j], i = 1:n, j = 1:m) +
        # Custos TSP ponderados
        sum_expr(peso_tsp * dist_uc_uc[i,k] * route[i,k,j,t], i = 1:n, k = 1:n, j = 1:m, t = 1:p) +
        # Custos fixos das agências
        sum_expr(agencias$custo_fixo[j] * y[j], j = 1:m),
        "min"
      )
  } else {
    model <- model |>
      set_objective(
        sum_expr(custos_transport[i,j] * x[i,j], i = 1:n, j = 1:m) +
        sum_expr(agencias$custo_fixo[j] * y[j], j = 1:m),
        "min"
      )
  }

  # Adicionar constraints básicas
  model <- model |>
    # Cada UC deve ser alocada a exatamente uma agência
    add_constraint(sum_expr(x[i,j], j = 1:m) == 1, i = 1:n) |>
    # UC só pode ser alocada a agência ativa
    add_constraint(x[i,j] <= y[j], i = 1:n, j = 1:m)

  # Adicionar constraints TSP se necessário
  if (peso_tsp > 0 && !is.null(distancias_ucs_ucs)) {
    model <- model |>
      # Rota só existe se ambas UCs estão na mesma agência
      add_constraint(route[i,k,j,t] <= x[i,j], i = 1:n, k = 1:n, j = 1:m, t = 1:p) |>
      add_constraint(route[i,k,j,t] <= x[k,j], i = 1:n, k = 1:n, j = 1:m, t = 1:p) |>
      # Cada UC sai para no máximo uma UC por período
      add_constraint(sum_expr(route[i,k,j,t], k = 1:n) <= 1, i = 1:n, j = 1:m, t = 1:p) |>
      # Cada UC recebe de no máximo uma UC por período
      add_constraint(sum_expr(route[i,k,j,t], i = 1:n) <= 1, k = 1:n, j = 1:m, t = 1:p) |>
      # Eliminação de subtours (MTZ)
      add_constraint(u[i,j,t] - u[k,j,t] + n * route[i,k,j,t] <= n - 1,
                     i = 1:n, k = 1:n, j = 1:m, t = 1:p)
  }

  # Resolver modelo
  result <- solve_model(model, with_ROI(solver = "glpk", verbose = TRUE))

  # Extrair solução
  alocacoes <- get_solution(result, x[i,j]) |>
    dplyr::filter(value > 0.9) |>
    dplyr::left_join(ucs |> dplyr::select(i, uc), by = "i") |>
    dplyr::left_join(agencias |> dplyr::select(j, agencia_codigo), by = "j")

  agencias_ativas <- get_solution(result, y[j]) |>
    dplyr::filter(value > 0.9) |>
    dplyr::left_join(agencias |> dplyr::select(j, agencia_codigo), by = "j")

  # Extrair rotas TSP se existirem
  rotas_tsp <- NULL
  if (peso_tsp > 0 && !is.null(distancias_ucs_ucs)) {
    rotas_tsp <- get_solution(result, route[i,k,j,t]) |>
      dplyr::filter(value > 0.9) |>
      dplyr::left_join(ucs |> dplyr::select(i, uc_orig = uc), by = "i") |>
      dplyr::left_join(ucs |> dplyr::select(i = k, uc_dest = uc), by = c("k" = "i")) |>
      dplyr::left_join(agencias |> dplyr::select(j, agencia_codigo), by = "j") |>
      dplyr::left_join(periodos |> dplyr::select(t, data), by = "t") |>
      dplyr::select(agencia_codigo, data, uc_orig, uc_dest)
  }

  return(list(
    alocacoes = alocacoes,
    agencias_ativas = agencias_ativas,
    rotas_tsp = rotas_tsp,
    valor_objetivo = objective_value(result),
    status = solver_status(result)
  ))
}


## FIX
## Checar numero de trechos com tsp. deveria depender da distancia maxima?
## Remover do tsp setores muito proximos
## Enviar distancias e duracao como matriz?
## Os custos por upa estão sendo calculados como com tsp, já que temm mais de uma upa por viagem?
## Como é calculado quando o assignment é por um agregado (município?) Fica ok com tsp?
## update milp version
