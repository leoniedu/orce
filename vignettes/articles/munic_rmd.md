---
author:
- Eduardo Leoni - SES/BA - IBGE
authors:
- Eduardo Leoni - SES/BA - IBGE
lang: pt
message: false
params:
  adicional_troca_jurisdicao: 100
  custo_fixo: 0
  custo_hora_viagem: 10
  dias_coleta: 2
  dist_diaria_km: 110
  valor_diaria: 335
  viagens: 1
title: Otimizando a Coleta de Dados do IBGE com o Pacote R 'orce'
toc-title: Índice
---

# Introdução

O pacote orce é uma ferramenta poderosa projetada para otimizar a
alocação de Unidades de Coleta (UCs), como setores censitários ou
estabelecimentos de saúde, às agências do IBGE. Essa alocação eficiente
é fundamental para garantir a coleta de dados de forma econômica e
eficaz em pesquisas e censos de grande escala, como o Censo Demográfico.

Imagine o desafio de coletar dados em milhares de domicílios espalhados
por um vasto território. O orce entra em ação para ajudar a definir a
melhor estratégia, garantindo que cada equipe do IBGE visite os locais
certos, minimizando o tempo de deslocamento e os custos envolvidos.

## Principais Características

1.  **Roteamento e Geocodificação:**

    -   Utiliza o banco de dados do CNEFE para obter coordenadas
        geográficas precisas para cada UC, garantindo a acurácia no
        cálculo de distâncias e rotas.
    -   A função `ponto_setor_densidade` auxilia na identificação de
        locais representativos dentro dos setores censitários,
        priorizando áreas de alta densidade populacional para facilitar
        o acesso e garantir que o algorítimo de roteamento tenha
        destinos/origens válidos.

2.  **Otimização Avançada da Alocação:**

    -   O orce implementa um algoritmo inteligente que encontra a melhor
        forma de distribuir as UCs entre as agências do IBGE, levando em
        conta diversos fatores, como a distância entre os locais, o
        tempo de viagem, os custos fixos de cada agência e a necessidade
        de pagar diárias aos pesquisadores.
    -   A função principal, alocar_upas permite que você personalize as
        restrições, como a capacidade de cada agência e as preferências
        de localização, para que a alocação se adapte às necessidades
        específicas do seu projeto.

3.  **Cálculo de Custos Detalhados:**

    -   O pacote considera as fronteiras administrativas para determinar
        quando é necessário pagar diárias aos pesquisadores, garantindo
        que os custos totais sejam calculados com precisão.
    -   Outros custos importantes, como combustível e tempo de viagem,
        também são levados em conta para fornecer uma estimativa
        completa dos gastos da coleta de dados.

4.  **Flexibilidade e Adaptabilidade:**

    -   O orce permite que você personalize vários parâmetros, como o
        custo do combustível, o custo por hora de viagem, o consumo de
        combustível por quilômetro e as restrições específicas de cada
        agência.
    -   Essa flexibilidade garante que o pacote possa ser adaptado a
        diferentes tipos de pesquisas e necessidades de coleta de dados,
        tornando-o uma ferramenta versátil para o IBGE.

## Impacto e Aplicações

O pacote `orce` tem o potencial de gerar um impacto significativo na
eficiência e na economicidade das operações de pesquisa e censo do IBGE.
Ao otimizar a alocação de UCs, o pacote pode:

-   **Reduzir custos de viagem e tempo de deslocamento:** Ao minimizar
    as distâncias percorridas e o tempo gasto em viagens, o pacote
    contribui para a redução dos custos operacionais e aumenta a
    produtividade das equipes de coleta de dados.
-   **Otimizar a utilização dos recursos das agências:** A alocação
    eficiente das UCs às agências garante que os recursos sejam
    utilizados de forma equilibrada. A opção de impor límites máximos e
    mínimos de unidades de coleta por agência ajuda a evitar sobrecarga
    em algumas agências e ociosidade em outras.
-   **Facilitar o planejamento e a gestão da coleta de dados:** A
    capacidade de personalizar parâmetros e restrições permite que o
    pacote se adapte às necessidades específicas de cada projeto,
    facilitando o planejamento e a gestão das operações de coleta de
    dados.

# Estudos de caso

## Caso 1. Calculando os custos da coleta da MUNIC

A Pesquisa de Informações Básicas Municipais (MUNIC) realizada pelo
Instituto Brasileiro de Geografia e Estatística (IBGE) é uma pesquisa
fundamental para coletar informações essenciais sobre os municípios em
todo o Brasil.

A alocação eficiente dos municípios às agências do IBGE responsáveis
pela coleta de dados é um aspecto importante para o sucesso da pesquisa
MUNIC, principalmente nas Unidades da Federação com maior número de
agências e municípios. O processo envolve atribuir cada município à
agência mais adequada, considerando fatores como proximidade geográfica,
capacidade da agência e custos de viagem. A complexidade dessa tarefa
aumenta com o número de municípios e agências envolvidas, tornando a
alocação manual desafiadora e potencialmente levando a atribuições
abaixo do ideal.

Para enfrentar esse desafio, o pacote `orce` utiliza algoritmos
avançados de otimização e incorpora vários fatores de custo para
identificar a estratégia de alocação mais eficiente, minimizando
despesas de viagem, carga de trabalho da equipe e custos gerais da
pesquisa.

Vamos começar a Superintendência Estadual do Espírito Santo, que tem um
número relativamente pequeno municípios e agências, facilitando a
exposição do processo de estimação. Espírito Santo tem 78 municípios, e
10 agências do IBGE.

:::: cell
::: cell-output-display
![](munic_rmd_files/figure-markdown/unnamed-chunk-3-1.png)
:::
::::

Vamos supor que seja necessário visitar todos os 78 municípios. Como
podemos estimar o custo da coleta? Partiremos de algumas premissas.

1.  Municípios na mesma microrregião ou região metropolitana não pagam
    diária, a não ser que seja exigida pernoite.
2.  Distâncias maiores que 110 km pagam diária, mesmo se na jurisdição
    da agência.
3.  A coleta presencial dura 2 dias.
4.  Quando há pernoite, são pagas 1,5 diárias, e a coleta é feita em 1
    viagem(ns).
5.  Quando não há pernoite, são feitas 2 viagem(ns) (ida e volta). Há
    pagamento de meia-diária nos casos especificados no item 1.
6.  As viagens, feitas por veículos do IBGE, tem origem nas agências e
    destino nos municípios de coleta. Os veículos fazem quilômetros por
    litro, e o custo do combustível é de por litro. **Importante**: o
    consumo de combustível pode ser reduzido significativamente fazendo
    "roteiros", em que uma viagem percorre mais de um município. Vamos
    ignorar, por enquanto, essa possibilidade.
7.  Diárias são calculadas para apenas um funcionário e tem o valor de
    335.

Os dados com as unidades de coleta tem a seguinte estrutura:

:::: cell
::: cell-output-display
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><div id="cnrttoorpa" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

  uc        agencia_codigo   dias_coleta   viagens
  --------- ---------------- ------------- ---------
  3200102   320120900        2             1
  3200136   320150600        2             1
  3200169   320150600        2             1
  3200201   320020100        2             1
  3200300   320240500        2             1
  3200359   320150600        2             1
  3200409   320240500        2             1
  3200508   320020100        2             1
  3200607   320320500        2             1
  3200706   320120900        2             1

</div></body></html>
:::
::::

