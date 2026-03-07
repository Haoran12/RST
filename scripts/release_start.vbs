Option Explicit

Dim fso, shell, root, backendDir, distIndex, envFile, envExample
Dim logsDir, pidFile, stdoutLog, stderrLog, processClass, startupConfig
Dim cmd, url, processId, returnCode, existingPid, backendPort, healthOk

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

root = fso.GetParentFolderName(fso.GetParentFolderName(WScript.ScriptFullName))
backendDir = root & "\backend"
distIndex = root & "\frontend\dist\index.html"
envFile = root & "\.env"
envExample = root & "\.env.example"
logsDir = root & "\logs"
pidFile = logsDir & "\rst-release.pid"
stdoutLog = logsDir & "\release-stdout.log"
stderrLog = logsDir & "\release-stderr.log"
backendPort = ReadEnvValue(envFile, "RST_BACKEND_PORT", "18080")

If Not fso.FileExists(distIndex) Then
  MsgBox "Missing frontend build. Run the package install script or scripts\release_build.bat first.", 48, "RST"
  WScript.Quit 1
End If

If Not fso.FileExists(envFile) Then
  If fso.FileExists(envExample) Then
    fso.CopyFile envExample, envFile
  End If
End If

If Not fso.FolderExists(logsDir) Then
  fso.CreateFolder logsDir
End If

If fso.FileExists(pidFile) Then
  existingPid = Trim(ReadTextFile(pidFile))
  If existingPid <> "" Then
    If IsProcessRunning(existingPid) Then
      MsgBox "RST is already running. Stop it first using the package stop script or scripts\release_stop.vbs.", 48, "RST"
      WScript.Quit 0
    End If
  End If
  On Error Resume Next
  fso.DeleteFile pidFile, True
  On Error GoTo 0
End If

cmd = "cmd.exe /c cd /d """ & backendDir & """ && set RST_BACKEND_RELOAD=0&& set RST_SERVE_FRONTEND=1&& uv run python -m app.main 1>>""" & stdoutLog & """ 2>>""" & stderrLog & """"

Set processClass = GetObject("winmgmts:\\.\root\cimv2:Win32_Process")
Set startupConfig = GetObject("winmgmts:\\.\root\cimv2:Win32_ProcessStartup").SpawnInstance_
startupConfig.ShowWindow = 0
returnCode = processClass.Create(cmd, Null, startupConfig, processId)

If returnCode <> 0 Then
  MsgBox "Failed to start RST background process. Error code: " & returnCode, 16, "RST"
  WScript.Quit 1
End If

WriteTextFile pidFile, CStr(processId)

url = "http://127.0.0.1:" & backendPort & "/"
healthOk = WaitForBackend("http://127.0.0.1:" & backendPort & "/health", 30000)

If healthOk Then
  shell.Run url, 1, False
Else
  MsgBox "RST started, but the backend did not become ready in time. Check logs\\release-stderr.log for details.", 48, "RST"
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

Sub WriteTextFile(path, content)
  Dim stream
  Set stream = fso.OpenTextFile(path, 2, True)
  stream.Write content
  stream.Close
End Sub

Function IsProcessRunning(pid)
  Dim exec, output
  Set exec = shell.Exec("cmd /c tasklist /FI ""PID eq " & pid & """")
  output = ""
  Do While Not exec.StdOut.AtEndOfStream
    output = output & exec.StdOut.ReadAll
  Loop
  IsProcessRunning = (InStr(1, output, "No tasks are running", 1) = 0 And Trim(output) <> "")
End Function

Function WaitForBackend(healthUrl, timeoutMs)
  Dim startedAt, http
  startedAt = Timer
  WaitForBackend = False

  Do
    On Error Resume Next
    Set http = CreateObject("WinHttp.WinHttpRequest.5.1")
    http.Open "GET", healthUrl, False
    http.SetTimeouts 1000, 1000, 1000, 1000
    http.Send
    If Err.Number = 0 Then
      If http.Status = 200 Then
        WaitForBackend = True
        Exit Function
      End If
    End If
    Err.Clear
    On Error GoTo 0

    WScript.Sleep 500
    If ((Timer - startedAt) * 1000) >= timeoutMs Then
      Exit Do
    End If
  Loop
End Function
