---
abstract: Apresentamos o pacote R `orce`, uma ferramenta criada para
  otimizar a alocação de Unidades de Coleta em pesquisas do IBGE, com o
  objetivo de minimizar os custos totais. Por meio de um modelo de
  otimização baseado em programação linear inteira mista, o pacote
  considera fatores como distâncias, tempo de viagem, custos fixos das
  agências e necessidade de diárias para encontrar a distribuição ideal
  das unidades de coleta. Estudos de caso realizados com a Pesquisa
  Nacional de Saúde (PNS) no Espírito Santo e a Pesquisa de Orçamentos
  Familiares (POF) na Bahia demonstram o potencial do orce para alcançar
  reduções significativas nos custos de coleta, chegando a até 40%. Além
  da economia financeira, o pacote promove um melhor balanceamento da
  carga de trabalho entre as agências e oferece flexibilidade para se
  adaptar às necessidades e restrições específicas de cada pesquisa. O
  artigo explora estratégias adicionais de otimização, como a
  reorganização da jurisdição das agências e o ajuste do tempo de viagem
  considerado para o pagamento de diárias. A análise dos resultados
  reforça a importância da redução dos custos fixos como fator crucial
  para alcançar maior eficiência e economia na coleta de dados. O `orce`
  demonstra potencial para melhorar a eficiência e reduzir custos na
  coleta de dados do IBGE, viabilizando pesquisas de alta qualidade com
  recursos otimizados."
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
  horas_viagem_pernoite: 1.5
  valor_diaria: 335
  viagens: 1
title: Otimizando a Coleta de Dados do IBGE com o Pacote R 'orce'
toc-title: Índice
---

# Introdução

A otimização da coleta de dados é um desafio comum em instituições de
pesquisa que lidam com grandes volumes de informações distribuídas
geograficamente. No caso do IBGE, a necessidade de otimizar a alocação
das Unidades de Coleta (UCs) se torna essencial, dada a complexidade
logística e os elevados custos envolvidos no processo.

As pesquisas MUNIC (Pesquisa de Informações Básicas Municipais) e POF
(Pesquisa de Orçamentos Familiares) são dois exemplos que ilustram a
importância dessa otimização. A MUNIC, que coleta dados sobre a gestão e
estrutura dos municípios brasileiros, e a POF, que investiga os hábitos
de consumo das famílias brasileiras, envolvem a coleta de dados em
milhares de domicílios e municípios, gerando altos custos logísticos.

O pacote orce é uma ferramenta projetada para otimizar a alocação de
Unidades de Coleta (UCs), como setores censitários, prefeituras de
municípios ou estabelecimentos de ensino, às agências do IBGE. A
eficiência dessa alocação é fundamental para garantir a coleta de dados
de forma econômica e eficaz em pesquisas e censos de grande escala, como
o Censo Demográfico.

Coletar dados em milhares de domicílios espalhados por um vasto
território é um grande desafio. O orce entra em ação para ajudar a
definir a melhor estratégia, minimizando o tempo de deslocamento e os
custos envolvidos.

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
2.  Quando o tempo de viagem é maior que horas, paga-se diária, mesmo se
    na jurisdição da agência.
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
<html><body><div id="pdeexjqaaf" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

  Uc        Agencia Codigo   Dias Coleta   Viagens
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
<html><body><div id="muovmvktbx" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

  Agencia Codigo   Municipio Codigo   Diaria Municipio
  ---------------- ------------------ ------------------
  320020100        3200102            TRUE
  320120900        3200102            FALSE
  320130800        3200102            TRUE
  320150600        3200102            TRUE
  320240500        3200102            TRUE
  320320500        3200102            TRUE
  320490600        3200102            TRUE
  320500200        3200102            TRUE
  320520000        3200102            TRUE
  320530900        3200102            TRUE

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
<html><body><div id="ksqoybsnny" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

  Agencia Codigo   Uc        Distancia Km   Duracao Horas   Diaria Municipio   Diaria Pernoite
  ---------------- --------- -------------- --------------- ------------------ -----------------
  320020100        3200102   132,51         2,2             TRUE               TRUE
  320120900        3200102   119,44         2,03            FALSE              TRUE
  320130800        3200102   134,24         1,86            TRUE               TRUE
  320150600        3200102   111,28         1,73            TRUE               TRUE
  320240500        3200102   159,66         2,23            TRUE               TRUE
  320320500        3200102   184,21         3,25            TRUE               TRUE
  320490600        3200102   267,44         4,59            TRUE               TRUE
  320500200        3200102   162,79         2,32            TRUE               TRUE
  320520000        3200102   148,3          2,2             TRUE               TRUE
  320530900        3200102   146,31         2,14            TRUE               TRUE

