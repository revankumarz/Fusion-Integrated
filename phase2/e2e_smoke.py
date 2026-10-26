"""End-to-end smoke test: real logins through Fusion -> IAM, then the ELM workflow over HTTP.

Run inside WSL with Fusion-Integrated's venv while IAM (:8001) and Fusion (:8000) are up.
Prints one PASS/FAIL line per check and exits non-zero on any failure.
"""
import datetime as dt
import sys
import uuid

import requests

BASE = "http://127.0.0.1:8000/api/v1"
PASSWORD = "fusion123"
results = []


def check(name, cond, detail=""):
    results.append(cond)
    print(("PASS " if cond else "FAIL ") + name + ("" if cond else f"  -> {detail}"))


class User:
    def __init__(self, username, role):
        self.s = requests.Session()
        r = self.s.post(f"{BASE}/auth/login", json={"username": username, "password": PASSWORD})
        r.raise_for_status()
        me = self.s.patch(f"{BASE}/me", json={"active_role": role},
                          headers={"X-CSRF-Token": self._csrf()}).json()
        self.user_id = me["user"]["id"]
        self.me = me

    def _csrf(self):
        return self.s.get(f"{BASE}/me").json().get("csrf_token", "")

    def get(self, path, **kw):
        return self.s.get(f"{BASE}/elm/{path}", **kw)

    def post(self, path, body=None):
        return self.s.post(f"{BASE}/elm/{path}", json=body or {}, headers={"X-CSRF-Token": self._csrf()})


emp = User("fac00021", "Employee")
appr = User("fac00050", "Leave Approver")
admin = User("stf00062", "Leave Admin")
print("employee user_id:", emp.user_id, "| nav modules:", [g.get("label") for g in emp.me.get("navigation", [])])
check("employee sees Leave Management in sidebar",
      any("Leave" in str(g) for g in emp.me.get("navigation", [])), emp.me.get("navigation"))

# --- admin: leave type + balance (UC-014 minimal)
code = "CL" + uuid.uuid4().hex[:4].upper()
r = admin.post("admin/types", {"code": code, "name": f"Casual Leave {code}", "max_days_per_year": 8})
check("admin creates leave type (201)", r.status_code == 201, r.text)
lt = r.json().get("id")
year = dt.date.today().year
r = admin.post("admin/balances", {"employee_id": emp.user_id, "leave_type_id": lt, "year": year, "allotted": 8})
check("admin allots balance (200)", r.status_code == 200, r.text)
r = emp.post("admin/types", {"code": "XX", "name": "x", "max_days_per_year": 1})
check("employee cannot create leave type (403)", r.status_code == 403, r.status_code)

# --- employee applies (UC-001, BR-EL-011)
d0 = dt.date.today() + dt.timedelta(days=30)
r = emp.post("applications", {"leave_type": lt, "start_date": str(d0), "end_date": str(d0 + dt.timedelta(days=2)), "reason": "family"})
check("employee applies 3 days (201)", r.status_code == 201, r.text)
app1 = r.json()
check("BR-EL-011 inclusive day count = 3", app1.get("days") == 3, app1)
r = emp.post("applications", {"leave_type": lt, "start_date": str(d0 + dt.timedelta(days=1)), "end_date": str(d0 + dt.timedelta(days=1)), "reason": "x"})
check("BR-EL-012 overlapping application rejected (409)", r.status_code == 409, r.text)
r = emp.post("applications", {"leave_type": lt, "start_date": str(d0 + dt.timedelta(days=10)), "end_date": str(d0 + dt.timedelta(days=30)), "reason": "x"})
check("insufficient balance rejected (409)", r.status_code == 409, r.text)
r = emp.post("applications", {"leave_type": lt, "start_date": str(d0), "end_date": str(d0 - dt.timedelta(days=1)), "reason": "x"})
check("end before start rejected (400)", r.status_code == 400, r.text)
r = emp.get("applications")
check("employee lists own applications", r.status_code == 200 and any(a["id"] == app1["id"] for a in r.json()), r.text)

# --- approvals (UC-005, BR-EL-036)
r = emp.get("applications/pending")
check("employee cannot see approval queue (403)", r.status_code == 403, r.status_code)
r = appr.get("applications/pending")
check("approver sees pending application", r.status_code == 200 and any(a["id"] == app1["id"] for a in r.json()), r.text)
r = appr.post(f"applications/{app1['id']}/decide", {"approve": True, "remarks": "ok"})
check("approver approves (200, APPROVED)", r.status_code == 200 and r.json().get("status") == "APPROVED", r.text)
r = appr.post(f"applications/{app1['id']}/decide", {"approve": True})
check("deciding twice rejected (409)", r.status_code == 409, r.text)
r = appr.post("applications/999999/decide", {"approve": True})
check("unknown application -> 404", r.status_code == 404, r.status_code)

# --- balance (UC-012)
r = emp.get("balance")
bal = next((b for b in r.json() if b["leave_type"] == lt), {}) if r.status_code == 200 else {}
check("balance endpoint works (200)", r.status_code == 200, r.text[:300])
check("balance used = 3 after approval", bal.get("used") == 3, bal)

# --- withdraw (BR-EL-022) and cancel (BR-EL-023)
r = emp.post("applications", {"leave_type": lt, "start_date": str(d0 + dt.timedelta(days=5)), "end_date": str(d0 + dt.timedelta(days=5)), "reason": "x"})
app2 = r.json()
r = emp.post(f"applications/{app2['id']}/withdraw")
check("employee withdraws pending (200, CANCELLED)", r.status_code == 200 and r.json().get("status") == "CANCELLED", r.text)
r = emp.post(f"applications/{app1['id']}/cancel")
check("employee cancels approved future leave (200)", r.status_code == 200 and r.json().get("status") == "CANCELLED", r.text)
r = emp.get("balance")
bal = next((b for b in r.json() if b["leave_type"] == lt), {}) if r.status_code == 200 else {}
check("balance restored to used = 0 after cancel", bal.get("used") == 0, bal)

# --- self-approval blocked
r = admin.post("admin/balances", {"employee_id": appr.user_id, "leave_type_id": lt, "year": year, "allotted": 8})
appr_emp = User("fac00050", "Employee")
r = appr_emp.post("applications", {"leave_type": lt, "start_date": str(d0 + dt.timedelta(days=40)), "end_date": str(d0 + dt.timedelta(days=40)), "reason": "x"})
own = r.json()
r = appr.post(f"applications/{own.get('id')}/decide", {"approve": True})
check("approver cannot approve own application (403)", r.status_code == 403, r.text)

print(f"\n{sum(results)}/{len(results)} checks passed")
sys.exit(0 if all(results) else 1)
