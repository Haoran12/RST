Option Explicit

Dim shell, fso, root, logsDir, pidFile, cmd, pid, stoppedByPid
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

root = fso.GetParentFolderName(fso.GetParentFolderName(WScript.ScriptFullName))
logsDir = root & "\logs"
pidFile = logsDir & "\rst-release.pid"
stoppedByPid = False

If fso.FileExists(pidFile) Then
  pid = Trim(ReadTextFile(pidFile))
  If pid <> "" Then
    cmd = "cmd /c taskkill /PID " & pid & " /T /F >nul 2>nul"
    shell.Run cmd, 0, True
    stoppedByPid = True
  End If

  On Error Resume Next
  fso.DeleteFile pidFile, True
  On Error GoTo 0
End If

cmd = "powershell -NoProfile -ExecutionPolicy Bypass -Command ""$ports=@(18080,15173); foreach($port in $ports){$procIds = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique; foreach($procId in $procIds){Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue}}"""
shell.Run cmd, 0, True

If stoppedByPid Then
  MsgBox "RST background process stopped.", 64, "RST"
Else
  MsgBox "RST stop command executed.", 64, "RST"
End If

Function ReadTextFile(path)
  Dim stream
  Set stream = fso.OpenTextFile(path, 1, False)
  ReadTextFile = stream.ReadAll
  stream.Close
End Function
