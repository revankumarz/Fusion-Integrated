# qwen review prompts (2026-10-26) — findings checked against the code

Five prompts, all qwen2.5-coder:7b via ollama-gen.ps1 (num_ctx 8192, num_predict 2048). Full prompts and responses: `model_chat.md` (last 5 entries); prompt files in `prompts/p2_und_01_*`, `p2_build_01_*`, `p2_rev_0*`.
Understand and Build/Run prompts were run against the preserved Phase-1 code (tag `phase1-final`), the Review prompts against the current Phase-2 code.
A first attempt at the Understand prompt was stopped after ~4,900 output tokens because the model was looping (no response logged); the script then got `num_predict` and `repeat_penalty`.

## Understand (p2_und_01) — run on phase1-final
| qwen said | Actually |
|---|---|
| Architecture summary of models/services | Correct |
| UC-005/007/008/012 "Implemented" | Wrong — withdraw/cancel were unreachable (D1) and the balance endpoint crashed (D2) |
| `application.approve` and `balance.view` "used but not declared" | Wrong — those were declared; the undeclared ones were `application.withdraw` / `.cancel` (it even listed them on the endpoints) |
| LeaveTypeListView "public, no permission" | Wrong — it required `leave_elm.application.view` |
| URLs `/leave/...` | Wrong — API is `/api/v1/elm/...` (`/leave/...` are the frontend routes) |

## Build/Run (p2_build_01) — run on phase1-final, given the 4 observed failures
| Failure | qwen's root cause | Actually (D-id in 01_review.md) |
|---|---|---|
| Balance 500 | Right line, wrong cause ("None leave_type"); fix would still crash | Call does not match the service signature (D2) |
| Manifest fails | "PERMISSIONS must be a dict" — wrong | An unused permission (`policy.manage`) is granted (D4) |
| Withdraw/cancel 403 | "ownership check inverted" — wrong; its fix would let only other users withdraw | Required permissions not declared in registry (D1) |
| Unknown id 500 | Correct: `.get()` raises DoesNotExist; wrap and raise NotFoundError | D3 |

## Review r1 (business rules) / r2 (API, security) / r3 (frontend/backend) — run on current code
| # | Finding | Verdict |
|---|---|---|
| r1-1 | CL half-day overlap (BR-EL-012) | Spec gap: half-day leave is not modelled at all — documented, not fixed |
| r1-2 | No enforcement of BR-EL-034 no-edit | False — no edit endpoint exists (`test_no_edit_endpoint`) |
| r1-3, r2-1 | Self-approval possible | False — blocked in `decide` (`test_approver_cannot_approve_own_application`) |
| r1-4, r2-4 | Can cancel/withdraw/read others' data | False — ownership checks + per-user querysets (`test_withdraw_pending`) |
| r1-5 | BR-EL-037 not enforced | False — policy services never approve |
| r1 list | BR-EL-035 notifications not implemented | True — documented gap |
| r2-2 | Input validation incomplete | **True** — allotment could exceed the leave type's max days/year; no upper bounds on year/allotted/max_days. **Fixed** (see below) |
| r2-3 | Error messages lack detail | Vague; errors already carry a message and code — no change |
| r3-1..3, 5, 6 | URLs, methods, fields match | Correct (no mismatch) |
| r3-4 | Status case mismatch | False — frontend lowercases before comparing |

## Fix from r2-2 (manual, 2026-10-26)
- `services/policy.py allot_balance`: reject allotment above `leave_type.max_days_per_year` (400 `above_max`).
- `api/serializers.py`: `max_days_per_year` ≤ 366, `year` 2000–2100, `allotted` ≤ 366.
- New test `test_allotment_above_leave_type_max_is_rejected`. ELM tests 15/15, `make check` exit 0, schema regenerated.

## Finding about the model
Out of 4 build failures it diagnosed 1 correctly; 2 suggested fixes would have made things worse. Of 11 review findings, 1 was a real defect, 2 were real spec gaps, the rest false positives. Useful as a checklist, not trustworthy without verification.
