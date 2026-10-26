# One qwen fix prompt per ELM file that still has TypeScript errors.
# Usage: .\fix_ts_round.ps1 -TscOut tsc_runN.txt -Round N
param([string]$TscOut, [int]$Round)
$g = "C:\Users\Revan\Desktop\a\logs\ollama-gen.ps1"
$R = "\\wsl.localhost\Ubuntu-24.04\home\revan\Documents\Fusion\Fusion-Integrated"
$L = "C:\Users\Revan\Desktop\a\logs\phase2\model_chat.md"
$P = "C:\Users\Revan\Desktop\a\logs\phase2\prompts"
$errs = Get-Content $TscOut | Where-Object { $_ -match '^src/modules/elm/.+\.tsx?\(' }
$byFile = $errs | Group-Object { ($_ -split '\(')[0] }
foreach ($grp in $byFile) {
  $file = "client/" + $grp.Name
  $name = Split-Path $grp.Name -Leaf
  $prompt = @"
Phase 2 frontend fix, round $Round. ``npx tsc --noEmit`` reports these errors in $file :

$($grp.Group -join "`n")

Fix every one of them and output the complete file $file .
- Import every Mantine component you use from "@mantine/core" and React hooks (useState) from "react"; remove imports that are never used.
- Types from ../api must use ``import type { ... } from "../api";`` (verbatimModuleSyntax).
- The api module is "../api" (client/src/modules/elm/api.ts), never "../../../api".
- Every DataTable needs rowKey={(r) => r.id} and typed render params.
- Call mutations with exactly the variable type the hook in api.ts declares.
- Remove leftover state or elements copied from the placement module (history drawer, ActionIcon history button).
Keep the page's behaviour otherwise unchanged.
"@
  $pf = "$P\p2_ts_r${Round}_$($name -replace '\.tsx?$','').txt"
  Set-Content $pf $prompt -Encoding UTF8
  "=== $file"
  powershell -ExecutionPolicy Bypass -File $g -Repo $R -Log $L -PromptFile $pf -Context "specs/fe_ui_notes.md,client/src/modules/elm/api.ts,$file" -Target $file
}