Usamos como código da unidade de coleta (`uc`) o código IBGE do
município. Os dados devem ser únicos por `uc`. Dias de coleta
(`dias_coleta`) e número de viagens (`viagens`) podem variar por
município. Basta alterar aqui se for o caso.

Precisamos também da distância de cada agência para cada município, e se
a viagem paga diária quando não há pernoite. No momento, estamos só
analisando os municípios com as respectivas agências de jurisdição, essa
diária não é devida. Mas ao analisar alocações alternativas, é
importante saber quando é que diárias são devidas. Essa informação está
na tabela `agencias_municipios_diaria`, disponível no pacote para todas
as unidades da federação.

:::: cell
::: cell-output-display
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><div id="fepxfglspr" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

  agencia_codigo   municipio_codigo   diaria_municipio
  ---------------- ------------------ ------------------
  320120900        3200102            FALSE
  320150600        3200136            FALSE
  320150600        3200169            FALSE
  320020100        3200201            FALSE
  320240500        3200300            FALSE
  320150600        3200359            FALSE
  320240500        3200409            FALSE
  320020100        3200508            FALSE
  320320500        3200607            FALSE
  320120900        3200706            FALSE

</div></body></html>
:::
::::

Precisamos também das distâncias, em quilômetros, entre cada agência e
cada sede municipal (disponível em
`distancias_agencias_municipios_osrm`), que combinamos com as
informações sobre as diárias (`agencias_municipios_diaria`).

:::: cell
::: cell-output-display
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><div id="zclpahvadx" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

  agencia_codigo   uc        distancia_km   duracao_horas   diaria_municipio
  ---------------- --------- -------------- --------------- ------------------
  320020100        3200102   132,51         2,2             TRUE
  320120900        3200102   119,44         2,03            FALSE
  320130800        3200102   134,24         1,86            TRUE
  320150600        3200102   111,28         1,73            TRUE
  320240500        3200102   159,66         2,23            TRUE
  320320500        3200102   184,21         3,25            TRUE
  320490600        3200102   267,44         4,59            TRUE
  320500200        3200102   162,79         2,32            TRUE
  320520000        3200102   148,3          2,2             TRUE
  320530900        3200102   146,31         2,14            TRUE

</div></body></html>
:::
::::

Observação: A coluna `duracao_horas` será importante quando formos
comparar diferentes propostas de alocação de municípios a agências.

Estamos, agora, prontos para calcular os custos de coleta.

#### Custos por agência

:::: cell
::: cell-output-display
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><div id="cxyyzngmno" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

                              Municipios   Total Diarias   Custo Diarias   Distancia Total Km   Custo Combustivel
  --------------------------- ------------ --------------- --------------- -------------------- -------------------
                                                                                                
  Alegre                      14           0               R\$0            2.914,72             R\$1.749
  Cachoeiro de Itapemirim     10           3               R\$1.005        1.892,12             R\$1.135
  Cariacica                   8            1,5             R\$502          1.564,54             R\$939
  Colatina                    12           6               R\$2.010        2.794,38             R\$1.677
  Guarapari                   9            1,5             R\$502          1.799,58             R\$1.080
  Linhares                    9            1,5             R\$502          1.796,6              R\$1.078
  Serra                       3            0               R\$0            414,28               R\$249
  São Mateus                  11           4,5             R\$1.508        2.455,06             R\$1.473
  Vila Velha                  1            0               R\$0            3,32                 R\$2
  Vitória                     1            0               R\$0            21,08                R\$13
  Total da Superintendência   78           18              R\$6.030        15.655,68            R\$9.393

</div></body></html>
:::
::::

#### Custos por município

:::: cell
::: cell-output-display
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><div id="owvzclgpmm" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

  municipio_nome           agencia_nome              custo_diarias   custo_combustivel
  ------------------------ ------------------------- --------------- -------------------
  Ecoporanga               Colatina                  R\$502          R\$218
  Água Doce do Norte       Colatina                  R\$502          R\$189
  Laranja da Terra         Cachoeiro de Itapemirim   R\$502          R\$184
  Ponto Belo               São Mateus                R\$502          R\$166
  Mucurici                 São Mateus                R\$502          R\$159
  Mantenópolis             Colatina                  R\$502          R\$153
  Barra de São Francisco   Colatina                  R\$502          R\$152
  Afonso Cláudio           Cachoeiro de Itapemirim   R\$502          R\$143
  Itaguaçu                 Cariacica                 R\$502          R\$143
  Montanha                 São Mateus                R\$502          R\$137

</div></body></html>
:::
::::

#### Lidando com contigências da coleta

Suponha agora que é necessário fazer uma visita ao município de Barra de
São Francisco, mas a agência de jurisdição não está disponível por
qualquer motivo (férias, licença de saúde, veículo do IBGE quebrado,
etc.) Quais são as agências alternativas para realizar essa coleta? A
função `alocar_ucs` retorna, opcionalmente, a lista completa de
combinações entre agências $X$ municípios, que permite facilmente
responder essa pergunta.

:::: cell
::: cell-output-display
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><div id="hbicbdlwhd" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

  agencia_nome              distancia_km   custo_diarias   custo_combustivel
  ------------------------- -------------- --------------- -------------------
  Colatina (Jurisdição)     126,91         R\$502          R\$152
  São Mateus                145,88         R\$502          R\$175
  Linhares                  168,86         R\$502          R\$203
  Serra                     236,99         R\$502          R\$284
  Cariacica                 252,96         R\$502          R\$304
  Vitória                   253,31         R\$502          R\$304
  Vila Velha                257,9          R\$502          R\$309
  Guarapari                 296,42         R\$502          R\$356
  Cachoeiro de Itapemirim   346,91         R\$502          R\$416
  Alegre                    370,25         R\$502          R\$444

</div></body></html>
:::
::::

Nota-se que há outras agências que podem realizar a coleta no
municípios, a um custo ligeiramente superior.

#### Otimizando a alocação de municípios

A pergunta que segue, naturalmente, é, há algum município que teria
custos de coleta menores se a coleta fosse realizada por agência
diferente da de jurisdição? A resposta é sim!

:::: cell
::: cell-output-display
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><div id="hubyixkxab" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

  municipio_nome          agencia_nome              distancia_km   custo_diarias   custo_combustivel
  ----------------------- ------------------------- -------------- --------------- -------------------
  Governador Lindenberg   Colatina                  50,87          R\$0            R\$122
  Presidente Kennedy      Cachoeiro de Itapemirim   38,27          R\$335          R\$92
  Itaguaçu                Colatina                  54,89          R\$335          R\$132
  São Gabriel da Palha    Colatina                  79,68          R\$335          R\$191
  Laranja da Terra        Colatina                  88,22          R\$335          R\$212
  Afonso Cláudio          Colatina                  111,28         R\$502          R\$134
  Ecoporanga              São Mateus                146,89         R\$502          R\$176

</div></body></html>
:::
::::

Sabemos que os custos com combustível e diárias estão longe de ser os
únicos fatores para selecionar a agência de coleta. A própria troca de
agência de coleta tem um custo não desprezível. Os funcionários da
agência de jurisdição provavelmente conhecem melhor o município de
coleta, e até na gerência da coleta (que agência mesmo coleta o
município X?) coloca um custo não trivial. Outras possibilidade é a
distância em quilômetros ser menor, mas o tempo de viagem (por conta de
qualidade da estrada, por exemplo) ser maior. O tempo gasto viajando
certamente tem um custo para além das diárias e combustível.

