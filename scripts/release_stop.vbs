Option Explicit

Dim shell, cmd
Set shell = CreateObject("WScript.Shell")

cmd = "powershell -NoProfile -ExecutionPolicy Bypass -Command ""$ports=@(18080,15173); foreach($port in $ports){$procIds = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique; foreach($procId in $procIds){Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue}}"""
shell.Run cmd, 0, True

MsgBox "RST background stop command executed.", 64, "RST v0.2"