</div></body></html>
:::
::::

Observação: A coluna `diaria_pernoite` é calculada com base na duração
da viagem (ida). A partir de 1,5, são pagas diárias, mesmo se na
jurisdição da agência.

Estamos, agora, prontos para calcular os custos de coleta.

#### Custos por agência

:::: cell
::: cell-output-display
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><div id="lgyvgnojzv" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

                              Municipios   Total Diarias   Custo Diarias   Distancia Total Km   Custo Combustivel
  --------------------------- ------------ --------------- --------------- -------------------- -------------------
                                                                                                
  Alegre                      14           1,5             R\$502          2.723                R\$1.634
  Cachoeiro de Itapemirim     10           3               R\$1.005        1.892,12             R\$1.135
  Cariacica                   8            3               R\$1.005        1.347,08             R\$808
  Colatina                    12           7,5             R\$2.512        2.605,74             R\$1.563
  Guarapari                   9            1,5             R\$502          1.799,58             R\$1.080
  Linhares                    9            1,5             R\$502          1.796,6              R\$1.078
  Serra                       3            0               R\$0            414,28               R\$249
  São Mateus                  11           6               R\$2.010        2.259,2              R\$1.356
  Vila Velha                  1            0               R\$0            3,32                 R\$2
  Vitória                     1            0               R\$0            21,08                R\$13
  Total da Superintendência   78           24              R\$8.040        14.862               R\$8.917

</div></body></html>
:::
::::

#### Custos por município

:::: cell
::: cell-output-display
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><div id="yuxnzcnxul" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

  Municipio                Agencia                   Custo Diarias   Custo Combustivel
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
<html><body><div id="imhrssufrm" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

  Agencia                   Distancia Km   Custo Diarias   Custo Combustivel
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
<html><body><div id="wjgcblzerh" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

  Municipio               Agencia                   Distancia Km   Custo Diarias   Custo Combustivel
  ----------------------- ------------------------- -------------- --------------- -------------------
  Governador Lindenberg   Colatina                  50,87          R\$0            R\$122
  Presidente Kennedy      Cachoeiro de Itapemirim   38,27          R\$335          R\$92
  Itaguaçu                Colatina                  54,89          R\$335          R\$132
  Itarana                 Colatina                  66,5           R\$335          R\$160
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
<html><body><div id="cjfydlgxso" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

  Municipio            Agencia Otimo             Agencia Jurisdicao        Distancia Km Otimo   Distancia Km Jurisdicao   Custo Deslocamento Otimo   Custo Deslocamento Jurisdicao
  -------------------- ------------------------- ------------------------- -------------------- ------------------------- -------------------------- -------------------------------
  Presidente Kennedy   Cachoeiro de Itapemirim   Guarapari                 38,27                113,37                    R\$455                     R\$676
  Itaguaçu             Colatina                  Cariacica                 54,89                119,31                    R\$501                     R\$683
  Itarana              Colatina                  Cariacica                 66,5                 108,73                    R\$537                     R\$668
  Laranja da Terra     Colatina                  Cachoeiro de Itapemirim   88,22                153,06                    R\$605                     R\$738

</div></body></html>
:::
::::

::::::: cell
::: cell-output-display
![](munic_rmd_files/figure-markdown/unnamed-chunk-17-1.png)
:::

::: cell-output-display
![](munic_rmd_files/figure-markdown/unnamed-chunk-17-2.png)
:::

::: cell-output-display
![](munic_rmd_files/figure-markdown/unnamed-chunk-17-3.png)
:::

::: cell-output-display
![](munic_rmd_files/figure-markdown/unnamed-chunk-17-4.png)
:::
:::::::

#### Resumo da otimização

:::: cell
::: cell-output-display
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><div id="cdfaofpzut" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

  Name                 Jurisdicao   Otimo       Reducao   Reducao Pct
  -------------------- ------------ ----------- --------- -------------
  custo_diarias        8.040        7.370       670       8,3%
  custo_combustivel    8.917,2      8.918,75    −1,55     −0,0%
  custo_horas_viagem   2.531,6      2.532,8     −1,2      −0,0%
  total                19.488,8     18.821,55   667,25    3,4%
  n_agencias           10           10          0         0,0%