Propomos avaliar o custo de deslocamento como a soma do custo de
diárias, combustível, e custo adicional por hora de viagem
correspondente a R\$10. Além disso, só são propostas trocas que
economizariam no mínimo R\$100 no custo de deslocamento para o
município.

:::: cell
::: cell-output-display
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><div id="mxdahaxyju" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

  Municipio            Agencia Otimo             Agencia Jurisdicao        Distancia Km Otimo   Distancia Km Jurisdicao   Custo Deslocamento Otimo   Custo Deslocamento Jurisdicao
  -------------------- ------------------------- ------------------------- -------------------- ------------------------- -------------------------- -------------------------------
  Presidente Kennedy   Cachoeiro de Itapemirim   Guarapari                 38,27                113,37                    R\$455                     R\$676
  Itaguaçu             Colatina                  Cariacica                 54,89                119,31                    R\$501                     R\$683
  Laranja da Terra     Colatina                  Cachoeiro de Itapemirim   88,22                153,06                    R\$605                     R\$738

</div></body></html>
:::
::::

:::::: cell
::: cell-output-display
![](munic_rmd_files/figure-markdown/unnamed-chunk-17-1.png)
:::

::: cell-output-display
![](munic_rmd_files/figure-markdown/unnamed-chunk-17-2.png)
:::

::: cell-output-display
![](munic_rmd_files/figure-markdown/unnamed-chunk-17-3.png)
:::
::::::

#### Resumo da otimização

:::: cell
::: cell-output-display
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><div id="qnvkcctqce" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

  name                 jurisdicao   otimo       reducao   reducao_pct
  -------------------- ------------ ----------- --------- -------------
  custo_diarias        6.030        5.527,5     502,5     8,3%
  custo_combustivel    9.393,41     9.365,83    27,58     0,3%
  custo_horas_viagem   2.665,6      2.659       6,6       0,2%
  total                18.089,01    17.552,33   536,68    3,0%
  n_agencias           10           10          0         0,0%

</div></body></html>
:::
::::

Utilizando o plano otimizado, com 3 alterações de agência de coleta, é
possível economizar 8% no valor das diárias, gastando 0,3% a **menos**
em combustível.

### Resultados para outras Superintendências Estaduais[^1]

:::: cell
::: cell-output-display
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><div id="nnrquyjvgb" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

                                          Jurisdição (R\$)   Ótimo (R\$)   Redução (R\$)   Redução (%)
  ----------------- --------------------- ------------------ ------------- --------------- -------------
  Centro Oeste                                                                             
                    Goiás                 70.613             67.385        3.228           4,6%
                    Mato Grosso           63.800             61.863        1.937           3,0%
                    Mato Grosso do Sul    24.985             24.507        479             1,9%
  Total da Região   ---                   159.398            153.755       5.643           ---
  Nordeste                                                                                 
                    Maranhão              66.919             61.575        5.344           8,0%
                    Bahia                 84.700             80.245        4.455           5,3%
                    Rio Grande do Norte   25.316             24.037        1.279           5,1%
                    Piauí                 64.880             63.642        1.238           1,9%
                    Pernambuco            27.313             26.987        327             1,2%
                    Alagoas               10.327             10.002        324             3,1%
                    Ceará                 38.249             37.957        293             0,8%
                    Sergipe               9.016              8.884         132             1,5%
                    Paraíba               34.324             34.221        103             0,3%
  Total da Região   ---                   361.044            347.549       13.495          ---
  Norte                                                                                    
                    Tocantins             53.519             52.834        685             1,3%
                    Acre                  9.165              8.542         623             6,8%
                    Rondônia              21.938             21.938        0               0,0%
                    Roraima               9.455              9.455         0               0,0%
                    Amapá                 11.187             11.187        0               0,0%
  Total da Região   ---                   105.264            103.956       1.308           ---
  Sudeste                                                                                  
                    Minas Gerais          158.418            154.414       4.004           2,5%
                    São Paulo             66.767             65.693        1.075           1,6%
                    Espírito Santo        18.089             17.552        537             3,0%
                    Rio de Janeiro        11.085             11.085        0               0,0%
  Total da Região   ---                   254.360            248.744       5.616           ---
  Sul                                                                                      
                    Rio Grande do Sul     89.923             84.541        5.382           6,0%
                    Santa Catarina        38.447             36.542        1.905           5,0%
                    Paraná                56.198             56.198        0               0,0%
  Total da Região   ---                   184.568            177.281       7.287           ---
  Total Brasil      ---                   1.064.635          1.031.285     33.350          ---

</div></body></html>
:::
::::

## Caso 2. Calculando os custos da coleta da POF para a SES/Bahia

