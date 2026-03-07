Option Explicit

Dim shell, fso, root, logsDir, pidFile, envFile, cmd, pid, stoppedByPid, backendPort
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

root = fso.GetParentFolderName(fso.GetParentFolderName(WScript.ScriptFullName))
logsDir = root & "\logs"
pidFile = logsDir & "\rst-release.pid"
envFile = root & "\.env"
backendPort = ReadEnvValue(envFile, "RST_BACKEND_PORT", "18080")
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

cmd = "powershell -NoProfile -ExecutionPolicy Bypass -Command ""$ports=@(" & backendPort & ",15173); foreach($port in $ports){$procIds = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique; foreach($procId in $procIds){Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue}}"""
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

Function ReadEnvValue(path, keyName, defaultValue)
  Dim stream, line, pairPos, currentKey, currentValue
  ReadEnvValue = defaultValue
  If Not fso.FileExists(path) Then
    Exit Function
  End If

  Set stream = fso.OpenTextFile(path, 1, False)
  Do While Not stream.AtEndOfStream
    line = Trim(stream.ReadLine)
    If line <> "" Then
      If Left(line, 1) <> "#" Then
        pairPos = InStr(line, "=")
        If pairPos > 1 Then
          currentKey = Trim(Left(line, pairPos - 1))
          If StrComp(currentKey, keyName, 1) = 0 Then
            currentValue = Trim(Mid(line, pairPos + 1))
            If currentValue <> "" Then
              ReadEnvValue = currentValue
            End If
            Exit Do
          End If
        End If
      End If
    End If
  Loop
  stream.Close
End Function
