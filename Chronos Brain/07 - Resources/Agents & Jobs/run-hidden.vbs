' Launches a PowerShell runner with NO console window at all.
'
' Why this exists: a scheduled task that runs powershell.exe directly opens a
' console window in the desktop session. Closing that window mid-run kills the
' job before it can write its heartbeat row.
'
' Window style 0 = hidden, not minimised - there is no window to close.
' bWaitOnReturn = True so Task Scheduler receives the runner's real exit code
' instead of reporting success the instant wscript hands off.
'
' Usage (Task Scheduler action):
'   wscript.exe "<path>\run-hidden.vbs" "<path>\<job>\run-<job>.ps1"

Set sh = CreateObject("WScript.Shell")

If WScript.Arguments.Count < 1 Then
  WScript.Quit 2
End If

cmd = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File """ _
      & WScript.Arguments(0) & """"

rc = sh.Run(cmd, 0, True)
WScript.Quit rc