:::: cell
::: cell-output-display
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><div id="ujoiibjspb" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

                           agencia_nome                  custo_combustivel_jurisdicao   custo_combustivel_otimo   custo_diarias_jurisdicao   custo_diarias_otimo   distancia_total_km_jurisdicao   distancia_total_km_otimo   n_upas_jurisdicao   n_upas_otimo   total_diarias_jurisdicao   total_diarias_otimo
  ------------------------ ----------------------------- ------------------------------ ------------------------- -------------------------- --------------------- ------------------------------- -------------------------- ------------------- -------------- -------------------------- ---------------------
                           CAMAÇARI                      R\$4.325                       R\$8.073                  R\$0                       R\$4.858              7.209                           13.455                     14                  22             0                          14
                           CONCEIÇÃO DO COITÉ            R\$1.936                       R\$6.221                  R\$3.182                   R\$12.730             3.226                           10.369                     6                   16             10                         38
                           FEIRA DE SANTANA              R\$2.673                       R\$8.986                  R\$0                       R\$46.398             4.454                           14.977                     20                  39             0                          138
                           ITABUNA                       R\$1.471                       R\$6.305                  R\$6.365                   R\$38.190             2.452                           10.509                     6                   22             19                         114
                           ITAMARAJU                     R\$1.198                       R\$5.063                  R\$6.365                   R\$50.920             1.997                           8.438                      8                   22             19                         152
                           JAGUAQUARA                    R\$1.843                       R\$5.384                  R\$0                       R\$23.952             3.072                           8.974                      7                   17             0                          72
                           RIBEIRA DO POMBAL             R\$2.032                       R\$7.977                  R\$9.548                   R\$54.270             3.386                           13.295                     8                   24             28                         162
                           SANTA MARIA DA VITÓRIA        R\$2.590                       R\$18.897                 R\$6.365                   R\$92.292             4.317                           31.495                     8                   35             19                         276
                           SANTO ANTÔNIO DE JESUS        R\$1.046                       R\$5.675                  R\$9.548                   R\$35.175             1.743                           9.458                      8                   22             28                         105
                           SENHOR DO BONFIM              R\$1.888                       R\$12.470                 R\$3.182                   R\$70.015             3.146                           20.783                     6                   27             10                         209
                           VITÓRIA DA CONQUISTA          R\$4.033                       R\$9.435                  R\$25.460                  R\$66.832             6.722                           15.726                     18                  31             76                         200
                           ALAGOINHAS                    R\$1.346                       NA                        R\$0                       NA                    2.243                           NA                         6                   NA             0                          NA
                           BARREIRAS                     R\$1.368                       NA                        R\$12.730                  NA                    2.279                           NA                         6                   NA             38                         NA
                           BOM JESUS DA LAPA             R\$1.101                       NA                        R\$0                       NA                    1.836                           NA                         3                   NA             0                          NA
                           BRUMADO                       R\$206                         NA                        R\$3.182                   NA                    343                             NA                         1                   NA             10                         NA
                           CACHOEIRA                     R\$9                           NA                        R\$0                       NA                    15                              NA                         1                   NA             0                          NA
                           CIPÓ                          R\$873                         NA                        R\$3.182                   NA                    1.455                           NA                         3                   NA             10                         NA
                           CRUZ DAS ALMAS                R\$1.080                       NA                        R\$0                       NA                    1.801                           NA                         5                   NA             0                          NA
                           ESPLANADA                     R\$1.749                       NA                        R\$3.182                   NA                    2.915                           NA                         4                   NA             10                         NA
                           EUCLIDES DA CUNHA             R\$2.721                       NA                        R\$12.730                  NA                    4.535                           NA                         7                   NA             38                         NA
                           EUNÁPOLIS                     R\$418                         NA                        R\$0                       NA                    697                             NA                         3                   NA             0                          NA
                           GUANAMBI                      R\$2.375                       NA                        R\$3.182                   NA                    3.958                           NA                         6                   NA             10                         NA
                           IBOTIRAMA                     R\$1.615                       NA                        R\$9.548                   NA                    2.692                           NA                         6                   NA             28                         NA
                           ILHÉUS                        R\$1.745                       NA                        R\$15.912                  NA                    2.909                           NA                         9                   NA             48                         NA
                           IPIAÚ                         R\$2.125                       NA                        R\$9.548                   NA                    3.542                           NA                         8                   NA             28                         NA
                           IPIRÁ                         R\$858                         NA                        R\$0                       NA                    1.431                           NA                         3                   NA             0                          NA
                           IRECÊ                         R\$1.281                       NA                        R\$0                       NA                    2.136                           NA                         4                   NA             0                          NA
                           ITABERABA                     R\$766                         NA                        R\$3.182                   NA                    1.277                           NA                         4                   NA             10                         NA
                           ITAPETINGA                    R\$1.588                       NA                        R\$9.548                   NA                    2.647                           NA                         6                   NA             28                         NA
                           JACOBINA                      R\$1.761                       NA                        R\$12.730                  NA                    2.935                           NA                         7                   NA             38                         NA
                           JEQUIÉ                        R\$424                         NA                        R\$0                       NA                    706                             NA                         3                   NA             0                          NA
                           JEREMOABO                     R\$148                         NA                        R\$3.182                   NA                    246                             NA                         1                   NA             10                         NA
                           JUAZEIRO                      R\$297                         NA                        R\$3.182                   NA                    494                             NA                         4                   NA             10                         NA
                           LIVRAMENTO DE NOSSA SENHORA   R\$1.091                       NA                        R\$3.182                   NA                    1.819                           NA                         4                   NA             10                         NA
                           MORRO DO CHAPÉU               R\$1.485                       NA                        R\$0                       NA                    2.476                           NA                         3                   NA             0                          NA
                           PAULO AFONSO                  R\$451                         NA                        R\$0                       NA                    752                             NA                         5                   NA             0                          NA
                           POÇÕES                        R\$528                         NA                        R\$9.548                   NA                    880                             NA                         3                   NA             28                         NA
                           PORTO SEGURO                  R\$1.085                       NA                        R\$3.182                   NA                    1.808                           NA                         4                   NA             10                         NA
                           REMANSO                       R\$9                           NA                        R\$0                       NA                    15                              NA                         1                   NA             0                          NA
                           RIACHÃO DO JACUÍPE            R\$15                          NA                        R\$0                       NA                    25                              NA                         1                   NA             0                          NA
                           SANTA RITA DE CÁSSIA          R\$1.120                       NA                        R\$12.730                  NA                    1.867                           NA                         4                   NA             38                         NA
                           SANTO AMARO                   R\$3.453                       NA                        R\$0                       NA                    5.755                           NA                         10                  NA             0                          NA
                           SÃO FRANCISCO DO CONDE        R\$788                         NA                        R\$0                       NA                    1.314                           NA                         3                   NA             0                          NA
                           SEABRA                        R\$743                         NA                        R\$3.182                   NA                    1.239                           NA                         2                   NA             10                         NA
                           SERRINHA                      R\$1.248                       NA                        R\$0                       NA                    2.081                           NA                         6                   NA             0                          NA
                           TEIXEIRA DE FREITAS           R\$888                         NA                        R\$12.730                  NA                    1.479                           NA                         7                   NA             38                         NA
                           VALENÇA                       R\$2.257                       NA                        R\$25.460                  NA                    3.762                           NA                         12                  NA             76                         NA
                           XIQUE-XIQUE                   R\$354                         NA                        R\$6.365                   NA                    589                             NA                         3                   NA             19                         NA
  Total Superintendência   ---                           R\$66.407                      R\$94.487                 R\$251.418                 R\$495.632            110.678                         157.479                    277                 277            750                        1.480

</div></body></html>
:::
::::

#### Reorganizando a jurisdição das agências

