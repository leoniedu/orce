# Quick test for the fixed distancia_tsp_min implementation
devtools::load_all()
# Test with very simple data including close UCs
set.seed(123)
result <- teste_orce_tsp(
  n_agencias = 2,
  n_ucs = 4,
  n_periodos = 1,
  peso_tsp = 0.5,
  distancia_tsp_min = 60,  # 60km threshold
  solver = "cbc"
)

cat("✓ Test completed successfully!\n")
cat("Status:", attr(result, "solucao_status"), "\n")
