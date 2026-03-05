Option Explicit

Dim fso, shell, root, backendDir, distIndex, envFile, envExample, cmd, url
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

root = fso.GetParentFolderName(fso.GetParentFolderName(WScript.ScriptFullName))
backendDir = root & "\backend"
distIndex = root & "\frontend\dist\index.html"
envFile = root & "\.env"
envExample = root & "\.env.example"

If Not fso.FileExists(distIndex) Then
  MsgBox "Missing frontend build. Run scripts\release_build.bat first.", 48, "RST v0.2"
  WScript.Quit 1
End If

If Not fso.FileExists(envFile) Then
  If fso.FileExists(envExample) Then
    fso.CopyFile envExample, envFile
  End If
End If

cmd = "cmd /c cd /d """ & backendDir & """ && set RST_BACKEND_RELOAD=0&& set RST_SERVE_FRONTEND=1&& uv run python -m app.main"
shell.Run cmd, 0, False

WScript.Sleep 2500
url = "http://127.0.0.1:18080/"
shell.Run url, 1, False
