# orce:  <span style="color:red">O</span>timização da <span style="color:red">R</span>ede de <span style="color:red">C</span>oleta <span style="color:red">E</span>statística (Optimizing statistical data collection networks)

## English 

The `orce` package is an R package designed to optimize the allocation of primary sampling units (PSUs), such as census tracts or health facilities, to IBGE (Brazilian Institute of Geography and Statistics) agencies. This allocation process is crucial for efficient and cost-effective data collection in large-scale surveys and censuses. The package addresses several challenges inherent to this process, including:

1. **Routing and Geocoding**: Determining the optimal routes between PSUs and agencies requires accurate location data. The `orce` package leverages the CNEFE (National Register of Addresses for Statistical Purposes) database to obtain precise coordinates for each PSU, prioritizing high-density areas within census tracts to ensure accessibility and representativeness. The `ponto_setor_densidade` function aids in identifying these representative locations.

2. **Allocation Optimization**: The core of the `orce` package is its allocation optimization algorithm. It employs mixed-integer linear programming to minimize the overall cost of data collection, considering factors like travel distances, travel time, and fixed agency costs. The `alocar_upas` function implements this optimization, allowing for flexible constraints on agency capacity and location preferences.

3. **Cost Calculation**: Accurately estimating the cost of data collection involves more than just distances and travel time. The `orce` package incorporates knowledge of administrative boundaries to determine whether "diárias" (travel allowances) are applicable. This nuanced cost calculation ensures that the optimization results reflect the true financial implications of different allocation scenarios.

4. **Flexibility and Adaptability**: The `orce` package offers various customization options to accommodate the specific needs of different surveys and data collection efforts. Users can define parameters such as fuel costs, hourly travel costs, vehicle fuel efficiency, and agency-specific constraints. The package also supports sequential allocation across multiple time periods (e.g., quarters), allowing for dynamic adjustments to the allocation plan.

In summary, the `orce` package provides a powerful and versatile solution for optimizing the allocation of PSUs to IBGE agencies. By addressing challenges related to routing, geocoding, allocation optimization, and cost calculation, it enables efficient and cost-effective data collection strategies. Its flexibility and adaptability make it a valuable tool for a wide range of survey and census operations in Brazil. 



---------

## Português 
O pacote orce é um pacote R projetado para otimizar a alocação de unidades primárias de amostragem (UPAs), como setores censitários ou estabelecimentos de saúde, às agências do IBGE (Instituto Brasileiro de Geografia e Estatística). Esse processo de alocação é crucial para a coleta de dados eficiente e econômica em pesquisas e censos de grande escala. O pacote aborda vários desafios inerentes a esse processo, incluindo:

Roteamento e Geocodificação: A determinação das rotas ideais entre as UPAs e as agências requer dados de localização precisos. O pacote orce utiliza o banco de dados do CNEFE (Cadastro Nacional de Endereços para Fins Estatísticos) para obter coordenadas precisas para cada UPA, priorizando áreas de alta densidade dentro dos setores censitários para garantir acessibilidade e representatividade. A função ponto_setor_densidade auxilia na identificação desses locais representativos.

Otimização da Alocação: O núcleo do pacote orce é seu algoritmo de otimização de alocação. Ele emprega programação linear inteira mista para minimizar o custo total da coleta de dados, considerando fatores como distâncias de viagem, tempo de viagem e custos fixos das agências. A função alocar_upas implementa essa otimização, permitindo restrições flexíveis na capacidade da agência e nas preferências de localização.

Cálculo de Custos: Estimar com precisão o custo da coleta de dados envolve mais do que apenas distâncias e tempo de viagem. O pacote orce incorpora o conhecimento das fronteiras administrativas para determinar se as "diárias" (ajudas de custo para viagens) são aplicáveis. Esse cálculo de custo diferenciado garante que os resultados da otimização reflitam as verdadeiras implicações financeiras de diferentes cenários de alocação.

Flexibilidade e Adaptabilidade: O pacote orce oferece várias opções de personalização para acomodar as necessidades específicas de diferentes pesquisas e esforços de coleta de dados. Os usuários podem definir parâmetros como custos de combustível, custos de viagem por hora, eficiência de combustível do veículo e restrições específicas da agência. O pacote também suporta alocação sequencial em vários períodos de tempo (por exemplo, trimestres), permitindo ajustes dinâmicos ao plano de alocação.

Em resumo, o pacote orce fornece uma solução poderosa e versátil para otimizar a alocação de UPAs às agências do IBGE. Ao abordar os desafios relacionados ao roteamento, geocodificação, otimização de alocação e cálculo de custos, ele permite estratégias de coleta de dados eficientes e econômicas. Sua flexibilidade e adaptabilidade o tornam uma ferramenta valiosa para uma ampla gama de operações de pesquisa e censo no Brasil.
