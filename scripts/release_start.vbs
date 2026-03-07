Option Explicit

Dim fso, shell, root, backendDir, distIndex, envFile, envExample
Dim logsDir, pidFile, stdoutLog, stderrLog, processClass, startupConfig
Dim cmd, url, processId, returnCode, existingPid

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

WScript.Sleep 2500
url = "http://127.0.0.1:18080/"
shell.Run url, 1, False

Function ReadTextFile(path)
  Dim stream
  Set stream = fso.OpenTextFile(path, 1, False)
  ReadTextFile = stream.ReadAll
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
  Set exec = shell.Exec("cmd /c tasklist /FI ""PID eq " & pid & "" | findstr /R /C:"" " & pid & " """)
  output = ""
  Do While Not exec.StdOut.AtEndOfStream
    output = output & exec.StdOut.ReadAll
  Loop
  IsProcessRunning = (Trim(output) <> "")
End Function