</div></body></html>
:::
::::

Utilizando o plano otimizado, com 4 alterações de agência de coleta, é
possível economizar 8% no valor das diárias, gastando apenas 0% a mais
em combustível.

### Resultados para outras Superintendências Estaduais[^1]

:::: cell
::: cell-output-display
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><div id="dermhrnhsr" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

                                          Jurisdição r   Ótimo r     Redução r   Redução
  ----------------- --------------------- -------------- ----------- ----------- ---------
  Centro Oeste                                                                   
                    Goiás                 78.312         74.151      4.161       5,3%
                    Mato Grosso           69.773         67.477      2.297       3,3%
                    Mato Grosso do Sul    24.675         24.140      535         2,2%
  Total da Região   ---                   172.761        165.768     6.993       ---
  Nordeste                                                                       
                    Bahia                 97.099         91.748      5.352       5,5%
                    Maranhão              71.841         68.103      3.737       5,2%
                    Piauí                 71.613         69.710      1.903       2,7%
                    Rio Grande do Norte   26.727         25.322      1.404       5,3%
                    Ceará                 42.860         41.644      1.216       2,8%
                    Paraíba               38.651         38.178      473         1,2%
                    Pernambuco            27.336         27.009      327         1,2%
                    Alagoas               10.327         10.002      324         3,1%
                    Sergipe               9.363          9.231       132         1,4%
  Total da Região   ---                   395.816        380.948     14.868      ---
  Norte                                                                          
                    Tocantins             58.107         57.074      1.033       1,8%
                    Acre                  10.562         9.959       602         5,7%
                    Rondônia              23.711         23.314      397         1,7%
                    Roraima               9.806          9.806       0           0,0%
                    Amapá                 11.193         11.193      0           0,0%
  Total da Região   ---                   113.379        111.347     2.032       ---
  Sudeste                                                                        
                    Minas Gerais          182.764        178.514     4.251       2,3%
                    São Paulo             68.994         67.919      1.075       1,6%
                    Espírito Santo        19.489         18.822      667         3,4%
                    Rio de Janeiro        11.783         11.783      0           0,0%
  Total da Região   ---                   283.030        277.037     5.993       ---
  Sul                                                                            
                    Rio Grande do Sul     98.559         92.542      6.018       6,1%
                    Santa Catarina        42.431         39.476      2.955       7,0%
                    Paraná                60.228         59.806      422         0,7%
  Total da Região   ---                   201.218        191.824     9.394       ---
  Total Brasil      ---                   1.166.205      1.126.925   39.280      ---

</div></body></html>
:::
::::

## Caso 2. A importância dos custos fixos (salário e treinamento): calculando os custos da coleta da POF para a SES/Bahia

:::: cell
::: cell-output-display
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><div id="tgbpfcpkew" style="padding-left:0px;padding-right:0px;padding-top:10px;padding-bottom:10px;overflow-x:auto;overflow-y:auto;width:auto;height:auto;">
  

  Modelo                                                                              N Agencias   Custo Total   Custo Fixo Total   Custo Diarias   Custo Combustivel
  ----------------------------------------------------------------------------------- ------------ ------------- ------------------ --------------- -------------------
  sem custo fixo / sem custo de treinamento                                           0            −R\$18.142    R\$0               −R\$18.760      R\$363
  custo de treinamento / redução diárias por pernoite                                 −15          −R\$46.536    −R\$62.111         R\$2.010        R\$10.574
  custo de treinamento / limite de 24 UPAs por agência / adicional_troca_jurisdicao   −13          −R\$49.149    −R\$54.152         −R\$7.538       R\$9.897
  custo de treinamento                                                                −15          −R\$51.468    −R\$62.501         −R\$4.355       R\$12.120
  custo de treinamento / reorganização                                                −17          −R\$65.266    −R\$70.579         −R\$12.730      R\$14.180
  custo de treinamento + salario de 1 apm / limite de 24 UPAs por agência             −35          −R\$503.702   −R\$777.251        R\$237.012      R\$30.102
  custo de treinamento + salario de 1 apm                                             −37          −R\$510.744   −R\$821.790        R\$275.538      R\$29.137

  : Redução de custos promovido pela otimização da rede de coleta

