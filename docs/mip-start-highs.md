# MIP Start with HiGHS via ompr/ROI

How to provide an initial feasible solution (MIP start / warm start) to the
HiGHS solver when using the ompr → ROI pipeline.

## Why

A MIP start gives the solver a known feasible solution before branch-and-bound.
This can help when:

- The solver hits time limits before finding a good incumbent
- You want the solver to prefer a specific solution when alternatives are
  within `rel_tol` of optimal
- The problem is large and the default heuristics are slow to find a first
  feasible point

## How it works

HiGHS reads an initial solution from a `.sol` file via the `read_solution_file`
option. The file format is:

```
Model status
Unknown

# Primal solution values
Feasible
Objective <value>
# Columns <ncols>
C0 <val>
C1 <val>
...
```

Column indices are 0-based. The objective value can be approximate (HiGHS
re-evaluates it). Not all variables need correct values — HiGHS will attempt
to complete a partial solution.

## ROI registration

ROI.plugin.highs registers `read_solution_file` as an `"X"` (pass-through)
control, but only after the plugin is first loaded. To ensure it's available on
the first solve, register it in `.onLoad`:

```r
try({
  ROI::ROI_plugin_register_solver_control("highs",
                                          "read_solution_file", "X")
}, silent = TRUE)
```

## Column ordering in ompr MILPModel

`ompr::variable_keys(model)` returns variable names in the order they appear
as columns in the constraint matrix. Use regex to find specific variables:

```r
keys <- ompr::variable_keys(model)
ncols <- length(keys)

# Find x[i,j] positions
x_pattern <- "^x\\[(\\d+),(\\d+)\\]$"
x_mask <- grepl(x_pattern, keys)
x_cols <- which(x_mask)  # 1-based global column indices
```

Ordering rules (ompr MILPModel):
- Continuous variables come before integer/binary variables
- Within each type group, declaration order is preserved
- Multi-index variables iterate the first index fastest: x[1,1], x[2,1], ..., x[1,2], x[2,2], ...

## Writing a .sol file from an ompr solution

```r
.write_sol_file <- function(result, model) {
  keys <- ompr::variable_keys(model)
  ncols <- length(keys)
  sol_vals <- stats::setNames(rep(0, ncols), keys)
  sol_vals[names(result$solution)] <- result$solution

  sol_file <- tempfile(fileext = ".sol")
  lines <- c(
    "Model status",
    "Unknown",
    "",
    "# Primal solution values",
    "Feasible",
    paste("Objective", ompr::objective_value(result)),
    paste("#", "Columns", ncols),
    paste0("C", seq_len(ncols) - 1L, " ", unname(sol_vals))
  )
  writeLines(lines, sol_file)
  sol_file
}
```

## Passing to the solver

```r
sol_file <- .write_sol_file(previous_result, model)
on.exit(unlink(sol_file), add = TRUE)

result <- ompr::solve_model(
  model,
  ompr.roi::with_ROI(
    solver = "highs",
    rel_tol = 0.005,
    read_solution_file = sol_file
  )
)
```

## Jurisdiction-based approach (tested, removed)

We implemented and tested a jurisdiction-based MIP start:

1. Build the same model with `x[i, j_juris] == 1` constraints (fixing each UC
   to its jurisdiction agency)
2. Solve — this is essentially an LP since all binary variables are fixed, so
   it's very fast
3. Write the full solution (including optimal `w[j]`) as a `.sol` file
4. Use it as warm start for the real optimization

**Result**: tested across all 24 UFs at `rel_tol` from 0.005 to 0.10 — zero
difference in costs or reallocations. HiGHS finds the same solution with or
without the MIP start for the current problem sizes (up to ~400 UCs, ~80
agencies). The feature was removed to reduce code complexity.

The jurisdiction solve itself was kept because it produces solver-optimal
`w[j]` values for the jurisdiction report, replacing the previous heuristic
ceiling-based estimate.

## When to revisit

- TSP mode (`peso_tsp > 0`) with DFJ cuts — reusing the previous iteration's
  solution across cut rounds
- Much larger problems where the solver hits time limits
- Non-deterministic solver behavior at higher `rel_tol`