:::: cell
::: cell-output-display
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><div id="xocilfuxrh" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

                           agencia_nome                  custo_combustivel_jurisdicao   custo_combustivel_otimo   custo_diarias_jurisdicao   custo_diarias_otimo   distancia_total_km_jurisdicao   distancia_total_km_otimo   n_upas_jurisdicao   n_upas_otimo   total_diarias_jurisdicao   total_diarias_otimo
  ------------------------ ----------------------------- ------------------------------ ------------------------- -------------------------- --------------------- ------------------------------- -------------------------- ------------------- -------------- -------------------------- ---------------------
                           CAMAÇARI                      R\$4.325                       R\$8.073                  R\$0                       R\$3.182              7.209                           13.455                     14                  22             0                          10
                           CONCEIÇÃO DO COITÉ            R\$1.936                       R\$6.221                  R\$3.182                   R\$12.730             3.226                           10.369                     6                   16             10                         38
                           FEIRA DE SANTANA              R\$2.673                       R\$8.986                  R\$0                       R\$41.372             4.454                           14.977                     20                  39             0                          124
                           ITABUNA                       R\$1.471                       R\$6.305                  R\$6.365                   R\$38.190             2.452                           10.509                     6                   22             19                         114
                           ITAMARAJU                     R\$1.198                       R\$5.063                  R\$6.365                   R\$50.920             1.997                           8.438                      8                   22             19                         152
                           JAGUAQUARA                    R\$1.843                       R\$5.384                  R\$0                       R\$22.278             3.072                           8.974                      7                   17             0                          66
                           RIBEIRA DO POMBAL             R\$2.032                       R\$7.977                  R\$9.548                   R\$50.920             3.386                           13.295                     8                   24             28                         152
                           SANTA MARIA DA VITÓRIA        R\$2.590                       R\$18.897                 R\$6.365                   R\$92.292             4.317                           31.495                     8                   35             19                         276
                           SANTO ANTÔNIO DE JESUS        R\$1.046                       R\$5.675                  R\$9.548                   R\$31.825             1.743                           9.458                      8                   22             28                         95
                           SENHOR DO BONFIM              R\$1.888                       R\$12.470                 R\$3.182                   R\$70.015             3.146                           20.783                     6                   27             10                         209
                           VITÓRIA DA CONQUISTA          R\$4.033                       R\$9.435                  R\$25.460                  R\$66.832             6.722                           15.726                     18                  31             76                         200
                           ALAGOINHAS                    R\$1.346                       NA                        R\$0                       NA                    2.243                           NA                         6                   NA             0                          NA
                           BARREIRAS                     R\$1.368                       NA                        R\$12.730                  NA                    2.279                           NA                         6                   NA             38                         NA
                           BOM JESUS DA LAPA             R\$1.101                       NA                        R\$0                       NA                    1.836                           NA                         3                   NA             0                          NA
                           BRUMADO                       R\$206                         NA                        R\$3.182                   NA                    343                             NA                         1                   NA             10                         NA
                           CACHOEIRA                     R\$9                           NA                        R\$0                       NA                    15                              NA                         1                   NA             0                          NA
                           CIPÓ                          R\$873                         NA                        R\$3.182                   NA                    1.455                           NA                         3                   NA             10                         NA
                           CRUZ DAS ALMAS                R\$1.080                       NA                        R\$0                       NA                    1.801                           NA                         5                   NA             0                          NA
                           ESPLANADA                     R\$1.749                       NA                        R\$3.182                   NA                    2.915                           NA                         4                   NA             10                         NA
                           EUCLIDES DA CUNHA             R\$2.721                       NA                        R\$12.730                  NA                    4.535                           NA                         7                   NA             38                         NA
                           EUNÁPOLIS                     R\$418                         NA                        R\$0                       NA                    697                             NA                         3                   NA             0                          NA
                           GUANAMBI                      R\$2.375                       NA                        R\$3.182                   NA                    3.958                           NA                         6                   NA             10                         NA
                           IBOTIRAMA                     R\$1.615                       NA                        R\$9.548                   NA                    2.692                           NA                         6                   NA             28                         NA
                           ILHÉUS                        R\$1.745                       NA                        R\$15.912                  NA                    2.909                           NA                         9                   NA             48                         NA
                           IPIAÚ                         R\$2.125                       NA                        R\$9.548                   NA                    3.542                           NA                         8                   NA             28                         NA
                           IPIRÁ                         R\$858                         NA                        R\$0                       NA                    1.431                           NA                         3                   NA             0                          NA
                           IRECÊ                         R\$1.281                       NA                        R\$0                       NA                    2.136                           NA                         4                   NA             0                          NA
                           ITABERABA                     R\$766                         NA                        R\$3.182                   NA                    1.277                           NA                         4                   NA             10                         NA
                           ITAPETINGA                    R\$1.588                       NA                        R\$9.548                   NA                    2.647                           NA                         6                   NA             28                         NA
                           JACOBINA                      R\$1.761                       NA                        R\$12.730                  NA                    2.935                           NA                         7                   NA             38                         NA
                           JEQUIÉ                        R\$424                         NA                        R\$0                       NA                    706                             NA                         3                   NA             0                          NA
                           JEREMOABO                     R\$148                         NA                        R\$3.182                   NA                    246                             NA                         1                   NA             10                         NA
                           JUAZEIRO                      R\$297                         NA                        R\$3.182                   NA                    494                             NA                         4                   NA             10                         NA
                           LIVRAMENTO DE NOSSA SENHORA   R\$1.091                       NA                        R\$3.182                   NA                    1.819                           NA                         4                   NA             10                         NA
                           MORRO DO CHAPÉU               R\$1.485                       NA                        R\$0                       NA                    2.476                           NA                         3                   NA             0                          NA
                           PAULO AFONSO                  R\$451                         NA                        R\$0                       NA                    752                             NA                         5                   NA             0                          NA
                           POÇÕES                        R\$528                         NA                        R\$9.548                   NA                    880                             NA                         3                   NA             28                         NA
                           PORTO SEGURO                  R\$1.085                       NA                        R\$3.182                   NA                    1.808                           NA                         4                   NA             10                         NA
                           REMANSO                       R\$9                           NA                        R\$0                       NA                    15                              NA                         1                   NA             0                          NA
                           RIACHÃO DO JACUÍPE            R\$15                          NA                        R\$0                       NA                    25                              NA                         1                   NA             0                          NA
                           SANTA RITA DE CÁSSIA          R\$1.120                       NA                        R\$12.730                  NA                    1.867                           NA                         4                   NA             38                         NA
                           SANTO AMARO                   R\$3.453                       NA                        R\$0                       NA                    5.755                           NA                         10                  NA             0                          NA
                           SÃO FRANCISCO DO CONDE        R\$788                         NA                        R\$0                       NA                    1.314                           NA                         3                   NA             0                          NA
                           SEABRA                        R\$743                         NA                        R\$3.182                   NA                    1.239                           NA                         2                   NA             10                         NA
                           SERRINHA                      R\$1.248                       NA                        R\$0                       NA                    2.081                           NA                         6                   NA             0                          NA
                           TEIXEIRA DE FREITAS           R\$888                         NA                        R\$12.730                  NA                    1.479                           NA                         7                   NA             38                         NA
                           VALENÇA                       R\$2.257                       NA                        R\$25.460                  NA                    3.762                           NA                         12                  NA             76                         NA
                           XIQUE-XIQUE                   R\$354                         NA                        R\$6.365                   NA                    589                             NA                         3                   NA             19                         NA
  Total Superintendência   ---                           R\$66.407                      R\$94.487                 R\$251.418                 R\$480.558            110.678                         157.479                    277                 277            750                        1.434

</div></body></html>
:::
::::

#### Aumentando a distância sem diária