</div></body></html>
:::
::::

A tabela demonstra o impacto da otimização da rede de coleta em
diferentes cenários, considerando custos fixos, diárias, combustível e
número de agências envolvidas[^2].

**Principais Observações:**

-   **Redução de Custos:** Em todos os cenários, a otimização resultou
    em redução significativa do custo total. A maior economia foi
    observada no cenário que inclui custos de treinamento e custos com
    salário ("custo de treinamento + salário de 1 apm"), com redução de
    R\$ 510.744.

-   **Impacto dos Custos Fixos:** A redução do número de agências e a
    consequente diminuição dos custos fixos (treinamento, salários,
    etc.) são os principais fatores que impulsionam a economia de
    custos. Isso fica evidente nos cenários que incluem o custo do
    salário dos entrevistadores, onde a redução de custos é mais
    expressiva.

-   **Custo de Deslocamento:** Em alguns cenários, o custo de
    deslocamento (combustível e diárias) aumenta após a otimização. Isso
    é explicado pela necessidade de percorrer distâncias maiores para
    cobrir as UCs com uma rede menor de agências. No entanto, esse
    aumento é mais do que compensado pela redução dos custos fixos,
    resultando em uma economia geral.

-   **Limite de UPAs por Agência:** A imposição de um limite de 24 UPAs
    por agência contribui para um melhor balanceamento da carga de
    trabalho, evitando a sobrecarga em algumas agências.

-   **Reorganização da Jurisdição:** A reorganização da jurisdição das
    agências também pode levar a uma redução de custos, embora em menor
    escala do que a redução de agências e a limitação de UPAs por
    agência.

## Conclusão

A otimização da rede de coleta promovida pelo pacote `orce` tem um
impacto significativo na redução de custos, principalmente pela
diminuição dos custos fixos associados às agências. A estratégia mais
eficaz envolve a combinação da redução do número de agências, a
imposição de limites de UPAs por agência e a reorganização da
jurisdição.

É importante ressaltar que a otimização deve considerar não apenas os
custos, mas também outros fatores como a qualidade dos dados coletados e
a capacidade operacional das agências. O pacote `orce` oferece
flexibilidade para ajustar os parâmetros e restrições do modelo,
permitindo encontrar a solução que melhor se adapta às necessidades e
particularidades de cada pesquisa.

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
\begin{array}{ll@{}ll}
\text{minimizar} & \displaystyle\sum\limits_{i=1}^{n}\sum\limits_{j=1}^{m} custo\_de\_viagem_{i,j} \cdot x_{i, j} + \sum\limits_{j=1}^{m} custo\_fixo_{j} \cdot y_{j}& &\\
\text{sujeito a} & \displaystyle\sum\limits_{j=1}^{m} x_{i, j} = 1 & i=1 ,\ldots, n&\\
& \displaystyle x_{i, j} \leq y_j, & i=1 ,\ldots, n & j=1 ,\ldots, m\\
& x_{i,j} \in \{0,1\} &i=1 ,\ldots, n, & j=1 ,\ldots, m \\
& y_{j} \in \{0,1\} &j=1 ,\ldots, m& \\
& \operatorname{(opcional)} \sum\limits_{i=1}^{n}{x}_{i,j} >= ( \operatorname{min\_upas} \cdot y_{j}) & j=1 ,\ldots, m&
\\
& \operatorname{(opcional)} \sum\limits_{i=1}^{n}{x}_{i,j} <= \operatorname{max\_upas}_{j} & j=1 ,\ldots, m&
\end{array}
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
    -   `min_uc_agencia`: número mínimo de UCs por agência (exceto
        agências treinadas)
    -   `max_uc_agencia`: número máximo de UCs por agência
    -   `semi_centralizada`: vetor com códigos de agências sem limite
        máximo de UCs
    -   `agencias_treinadas`: vetor com códigos de agências já treinadas
        (sem custo de treinamento)
    -   `agencias_treinamento`: código da(s) agência(s) de treinamento
-   **Dados de Distância**:
    -   `distancias_ucs`: distâncias entre UCs e agências, contendo:
    -   uc, agencia_codigo, duracao_horas, diaria_municipio,
        diaria_pernoite
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

[^2]: Observação: A coleta nas agências da capital, Salvador I e II, são
    excluídas do modelo, pois são muito maiores do que as demais, e têm
    coleta realizada pela supervisão estadual da Pesquisa.
