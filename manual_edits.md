# Manual edits (not model-generated)

Final submission follows the instructor's rule: only integration/mechanical corrections to the model output.
Model: qwen2.5-coder:7b (Q4_K_M) via Ollama 0.40.1, driven by logs/ollama-gen.ps1. Raw responses: logs/model1_chat.md.

## Final code = exact model output

| File | Source (prompt in logs/prompts/) |
|------|----------------------------------|
| modules/elm/__init__.py, apps.py, models.py | 01_backend_core |
| modules/elm/registry.py | 02a_registry_urls (module/nav registration) |
| config/urls.py | 02b (route registration; model's `# Added line` comment kept) |
| config/settings/base.py | 03_settings (module registration; model's `# Added module` comment kept) |
| modules/elm/services/leave.py | 04_services, unchanged |
| modules/elm/api/serializers.py, urls.py, views.py | 05_api |
| modules/elm/migrations/0001_initial.py | `manage.py makemigrations elm` (Django-generated; database connection) |

## Only manual change (allowed: "imports")

| File | Edit |
|------|------|
| modules/elm/api/views.py | Added missing imports `LeaveBalanceSerializer`, `from django.utils import timezone`, `from core.api.exceptions import BadRequestError` (model used them without importing; URLconf failed to load) |

## Reverted (not allowed under the rule)

Follow-up prompts 04b, 04c, 05b, 05c (logic fixes, hardening, cleanup), 07/07b/07c (admin feature = adding a missing requirement) were tried during the session but reverted. Their prompts and responses remain in the log as evidence.

## Known model defects left as-is

- `make permissions` fails: `leave_elm.policy.manage` is granted but no code uses it (model never built Leave Admin features).
- withdraw/cancel require permissions that are not declared in registry.py (nobody can withdraw/cancel).
- `.get()` misses raise DoesNotExist → HTTP 500 instead of 404/409.
- MyBalanceView calls `get_balance(user, None, year, for_update=False)`; the service has no `for_update` parameter → TypeError at runtime.
- registry.py has a stray old docstring string in the middle of the file.
- No frontend pages generated.