:::: cell
::: cell-output-display
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><div id="rgsjxacoad" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

                           agencia_nome                  custo_combustivel_jurisdicao   custo_combustivel_otimo   custo_diarias_jurisdicao   custo_diarias_otimo   distancia_total_km_jurisdicao   distancia_total_km_otimo   n_upas_jurisdicao   n_upas_otimo   total_diarias_jurisdicao   total_diarias_otimo
  ------------------------ ----------------------------- ------------------------------ ------------------------- -------------------------- --------------------- ------------------------------- -------------------------- ------------------- -------------- -------------------------- ---------------------
                           CAMAÇARI                      R\$4.325                       R\$8.073                  R\$0                       R\$4.858              7.209                           13.455                     14                  22             0                          14
                           CRUZ DAS ALMAS                R\$1.080                       R\$9.676                  R\$0                       R\$8.040              1.801                           16.127                     5                   19             0                          24
                           FEIRA DE SANTANA              R\$2.673                       R\$9.178                  R\$0                       R\$20.938             4.454                           15.297                     20                  32             0                          62
                           IPIAÚ                         R\$3.329                       R\$5.734                  R\$3.182                   R\$5.025              5.549                           9.557                      8                   11             10                         15
                           ITABUNA                       R\$1.471                       R\$5.446                  R\$6.365                   R\$22.278             2.452                           9.077                      6                   17             19                         66
                           JACOBINA                      R\$2.953                       R\$15.852                 R\$6.365                   R\$65.325             4.922                           26.419                     7                   29             19                         195
                           JAGUAQUARA                    R\$1.843                       R\$4.897                  R\$0                       R\$4.858              3.072                           8.162                      7                   12             0                          14
                           RIBEIRA DO POMBAL             R\$3.296                       R\$10.862                 R\$3.182                   R\$51.088             5.493                           18.103                     8                   26             10                         152
                           SANTA MARIA DA VITÓRIA        R\$2.590                       R\$17.951                 R\$6.365                   R\$89.110             4.317                           29.918                     8                   34             19                         266
                           SERRINHA                      R\$1.248                       R\$5.344                  R\$0                       R\$6.365              2.081                           8.907                      6                   14             0                          19
                           TEIXEIRA DE FREITAS           R\$3.360                       R\$10.997                 R\$0                       R\$25.460             5.599                           18.328                     7                   21             0                          76
                           VALENÇA                       R\$7.105                       R\$5.911                  R\$3.182                   R\$0                  11.841                          9.852                      12                  10             10                         0
                           VITÓRIA DA CONQUISTA          R\$5.250                       R\$11.044                 R\$19.095                  R\$54.102             8.750                           18.406                     18                  30             57                         162
                           ALAGOINHAS                    R\$1.346                       NA                        R\$0                       NA                    2.243                           NA                         6                   NA             0                          NA
                           BARREIRAS                     R\$1.960                       NA                        R\$9.548                   NA                    3.267                           NA                         6                   NA             28                         NA
                           BOM JESUS DA LAPA             R\$1.101                       NA                        R\$0                       NA                    1.836                           NA                         3                   NA             0                          NA
                           BRUMADO                       R\$206                         NA                        R\$3.182                   NA                    343                             NA                         1                   NA             10                         NA
                           CACHOEIRA                     R\$9                           NA                        R\$0                       NA                    15                              NA                         1                   NA             0                          NA
                           CIPÓ                          R\$873                         NA                        R\$3.182                   NA                    1.455                           NA                         3                   NA             10                         NA
                           CONCEIÇÃO DO COITÉ            R\$1.936                       NA                        R\$3.182                   NA                    3.226                           NA                         6                   NA             10                         NA
                           ESPLANADA                     R\$2.426                       NA                        R\$0                       NA                    4.043                           NA                         4                   NA             0                          NA
                           EUCLIDES DA CUNHA             R\$3.337                       NA                        R\$9.548                   NA                    5.562                           NA                         7                   NA             28                         NA
                           EUNÁPOLIS                     R\$418                         NA                        R\$0                       NA                    697                             NA                         3                   NA             0                          NA
                           GUANAMBI                      R\$2.375                       NA                        R\$3.182                   NA                    3.958                           NA                         6                   NA             10                         NA
                           IBOTIRAMA                     R\$1.615                       NA                        R\$9.548                   NA                    2.692                           NA                         6                   NA             28                         NA
                           ILHÉUS                        R\$3.751                       NA                        R\$6.365                   NA                    6.251                           NA                         9                   NA             19                         NA
                           IPIRÁ                         R\$858                         NA                        R\$0                       NA                    1.431                           NA                         3                   NA             0                          NA
                           IRECÊ                         R\$1.281                       NA                        R\$0                       NA                    2.136                           NA                         4                   NA             0                          NA
                           ITABERABA                     R\$1.361                       NA                        R\$0                       NA                    2.269                           NA                         4                   NA             0                          NA
                           ITAMARAJU                     R\$1.198                       NA                        R\$6.365                   NA                    1.997                           NA                         8                   NA             19                         NA
                           ITAPETINGA                    R\$2.346                       NA                        R\$6.365                   NA                    3.910                           NA                         6                   NA             19                         NA
                           JEQUIÉ                        R\$424                         NA                        R\$0                       NA                    706                             NA                         3                   NA             0                          NA
                           JEREMOABO                     R\$739                         NA                        R\$0                       NA                    1.232                           NA                         1                   NA             0                          NA
                           JUAZEIRO                      R\$946                         NA                        R\$0                       NA                    1.576                           NA                         4                   NA             0                          NA
                           LIVRAMENTO DE NOSSA SENHORA   R\$1.091                       NA                        R\$3.182                   NA                    1.819                           NA                         4                   NA             10                         NA
                           MORRO DO CHAPÉU               R\$1.485                       NA                        R\$0                       NA                    2.476                           NA                         3                   NA             0                          NA
                           PAULO AFONSO                  R\$451                         NA                        R\$0                       NA                    752                             NA                         5                   NA             0                          NA
                           POÇÕES                        R\$2.639                       NA                        R\$0                       NA                    4.399                           NA                         3                   NA             0                          NA
                           PORTO SEGURO                  R\$1.085                       NA                        R\$3.182                   NA                    1.808                           NA                         4                   NA             10                         NA
                           REMANSO                       R\$9                           NA                        R\$0                       NA                    15                              NA                         1                   NA             0                          NA
                           RIACHÃO DO JACUÍPE            R\$15                          NA                        R\$0                       NA                    25                              NA                         1                   NA             0                          NA
                           SANTA RITA DE CÁSSIA          R\$1.120                       NA                        R\$12.730                  NA                    1.867                           NA                         4                   NA             38                         NA
                           SANTO AMARO                   R\$3.453                       NA                        R\$0                       NA                    5.755                           NA                         10                  NA             0                          NA
                           SANTO ANTÔNIO DE JESUS        R\$2.443                       NA                        R\$3.182                   NA                    4.072                           NA                         8                   NA             10                         NA
                           SÃO FRANCISCO DO CONDE        R\$788                         NA                        R\$0                       NA                    1.314                           NA                         3                   NA             0                          NA
                           SEABRA                        R\$743                         NA                        R\$3.182                   NA                    1.239                           NA                         2                   NA             10                         NA
                           SENHOR DO BONFIM              R\$2.532                       NA                        R\$0                       NA                    4.219                           NA                         6                   NA             0                          NA
                           XIQUE-XIQUE                   R\$1.699                       NA                        R\$0                       NA                    2.831                           NA                         3                   NA             0                          NA
  Total Superintendência   ---                           R\$90.586                      R\$120.964                R\$133.665                 R\$357.445            150.977                         201.607                    277                 277            399                        1.067

</div></body></html>
:::
::::

#### Máximo de 24 UPAs por agência (\~2 UPAs por mês)

