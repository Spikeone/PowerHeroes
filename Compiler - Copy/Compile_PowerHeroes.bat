copy "..\PowerHeroes.ps1" "PowerHeroes.ps1"
call "callPS2EXE.bat" "PowerHeroes.ps1" "PowerHeroes.exe"
copy "PowerHeroes.exe" "..\PowerHeroes.exe"
del "PowerHeroes.exe"
del "PowerHeroes.exe.config"
del "PowerHeroes.ps1"
pause