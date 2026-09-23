# Chronos - Shop Manager runner
#
# Triggered by the Windows scheduled task "Chronos - Shop Manager", through
# run-hidden.vbs. Windows owns the schedule, so this survives reboots, closed
# terminals and ended Claude sessions.
#
# Every run appends one row to run-log.md whether or not anything happened.
# That heartbeat is the point: a missed run and a quiet run otherwise look
# identical.

$ErrorActionPreference = 'Stop'

# Paths are derived from this script's own location, never hardcoded, so a
# folder rename cannot silently break the job.
$JobDir  = $PSScriptRoot
$LogFile = Join-Path $JobDir 'run-log.md'
$Skill   = Join-Path $JobDir 'SKILL.md'
$Vault   = (Resolve-Path (Join-Path $JobDir '..\..\..')).Path

# The agent folder - the same folder a manual session is started from, so a
# scheduled run loads the same CLAUDE.md and follows the same rules.
$WorkDir = Join-Path $HOME 'Chronos (AGENT)'

$Claude = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $Claude) { $Claude = Join-Path $HOME '.local\bin\claude.exe' }

# Browser-driving jobs share one lock so two runs never fight over the window.
$Lock = Join-Path $env:TEMP 'chronos-browser.lock'

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
    # Wait up to 15 minutes for another browser job to finish. A lock older
    # than 20 minutes belongs to a run that died, so ignore it.
    $waited = 0
    while ((Test-Path $Lock) -and $waited -lt 900) {
        if (((Get-Date) - (Get-Item $Lock).LastWriteTime).TotalMinutes -gt 20) { break }
        Start-Sleep -Seconds 30
        $waited += 30
    }
    Set-Content -Path $Lock -Value (Get-Date -Format o) -Encoding utf8

    # Check every input BEFORE invoking the model. A missing file discovered
    # mid-run produces a polite refusal and an exit code of 0.
    if (-not (Test-Path $Claude))  { Write-Log 'FAILED' 'claude CLI not found'; exit 1 }
    if (-not (Test-Path $Skill))   { Write-Log 'FAILED' 'SKILL.md not found - was it renamed?'; exit 1 }
    if (-not (Test-Path $WorkDir)) { Write-Log 'FAILED' 'agent folder not found'; exit 1 }

    $prompt = @"
SCHEDULED SHOP MANAGER RUN.

Read and follow this file exactly: $Skill
The security section is binding - read it first.

Also read the heartbeat log at: $LogFile
If the newest row is more than ~28 hours old, open your report by saying a
run was missed.

Finish with these as your final two lines:

  SUMMARY: <one line - what happened, or nothing new>
  CHECKS-COMPLETE

Print CHECKS-COMPLETE only if every check genuinely ran. If any could not
run, say what failed and do not print it.
"@

    Set-Location $WorkDir

    # The prompt goes in through STDIN, never as an argument. Windows
    # PowerShell mangles native-command arguments that contain double quotes,
    # which truncates the prompt: the model answers a fragment, prints no
    # token, and exits 0.
    #
    # --chrome     gives the headless session browser tools; without it the
    #              job runs and checks nothing.
    # --add-dir    grants access to the vault, which sits outside the working
    #              folder. Without it a smaller model stops at "I need
    #              permission to read that file" and exits 0.
    # --model      pinned to an explicit ID, not an alias, so the job cannot be
    #              moved to a different model without anyone choosing it.
    # --effort     set explicitly; otherwise the run inherits the global
    #              default, usually the most expensive setting.
    $PromptFile = Join-Path $env:TEMP 'chronos-shop-prompt.txt'
    Set-Content -Path $PromptFile -Value $prompt -Encoding utf8
    $out = Get-Content $PromptFile -Raw |
           & $Claude --chrome --add-dir "$Vault" --model claude-sonnet-5 --effort high -p 2>&1 |
           Out-String
    Remove-Item $PromptFile -ErrorAction SilentlyContinue

    # Exit code 0 means "the process ended", NOT "the work happened". The run
    # must prove it finished by printing CHECKS-COMPLETE.
    if ($LASTEXITCODE -ne 0) {
        # Log the reason, not the number. "exited 1" is the CLI's generic
        # failure code - an expired login, a usage limit and a network drop
        # all produce it.
        $why = $out -split "`n" |
               Where-Object { $_ -match 'usage limit|rate.?limit|expired|unauthor|forbidden|denied|not found|error' } |
               Select-Object -First 1
        if ($why) { Write-Log 'FAILED' "exited $LASTEXITCODE - $why" }
        else      { Write-Log 'FAILED' "exited $LASTEXITCODE" }
    }
    elseif ($out -notmatch 'CHECKS-COMPLETE') {
        $why = $out -split "`n" |
               Where-Object { $_ -match 'FAIL|error|cannot|unable|denied' } |
               Select-Object -First 1
        if (-not $why) { $why = 'no CHECKS-COMPLETE token - the run did not finish its checks' }
        Write-Log 'FAILED' $why
    }
    else {
        # Take the line tagged SUMMARY:, not just the last line of output.
        $summary = $out -split "`n" | Where-Object { $_ -match 'SUMMARY:' } | Select-Object -Last 1
        if (-not $summary) { $summary = 'completed' }
        Write-Log 'OK' $summary
    }
}
catch {
    Write-Log 'FAILED' $_.Exception.Message
    exit 1
}
finally {
    Remove-Item $Lock -Force -ErrorAction SilentlyContinue
}
