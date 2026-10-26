# Assignment 6B — Phase 2 proof (ELM, roll no 24BCS253)

Baseline: Phase 1 = PR #19, tag `phase1-final` (5e17a70). Phase 2 branch: `elm-phase2-24BCS253`.
Model: qwen2.5-coder:7b (Q4_K_M) via Ollama, used through `logs/ollama-gen.ps1`. Every prompt and full response is in `model_chat.md` (18 prompts; prompt files in `prompts/`).

## What was reviewed
Full review, use-case coverage table and defect list: `01_review.md` (D1–D10).

## What was fixed / added
| Item | Produced by | Evidence |
|---|---|---|
| D1–D7 backend defects (withdraw/cancel permissions, balance crash, 404/409 handling, permission manifest, transaction + row lock, apply permission, error messages) | qwen (re-applied 2026-10-11 outputs) | `e2e_run2.txt` 21/21 |
| Admin services/endpoints (leave types, balance allotment — UC-014 minimal) | qwen | `e2e_run2.txt` |
| `modules/elm/tests/test_leave.py`, 14 tests | qwen (3 rounds) + manual rewrite of 6 multi-step tests | `pytest_elm_run4.txt` 14/14 |
| Frontend: `api.ts`, routes, registry entry, 5 pages | qwen (p2_03–p2_11 + 3 TS fix rounds) | `tsc_run1..5.txt` |
| Frontend runtime fixes (LeaveBalancePage imports, ApplyLeavePage Select handler, LeaveTypesPage input types), unused imports, notification text | manual | `01_review.md` "Manual edit (2026-10-26)" |
| Lint (ruff, 56) and OpenAPI schema fixes so CI passes; no behaviour change | manual | `01_review.md` "CI readiness", `check.txt` |

## Results
| Check | Result | File |
|---|---|---|
| End-to-end through real Fusion + IAM logins | 21/21 | `e2e_run2.txt` |
| ELM pytest | 14/14 | `pytest_elm_run4.txt` |
| Full Fusion test suite | green, no regressions | `01_review.md` |
| TypeScript errors in ELM pages | 58 → 36 → 33 → 27 → 7 → **0** | `tsc_run1.txt` … `tsc_run5.txt` |
| `make check-client` (typecheck + client tests + build) | pass | — |
| `make check` (Django check, migrations, ruff, import contracts, nav/route, permission manifest, schema, pytest) | pass (after manual lint/schema fixes) | `check.txt` |

## Findings about the model
- With a long example page in context, the 7B model copied it verbatim (3 of 5 pages were the placement page renamed).
- Hardcoded dates and wrong actors persisted in long tests despite explicit instructions.
- Later fix rounds had diminishing returns; it re-made the same mistakes on files it had already seen even when given the exact compiler error lines.
- Works well for short, single-file tasks with a small reference sheet instead of a full example.

## Not done (documented gaps)
Unit Head routing (UC-003/004), substitutes (UC-002/019), extension (UC-009), resumption (UC-010/011), printable application, holiday calendar, offline leave, SLA, year-end processing.
