# Sends a prompt + context files to a local Ollama model and writes the files it returns.
# Usage: .\ollama-gen.ps1 -PromptFile p.txt -Context a,b -Model qwen2.5-coder:7b
param(
  [Parameter(Mandatory)][string]$PromptFile,
  [string[]]$Context = @(),
  [string]$Target = "",
  [string]$Model = "qwen2.5-coder:7b",
  [int]$NumCtx = 12288,
  [string]$Repo = "C:\Users\Revan\Desktop\a\ELM_MODEL_1",
  [string]$Log = "C:\Users\Revan\Desktop\a\logs\model1_chat.md"
)
$ErrorActionPreference = "Stop"
$task = Get-Content $PromptFile -Raw -Encoding UTF8
$Context = $Context -split ',' | Where-Object { $_ }

$ctx = ""
foreach ($c in $Context) {
  $ctx += "`n--- FILE: $c ---`n" + (Get-Content (Join-Path $Repo $c) -Raw -Encoding UTF8) + "`n"
}

$system = @"
You are a senior Django developer working inside the Fusion ERP repository.
Output ONLY the files you create or change. For every file use exactly this format:

FILE: relative/path/from/repo/root.py
``````python
<entire file content>
``````

Always give the complete file, never a diff or "..." placeholders. No explanations outside the files.
"@

$user = "Repository context files:`n$ctx`n`nTASK:`n$task"
$body = @{
  model    = $Model
  stream   = $false
  options  = @{ num_ctx = $NumCtx; temperature = 0.2 }
  messages = @(@{ role = "system"; content = $system }, @{ role = "user"; content = $user })
} | ConvertTo-Json -Depth 5

$t0 = Get-Date
$r = Invoke-RestMethod -Uri http://127.0.0.1:11434/api/chat -Method Post -Body ([Text.Encoding]::UTF8.GetBytes($body)) -ContentType "application/json" -TimeoutSec 3600
$secs = [int]((Get-Date) - $t0).TotalSeconds
$out = $r.message.content

$stats = "model=$Model num_ctx=$NumCtx prompt_tokens=$($r.prompt_eval_count) output_tokens=$($r.eval_count) wall=${secs}s"
Add-Content $Log -Encoding utf8 "`n# ollama-gen $(Get-Date -Format s) ($stats)`n`n#### Prompt ($PromptFile; context: $($Context -join ', '))`n`n$task`n`n#### Model response`n`n$out`n"

$rx = [regex]'(?ms)^FILE:\s*`?([^\r\n`]+?)`?\s*\r?\n```[a-zA-Z]*\r?\n(.*?)\r?\n```'
$n = 0
foreach ($m in $rx.Matches($out)) {
  $rel = $m.Groups[1].Value.Trim()
  $dest = Join-Path $Repo $rel
  New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
  [IO.File]::WriteAllText($dest, $m.Groups[2].Value + "`n", (New-Object Text.UTF8Encoding $false))
  "wrote $rel"; $n++
}
if ($n -eq 0 -and $Target) {
  # Model sometimes drops the FILE: header on single-file edits; take its first code block.
  $b = [regex]::Match($out, '(?ms)```[a-zA-Z]*\r?\n(.*?)\r?\n```')
  if ($b.Success) {
    [IO.File]::WriteAllText((Join-Path $Repo $Target), $b.Groups[1].Value + "`n", (New-Object Text.UTF8Encoding $false))
    "wrote $Target (no FILE: header, used -Target)"; $n = 1
  }
}
"$stats files=$n"
if ($n -eq 0) { "NO FILES PARSED. Raw output:"; $out }
