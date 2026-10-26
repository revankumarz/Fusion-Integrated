# Usage: .\run-aider.ps1 <prompt-file> -Files a,b -ReadOnly c,d
param([string]$PromptFile, [string[]]$Files = @(), [string[]]$ReadOnly = @())
$env:OLLAMA_API_BASE = "http://127.0.0.1:11434"
$env:PYTHONIOENCODING = "utf-8"
$prompt = (Resolve-Path $PromptFile).Path
Set-Location C:\Users\Revan\Desktop\a\ELM_MODEL_1
$a = @(
  "--model", "ollama_chat/qwen2.5-coder:7b",
  "--model-settings-file", ".aider.model.settings.yml",
  "--map-tokens", "0",
  "--no-auto-commits", "--yes-always", "--no-gitignore",
  "--no-show-model-warnings", "--no-check-update", "--no-pretty", "--no-stream",
  "--chat-history-file", "..\logs\model1_chat.md",
  "--message-file", $prompt
)
foreach ($r in $ReadOnly) { $a += @("--read", $r) }
& C:\Users\Revan\.local\bin\aider @a @Files
