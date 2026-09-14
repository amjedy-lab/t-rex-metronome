# Сборка t_rex_metr.exe из TimerMetronome.ps1
$ErrorActionPreference = 'Stop'
# Требуется модуль ps2exe (Install-Module ps2exe), версия 1.0.18+
Import-Module ps2exe -MinimumVersion 1.0.18 -ErrorAction Stop
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outExe = Join-Path $dir 't_rex_metr.exe'
invoke-ps2exe -inputFile (Join-Path $dir 'TimerMetronome.ps1') `
              -outputFile $outExe `
              -iconFile (Join-Path $dir 'T-REX.ico') `
              -title 'T-REX метроном' `
              -description 'T-REX метроном — прозрачный виджет таймер + метроном' `
              -product 'T-REX метроном' `
              -sta -noConsole
Write-Output ("built: " + (Get-Item $outExe).Length + " bytes")
