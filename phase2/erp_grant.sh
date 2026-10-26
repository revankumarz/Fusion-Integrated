#!/bin/bash
# LOCAL TEST ENVIRONMENT ONLY.
# The IAM rebuilds a user's designations from the ERP tables at every login
# (iam/sync.py refresh_designations), which wipes roles added with assign_role.
# So for testing we also record the ELM designations in the local ERP dump.
cd ~/Documents/Fusion/Fusion_System_Administrator/Backend/backend
../venv/bin/python manage.py shell -c "
from api.models.erp import AuthUser, GlobalsDesignation, GlobalsHoldsdesignation
grants = [('fac00021', 'Employee'), ('fac00050', 'Leave Approver'),
          ('fac00050', 'Employee'), ('stf00062', 'Leave Admin')]
for username, name in grants:
    d, _ = GlobalsDesignation.objects.get_or_create(
        name=name, defaults={'full_name': name, 'type': 'administrative', 'basic': False})
    u = AuthUser.objects.get(username=username)
    _, made = GlobalsHoldsdesignation.objects.get_or_create(designation=d, user=u, working=u)
    print(('granted ' if made else 'already ') + name + ' -> ' + username)
from iam import sync
for username in sorted({g[0] for g in grants}):
    uid = AuthUser.objects.get(username=username).id
    print('refreshed', username, sync.refresh_designations(uid))
"
