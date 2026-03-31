# Jurisdiction-based MIP Start for HiGHS

## Overview

Add an optional MIP start that seeds the HiGHS solver with the jurisdiction
assignment (`x[i, j_juris] = 1` for each UC). Combined with `rel_tol`, the
solver only departs from jurisdiction when it finds something meaningfully
better — reducing unnecessary swaps when the cost difference is marginal.

## Problem

The solver sometimes reassigns UCs away from their jurisdiction agency even
when the alternative is only fractionally cheaper. This causes instability:
runs with slightly different parameters produce different assignments for no
operationally meaningful reason. The existing `adicional_troca_jurisdicao`
penalty helps but doesn't solve the problem for low-absolute-cost UCs.

## Design

### New parameter

`orce()` gains `mip_start = FALSE`. When `TRUE` and `solver == "highs"`,
the jurisdiction assignment is written to a `.sol` file and passed to HiGHS
via `read_solution_file`. For other solvers, the parameter is silently ignored.

### `.build_mip_start_sol()` internal function

Located in `orce.R`, before `.solve_once()`.

**Inputs:** `ucs_i`, `agencias_t`, `model` (ompr MILPModel).

**Logic:**

1. Map each UC `i` to its jurisdiction agency index `j` via
   `match(ucs_i$agencia_codigo_jurisdicao, agencias_t$agencia_codigo)`.
   If any UC's jurisdiction agency is missing from candidates, return `NULL`
   (no MIP start).

2. Use `ompr::variable_keys(model)` to discover column positions of `x[i,j]`
   variables. Parse keys with regex `^x\\[(\\d+),(\\d+)\\]$`. This is robust
   to any variable ordering (handles `n_entrevistadores_tipo` being
   `"continuous"` or `"integer"`, TSP variables, etc.).

3. Build a numeric vector of length `ncols` initialized to 0. Set
   `x[i, j_juris] = 1` for each UC.

4. Write the `.sol` file:
   ```
   Objective 0
   # Columns <ncols>
   C0 <val>
   C1 <val>
   ...
   ```

5. Return the temp file path.

### `.solve_once()` changes

Gains optional `sol_file` parameter. When `solver == "highs"` and `sol_file`
is not `NULL`, adds `read_solution_file = sol_file` to the `with_ROI()` call.

### Lifecycle

- Temp file created once before the solve/DFJ loop in `.orce_impl()`.
- Cleaned up via `on.exit(unlink(...))`.
- Reused across DFJ iterations.

### ROI registration

`read_solution_file` registered in `onLoad.R` so ROI passes it through to
HiGHS (same pattern as existing `rel_tol` → `mip_rel_gap` registration).

### Edge cases

| Case | Behavior |
|------|----------|
| Jurisdiction agency filtered out | No MIP start (returns NULL) |
| `alocar_por != "uc"` | Take first jurisdiction per grouped `i` |
| Infeasible jurisdiction (capacity) | HiGHS discards gracefully |
| TSP mode | Extra variables get 0, works the same |
| Non-HiGHS solver | Silently ignored |

## What it doesn't do

- Doesn't set `y[j]` or `w[j]` — HiGHS completes partial solutions.
- Doesn't change the model or objective — purely a solver hint.
- Doesn't affect non-HiGHS solvers.

## Testing strategy

- Unit test: `.build_mip_start_sol()` generates correct file format and column values.
- Integration test: `orce(mip_start = TRUE)` with HiGHS produces valid results.
- Regression: existing tests unaffected (default `mip_start = FALSE`).
- Edge case: missing jurisdiction agency returns NULL.

## Success criteria

- All existing tests pass.
- HiGHS log shows "Attempting to find feasible solution by solving MIP for
  user-supplied values" when `mip_start = TRUE`.
- Non-HiGHS solvers unaffected.
- Temp file cleaned up after solving.
