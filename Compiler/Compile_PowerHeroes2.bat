copy "..\PowerHeroes.ps1" "PowerHeroes.ps1"
powershell.exe .\ps2exe2.ps1
copy "PowerHeroes.exe" "..\PowerHeroes.exe"
del "PowerHeroes.exe"
del "PowerHeroes.exe.config"
del "PowerHeroes.ps1"
pause