# Phase 2 — Step 1/3/4: Review of the Phase-1 ELM implementation

Baseline: tag `phase1-final` (commit 5e17a70, PR #19). Model: qwen2.5-coder:7b (Q4_K_M) via Ollama.
Environment: WSL Ubuntu 24.04 — Postgres (fusionlab + fusion_integrated), IAM (Fusion_System_Administrator @ c25e703) on :8001, Fusion-Integrated on :8000.

## What Phase 1 contains
| Layer | Content |
|---|---|
| Models | LeaveType, LeaveBalance, LeaveApplication (status DRAFT/SUBMITTED/APPROVED/REJECTED/CANCELLED) |
| Services | apply, decide (single approver), withdraw, cancel_approved, count_days, get_balance |
| API | /api/v1/elm/: types, applications, applications/pending, …/decide, …/withdraw, …/cancel, balance |
| Registry | 5 permissions, roles Employee / Leave Approver / Leave Admin, 5 nav items |
| Frontend | none |
| Tests | none |

Build/run: `manage.py check` clean, `migrate` creates elm tables (verified 2026-10-12).

## Use-case coverage (spec: 03_ELM_Use_Case_Specifications_v1.4)
| UC | Name | Phase 1 |
|---|---|---|
| 001 | Apply for Leave | Partial — no categories/entitlements, no station leave, no substitute, no routing |
| 002 | Respond to Substitute Request | Missing |
| 003 | Unit Head review | Missing (single generic approver) |
| 004 | Verify/route higher-sanction | Missing |
| 005 | Final sanctioning decision | Partial (generic `decide`) |
| 007 | Withdraw pending | Present but broken (see D1) |
| 008 | Cancel approved leave | Present but broken (see D1) |
| 009 | Extension | Missing |
| 010/011 | Resumption | Missing |
| 012 | View balances/history | Partial, balance endpoint crashes (D2) |
| 013 | Printable application | Missing |
| 014 | Policy/hierarchy config | Missing (permission exists, nothing uses it — D4) |
| 015 | Holiday/RH calendar | Missing |
| 016/017 | Offline leave / record maintenance | Missing |
| 018/021 | SLA config / events | Missing |
| 019 | Replacement substitute | Missing |
| 020 | Year-end processing | Missing |

## Defects found (by review + running it)
| ID | Severity | Where | Problem |
|---|---|---|---|
| D1 | Critical | services/leave.py withdraw, cancel_approved | Require `leave_elm.application.withdraw` / `.cancel`, which are not declared in registry.py → nobody can ever withdraw or cancel (BR-EL-022/023 unreachable) |
| D2 | Critical | api/views.py MyBalanceView | Calls `get_balance(user, None, year, for_update=False)`; service takes 3 args and returns one row → TypeError (HTTP 500) every call |
| D3 | High | services/leave.py | `.get()` misses raise DoesNotExist → HTTP 500 instead of 404/409 |
| D4 | Critical (integration) | registry.py | `leave_elm.policy.manage` granted but unused → `make permissions` fails → roles cannot be published to IAM → module unusable through Fusion login |
| D5 | High | services/leave.py apply | Overlap + balance checks run outside the transaction and balance row is not locked → concurrent applications can overdraw balance |
| D6 | Medium | api/views.py MyApplicationsView | POST guarded only by `.view`, not `.apply` |
| D7 | Medium | services/leave.py | Error messages missing on ConflictError (generic text to user) |
| D8 | Low | registry.py | Stray outdated docstring mid-file; `# Added …` comments in config |
| D9 | High | whole module | No tests at all |
| D10 | High | client/ | No frontend pages although nav items point to /leave/* |

## Progress log

### 2026-10-12 — P0 fixed and verified
- Re-applied the model's own fix outputs from the 2026-10-11 session (prompts 04b, 04c, 05b, 05c, 07, 07b, 07c in logs/model1_chat.md; reverted then for Phase-1 rules): fixes D1–D7, adds admin services/endpoints (UC-014 minimal), registry docstring (D8 partial).
- `manage.py check` clean; `permission_manifest` now passes (D4); migrations in sync.
- Published roles to IAM (`setup_roles.sh`). Found an **environment issue**: IAM rebuilds designations from the ERP tables at every login (iam/sync.py `refresh_designations`), wiping `assign_role` grants. Worked around for local testing with `erp_grant.sh` (records designations in the local ERP dump). Also hit the IAM login throttle (5/min) — Fusion surfaces it as 401 "Incorrect username or password".
- End-to-end test through real logins (`e2e_smoke.py`): **21/21 pass** (e2e_run2.txt). Run 1 (e2e_run1.txt) failed entirely because of the role wipe above.

### 2026-10-12 — P1 automated tests (D9)
- qwen generated `modules/elm/tests/test_leave.py` (14 tests, prompt p2_01). Round 1: 4/14 pass — all failures were test bugs (sent leave-type code instead of id; wrong permission for /balance).
- Round 2 (p2_02, with diagnosis + serializer as context): 5/14. Round 3 (p2_06, explicit per-test rules): 8/14 — model kept hardcoded 2023 dates and the wrong actor in the 6 long multi-step tests despite explicit instructions (7B limit on long files).
- **Manual edit:** rewrote those 6 test functions (added `_apply`/`_approver` helpers, relative dates, correct applicant/approver). Intent unchanged. Result **14/14 pass**; full Fusion suite also green (no regressions).
- Finding: withdraw checks status before ownership, so a stranger withdrawing an already-cancelled request gets 409 instead of 403 (minor information leak about another user's request state).

### 2026-10-12 — P2 frontend (D10)
- qwen generated api.ts, routes.tsx, registry entry (p2_03) and 5 pages (p2_04, p2_05). Routes + registry correct.
- `npx tsc --noEmit` (tsc_run1.txt): **58 errors, all in ELM files**; rest of the client compiles.
  - api.ts: every URL prefixed "/api/v1/elm" although http baseURL is already "/api/v1" (would 404); broken invalidation helper (`useQueryClient` used as a type).
  - **LeaveBalancePage, LeaveApprovalsPage, LeaveTypesPage were verbatim copies of the placement MyApplicationsPage** given as the style example (same component name, placement imports). Finding: given a long example, the 7B model copies instead of adapting.
  - MyLeavePage: missing imports, paginated `results` assumed, leftover HistoryDrawer; ApplyLeavePage: unused imports.
- Fix strategy: one page per prompt, example page removed from context, short UI reference sheet (specs/fe_ui_notes.md) instead, compiler errors pasted into fix prompts (p2_07–p2_11).
- Round 2 (one fix prompt per page with that page's tsc errors): **58 → 36** (tsc_run2.txt), then **33** after re-checking (tsc_run3.txt). Still all in ELM pages.
- Round 3 (2026-10-25, `fix_ts_round.ps1 -Round 3`, prompts p2_ts_r3_*, 5 prompts — MyLeavePage was re-run once after the first attempt was killed with no response): **33 → 27** (tsc_run4.txt), all in ELM pages, rest of the client clean.
  - MyLeavePage: 9 → 4 (mutation argument types and ActionIcon/history leftovers fixed; unused imports remain).
  - ApplyLeavePage (2) and LeaveApprovalsPage (3): **same errors as before** — the model returned the file without fixing the listed lines.
  - LeaveBalancePage: 10 — still imports `"../../../api"` despite an explicit rule in the prompt, and now imports DataTable/PageHeader/ErrorState from `@mantine/core` (they are Fusion components).
  - LeaveTypesPage: 8 — Mantine NumberInput/Select value types (`string | number`, string-valued Select data).
  - Finding: fix rounds have diminishing returns; the 7B model repeats the same mistakes on files it has already seen, even when the exact error lines are given.
- **Manual edit (2026-10-26)** — only the errors that break the pages at runtime; no new behaviour:
  - LeaveBalancePage: import paths (`../api`, DataTable/ErrorState/PageHeader from `ui/components`), dropped unused imports. Page could not load before (module not found).
  - ApplyLeavePage: leave-type Select `onChange` used `e.target.value` (Select passes the value string) → `setType(v ?? "")`. Would have crashed on selection.
  - LeaveTypesPage: NumberInput values converted with `Number(...)`; Select uses string ids (`String(t.id)`) and converts back; `loading={isPending}` on the table.
  - Result: **27 → 7** (tsc_run5.txt). Remaining 7 were unused imports/variables only (LeaveApprovalsPage 3, MyLeavePage 4).
- **Manual edit (2026-10-26, cleanup):** removed those 7 unused imports/variables; MyLeavePage withdraw/cancel notifications showed the leave-type id → now show the type name. `make check-client` (typecheck + client tests + vite build): **pass, 0 TS errors**.

### 2026-10-26 — CI readiness (manual)
- `make check` (what CI runs) failed: **ruff 56 errors**, all in modules/elm (29 line-too-long, 12 uppercase test variables, 6 import order, 4 `raise` without `from`, 2 unused variables, 2 unnecessary assignments, 1 unused import). Some were already in Phase-1 files (models.py, registry.py), so Phase 1 would also have failed CI.
- **Manual edit:** `ruff --fix` for the 7 auto-fixable ones; the rest wrapped/renamed by hand (`raise … from None`, `_balance_of` helper for the repeated locked-balance lookup, `_nav` helper in registry.py). No behaviour change. The repo does not use `ruff format`, so it was not run.
- Then `schema-check` failed: Withdraw/Cancel views had no request schema and `get_available` no type hint → added `request=None` (same as placement) and `-> int`; regenerated `openapi/fusion-integrated.v1.yaml` with `make schema`.
- Result: **`make check` exit 0** — Django check, migrations, ruff, import contracts, cross-module FK, nav/routes, permission manifest, schema and full pytest all pass (check.txt).
- Committed on `elm-phase2-24BCS253`: Backend fixes, Leave tests, Frontend api, Leave pages.

### 2026-10-26 — qwen used for Understand, Build/Run and Review
- The 12 Oct understand/build/review work had been done manually. To document those stages with the code LLM, 5 qwen prompts were run on 26 Oct: Understand and Build/Run against the preserved Phase-1 code (`phase1-final`), Review ×3 against the current code. Details and verdict on every finding: `05_qwen_review_check.md`.
- First Understand attempt looped (~4,900 tokens, stopped, not logged) → added `num_predict`/`repeat_penalty` to ollama-gen.ps1.
- qwen diagnosed 1 of 4 build failures correctly; most review findings were false positives already covered by tests. One real defect (r2-2: allotment could exceed the leave type's max days/year, no upper bounds) → **manual fix** + new test; ELM tests **15/15**, `make check` exit 0. Commit `Review fixes`, pushed to PR #273.
- Phase-2 qwen prompts total: **23**.

## Phase-2 priorities
1. P0 — make it work end-to-end through Fusion: D1, D2, D3, D4, D5, D6 (+ verify with tests and real login).
2. P1 — tests for services and API (role checks, BR-EL-011/012/022/023/034).
3. P1 — admin features (UC-014 minimal: leave types + balance allotment) so Leave Admin role is real.
4. P2 — frontend pages for the 5 nav items.
5. P2 — larger workflow gaps (Unit Head routing, substitutes, extension, resumption) as time allows; document what remains.
