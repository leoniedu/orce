#' Alocação Otimizada de Unidades de Coleta (UCs) a Agências
#'
#' Esta função realiza a alocação otimizada de Unidades de Coleta (UCs) a agências, com o objetivo de minimizar os custos totais de deslocamento e operação, considerando múltiplos períodos de coleta. A alocação leva em consideração restrições de capacidade das agências (em número de dias de coleta por período), custos de deslocamento (combustível, tempo de viagem e diárias), custos fixos das agências e custos de treinamento. Quando `use_cache = TRUE`, os resultados são armazenados em cache no disco e reutilizados para entradas idênticas, o que pode acelerar significativamente cálculos repetidos. A função `limpar_cache_ucs` auxilia na limpeza desse cache em disco. A função procede utilizando apenas as colunas requeridas para o processamento.
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
#' @param use_cache Lógico indicando se deve usar resultados em cache. Quando TRUE,
#'   resultados para entradas idênticas serão recuperados do cache em disco em vez
#'   de recalcular. Isso pode acelerar cálculos repetidos mas usa espaço em disco.
#'   O padrão é TRUE.
#' @param orce_function Função construtora do modelo OMPR a ser usada. Recebe um único
#'   argumento `env` (um ambiente) com todos os objetos já preparados dentro de `.orce_impl`
#'   e deve retornar um objeto `ompr::MIPModel`. O padrão é `orce_model_default`.
#'
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
                        distancias_agencias = NULL,
                        adicional_troca_jurisdicao = 0,
                        resultado_completo = FALSE,
                        solver = "cbc",
                        rel_tol = .005,
                        max_time = 30 * 60,
                        use_cache = TRUE,
                  distancias_ucs_ucs=NULL,
                  peso_tsp=.5,
                  # Função construtora do modelo OMPR (padrão: orce_model_default)
                  orce_function = orce_model_mip,
                         ...) {
  # `orce_function` deve ser uma função que recebe `env` e retorna `ompr::MIPModel`

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
    distancias_agencias = distancias_agencias,
    adicional_troca_jurisdicao = adicional_troca_jurisdicao,
    resultado_completo = resultado_completo,
    solver = solver,
    rel_tol = rel_tol,
    max_time = max_time,
    distancias_ucs_ucs=distancias_ucs_ucs,
    peso_tsp=peso_tsp,
    orce_function = orce_function
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
                             distancias_agencias,
                             adicional_troca_jurisdicao,
                             resultado_completo,
                             solver,
                             rel_tol,
                             max_time,
                       distancias_ucs_ucs,
                       peso_tsp,
                             orce_function,
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
    ) + agencias_t$diaria_valor * dias_treinamento * treinamento_com_diaria
    custo_treinamento[agencias_t$agencia_codigo %in% agencias_treinadas] <- 0
  }

  agencias_t$custo_treinamento_por_entrevistador <- custo_treinamento

  # ... (rest of the code remains the same)
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
    dplyr::summarise(dplyr::across(dplyr::where(is.numeric), sum), n_ucs = dplyr::n()) |>
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
  # Criar matrizes de custos
  transport_cost_i_j <- make_i_j(x = dist_i_agencias, col = "custo_deslocamento_com_troca")
  diarias_i_j <- make_i_j(x = dist_i_agencias, col = "total_diarias")
  dias_coleta_i_j <- make_i_j(x = dist_i_agencias, col = "dias_coleta")

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
  # Índices para TSP multi-depósitos: primeiros m nós são as agências (bases),
  # nós m+1..m+n são as UCs.
  n_uc <- n
  N <- m + n_uc
  tsp <- peso_tsp > 0

  # Preprocessar matriz de distâncias UC-UC/bases se TSP estiver ativo
  if (tsp) {
    distancias_ucs_ucs <- .ensure_ucs_ucs_matrix(
      agencias_t = agencias_t,
      ucs_i = ucs_i,
      distancias_ucs_ucs = distancias_ucs_ucs
    )
  }
  # Construir modelo via função injetável
  model <- orce_function(environment())

  cli::cli_progress_step("Otimizando...")

  # Resolver o modelo de otimização
  if (solver == "symphony") {
    log <- utils::capture.output(
      result <- ompr::solve_model(
        model,
        ompr.roi::with_ROI(solver = solver,
                           max_time = as.numeric(max_time),
                           gap_limit = rel_tol * 100, ...)
      )
    )
  } else {
    log <- utils::capture.output(
      result <- ompr::solve_model(
        model,
        ompr.roi::with_ROI(solver = solver,
                           max_time = as.numeric(max_time),
                           rel_tol = rel_tol, ...)
      )
    )
  }

  if (solver == "symphony") {
    if (result$additional_solver_output$ROI$status$msg$code %in% c(231L, 232L)) {
      result$status <- result$additional_solver_output$ROI$status$msg$message
    }
  }

  stopifnot(result$status != "error")
  # Extrair a solução
  resultado <- list()
  if (tsp) {
  segmentos_rota <- result |>
    ompr::get_solution(route[i, k, j]) |>
    dplyr::mutate(im=i-m, km=k-m)|>
    dplyr::filter(value > .9) |>
    dplyr::left_join(ucs_i |> dplyr::select(im=i, orig = uc), by = "im") |>
    dplyr::left_join(ucs_i |> dplyr::select(km=i, dest = uc), by = c("km")) |>
    dplyr::left_join(agencias_t |> dplyr::select(j, agencia_codigo), by = "j") |>
    dplyr::left_join(agencias_t |> dplyr::select(i=j, orig_=agencia_codigo), by = "i") |>
    dplyr::left_join(agencias_t |> dplyr::select(k=j, dest_=agencia_codigo), by = "k") |>
    dplyr::mutate(orig=dplyr::coalesce(orig, orig_), orig_=NULL,
                  dest=dplyr::coalesce(dest, dest_), orig_=NULL
                  )%>%
    dplyr::rowwise() |>
    dplyr::mutate(
      distancia_km = distancias_ucs_ucs[i, k]
    )
  resultado$segmentos_rota <- segmentos_rota
  }
  dist_i_agencias <- dist_i_agencias |> dplyr::select(-custo_deslocamento_com_troca)

  matching <- result |>
    ompr::get_solution(x[i, j]) |>
    dplyr::filter(value > .9) |>
    dplyr::select(i, j)

  workers <- result |>
    ompr::get_solution(w[j]) |>
    dplyr::filter(value > .9) |>
    dplyr::select(j, entrevistadores = value)

  # Criar resultados para alocação ótima
  resultado_ucs_otimo <- dist_uc_agencias|>
    dplyr::inner_join(matching, by=c("i", "j"))|>
    dplyr::left_join(ucs |> dplyr::distinct(dplyr::pick(dplyr::all_of(c("uc", alocar_por)))), by = "uc")|>
    dplyr::left_join(indice_t, by="t")|>
    dplyr::select(-i,-j,-t, -custo_deslocamento_com_troca)

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
    dplyr::mutate(custo_total_entrevistadores = entrevistadores * remuneracao_entrevistador + entrevistadores * custo_treinamento_por_entrevistador)

  if (tsp) {
    resultado_agencias_otimo <- resultado_agencias_otimo%>%
      dplyr::left_join(
    segmentos_rota%>%
      dplyr::group_by(agencia_codigo)%>%
      dplyr::summarise(distancia_km_tsp=sum(distancia_km)))
  }

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
      custo_total_entrevistadores = entrevistadores * remuneracao_entrevistador + entrevistadores * custo_treinamento_por_entrevistador
    ) |>
    dplyr::ungroup()
  # Preparar resultados finais
  resultado$resultado_ucs_otimo <- resultado_ucs_otimo
  resultado$resultado_ucs_jurisdicao <- resultado_ucs_jurisdicao
  resultado$resultado_agencias_otimo <- resultado_agencias_otimo
  resultado$resultado_agencias_jurisdicao <- resultado_agencias_jurisdicao
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
