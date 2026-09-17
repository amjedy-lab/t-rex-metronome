# Сборка t_rex_metr.exe из TimerMetronome.ps1
# После ps2exe к exe доклеивается appended-payload: gz(zip(NAudio.Core.dll + NAudio.Wasapi.dll))
# + ASCII-футер TREX-METR-PAYLOAD-V1:len=<N>\n — движок точного щёлканья работает из одного exe
# (скрипт при старте распаковывает его в %LOCALAPPDATA%\T-REX-Metronome\payload\<len>; DLL рядом
# с exe, если положены, имеют приоритет). Нет payload/DLL — прежний путь SoundPlayer (v1.18).
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

# --- appended-payload: DLL движка внутри exe ---
$dlls = @('NAudio.Core.dll', 'NAudio.Wasapi.dll') | ForEach-Object { Join-Path $dir $_ }
if (@($dlls | Where-Object { Test-Path -LiteralPath $_ }).Count -eq 2) {
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    $zipMs = [IO.MemoryStream]::new()
    $zip = [IO.Compression.ZipArchive]::new($zipMs, [IO.Compression.ZipArchiveMode]::Create, $true)
    foreach ($dll in $dlls) {
        $entry = $zip.CreateEntry([IO.Path]::GetFileName($dll), [IO.Compression.CompressionLevel]::Optimal)
        $es = $entry.Open()
        $fs = [IO.File]::OpenRead($dll)
        $fs.CopyTo($es)
        $fs.Close(); $es.Close()
    }
    $zip.Dispose()
    $gzMs = [IO.MemoryStream]::new()
    $gzOut = [IO.Compression.GZipStream]::new($gzMs, [IO.Compression.CompressionMode]::Compress)
    $zipMs.Position = 0
    $zipMs.CopyTo($gzOut)
    $gzOut.Dispose()
    $gz = $gzMs.ToArray()
    $fs = [IO.File]::Open($outExe, 'Open', 'Write')
    $fs.Seek(0, 'End') | Out-Null
    $fs.Write($gz, 0, $gz.Length)
    $footer = [Text.Encoding]::ASCII.GetBytes("TREX-METR-PAYLOAD-V1:len=$($gz.Length)`n")
    $fs.Write($footer, 0, $footer.Length)
    $fs.Close()
    Write-Output ("payload appended: gz=" + $gz.Length + " bytes")
} else {
    Write-Output "ВНИМАНИЕ: NAudio.Core.dll/NAudio.Wasapi.dll не найдены рядом со скриптом — exe собран БЕЗ встроенного движка (будет путь v1.18)"
}
Write-Output ("built: " + (Get-Item $outExe).Length + " bytes")