:::: cell
::: cell-output-display
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><div id="rupfiswicc" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

                           agencia_nome                  custo_combustivel_jurisdicao   custo_combustivel_otimo   custo_diarias_jurisdicao   custo_diarias_otimo   distancia_total_km_jurisdicao   distancia_total_km_otimo   n_upas_jurisdicao   n_upas_otimo   total_diarias_jurisdicao   total_diarias_otimo
  ------------------------ ----------------------------- ------------------------------ ------------------------- -------------------------- --------------------- ------------------------------- -------------------------- ------------------- -------------- -------------------------- ---------------------
                           CAMAÇARI                      R\$4.325                       R\$8.315                  R\$0                       R\$11.222             7.209                           13.859                     14                  24             0                          34
                           CONCEIÇÃO DO COITÉ            R\$1.936                       R\$8.782                  R\$3.182                   R\$35.008             3.226                           14.637                     6                   23             10                         104
                           CRUZ DAS ALMAS                R\$1.080                       R\$7.600                  R\$0                       R\$38.190             1.801                           12.667                     5                   24             0                          114
                           FEIRA DE SANTANA              R\$2.673                       R\$4.316                  R\$0                       R\$3.182              4.454                           7.194                      20                  24             0                          10
                           IRECÊ                         R\$1.281                       R\$9.701                  R\$0                       R\$57.285             2.136                           16.168                     4                   22             0                          171
                           ITABUNA                       R\$1.471                       R\$7.247                  R\$6.365                   R\$44.555             2.452                           12.079                     6                   24             19                         133
                           ITAMARAJU                     R\$1.198                       R\$6.247                  R\$6.365                   R\$57.285             1.997                           10.412                     8                   24             19                         171
                           JAGUAQUARA                    R\$1.843                       R\$7.639                  R\$0                       R\$46.230             3.072                           12.732                     7                   24             0                          138
                           RIBEIRA DO POMBAL             R\$2.032                       R\$8.127                  R\$9.548                   R\$54.270             3.386                           13.545                     8                   24             28                         162
                           SANTA MARIA DA VITÓRIA        R\$2.590                       R\$11.051                 R\$6.365                   R\$57.285             4.317                           18.418                     8                   24             19                         171
                           SENHOR DO BONFIM              R\$1.888                       R\$5.559                  R\$3.182                   R\$35.008             3.146                           9.265                      6                   16             10                         104
                           VITÓRIA DA CONQUISTA          R\$4.033                       R\$6.724                  R\$25.460                  R\$44.555             6.722                           11.206                     18                  24             76                         133
                           ALAGOINHAS                    R\$1.346                       NA                        R\$0                       NA                    2.243                           NA                         6                   NA             0                          NA
                           BARREIRAS                     R\$1.368                       NA                        R\$12.730                  NA                    2.279                           NA                         6                   NA             38                         NA
                           BOM JESUS DA LAPA             R\$1.101                       NA                        R\$0                       NA                    1.836                           NA                         3                   NA             0                          NA
                           BRUMADO                       R\$206                         NA                        R\$3.182                   NA                    343                             NA                         1                   NA             10                         NA
                           CACHOEIRA                     R\$9                           NA                        R\$0                       NA                    15                              NA                         1                   NA             0                          NA
                           CIPÓ                          R\$873                         NA                        R\$3.182                   NA                    1.455                           NA                         3                   NA             10                         NA
                           ESPLANADA                     R\$1.749                       NA                        R\$3.182                   NA                    2.915                           NA                         4                   NA             10                         NA
                           EUCLIDES DA CUNHA             R\$2.721                       NA                        R\$12.730                  NA                    4.535                           NA                         7                   NA             38                         NA
                           EUNÁPOLIS                     R\$418                         NA                        R\$0                       NA                    697                             NA                         3                   NA             0                          NA
                           GUANAMBI                      R\$2.375                       NA                        R\$3.182                   NA                    3.958                           NA                         6                   NA             10                         NA
                           IBOTIRAMA                     R\$1.615                       NA                        R\$9.548                   NA                    2.692                           NA                         6                   NA             28                         NA
                           ILHÉUS                        R\$1.745                       NA                        R\$15.912                  NA                    2.909                           NA                         9                   NA             48                         NA
                           IPIAÚ                         R\$2.125                       NA                        R\$9.548                   NA                    3.542                           NA                         8                   NA             28                         NA
                           IPIRÁ                         R\$858                         NA                        R\$0                       NA                    1.431                           NA                         3                   NA             0                          NA
                           ITABERABA                     R\$766                         NA                        R\$3.182                   NA                    1.277                           NA                         4                   NA             10                         NA
                           ITAPETINGA                    R\$1.588                       NA                        R\$9.548                   NA                    2.647                           NA                         6                   NA             28                         NA
                           JACOBINA                      R\$1.761                       NA                        R\$12.730                  NA                    2.935                           NA                         7                   NA             38                         NA
                           JEQUIÉ                        R\$424                         NA                        R\$0                       NA                    706                             NA                         3                   NA             0                          NA
                           JEREMOABO                     R\$148                         NA                        R\$3.182                   NA                    246                             NA                         1                   NA             10                         NA
                           JUAZEIRO                      R\$297                         NA                        R\$3.182                   NA                    494                             NA                         4                   NA             10                         NA
                           LIVRAMENTO DE NOSSA SENHORA   R\$1.091                       NA                        R\$3.182                   NA                    1.819                           NA                         4                   NA             10                         NA
                           MORRO DO CHAPÉU               R\$1.485                       NA                        R\$0                       NA                    2.476                           NA                         3                   NA             0                          NA
                           PAULO AFONSO                  R\$451                         NA                        R\$0                       NA                    752                             NA                         5                   NA             0                          NA
                           POÇÕES                        R\$528                         NA                        R\$9.548                   NA                    880                             NA                         3                   NA             28                         NA
                           PORTO SEGURO                  R\$1.085                       NA                        R\$3.182                   NA                    1.808                           NA                         4                   NA             10                         NA
                           REMANSO                       R\$9                           NA                        R\$0                       NA                    15                              NA                         1                   NA             0                          NA
                           RIACHÃO DO JACUÍPE            R\$15                          NA                        R\$0                       NA                    25                              NA                         1                   NA             0                          NA
                           SANTA RITA DE CÁSSIA          R\$1.120                       NA                        R\$12.730                  NA                    1.867                           NA                         4                   NA             38                         NA
                           SANTO AMARO                   R\$3.453                       NA                        R\$0                       NA                    5.755                           NA                         10                  NA             0                          NA
                           SANTO ANTÔNIO DE JESUS        R\$1.046                       NA                        R\$9.548                   NA                    1.743                           NA                         8                   NA             28                         NA
                           SÃO FRANCISCO DO CONDE        R\$788                         NA                        R\$0                       NA                    1.314                           NA                         3                   NA             0                          NA
                           SEABRA                        R\$743                         NA                        R\$3.182                   NA                    1.239                           NA                         2                   NA             10                         NA
                           SERRINHA                      R\$1.248                       NA                        R\$0                       NA                    2.081                           NA                         6                   NA             0                          NA
                           TEIXEIRA DE FREITAS           R\$888                         NA                        R\$12.730                  NA                    1.479                           NA                         7                   NA             38                         NA
                           VALENÇA                       R\$2.257                       NA                        R\$25.460                  NA                    3.762                           NA                         12                  NA             76                         NA
                           XIQUE-XIQUE                   R\$354                         NA                        R\$6.365                   NA                    589                             NA                         3                   NA             19                         NA
  Total Superintendência   ---                           R\$66.407                      R\$91.308                 R\$251.418                 R\$484.075            110.678                         152.180                    277                 277            750                        1.445

</div></body></html>
:::
::::

------------------------------------------------------------------------

## Apêndice: Detalhes técnicos do problema de otimização

Este apêndice detalha o problema de otimização que o pacote orce
resolve, que é a alocação ideal de Unidades de Coleta (UCs) às agências,
com o objetivo de minimizar os custos totais, incluindo custos de
deslocamento e custos fixos de cada agência. O modelo de otimização é
baseado no problema clássico de localização de armazéns.

### O Desafio

Dadas as localizações das UCs e das agências, a tarefa é decidir quais
agências serão utilizadas e como as UPAs serão distribuídas entre elas.
Em outras palavras, precisamos decidir simultaneamente:

-   Quais agências treinar/contratar.
-   Como alocar as UC a cada agência.

Começamos com um conjunto de UCs $U = \{1 \ldots n\}$ e um conjunto de
agências potenciais $A = \{1 \ldots m\}$ que poderiam ser ativadas.
Também temos uma função de custo que fornece o custo de viagem de uma
agência para uma UC. Além disso, há um custo fixo (incluindo custos de
treinamento, entre outros) associado a cada agência, caso ela seja
selecionada para a coleta de dados. Agências com um pequeno número de
UCs podem ser inviáveis. Agências no interior com um grande número de
UCs também podem ser inviáveis. A solução deve ter pelo menos *min_upas*
e no máximo *max_upas* por agência ativada. Observe que, ao permitir a
coleta "semi-centralizada", não há limite para o número de UCs nas
agências listadas.

Para modelar essa situação, usamos duas variáveis de decisão:

