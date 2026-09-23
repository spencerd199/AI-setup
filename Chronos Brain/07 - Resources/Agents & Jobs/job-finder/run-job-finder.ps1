# Chronos - Job Finder runner
#
# Triggered by the Windows scheduled task "Chronos - Job Finder", through
# run-hidden.vbs, weekdays at 8:00 AM.
#
# Same pattern as every other job: the OS owns the trigger, the instructions
# live in SKILL.md in the vault, and every run writes one heartbeat row.

$ErrorActionPreference = 'Stop'

$JobDir   = $PSScriptRoot
$LogFile  = Join-Path $JobDir 'run-log.md'
$Skill    = Join-Path $JobDir 'SKILL.md'
$Criteria = Join-Path $JobDir 'criteria.md'
$Vault    = (Resolve-Path (Join-Path $JobDir '..\..\..')).Path
$WorkDir  = Join-Path $HOME 'Chronos (AGENT)'

$Claude = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $Claude) { $Claude = Join-Path $HOME '.local\bin\claude.exe' }

function Clean($s) {
    $s = ($s -replace '^\s*SUMMARY:\s*', '' -replace '\|', '/' -replace "`r|`n", ' ').Trim()
    if ($s.Length -gt 160) { $s = $s.Substring(0, 160) + '...' }
    return $s
}

function Write-Log($status, $detail) {
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
    Add-Content -Path $LogFile -Value "| $stamp | $status | $(Clean $detail) |" -Encoding utf8
}

try {
    if (-not (Test-Path $Claude))   { Write-Log 'FAILED' 'claude CLI not found'; exit 1 }
    if (-not (Test-Path $Skill))    { Write-Log 'FAILED' 'SKILL.md not found - was it renamed?'; exit 1 }
    if (-not (Test-Path $Criteria)) { Write-Log 'FAILED' 'criteria.md not found - was it renamed?'; exit 1 }
    if (-not (Test-Path $WorkDir))  { Write-Log 'FAILED' 'agent folder not found'; exit 1 }

    $today = Get-Date -Format 'yyyy-MM-dd'

    $prompt = @"
SCHEDULED JOB FINDER RUN. Today is $today.

Read and follow this file exactly: $Skill
Screen every role against: $Criteria

You never submit anything. Every role that passes is drafted and written to
Pending Approvals, then you stop.

Finish with these as your final two lines:

  SUMMARY: <one line - found, passed, drafted>
  SCREEN-COMPLETE

Print SCREEN-COMPLETE only if you genuinely searched, screened and drafted.
If any part failed, say what failed and do not print it.
"@

    Set-Location $WorkDir

    # Prompt through STDIN, explicit vault access, pinned model and effort -
    # the reasons for each are written up in Agents & Jobs.md.
    $PromptFile = Join-Path $env:TEMP 'chronos-jobfinder-prompt.txt'
    Set-Content -Path $PromptFile -Value $prompt -Encoding utf8
    $out = Get-Content $PromptFile -Raw |
           & $Claude --add-dir "$Vault" --model claude-sonnet-5 --effort high -p 2>&1 |
           Out-String
    Remove-Item $PromptFile -ErrorAction SilentlyContinue

    if ($LASTEXITCODE -ne 0) {
        # TODO: log the failure reason, not just the code - the fix already
        # in run-shop-manager.ps1. Tracked on Active Priorities.
        Write-Log 'FAILED' "exited $LASTEXITCODE"
    }
    elseif ($out -notmatch 'SCREEN-COMPLETE') {
        $why = $out -split "`n" |
               Where-Object { $_ -match 'FAIL|error|cannot|unable|not found|denied' } |
               Select-Object -First 1
        if (-not $why) { $why = 'no SCREEN-COMPLETE token - the run did not finish' }
        Write-Log 'FAILED' $why
    }
    else {
        $summary = $out -split "`n" | Where-Object { $_ -match 'SUMMARY:' } | Select-Object -Last 1
        if (-not $summary) { $summary = 'completed' }
        Write-Log 'OK' $summary
    }
}
catch {
    Write-Log 'FAILED' $_.Exception.Message
    exit 1
}
