#!/bin/bash
# Publish ELM permissions to the IAM and give three dump accounts the ELM roles.
set -e
FI=~/Documents/Fusion/Fusion-Integrated
IAM=~/Documents/Fusion/Fusion_System_Administrator/Backend/backend
cd "$FI" && .venv/bin/python manage.py permission_manifest
cd "$IAM"
../venv/bin/python manage.py seed_iam_permissions --manifest "$FI/registry/permissions.json"
../venv/bin/python manage.py assign_role --user fac00021 --designation "Employee"
../venv/bin/python manage.py assign_role --user fac00050 --designation "Leave Approver"
../venv/bin/python manage.py assign_role --user stf00062 --designation "Leave Admin"
# fac00050 also applies for leave in the self-approval test
../venv/bin/python manage.py assign_role --user fac00050 --designation "Employee"