-   $x_{i,j}$: uma variável binária que assume o valor 1 se a UC $i$ for
    alocada à agência $j$ e 0 caso contrário.

-   $y_j$: uma variável binária que assume o valor 1 se a agência $j$
    for selecionada para realizar a coleta e 0 caso contrário.

$$
\begin{equation*}
\begin{array}{ll@{}ll}
\text{minimizar} & \displaystyle\sum\limits_{i=1}^{n}\sum\limits_{j=1}^{m} custo\_de\_viagem_{i,j} \cdot x_{i, j} + \sum\limits_{j=1}^{m} custo\_fixo_{j} \cdot y_{j}& &\\
\text{sujeito a} & \displaystyle\sum\limits_{j=1}^{m} x_{i, j} = 1 & i=1 ,\ldots, n&\\
& \displaystyle x_{i, j} \leq y_j, & i=1 ,\ldots, n & j=1 ,\ldots, m&\\
& x_{i,j} \in \{0,1\} &i=1 ,\ldots, n, & j=1 ,\ldots, m \\
& y_{j} \in \{0,1\} &j=1 ,\ldots, m& \\
& \operatorname{(opcional)} \sum\limits_{i=1}^{n}{x}_{i,j} >= ( \operatorname{min\_upas} \cdot y_{j}) & j=1 ,\ldots, m&
\\
& \operatorname{(opcional)} \sum\limits_{i=1}^{n}{x}_{i,j} <= \operatorname{max\_upas}_{j} & j=1 ,\ldots, m&
\end{array}
\end{equation*}
$$

**Explicação:**

-   **Função Objetivo:** Minimizar o custo total, que é a soma dos
    custos de viagem para cada UC alocada a uma agência e dos custos
    fixos de cada agência ativada.
-   **Restrições:**
    -   **Cada UC deve ser alocada a exatamente uma agência.**
    -   **Uma agência só pode receber UCs se estiver ativa.**
    -   **Opcional:** Cada agência ativada deve ter pelo menos
        `min_upas` UCs alocadas.
    -   **Opcional:** Cada agência ativada deve ter no máximo `max_upas`
        UCs alocadas.

**Variáveis de Decisão:**

-   **x\[i, j\]**: Indica se a UC `i` é alocada à agência `j` (1 se sim,
    0 se não).
-   **y\[j\]**: Indica se a agência `j` está ativa (1 se sim, 0 se não).

Este modelo matemático representa o problema de alocação ótima e é
resolvido pelo pacote `orce` para encontrar a solução que minimiza os
custos totais, considerando as restrições e os custos específicos de
cada cenário.

## Apêndice: Função principal: `alocar_ucs`

A função `alocar_ucs` realiza a alocação otimizada de Unidades de Coleta
(UCs) às agências, buscando minimizar os custos totais de deslocamento e
operação. O processo de otimização considera diversas variáveis e
restrições para encontrar a solução mais eficiente.

**Entradas da Função**

-   **Dados das UCs (`ucs`)**:
    -   `uc`: código único da UC
    -   `agencia_codigo`: código da agência à qual a UC está atualmente
        alocada
    -   `dias_coleta`: número de dias de coleta na UC
    -   `viagens`: número de viagens necessárias para a coleta na UC
-   **Dados das Agências (`agencias`)**: (opcional, se não fornecido,
    assume as agências das UCs)
    -   `agencia_codigo`: código único da agência
-   **Parâmetros de Custo**:
    -   `custo_litro_combustivel`: custo do combustível por litro
    -   `custo_hora_viagem`: custo por hora de viagem
    -   `kml`: consumo médio de combustível do veículo (km/l)
    -   `valor_diaria`: valor da diária
    -   `custo_fixo`: custo fixo mensal da agência
    -   `dias_treinamento`: número de dias/diárias para treinamento
    -   `adicional_troca_jurisdicao`: custo adicional por troca de
        jurisdição
-   **Restrições de Alocação**:
    -   `dist_diaria_km`: distância mínima para pagamento de diária
    -   `min_uc_agencia`: número mínimo de UCs por agência (exceto
        agências treinadas)
    -   `max_uc_agencia`: número máximo de UCs por agência
    -   `semi_centralizada`: vetor com códigos de agências sem limite
        máximo de UCs
    -   `agencias_treinadas`: vetor com códigos de agências já treinadas
        (sem custo de treinamento)
    -   `agencias_treinamento`: código da(s) agência(s) de treinamento
-   **Dados de Distância**:
    -   `distancias_ucs`: distâncias entre UCs e agências
    -   `distancias_agencias`: distâncias entre as agências
-   **Outras Opções**:
    -   `resultado_completo`: se TRUE, retorna informações adicionais
        sobre todas as combinações de UCs e agências

**Processamento Interno**

1.  **Pré-processamento**:
    -   Verifica se os argumentos de entrada são válidos
    -   Define o número máximo de UCs por agência, se não fornecido
    -   Cria a alocação por jurisdição (se `agencias` não for fornecido,
        assume as agências das UCs)
    -   Seleciona a agência de treinamento mais próxima para cada
        agência de coleta
    -   Calcula os custos de treinamento com base na distância e se a
        agência já foi treinada
    -   Combina informações de UCs e agências em um formato adequado
        para a otimização
    -   Calcula os custos de transporte (combustível, tempo de viagem,
        diárias) para cada combinação de UC e agência
2.  **Modelagem da Otimização**:
    -   Utiliza o pacote `ompr` para criar um modelo de otimização
    -   Define variáveis de decisão:
        -   `x[i, j]`: 1 se a UC `i` for alocada à agência `j`, 0 caso
            contrário
        -   `y[j]`: 1 se a agência `j` for incluída na solução, 0 caso
            contrário
    -   Define a função objetivo: minimizar o custo total
        (deslocamento + custos fixos das agências + custos de
        treinamento)
    -   Adiciona restrições:
        -   Cada UC deve ser alocada a exatamente uma agência
        -   Se uma UC é alocada a uma agência, a agência deve estar
            ativa
        -   Restrições de número mínimo e máximo de UCs por agência (se
            aplicável)
3.  **Solução da Otimização**:
    -   Resolve o modelo usando o solver GLPK
    -   Extrai a solução ótima: quais UCs são alocadas a quais agências
4.  **Pós-processamento**:
    -   Cria tabelas com os resultados da alocação ótima e da alocação
        original (por jurisdição), tanto para UCs quanto para agências
    -   Se `resultado_completo` for TRUE, retorna também um `tibble` com
        todas as combinações de UCs e agências e seus respectivos custos

**Saídas da Função**

-   `resultado_ucs_otimo`: alocação ótima das UCs e seus custos
-   `resultado_ucs_jurisdicao`: alocação original das UCs e seus custos
-   `resultado_agencias_otimo`: alocação ótima das agências, custos e
    número de UCs alocadas
-   `resultado_agencias_jurisdicao`: alocação original das agências,
    custos e número de UCs alocadas
-   `ucs_agencias_todas` (opcional): todas as combinações de UCs e
    agências e seus custos

**Observações**

-   O cálculo de diárias já considera jurisdição, microrregiões, áreas
    metropolitanas e distância/necessidade de pernoite.
-   A flexibilidade do pacote permite ajustar os parâmetros e restrições
    para atender às necessidades específicas do planejamento da coleta
    de dados.

[^1]: Foram excluídas Superintendências Estaduais onde não há rotas
    rodoviárias para todos os municípios: 13, 15, 53
