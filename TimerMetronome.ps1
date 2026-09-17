# T-REX метроном v1.19 — прозрачный виджет "таймер + метроном" (WPF)
# Управление: перетаскивание — за панель; прозрачность — колёсико или панель под шестерёнкой; закрытие — X или правый клик.
# v1.19: новый аудиодвижок щелчков (NAudio, опционально): клики заранее закладываются в непрерывную аудиоленту
#        (BufferedWaveProvider + WasapiOut) с упреждением ~350 мс и звучат по часам аудиоустройства — дрожание
#        диспетчера WPF перестаёт быть слышным. NAudio.Core.dll + NAudio.Wasapi.dll (MIT) кладутся рядом со
#        скриптом/exe; если их нет или устройство не открылось — прежний путь v1.18 (SoundPlayer по тикам).
# v1.18: ровный темп метронома: тики планируются по абсолютной сетке от старта (задержка диспетчера
#        компенсируется коротким следующим интервалом, темп не ползёт), тики получили приоритет Send,
#        на время работы метронома системный таймер переведён в режим 1 мс (timeBeginPeriod),
#        звуки предзагружены (Load) — первый щелчок не ждёт чтения wav.
# v1.17: поле дробления в логе тренировки переименовано в Duration — это длительность НОТЫ (4=четверть,
#        8=восьмая, 16=шестнадцатая, 3=триоль), та же нотация, что у -div; поле Div убрано.
# v1.16: дробление доли — четверти/восьмые/шестнадцатые/триоли (кнопка-циклер с глифами, -div 4|8|16|3);
#        BPM остаётся темпом ЧЕТВЕРТИ, дробление добавляет тихие щелчки внутрь доли.
# v1.15: в связанном режиме сигнал окончания звучит ПОСЛЕ доигранного такта (последняя доля слышна, писк — в конце),
#        а не в момент нуля, где он перекрывал финальные доли; вне связанного режима — как раньше, на нуле.
# v1.14: лог тренировки пишется в момент завершения (ноль таймера, в связанном режиме — конец доигранного такта),
#        а не при закрытии окна; закрытие по крестику/правому клику лог НЕ пишет. Кружок "успешно" по умолчанию
#        поставлен; снятие кликом = записать событие (Success=false) и сразу закрыть виджет; на кружке подсказка.
#        При автозапуске шапка горит красным; "Связать" не нажимается (с -link — красная, как шапка);
#        "Автозагрузка" в этом режиме скрыта. Обычный запуск — прежний вид.
# v1.13: "успешно" — зелёный кружок с перекрещенными барабанными палочками (без ">"); в связанном режиме
#        при нуле таймера такт доигрывается до конца, время таймера уходит в минус.
# v1.12: путь лога тренировок задаётся -logPath (по умолчанию tm_trainings.jsonl рядом с виджетом).
# v1.11: лог тренировок в JSON (только при -autoStart): метка -label или GUID, параметры старта, "завершено" (автовыход),
#        "успешно" (кружок в левом нижнем углу, по умолчанию поставлен); сильные доли — синие, как кнопка размера такта.
# v1.10: сильные доли — зелёные точки с красным ">"; подсветка текущей доли во время звучания;
#        при закрытии запоминаются bpm, размер такта, сильные доли и стартовое время таймера.
# v1.9: прозрачность — всплывающая панель под шестерёнкой (справа вверху); автозагрузка — кнопка слева вверху; нижняя панель убрана.
# v1.8: регулятор прозрачности (+сохранение), автозагрузка (ярлык в Startup), защита от второго экземпляра.
# v1.7: настраиваемые сильные доли — точки под метрономом (клик = закрасить ">" / снять), параметр -accents.
# v1.6: сохранение позиции окна (tm_settings.txt), старт из правого нижнего угла, параметр -opacity.
# v1.5: параметр -beats (размер такта), имя файла t_rex_metr.exe без версии.
# v1.4: флаг -autoStart — сразу начать отсчёт после запуска.
# v1.3: параметры командной строки (-seconds/-bpm/-link/-exitOnFinish), см. readme.md.
# v1.2: иконка с динозавром и таймером.
# v1.1: заголовок T-REX, русские надписи, режим "Связать" (общий старт, метроном стоп при нуле), BPM по умолчанию 60.

param(
    [Alias('t')][int]$seconds = 0,          # время таймера на старте, сек (0 = из настроек, иначе 300)
    [Alias('b')][int]$bpm = 0,              # темп метронома (0 = из настроек, иначе 60)
    [Alias('r')][int]$beats = 0,            # размер такта 2..8 (0 = из настроек, иначе 4)
    [Alias('d')][int]$div = 0,              # дробление доли: 4=четверти, 8=восьмые, 16=шестнадцатые, 3=триоли (0 = из настроек, иначе 4)
    [Alias('c')][string]$accents = '',      # сильные доли через запятую, напр. "1,3" (пусто = из настроек, иначе только 1-я)
    [Alias('l')][switch]$link,              # включить режим "Связать"
    [Alias('e')][switch]$exitOnFinish,      # закрыть виджет после завершения таймера
    [Alias('a')][switch]$autoStart,         # сразу начать отсчёт после запуска
    [Alias('o')][double]$opacity = 100,     # прозрачность окна в % (20..100)
    [Alias('m')][string]$label = '',        # метка тренировки для лога (пусто = GUID; лог — только при -autoStart)
    [Alias('p')][string]$logPath = ''       # путь к файлу лога тренировок (пусто = tm_trainings.jsonl рядом с виджетом; относительный — от его каталога)
)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# --- защита от второго экземпляра: именованный mutex (Local\ = в пределах сессии пользователя) ---
$singleton = New-Object System.Threading.Mutex($false, 'Local\T-REX-metronome')
$firstInstance = $false
try { $firstInstance = $singleton.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $firstInstance = $true }
if (-not $firstInstance) {
    # поднять окно уже запущенного экземпляра и тихо уйти (без Write-Output: в noConsole-exe он превращается в MessageBox)
    try {
        Add-Type -Namespace Win32 -Name Native -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);'
        $other = Get-Process | Where-Object { $_.Id -ne $PID -and $_.MainWindowTitle -eq 'T-REX метроном' } | Select-Object -First 1
        if ($other -and $other.MainWindowHandle -ne [IntPtr]::Zero) { [void][Win32.Native]::SetForegroundWindow($other.MainWindowHandle) }
    } catch { }
    [Environment]::Exit(0)
}

# Папка скрипта/exe: в скомпилированном ps2exe виде $MyInvocation пустой, берём путь запущенного файла
$cmdLineSelf = [Environment]::GetCommandLineArgs()[0]
$isExe = -not $MyInvocation.MyCommand.Path      # true в ps2exe-сборке
$selfPath = if ($MyInvocation.MyCommand.Path) {
    $MyInvocation.MyCommand.Path
} elseif ($cmdLineSelf -and (Test-Path -LiteralPath $cmdLineSelf)) {
    (Resolve-Path -LiteralPath $cmdLineSelf).Path
} else {
    $PWD.Path
}
$scriptDir = Split-Path -Parent $selfPath

# --- звуковые файлы: генерируются один раз рядом со скриптом ---
function Make-Wav([string]$path, [double]$freq, [double]$dur, [double]$decay, [double]$amp = 0.75) {
    $rate = 44100; $n = [int]($rate * $dur)
    $samples = New-Object 'int16[]' $n
    for ($i = 0; $i -lt $n; $i++) {
        $env = [Math]::Exp(-$decay * $i / $n)
        $v = [Math]::Sin(2 * [Math]::PI * $freq * $i / $rate) * $env * $amp
        $samples[$i] = [int16]($v * 32767)
    }
    $data = [byte[]]::new($n * 2)
    [Buffer]::BlockCopy($samples, 0, $data, 0, $data.Length)
    $fs = [IO.File]::Create($path); $bw = New-Object IO.BinaryWriter($fs)
    $enc = [Text.Encoding]::ASCII
    $bw.Write($enc.GetBytes("RIFF")); $bw.Write([int32](36 + $data.Length))
    $bw.Write($enc.GetBytes("WAVEfmt ")); $bw.Write([int32]16)
    $bw.Write([int16]1); $bw.Write([int16]1); $bw.Write([int32]$rate); $bw.Write([int32]($rate * 2))
    $bw.Write([int16]2); $bw.Write([int16]16)
    $bw.Write($enc.GetBytes("data")); $bw.Write([int32]$data.Length); $bw.Write($data)
    $bw.Close()
}
$wavTick    = Join-Path $scriptDir 'tm_tick.wav'
$wavTickHi  = Join-Path $scriptDir 'tm_tick_hi.wav'
$wavTickSub = Join-Path $scriptDir 'tm_tick_sub.wav'
$wavAlarm   = Join-Path $scriptDir 'tm_alarm.wav'
if (-not (Test-Path $wavTick))   { Make-Wav $wavTick   900 0.05 6 }
if (-not (Test-Path $wavTickHi)) { Make-Wav $wavTickHi 1400 0.05 6 }
if (-not (Test-Path $wavTickSub)) { Make-Wav $wavTickSub 650 0.03 9 0.4 }   # промежуточный щелчок дробления: тише и короче
if (-not (Test-Path $wavAlarm))  {
    # тройной сигнал: 3 тона по 0.2 c с паузами
    $rate = 44100; $dur = 1.0; $n = [int]($rate * $dur)
    $samples = New-Object 'int16[]' $n
    for ($i = 0; $i -lt $n; $i++) {
        $t = $i / $rate; $seg = $t % 0.333
        $v = 0.0
        if ($seg -lt 0.2) { $v = [Math]::Sin(2*[Math]::PI*880*$t) * [Math]::Exp(-8*($seg % 0.2)) * 0.7 }
        $samples[$i] = [int16]($v * 32767)
    }
    $data = [byte[]]::new($n * 2)
    [Buffer]::BlockCopy($samples, 0, $data, 0, $data.Length)
    $fs = [IO.File]::Create($wavAlarm); $bw = New-Object IO.BinaryWriter($fs)
    $enc = [Text.Encoding]::ASCII
    $bw.Write($enc.GetBytes("RIFF")); $bw.Write([int32](36 + $data.Length))
    $bw.Write($enc.GetBytes("WAVEfmt ")); $bw.Write([int32]16)
    $bw.Write([int16]1); $bw.Write([int16]1); $bw.Write([int32]$rate); $bw.Write([int32]($rate*2))
    $bw.Write([int16]2); $bw.Write([int16]16)
    $bw.Write($enc.GetBytes("data")); $bw.Write([int32]$data.Length); $bw.Write($data)
    $bw.Close()
}
$playerTick   = New-Object System.Media.SoundPlayer($wavTick)
$playerTickHi = New-Object System.Media.SoundPlayer($wavTickHi)
$playerTickSub = New-Object System.Media.SoundPlayer($wavTickSub)
$playerAlarm  = New-Object System.Media.SoundPlayer($wavAlarm)
# предзагрузка: Play() больше не тратит время на чтение wav перед первым щелчком
foreach ($p in @($playerTick, $playerTickHi, $playerTickSub, $playerAlarm)) { try { $p.Load() } catch { } }

# --- движок точного щёлканья (v1.19, опциональный): клики заранее пишутся в непрерывную аудиоленту
# (BufferedWaveProvider -> WasapiOut) с упреждением и звучат по часам аудиоустройства, а не по таймеру.
# Библиотеки NAudio.Core.dll + NAudio.Wasapi.dll (MIT, netstandard2.0): сначала рядом со скриптом/exe,
# а для exe — из ВСТРОЕННОГО appended-payload (gz(zip(DLL)) в хвосте exe, ASCII-футер
# TREX-METR-PAYLOAD-V1:len=<N>; доклеивает build_exe.ps1), распаковка в %LOCALAPPDATA%\T-REX-Metronome.
# Ничего не нашлось / не открылось устройство — работаем прежним путём SoundPlayer (v1.18). ---
$audio = $null
try {
    $dllCore = Join-Path $scriptDir 'NAudio.Core.dll'
    $dllWas  = Join-Path $scriptDir 'NAudio.Wasapi.dll'
    if (-not ((Test-Path -LiteralPath $dllCore) -and (Test-Path -LiteralPath $dllWas)) -and $isExe) {
        # exe без DLL рядом: извлечь встроенный payload из собственного файла
        Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
        $marker = 'TREX-METR-PAYLOAD-V1:len='
        $fs = [IO.File]::OpenRead($selfPath)
        try {
            $tailLen = [int][Math]::Min(4096, $fs.Length)
            $tail = New-Object 'byte[]' $tailLen
            [void]$fs.Seek(-$tailLen, 'End')
            [void]$fs.Read($tail, 0, $tailLen)
            $txt = [Text.Encoding]::ASCII.GetString($tail)
            $mi = $txt.LastIndexOf($marker)
            if ($mi -ge 0) {
                $nEnd = $txt.IndexOf("`n", $mi)
                if ($nEnd -lt 0) { $nEnd = $txt.Length }
                $len = [int]($txt.Substring($mi + $marker.Length, $nEnd - $mi - $marker.Length).Trim())
                $footerStart = $fs.Length - $tailLen + $mi
                if ($len -gt 0 -and ($footerStart - $len) -ge 0) {
                    $gz = New-Object 'byte[]' $len
                    [void]$fs.Seek($footerStart - $len, 'Begin')
                    [void]$fs.Read($gz, 0, $len)
                    $ms = [IO.MemoryStream]::new($gz)
                    $gzIn = [IO.Compression.GZipStream]::new($ms, [IO.Compression.CompressionMode]::Decompress)
                    $zipMs = [IO.MemoryStream]::new()
                    $gzIn.CopyTo($zipMs)
                    $gzIn.Dispose()
                    $zipMs.Position = 0
                    $zip = [IO.Compression.ZipArchive]::new($zipMs, [IO.Compression.ZipArchiveMode]::Read)
                    try {
                        # каталог-кэш по размеру payload: другой payload = другой каталог, перезатирания нет
                        $dstDir = Join-Path $env:LOCALAPPDATA "T-REX-Metronome\payload\len$len"
                        if (-not (Test-Path -LiteralPath (Join-Path $dstDir 'NAudio.Wasapi.dll'))) {
                            [void][IO.Directory]::CreateDirectory($dstDir)
                            foreach ($entry in $zip.Entries) {
                                $es = $entry.Open()
                                $ofs = [IO.File]::Create((Join-Path $dstDir $entry.FullName))
                                $es.CopyTo($ofs)
                                $ofs.Close(); $es.Close()
                            }
                        }
                    } finally { $zip.Dispose() }
                    $dllCore = Join-Path $dstDir 'NAudio.Core.dll'
                    $dllWas  = Join-Path $dstDir 'NAudio.Wasapi.dll'
                }
            }
        } finally { $fs.Close() }
    }
    if ((Test-Path -LiteralPath $dllCore) -and (Test-Path -LiteralPath $dllWas)) {
        $null = [Reflection.Assembly]::LoadFrom($dllCore)
        $null = [Reflection.Assembly]::LoadFrom($dllWas)
        $audio = @{ Ready = $true }
    }
} catch { $audio = $null }

# сэмплы щелчка для ленты: из wav-файла (канонический PCM 16 бит/моно/44100) или синус в памяти (дефолт Make-Wav)
function Get-ClickSamples([string]$wavPath, [double]$freq, [double]$dur, [double]$decay, [double]$amp) {
    try {
        $b = [IO.File]::ReadAllBytes($wavPath)
        if ($b.Length -gt 44 -and $b[0] -eq 0x52 -and $b[1] -eq 0x49) {   # "RI" из "RIFF"
            $fmtOk = $false; $dataOff = -1; $dataLen = 0; $pos = 12
            while ($pos + 8 -le $b.Length) {
                $id = [Text.Encoding]::ASCII.GetString($b, $pos, 4)
                $len = [BitConverter]::ToInt32($b, $pos + 4)
                if ($id -eq 'fmt ') {
                    $ch   = [BitConverter]::ToInt16($b, $pos + 10)   # каналы (смещение 2 внутри fmt)
                    $rate = [BitConverter]::ToInt32($b, $pos + 12)   # частота (смещение 4)
                    $bits = [BitConverter]::ToInt16($b, $pos + 22)   # биты (смещение 14)
                    $fmtOk = ($ch -eq 1 -and $rate -eq 44100 -and $bits -eq 16)
                } elseif ($id -eq 'data') { $dataOff = $pos + 8; $dataLen = [Math]::Min($len, $b.Length - $dataOff) }
                if ($len -le 0) { break }
                $pos += 8 + $len + ($len % 2)
            }
            if ($fmtOk -and $dataOff -gt 0 -and $dataLen -gt 0) {
                $s = New-Object 'byte[]' $dataLen
                [Array]::Copy($b, $dataOff, $s, 0, $dataLen)
                return $s
            }
        }
    } catch { }
    $rate = 44100; $n = [int]($rate * $dur)
    $s = New-Object 'byte[]' ($n * 2)
    for ($i = 0; $i -lt $n; $i++) {
        $env = [Math]::Exp(-$decay * $i / $n)
        $v = [int16]([Math]::Sin(2 * [Math]::PI * $freq * $i / $rate) * $env * $amp * 32767)
        $bb = [BitConverter]::GetBytes($v); $s[$i*2] = $bb[0]; $s[$i*2+1] = $bb[1]
    }
    return $s
}
# моно-сэмплы -> стерео-массив ленты (левый и правый канал дублируются)
function Convert-ToStereo([byte[]]$mono) {
    $st = New-Object 'byte[]' ($mono.Length * 2)
    $half = [Math]::Floor($mono.Length / 2)
    for ($i = 0; $i -lt $half; $i++) {
        $st[$i*4] = $mono[$i*2]; $st[$i*4+1] = $mono[$i*2+1]
        $st[$i*4+2] = $mono[$i*2]; $st[$i*4+3] = $mono[$i*2+1]
    }
    return $st
}
if ($audio) {
    $audio.Clicks = @{
        Tick = Convert-ToStereo (Get-ClickSamples $wavTick 900 0.05 6 0.75)
        Hi   = Convert-ToStereo (Get-ClickSamples $wavTickHi 1400 0.05 6 0.75)
        Sub  = Convert-ToStereo (Get-ClickSamples $wavTickSub 650 0.03 9 0.4)
    }
}

# --- сама лента: стерео 16 бит 44100; Written — сколько мс записано, Played — сколько мс прочитано выводом ---
$audioBytesPerMs  = 176.4          # 44100 Гц * 2 канала * 2 байта / 1000
$audioLookaheadMs = 350            # насколько вперёд планировщик пишет ленту (покрывает дрожание диспетчера)
$audioLaunchMs    = 150            # пауза до первого щелчка после старта (лента должна заполниться)
$audioSilence     = New-Object 'byte[]' 17640    # кэш 100 мс тишины
function Start-AudioEngine {
    if (-not $audio.Ready) { return $false }
    try {
        $wf = New-Object NAudio.Wave.WaveFormat(44100, 16, 2)
        $buf = New-Object NAudio.Wave.BufferedWaveProvider($wf)
        $buf.BufferDuration = [TimeSpan]::FromSeconds(2)
        $buf.ReadFully = $true
        $out = New-Object NAudio.Wave.WasapiOut([NAudio.CoreAudioApi.AudioClientShareMode]::Shared, 60)
        $out.Init($buf)
        $out.Play()
        $audio.Out = $out; $audio.Buf = $buf; $audio.Written = 0.0
        Write-AudioSilenceMs $audioLaunchMs
        return $true
    } catch { $audio.Ready = $false; $audio.Out = $null; $audio.Buf = $null; return $false }
}
function Stop-AudioEngine {
    if ($audio.Out) { try { $audio.Out.Stop(); $audio.Out.Dispose() } catch { } }
    $audio.Out = $null; $audio.Buf = $null
}
function Write-AudioSilenceMs([double]$ms) {
    $n = [int]($ms * $audioBytesPerMs)
    # только ЦЕЛЫЕ стерео-кадры (кратно 4 байтам): нечётный кусок сдвигает весь поток на полсэмпла,
    # и следующий клик звучит шумом с клиппингом (призвук на дробных сетках, напр. триоли 150 BPM);
    # потерянные 1-3 байта войдут в следующий кусок — позиция узлов уходит не более чем на 1 сэмпл
    $n -= ($n % 4)
    while ($n -gt 0) {
        $c = [Math]::Min($n, $audioSilence.Length)
        $audio.Buf.AddSamples($audioSilence, 0, $c)
        $audio.Written += $c / $audioBytesPerMs
        $n -= $c
    }
}
function Write-AudioUntilMs([double]$targetMs) {
    if ($audio.Written -lt $targetMs) { Write-AudioSilenceMs ($targetMs - $audio.Written) }
}
function Write-AudioClick([byte[]]$stereo) {
    $audio.Buf.AddSamples($stereo, 0, $stereo.Length)
    $audio.Written += $stereo.Length / $audioBytesPerMs
}
function Get-AudioPlayedMs { ($audio.Written - $audio.Buf.BufferedBytes / $audioBytesPerMs) }
# смена сетки на лету (BPM/дробление): следующий щелчок — от текущего конца ленты,
# уже записанное прозвучит по-старому (рывка нет), счётчик такта сохраняется
function Reset-AudioGrid {
    $state.NextClickMs = [Math]::Max($audio.Written, (Get-AudioPlayedMs) + $audioLaunchMs)
}

# --- точность метронома: повышаем разрешение системного таймера до 1 мс на время работы щелчков ---
# (штатный тик Windows ~15.6 мс квантует короткие интервалы; границы подъёма/сброса — Start-Metro/Add_Closed)
Add-Type -Namespace WinMM -Name Native -MemberDefinition @'
[DllImport("winmm.dll")] public static extern uint timeBeginPeriod(uint ms);
[DllImport("winmm.dll")] public static extern uint timeEndPeriod(uint ms);
'@

# --- интерфейс ---
[void][System.Windows.Forms.Application]::EnableVisualStyles()
$xamlText = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="T-REX метроном" Width="540" SizeToContent="Height"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="False" ResizeMode="NoResize"
        WindowStartupLocation="Manual" Left="40" Top="40">
  <Window.Resources>
    <Style x:Key="FlatBtn" TargetType="Button">
      <Setter Property="FontFamily" Value="Segoe UI"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Foreground" Value="#FFE6E6EB"/>
      <Setter Property="Background" Value="#37374A"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Margin" Value="2"/>
      <Setter Property="Padding" Value="6,4"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Background" Value="#4E4E68"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.35"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="GoBtn" TargetType="Button" BasedOn="{StaticResource FlatBtn}">
      <Setter Property="Background" Value="#3A7A58"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background" Value="#4E9E72"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style x:Key="StopBtn" TargetType="Button" BasedOn="{StaticResource FlatBtn}">
      <Setter Property="Background" Value="#96464A"/>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Setter Property="Background" Value="#BE5F63"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style x:Key="NeutralBtn" TargetType="Button" BasedOn="{StaticResource FlatBtn}">
      <Setter Property="Background" Value="#3A4A7A"/>
    </Style>
    <Style x:Key="DotBtn" TargetType="Button">
      <Setter Property="FontFamily" Value="Segoe UI"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Foreground" Value="#FF7FB4FF"/>
      <Setter Property="Width" Value="24"/>
      <Setter Property="Height" Value="24"/>
      <Setter Property="Margin" Value="3,0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Background" Value="#40FFFFFF"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" CornerRadius="12"
                    BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Opacity" Value="0.75"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>
  <Border CornerRadius="14" Background="#E0202028" Margin="6">
    <Border.Effect>
      <DropShadowEffect BlurRadius="8" ShadowDepth="0" Opacity="0.5"/>
    </Border.Effect>
    <Grid Margin="10,6,10,10">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>

      <!-- шапка: автозагрузка слева, заголовок в центре, связать/шестерёнка/крестик справа -->
      <DockPanel Grid.Row="0" Margin="0,0,0,6">
        <Button x:Name="BtnAutostart" DockPanel.Dock="Left" Content="Автозагрузка: выкл"
                Style="{StaticResource NeutralBtn}" FontSize="11" Padding="8,4"/>
        <Button x:Name="BtnClose" DockPanel.Dock="Right" Content="X" Width="20" Height="18" FontSize="10"
                Foreground="#FF8888AA" BorderThickness="0" Background="Transparent" Cursor="Hand"/>
        <Button x:Name="BtnGear" DockPanel.Dock="Right" Content="&#xE713;" FontFamily="Segoe MDL2 Assets" FontSize="11"
                Width="24" Height="18" Foreground="#FF8888AA" BorderThickness="0" Background="Transparent" Cursor="Hand"
                Margin="0,0,6,0"/>
        <Button x:Name="BtnLink" DockPanel.Dock="Right" Content="Связать" Style="{StaticResource NeutralBtn}" Margin="0,0,10,0"/>
        <TextBlock x:Name="TitleText" Text="T-REX метроном v1.19" FontFamily="Segoe UI" FontSize="13" FontWeight="Bold"
                   Foreground="#FF7FB4FF" HorizontalAlignment="Center" VerticalAlignment="Center"/>
      </DockPanel>

      <!-- основная часть -->
      <Grid Grid.Row="1">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <!-- ТАЙМЕР -->
        <StackPanel Grid.Column="0">
          <TextBlock Text="ТАЙМЕР" FontFamily="Segoe UI" FontSize="11" Foreground="#FF7FB4FF" FontWeight="Bold" Margin="2,0,0,0"/>
          <TextBlock x:Name="TimerDisplay" Text="05:00" FontFamily="Consolas" FontSize="34" FontWeight="Bold"
                     Foreground="#FFE6E6EB" HorizontalAlignment="Center" Margin="0,2,0,4"/>
          <UniformGrid Columns="4" Margin="0,0,0,6">
            <Button x:Name="BtnM60" Content="-1м" Style="{StaticResource FlatBtn}"/>
            <Button x:Name="BtnM10" Content="-10с" Style="{StaticResource FlatBtn}"/>
            <Button x:Name="BtnP10" Content="+10с" Style="{StaticResource FlatBtn}"/>
            <Button x:Name="BtnP60" Content="+1м" Style="{StaticResource FlatBtn}"/>
          </UniformGrid>
          <UniformGrid Columns="2">
            <Button x:Name="BtnTimerStart" Content="Старт" Style="{StaticResource GoBtn}"/>
            <Button x:Name="BtnTimerReset" Content="Сброс" Style="{StaticResource StopBtn}"/>
          </UniformGrid>
          <!-- метка "успешно" (видна только при -autoStart): зелёный кружок с перекрещенными палочками; клик = снять/поставить -->
          <StackPanel x:Name="SuccessPanel" Orientation="Horizontal" Visibility="Collapsed" Margin="0,8,0,0">
            <Button x:Name="BtnSuccess" Style="{StaticResource DotBtn}"/>
            <TextBlock Text="успешно" FontFamily="Segoe UI" FontSize="11" Foreground="#FF8888AA"
                       VerticalAlignment="Center" Margin="8,0,0,0"/>
          </StackPanel>
        </StackPanel>

        <Separator Grid.Column="1" Background="#30FFFFFF" Margin="8,4"/>

        <!-- МЕТРОНОМ -->
        <StackPanel Grid.Column="2" Margin="10,0,0,0">
          <TextBlock Text="МЕТРОНОМ" FontFamily="Segoe UI" FontSize="11" Foreground="#FF7FB4FF" FontWeight="Bold" Margin="2,0,0,0" HorizontalAlignment="Center"/>
          <TextBlock x:Name="BpmDisplay" Text="60 BPM" FontFamily="Consolas" FontSize="30" FontWeight="Bold"
                     Foreground="#FFE6E6EB" HorizontalAlignment="Center" Margin="0,4,0,4"/>
          <UniformGrid Columns="4" Margin="0,0,0,6">
            <Button x:Name="BtnBpmM10" Content="-10" Style="{StaticResource FlatBtn}"/>
            <Button x:Name="BtnBpmM1" Content="-1" Style="{StaticResource FlatBtn}"/>
            <Button x:Name="BtnBpmP1" Content="+1" Style="{StaticResource FlatBtn}"/>
            <Button x:Name="BtnBpmP10" Content="+10" Style="{StaticResource FlatBtn}"/>
          </UniformGrid>
          <UniformGrid Columns="3" Margin="0,0,0,6">
            <Button x:Name="BtnMetroStart" Content="Старт" Style="{StaticResource GoBtn}"/>
            <Button x:Name="BtnBeat" Content="4/4" Style="{StaticResource NeutralBtn}"/>
            <!-- дробление доли: контент (глиф-картинка) ставится кодом, Update-DivBtn -->
            <Button x:Name="BtnDiv" Style="{StaticResource NeutralBtn}" Padding="4,4"/>
          </UniformGrid>
          <!-- сильные доли такта: закрашенная точка с ">" = сильная -->
          <StackPanel x:Name="BeatDots" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,8,0,0"/>
        </StackPanel>
      </Grid>

      <!-- всплывающая панель прозрачности: открывается шестерёнкой, поверх контента (потому и последний элемент грида) -->
      <Border x:Name="OpacityPanel" Grid.RowSpan="2" Visibility="Collapsed"
              HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,30,2,0"
              Background="#F514141C" CornerRadius="8" Padding="8,6">
        <Border.Effect>
          <DropShadowEffect BlurRadius="6" ShadowDepth="0" Opacity="0.5"/>
        </Border.Effect>
        <StackPanel Orientation="Horizontal">
          <TextBlock Text="Прозрачность" FontFamily="Segoe UI" FontSize="11" Foreground="#FF8888AA" VerticalAlignment="Center" Margin="0,0,6,0"/>
          <Button x:Name="BtnOpM10" Content="-10" Style="{StaticResource FlatBtn}"/>
          <TextBlock x:Name="OpDisplay" Text="100 %" FontFamily="Consolas" FontSize="13" FontWeight="Bold"
                     Foreground="#FFE6E6EB" VerticalAlignment="Center" Margin="6,0" Width="46" TextAlignment="Center"/>
          <Button x:Name="BtnOpP10" Content="+10" Style="{StaticResource FlatBtn}"/>
          <Button x:Name="BtnAbout" Content="О программе" Cursor="Hand" Margin="12,0,0,0" Padding="2,0"
                  Background="Transparent" BorderThickness="0" Foreground="#FF7FB4FF"
                  FontFamily="Segoe UI" FontSize="11">
            <Button.Template>
              <ControlTemplate TargetType="Button">
                <TextBlock Text="{TemplateBinding Content}" Foreground="#FF7FB4FF" FontSize="11"
                           FontFamily="Segoe UI" TextDecorations="Underline"/>
              </ControlTemplate>
            </Button.Template>
          </Button>
        </StackPanel>
      </Border>
    </Grid>
  </Border>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlText)
$win = [Windows.Markup.XamlReader]::Load($reader)

$Find = { param($n) $win.FindName($n) }
$timerDisplay  = & $Find 'TimerDisplay'
$bpmDisplay    = & $Find 'BpmDisplay'
$btnTimerStart = & $Find 'BtnTimerStart'
$btnMetroStart = & $Find 'BtnMetroStart'
$btnBeat       = & $Find 'BtnBeat'
$btnDiv        = & $Find 'BtnDiv'
$btnLink       = & $Find 'BtnLink'
$beatDots      = & $Find 'BeatDots'
$opDisplay     = & $Find 'OpDisplay'
$btnAutostart  = & $Find 'BtnAutostart'
$btnGear       = & $Find 'BtnGear'
$btnAbout      = & $Find 'BtnAbout'
$opacityPanel  = & $Find 'OpacityPanel'
$successPanel  = & $Find 'SuccessPanel'
$btnSuccess    = & $Find 'BtnSuccess'
$titleText     = & $Find 'TitleText'

# --- состояние ---
$state = @{
    TimerLeft   = 300      # остаток, сек
    TimerInitial= 300      # время, с которого последний раз стартовали (сброс и сохранение)
    TimerRun    = $false
    Bpm         = 60
    MetroRun    = $false
    Beats       = 4
    Div         = 1     # щелчков на долю: 1=четверти, 2=восьмые, 4=шестнадцатые, 3=триоли (нотация 4|8|16|3 — только в CLI/файлах)
    Accents     = @(1)     # сильные доли (номера с 1); дефолт — только первая
    ClickCount  = 0        # щелчков прозвучало в такте (0..Beats*Div-1); доля = floor(i/Div)+1
    MetroSw     = $null    # Stopwatch сетки щелчков (антидрейф): узлы = k*интервал от момента старта (fallback-путь)
    UseAudio    = $false   # щелчки идут через аудиоленту NAudio (движок запущен); $false — прежний путь по тикам
    NextClickMs = 0.0      # лента: позиция следующего щелчка (мс от старта движка)
    FinaleAtMs  = $null    # лента: запланированная граница доигрываемого такта (Overrun-финиш)
    Highlights  = @()      # очередь подсветки долей: @{Ms;Beat;Sub} — гасится, когда позиция ленты прозвучала
    TimerResRaised = $false # timeBeginPeriod(1) поднят (сброс — в Add_Closed)
    Linked      = $false   # режим "Связать": общий старт, метроном стоп при нуле таймера
    Overrun     = $false   # перехлёст: таймер на нуле, такт доигрывается до конца (время уходит в минус)
    ExitOnFinish= $false   # закрыть виджет, когда таймер дойдёт до нуля
    AutoStart   = $false   # старт из CLI: показывает "успешно" и включает лог тренировки
    Completed   = $false   # тренировка завершена автовыходом (таймер дошёл до нуля при -exitOnFinish)
    Success     = $true    # "успешно": по умолчанию поставлен; снятие кликом = записать (Success=false) и закрыть
    TrainingLogged = $false # событие тренировки уже записано в лог (защита от повторной записи)
    TrainingLabel = ''     # метка тренировки для лога (-label или GUID)
    StartedAt   = ''       # время старта для лога
}

# --- индикаторные кружки (сильные доли, "успешно"): заполненный синий с красным ">" = включён ---
function Update-Dot {
    param($dot, [bool]$on)
    if ($on) {
        $dot.Background = '#3A4A7A'      # синий, как кнопка размера такта (NeutralBtn "4/4")
        $dot.Foreground = '#FFFF6B6B'    # красный глиф ">"
        $dot.Content = '>'
    } else {
        $dot.Background = '#40FFFFFF'
        $dot.Content = $null
    }
}
# кружок "успешно": зелёный (как СТАРТ) с перекрещенными барабанными палочками = включён;
# снятый — прозрачный круг с приглушёнными палочками
function Update-SuccessDot {
    param([bool]$on)
    if ($on) {
        $btnSuccess.Background = '#3A7A58'
        $stick = '#FFE6E6EB'
    } else {
        $btnSuccess.Background = '#40FFFFFF'
        $stick = '#FF8888AA'
    }
    $c = New-Object System.Windows.Controls.Canvas
    $c.Width = 16; $c.Height = 16
    foreach ($pts in @(@(3,3,13,13), @(13,3,3,13))) {
        $l = New-Object System.Windows.Shapes.Line
        $l.X1 = $pts[0]; $l.Y1 = $pts[1]; $l.X2 = $pts[2]; $l.Y2 = $pts[3]
        $l.Stroke = $stick
        $l.StrokeThickness = 2.5
        $l.StrokeStartLineCap = 'Round'
        $l.StrokeEndLineCap = 'Round'
        [void]$c.Children.Add($l)
    }
    $btnSuccess.Content = $c
}
# подсветка текущей доли во время звучания: синее кольцо + увеличение точки (0 = погасить);
# -Sub = промежуточный щелчок дробления: лёгкий пульс без кольца
function Update-BeatHighlight {
    param([int]$beat, [switch]$Sub)
    for ($i = 0; $i -lt $beatDots.Children.Count; $i++) {
        $d = $beatDots.Children[$i]
        if (($i + 1) -eq $beat) {
            if ($Sub) {
                $d.BorderThickness = New-Object System.Windows.Thickness(0)
                $d.RenderTransform = New-Object System.Windows.Media.ScaleTransform(1.15, 1.15)
            } else {
                $d.BorderBrush = '#FF7FB4FF'
                $d.BorderThickness = New-Object System.Windows.Thickness(2)
                $d.RenderTransform = New-Object System.Windows.Media.ScaleTransform(1.3, 1.3)
            }
        } else {
            $d.BorderThickness = New-Object System.Windows.Thickness(0)
            $d.RenderTransform = $null
        }
    }
}
function Set-Dots {
    $beatDots.Children.Clear()
    for ($i = 1; $i -le $state.Beats; $i++) {
        $dot = New-Object System.Windows.Controls.Button
        $dot.Style = $win.TryFindResource('DotBtn')
        $dot.Tag = $i
        $dot.RenderTransformOrigin = New-Object System.Windows.Point(0.5, 0.5)
        Update-Dot $dot ($state.Accents -contains $i)
        $dot.Add_Click({
            param($sender, $e)
            $n = [int]$sender.Tag
            if ($state.Accents -contains $n) {
                $state.Accents = @($state.Accents | Where-Object { $_ -ne $n })
            } else {
                $state.Accents = @(@($state.Accents) + $n | Sort-Object -Unique)
            }
            Update-Dot $sender ($state.Accents -contains $n)
        })
        [void]$beatDots.Children.Add($dot)
    }
}

# --- дробление доли: глиф-кнопка (PNG рядом с виджетом; нет файлов — текстовая подпись, как с wav это не ошибка) ---
$divPng  = @{ 1 = 'tm_div_4.png'; 2 = 'tm_div_8.png'; 3 = 'tm_div_3.png'; 4 = 'tm_div_16.png' }
$divName = @{ 1 = 'четверти'; 2 = 'восьмые'; 3 = 'триоли'; 4 = 'шестнадцатые' }
$divText = @{ 1 = '1/4'; 2 = '1/8'; 3 = '3'; 4 = '1/16' }
$divNote = @{ 1 = 4; 2 = 8; 3 = 3; 4 = 16 }   # нотация CLI/tm_settings/лога (числом)
function Update-DivBtn {
    $png = Join-Path $scriptDir $divPng[$state.Div]
    if (Test-Path -LiteralPath $png) {
        $img = New-Object System.Windows.Controls.Image
        $bi = New-Object System.Windows.Media.Imaging.BitmapImage
        $bi.BeginInit()
        $bi.UriSource = [Uri]::new($png)      # [Uri]::new(path) даёт file:// и для кириллических путей
        $bi.CacheOption = 'OnLoad'            # не держать файл занятым
        $bi.EndInit()
        $img.Source = $bi
        $img.Width = 18; $img.Height = 18
        $img.Stretch = 'Uniform'
        $btnDiv.Content = $img
    } else {
        $btnDiv.Content = $divText[$state.Div]
    }
    $btnDiv.ToolTip = "Дробление: $($divName[$state.Div]) — клик переключает.`nBPM задаёт темп четверти; дробление добавляет тихие щелчки внутрь доли."
}
# интервал между щелчками: четверть / дробление
function Get-MetroInterval { [TimeSpan]::FromMilliseconds(60000 / $state.Bpm / $state.Div) }

# --- настройки из tm_settings.txt: Left Top Opacity% Bpm Beats Accents TimerInitial ---
# (первые 3 поля — формат v1.6..v1.9; остальные добавлены в v1.10; отсутствующие = дефолты)
$settingsFile = Join-Path $scriptDir 'tm_settings.txt'
# лог тренировок (JSON-строки, только при -autoStart): один файл, события дописываются; путь — из -logPath или дефолт
$logFile = if ($logPath) {
    if ([IO.Path]::IsPathRooted($logPath)) { $logPath } else { Join-Path $scriptDir $logPath }
} else {
    Join-Path $scriptDir 'tm_trainings.jsonl'
}
# запись события тренировки (одна JSON-строка, JSONL); вызывается в момент завершения:
# ноль таймера / конец доигранного такта, либо клик по кружку "успешно". Повторно не пишет.
# Duration — длительность НОТЫ (4|8|16|3, как у -div). Закрытие до конца лог НЕ пишет (как с v1.14).
function Write-TrainingLog {
    if (-not $state.AutoStart -or $state.TrainingLogged) { return }
    $state.TrainingLogged = $true
    try {
        $rec = [ordered]@{
            Label        = $state.TrainingLabel
            Started      = $state.StartedAt
            Finished     = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
            Duration     = $divNote[$state.Div]     # длительность ноты: 4|8|16|3 (триоль = 3)
            Seconds      = $state.TimerInitial
            Bpm          = $state.Bpm
            Beats        = $state.Beats
            Accents      = @($state.Accents)
            Linked       = $state.Linked
            Opacity      = [int][Math]::Round($win.Opacity * 100)
            ExitOnFinish = $state.ExitOnFinish
            AutoStart    = $true
            Completed    = $state.Completed
            Success      = $state.Success
        }
        $json = $rec | ConvertTo-Json -Compress
        $logDir = [IO.Path]::GetDirectoryName($logFile)
        if ($logDir -and -not (Test-Path -LiteralPath $logDir)) { [void][IO.Directory]::CreateDirectory($logDir) }
        [IO.File]::AppendAllText($logFile, $json + [Environment]::NewLine, (New-Object Text.UTF8Encoding $false))
    } catch { }
}
$wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$posApplied = $false
$savedOpacity = 100
$savedBpm = 0; $savedBeats = 0; $savedTimerInitial = 0; $savedDiv = 0
$savedAccents = $null        # @() = "сильных нет" (в файле "-"); $null = поля нет в файле
if (Test-Path $settingsFile) {
    try {
        $parts = (Get-Content $settingsFile -Raw).Trim() -split '\s+'
        $sl = [int]$parts[0]; $st = [int]$parts[1]
        if ($parts.Count -ge 3) { $savedOpacity = [Math]::Min(100, [Math]::Max(20, [int]$parts[2])) }
        if ($parts.Count -ge 4) { $v = 0; if ([int]::TryParse($parts[3], [ref]$v)) { $savedBpm = [Math]::Min(300, [Math]::Max(30, $v)) } }
        if ($parts.Count -ge 5) { $v = 0; if ([int]::TryParse($parts[4], [ref]$v)) { $savedBeats = [Math]::Min(8, [Math]::Max(2, $v)) } }
        if ($parts.Count -ge 6) {
            if ($parts[5] -eq '-') { $savedAccents = @() }
            else {
                $nums = @()
                foreach ($p in ($parts[5] -split '[,\s]+')) {
                    $v = 0
                    if ([int]::TryParse($p, [ref]$v) -and $v -ge 1 -and $savedBeats -gt 0 -and $v -le $savedBeats) { $nums += $v }
                }
                if ($nums.Count -gt 0) { $savedAccents = @($nums | Sort-Object -Unique) }
            }
        }
        if ($parts.Count -ge 7) { $v = 0; if ([int]::TryParse($parts[6], [ref]$v) -and $v -ge 1 -and $v -le 5999) { $savedTimerInitial = $v } }
        if ($parts.Count -ge 8) { $v = 0; if ([int]::TryParse($parts[7], [ref]$v) -and ($v -eq 3 -or $v -eq 4 -or $v -eq 8 -or $v -eq 16)) { $savedDiv = $v } }
        $vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
        if ($sl -ge ($vs.Left - 10) -and $sl -le ($vs.Right - 100) -and $st -ge ($vs.Top - 10) -and $st -le ($vs.Bottom - 50)) {
            $win.Left = $sl; $win.Top = $st
            $posApplied = $true
        }
    } catch { }
}
if (-not $posApplied) {
    $win.Left = $wa.Right - 560     # 540 ширина + отступ
    $win.Top = $wa.Bottom - 248     # ~220 высота (SizeToContent) + отступ на тень
}

# --- параметры командной строки: явное значение бьёт сохранённое; нет ни того ни другого — дефолт ---
if ($seconds -gt 0) { $state.TimerLeft = [Math]::Min(5999, $seconds) }
elseif ($savedTimerInitial -gt 0) { $state.TimerLeft = $savedTimerInitial }
$state.TimerInitial = $state.TimerLeft    # стартовое время таймера; обновляется при каждом запуске отсчёта
if ($bpm -gt 0) { $state.Bpm = [Math]::Min(300, [Math]::Max(30, $bpm)) }
elseif ($savedBpm -gt 0) { $state.Bpm = $savedBpm }
$bpmDisplay.Text = "$($state.Bpm) BPM"
if ($beats -gt 0) { $state.Beats = [Math]::Min(8, [Math]::Max(2, $beats)) }
elseif ($savedBeats -gt 0) { $state.Beats = $savedBeats }
$btnBeat.Content = "$($state.Beats)/4"
# дробление доли: -div 4|8|16|3 (мусор игнорируется); иначе сохранённое; нет ни того ни другого — четверти.
# Нотация 4|8|16|3 (в CLI и tm_settings) переводится во внутреннее "щелчков на долю" 1|2|4|3
$divArg = 0
if ($div -eq 3 -or $div -eq 4 -or $div -eq 8 -or $div -eq 16) { $divArg = $div } elseif ($savedDiv) { $divArg = $savedDiv }
$state.Div = switch ($divArg) { 8 { 2 } 16 { 4 } 3 { 3 } default { 1 } }
Update-DivBtn
# сильные доли: из -accents (номера с 1, вне размера такта игнорируются, мусор = дефолт),
# иначе из сохранённых, иначе дефолт @(1)
if ($accents) {
    $nums = @()
    foreach ($p in ($accents -split '[,\s]+')) {
        $v = 0
        if ([int]::TryParse($p, [ref]$v) -and $v -ge 1 -and $v -le $state.Beats) { $nums += $v }
    }
    if ($nums.Count -gt 0) { $state.Accents = @($nums | Sort-Object -Unique) }
} elseif ($null -ne $savedAccents) {
    $state.Accents = @($savedAccents)
}
Set-Dots
$state.ExitOnFinish = [bool]$exitOnFinish

# --- тренировка (-autoStart): кружок "успешно" в левом нижнем углу + лог тренировки при закрытии ---
$state.AutoStart = [bool]$autoStart
$state.TrainingLabel = if ($label) { $label } else { [guid]::NewGuid().ToString() }
$state.StartedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
if ($autoStart) {
    $successPanel.Visibility = 'Visible'
    Update-SuccessDot $state.Success
    $titleText.Foreground = '#FFFF6B6B'   # красная шапка = режим тренировки (автостарт, пишется лог)
    $btnAutostart.Visibility = 'Collapsed'   # в тренировке автозагрузку не переключаем
    $btnLink.IsEnabled = $false              # и связь не переключаем (красной её делает -link ниже)
    $btnSuccess.ToolTip = "Кружок поставлен = тренировка пройдена успешно.`nСнять кликом = тренировка НЕ удалась: событие записывается в лог (успех = нет) и виджет закрывается.`nЗакрытие по крестику или правому клику лог не пишет."
}
# --- прозрачность: явный -opacity бьёт сохранённую; иначе сохранённая; иначе 100 % ---
$startOpacity = [Math]::Min(100, [Math]::Max(20, $opacity))
if ($opacity -eq 100) { $startOpacity = $savedOpacity }
$win.Opacity = $startOpacity / 100.0
$opDisplay.Text = "$startOpacity %"
if ($link) {
    $state.Linked = $true
    $btnLink.Content = 'Связано'
    $btnLink.Background = if ($state.AutoStart) { '#FFFF6B6B' } else { '#3A7A58' }   # в тренировке -link подсвечивается красным, как шапка
    $btnMetroStart.IsEnabled = $false
}

function Update-TimerDisplay {
    $v = $state.TimerLeft
    $sign = ''
    if ($v -lt 0) { $sign = '-'; $v = -$v }   # перехлёст: время ушло за ноль, пока доигрывался такт
    $m = [int][Math]::Floor($v / 60)
    $s = $v % 60
    $timerDisplay.Text = '{0}{1:00}:{2:00}' -f $sign, $m, $s
}
function Start-Metro {
    if (-not $state.MetroRun) {
        $state.ClickCount = 0
        $state.Highlights = @()
        $state.FinaleAtMs = $null
        # основной путь: аудиолента NAudio (если библиотеки на месте и устройство открылось);
        # планировщик тикает грубо (50 мс) — точность обеспечивает не он, а часы аудиоустройства
        $engineStarted = $false
        if ($audio -and $audio.Ready) {
            $engineStarted = Start-AudioEngine
            if ($engineStarted) { $state.NextClickMs = $audioLaunchMs + 0.0 }
        }
        $state.UseAudio = $engineStarted
        if ($engineStarted) {
            $metroTimer.Interval = [TimeSpan]::FromMilliseconds(50)
        } else {
            $state.MetroSw = [System.Diagnostics.Stopwatch]::StartNew()   # сетка щелчков отсчитывается от этого момента
            $metroTimer.Interval = Get-MetroInterval
        }
        $metroTimer.Start(); $state.MetroRun = $true
        if (-not $state.TimerResRaised) {
            # 1 мс вместо штатных ~15.6: тикам планировщика (и подсветке) меньше приходится ждать системный тик
            try { $state.TimerResRaised = $true; [void][WinMM.Native]::timeBeginPeriod(1) } catch { }
        }
        $btnMetroStart.Content = 'Стоп'
    }
}
function Stop-Metro {
    if ($state.MetroRun) {
        $metroTimer.Stop(); $state.MetroRun = $false
        if ($state.UseAudio) { $state.UseAudio = $false; Stop-AudioEngine }
        $btnMetroStart.Content = 'Старт'
        Update-BeatHighlight 0
    }
}

# --- отложенное закрытие (для -exitOnFinish): даём прозвучать сигналу ---
$closeTimer = New-Object System.Windows.Threading.DispatcherTimer
$closeTimer.Interval = [TimeSpan]::FromSeconds(2.5)
$closeTimer.Add_Tick({ $win.Close() })

# --- таймер: тик раз в секунду ---
$dispatchTimer = New-Object System.Windows.Threading.DispatcherTimer
$dispatchTimer.Interval = [TimeSpan]::FromSeconds(1)
$dispatchTimer.Add_Tick({
    if ($state.TimerLeft -gt 0 -or $state.Overrun) {
        $state.TimerLeft--
        Update-TimerDisplay
        if ($state.TimerLeft -eq 0) {
            if ($state.Linked -and $state.MetroRun) {
                # перехлёст: такт доигрывается до конца, время уходит в минус (стоп — в тике метронома);
                # сигнал здесь НЕ играем — он прозвучит после доигранного такта, чтобы финальные доли были слышны
                $state.Overrun = $true
            } else {
                $playerAlarm.Play()
                $dispatchTimer.Stop()
                $state.TimerRun = $false
                $btnTimerStart.Content = 'Старт'
                if ($state.Linked) { Stop-Metro }   # в связанном режиме метроном замолкает на нуле
                if ($state.ExitOnFinish) { $state.Completed = $true; $closeTimer.Start() }   # автовыход = тренировка завершена
                Write-TrainingLog   # событие логируется в момент завершения, а не при закрытии окна
            }
        }
    }
})

# --- метроном ---
# приоритет Send: тик метронома исполняется до ввода и рендера, а не ждёт их в очереди диспетчера
$metroTimer = New-Object System.Windows.Threading.DispatcherTimer([System.Windows.Threading.DispatcherPriority]::Send)
$metroTimer.Add_Tick({
    if ($state.UseAudio) {
        # ===== основной путь: аудиолента. Тик — грубый планировщик: докладывает в буфер ленту
        # (тишину и щелчки) с упреждением; звучание идёт по часам аудиоустройства, дрожание
        # диспетчера на слух отсутствует, пока оно меньше упреждения =====
        $playedMs = Get-AudioPlayedMs
        $horizonMs = $playedMs + $audioLookaheadMs
        $intervalMs = (Get-MetroInterval).TotalMilliseconds
        # счётчик щелчков такта: 0..Beats*Div-1; доля = floor(i/Div)+1, i кратно Div = щелчок ДОЛИ;
        # после запланированного финала (FinaleAtMs) новых щелчков не закладываем
        while ($null -eq $state.FinaleAtMs -and $state.NextClickMs -le $horizonMs) {
            Write-AudioUntilMs $state.NextClickMs
            $i = $state.ClickCount
            $beat = [math]::Floor($i / $state.Div) + 1
            $isBeatClick = ($i % $state.Div) -eq 0
            if (-not $isBeatClick) { Write-AudioClick $audio.Clicks.Sub }
            elseif ($state.Accents -contains $beat) { Write-AudioClick $audio.Clicks.Hi }
            else { Write-AudioClick $audio.Clicks.Tick }
            $state.Highlights += @{ Ms = $state.NextClickMs; Beat = $beat; Sub = (-not $isBeatClick) }
            $state.ClickCount = ($i + 1) % ($state.Beats * $state.Div)
            $state.NextClickMs += $intervalMs
            if ($state.Overrun -and $state.ClickCount -eq 0) {
                # такт после нуля таймера запланирован до конца: стоп, когда лента дойдёт до границы такта
                $state.FinaleAtMs = $state.NextClickMs
                break
            }
        }
        if ($null -eq $state.FinaleAtMs) { Write-AudioUntilMs $horizonMs }
        elseif ($audio.Written -lt $state.FinaleAtMs) {
            # финал запланирован: ленту нужно дописать тишиной ДО границы такта (+запас), иначе буфер
            # высохнет, позиция «прочитано» замрёт раньше границы и финал никогда не наступит;
            # запас +10 мс закрывает недобор из-за выравнивания кусков кратно 4 байтам (последние
            # 1-3 байта иначе никогда не записываются и played не дотягивает до FinaleAtMs ровно на них)
            Write-AudioUntilMs ($state.FinaleAtMs + 10)
        }
        # подсветка: применяем последний щелчок, чья позиция уже прозвучала (по часам ленты)
        $lastH = $null
        $rest = @()
        foreach ($h in $state.Highlights) { if ($h.Ms -le $playedMs) { $lastH = $h } else { $rest += $h } }
        if ($lastH) { $state.Highlights = $rest; Update-BeatHighlight $lastH.Beat $lastH.Sub }
        # финиш доигранного такта — в момент границы такта по часам ленты (последний щелчок уже в буфере устройства);
        # допуск 0.02 мс (~сэмпл) — округление байтов ленты не должно мешать достижению границы
        if ($null -ne $state.FinaleAtMs -and $playedMs -ge ($state.FinaleAtMs - 0.02)) {
            $state.FinaleAtMs = $null
            $state.Overrun = $false
            $dispatchTimer.Stop()
            $state.TimerRun = $false
            $btnTimerStart.Content = 'Старт'
            Stop-Metro
            $playerAlarm.Play()   # сигнал — после последней прозвучавшей доли, а не в момент нуля
            if ($state.ExitOnFinish) { $state.Completed = $true; $closeTimer.Start() }
            Write-TrainingLog   # такт после нуля доигран: событие логируется здесь
        }
    } else {
        # ===== fallback-путь (нет NAudio или устройства): щелчок играется самим тиком =====
        $i = $state.ClickCount
        $beat = [math]::Floor($i / $state.Div) + 1
        $isBeatClick = ($i % $state.Div) -eq 0
        if (-not $isBeatClick) { $playerTickSub.Play() }
        elseif ($state.Accents -contains $beat) { $playerTickHi.Play() }
        else { $playerTick.Play() }
        Update-BeatHighlight $beat (-not $isBeatClick)
        $state.ClickCount = ($i + 1) % ($state.Beats * $state.Div)
        if ($state.Overrun -and $state.ClickCount -eq 0) {
            # такт после нуля таймера доигран до конца: остановить всё на границе такта
            $state.Overrun = $false
            $dispatchTimer.Stop()
            $state.TimerRun = $false
            $btnTimerStart.Content = 'Старт'
            Stop-Metro
            $playerAlarm.Play()   # сигнал — после последней прозвучавшей доли, а не в момент нуля
            if ($state.ExitOnFinish) { $state.Completed = $true; $closeTimer.Start() }
            Write-TrainingLog   # такт после нуля доигран: событие логируется здесь
        }
        if ($state.MetroRun) {
            # антидрейф: интервал до БЛИЖАЙШЕГО БУДУЩЕГО узла сетки от старта, а не «номинал от сейчас» —
            # разовая задержка диспетчера компенсируется более коротким интервалом, и темп не ползёт
            # (скобки обязательны: Get-MetroInterval.TotalMilliseconds = вызов несуществующей команды)
            $nominalMs = (Get-MetroInterval).TotalMilliseconds
            $nextMs = $nominalMs - ($state.MetroSw.ElapsedMilliseconds % $nominalMs)
            if ($nextMs -lt 1) { $nextMs = 1 }
            $metroTimer.Interval = [TimeSpan]::FromMilliseconds($nextMs)
        }
    }
})

# --- кнопки таймера ---
$clickTime = {
    param($sender, $e)
    $delta = switch ($sender.Content) { '-1м' { -60 } '-10с' { -10 } '+10с' { 10 } '+1м' { 60 } }
    if (-not $state.TimerRun) {
        $state.Overrun = $false
        $state.TimerLeft = [Math]::Min(5999, [Math]::Max(0, $state.TimerLeft + $delta))
        Update-TimerDisplay
    }
}
foreach ($n in 'BtnM60','BtnM10','BtnP10','BtnP60') {
    (& $Find $n).Add_Click($clickTime)
}
$btnTimerStart.Add_Click({
    if (-not $state.TimerRun -and $state.TimerLeft -gt 0) {
        $state.Overrun = $false
        $state.TimerInitial = $state.TimerLeft     # запомнить, с чего стартовали в этот раз
        $dispatchTimer.Start(); $state.TimerRun = $true; $btnTimerStart.Content = 'Пауза'
        if ($state.Linked) { Start-Metro }
    } elseif ($state.TimerRun) {
        $dispatchTimer.Stop(); $state.TimerRun = $false; $btnTimerStart.Content = 'Старт'
        if ($state.Linked) { Stop-Metro }
    }
})
(& $Find 'BtnTimerReset').Add_Click({
    $dispatchTimer.Stop(); $state.TimerRun = $false; $state.Overrun = $false
    $state.TimerLeft = $state.TimerInitial     # к последнему стартовому времени, а не к 300
    $btnTimerStart.Content = 'Старт'
    if ($state.Linked) { Stop-Metro }
    Update-TimerDisplay
})

# --- автостарт из командной строки (-autoStart) ---
if ($autoStart -and $state.TimerLeft -gt 0) {
    $state.TimerInitial = $state.TimerLeft
    $dispatchTimer.Start(); $state.TimerRun = $true
    $btnTimerStart.Content = 'Пауза'
    if ($state.Linked) { Start-Metro }
}

# --- кнопки метронома ---
$clickBpm = {
    param($sender, $e)
    $delta = [int]$sender.Content
    $state.Bpm = [Math]::Min(300, [Math]::Max(30, $state.Bpm + $delta))
    $bpmDisplay.Text = "$($state.Bpm) BPM"
    if ($state.UseAudio) { Reset-AudioGrid }   # новый темп = новая сетка от конца ленты (уже записанное доиграется)
    else { $metroTimer.Interval = Get-MetroInterval }
    if ($state.MetroRun -and -not $state.UseAudio) { $state.MetroSw.Restart() }
}
foreach ($n in 'BtnBpmM10','BtnBpmM1','BtnBpmP1','BtnBpmP10') {
    (& $Find $n).Add_Click($clickBpm)
}
$btnMetroStart.Add_Click({
    if ($state.MetroRun) { Stop-Metro } else { Start-Metro }
})
$btnBeat.Add_Click({
    # цикл размера такта: 2..8, затем снова 2; сильные доли сбрасываются к дефолту (первая)
    $state.Beats = if ($state.Beats -ge 8) { 2 } else { $state.Beats + 1 }
    $state.ClickCount = 0
    $state.Accents = @(1)
    $btnBeat.Content = "$($state.Beats)/4"
    Set-Dots
})
$btnDiv.Add_Click({
    # цикл дробления: четверти -> восьмые -> шестнадцатые -> триоли -> четверти;
    # такт начинается заново (следующий щелчок = первая доля), интервал пересчитывается
    $state.Div = switch ($state.Div) { 1 { 2 } 2 { 4 } 4 { 3 } default { 1 } }
    $state.ClickCount = 0
    if ($state.UseAudio) { Reset-AudioGrid }   # новая плотность щелчков = новая сетка от конца ленты
    else { $metroTimer.Interval = Get-MetroInterval }
    if ($state.MetroRun -and -not $state.UseAudio) { $state.MetroSw.Restart() }
    Update-DivBtn
})

# --- метка "успешно" (тренировка): кружок по умолчанию поставлен (успех);
# снятие кликом = «тренировка НЕ удалась»: записать событие (Success=false) и сразу закрыть виджет ---
$btnSuccess.Add_Click({
    $state.Success = $false
    Update-SuccessDot $state.Success
    Write-TrainingLog
    $win.Close()
})

# --- переключатель "Связать" ---
$btnLink.Add_Click({
    $state.Linked = -not $state.Linked
    if ($state.Linked) {
        $btnLink.Content = 'Связано'
        $btnLink.Background = '#3A7A58'
        $btnMetroStart.IsEnabled = $false   # управляет общая кнопка Старт у таймера
        # метроном подчиняется текущему состоянию таймера
        if ($state.TimerRun) { Start-Metro } else { Stop-Metro }
    } else {
        $btnLink.Content = 'Связать'
        $btnLink.Background = '#3A4A7A'
        $btnMetroStart.IsEnabled = $true
    }
})

# --- автозагрузка: ярлык "T-REX метроном.lnk" в Startup пользователя ---
$startupLnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'T-REX метроном.lnk'
function Test-Autostart { Test-Path -LiteralPath $startupLnk }
function Set-Autostart {
    param([bool]$on)
    if ($on) {
        $ws = New-Object -ComObject WScript.Shell
        $sc = $ws.CreateShortcut($startupLnk)
        if ($isExe) {
            $sc.TargetPath = $selfPath
            $sc.Arguments = ''
        } else {
            $sc.TargetPath = (Get-Process -Id $PID).Path
            $sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$selfPath`""
        }
        $sc.WorkingDirectory = $scriptDir
        $ico = Join-Path $scriptDir 'T-REX.ico'
        if (Test-Path -LiteralPath $ico) { $sc.IconLocation = "$ico,0" }
        $sc.Save()
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($ws)
    } else {
        Remove-Item -LiteralPath $startupLnk -ErrorAction SilentlyContinue
    }
}
function Update-AutostartBtn {
    if (Test-Autostart) {
        $btnAutostart.Content = 'Автозагрузка: вкл'
        $btnAutostart.Background = '#3A7A58'
    } else {
        $btnAutostart.Content = 'Автозагрузка: выкл'
        $btnAutostart.Background = '#3A4A7A'
    }
}
$btnAutostart.Add_Click({
    Set-Autostart (-not (Test-Autostart))
    Update-AutostartBtn
})
Update-AutostartBtn

# --- перетаскивание, прозрачность, закрытие ---
$win.Add_MouseLeftButtonDown({ $win.DragMove() })
$clickOpacity = {
    param($sender, $e)
    $op = [int][Math]::Round($win.Opacity * 100) + [int]$sender.Content
    $op = [Math]::Min(100, [Math]::Max(20, $op))
    $win.Opacity = $op / 100.0
    $opDisplay.Text = "$op %"
}
foreach ($n in 'BtnOpM10', 'BtnOpP10') {
    (& $Find $n).Add_Click($clickOpacity)
}
$btnGear.Add_Click({
    # показать/скрыть панель прозрачности под шестерёнкой
    if ($opacityPanel.Visibility -eq 'Collapsed') { $opacityPanel.Visibility = 'Visible' } else { $opacityPanel.Visibility = 'Collapsed' }
})

# --- "О программе": окно с автором; ссылка/закрытие открывают readme.md ---
$readmeFile = Join-Path $scriptDir 'readme.md'
$btnAbout.Add_Click({
    $aboutWin = New-Object System.Windows.Window
    $aboutWin.Title = 'О программе'
    $aboutWin.WindowStyle = 'ToolWindow'
    $aboutWin.SizeToContent = 'WidthAndHeight'
    $bc = New-Object System.Windows.Media.BrushConverter
    $aboutWin.Background = $bc.ConvertFromString('#FF1E1E26')
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = New-Object System.Windows.Thickness(16)
    $tb1 = New-Object System.Windows.Controls.TextBlock
    $tb1.Text = 'T-REX метроном v1.19'
    $tb1.FontFamily = New-Object System.Windows.Media.FontFamily('Segoe UI')
    $tb1.FontSize = 16; $tb1.FontWeight = [System.Windows.FontWeights]::Bold
    $tb1.Foreground = $bc.ConvertFromString('#FF7FB4FF')
    $tb2 = New-Object System.Windows.Controls.TextBlock
    $tb2.Text = 'Автор — Валентин Суровцев'
    $tb2.FontFamily = New-Object System.Windows.Media.FontFamily('Segoe UI')
    $tb2.FontSize = 13
    $tb2.Foreground = $bc.ConvertFromString('#FFE6E6EB')
    $tb2.Margin = New-Object System.Windows.Thickness(0,8,0,0)
    $lnk = New-Object System.Windows.Controls.TextBlock
    $h = New-Object System.Windows.Documents.Hyperlink
    $h.Inlines.Add('Открыть readme.md (описание и история версий)')
    $lnk.Inlines.Add($h)
    $lnk.Margin = New-Object System.Windows.Thickness(0,12,0,0)
    $openReadme = {
        if (Test-Path -LiteralPath $readmeFile) {
            Start-Process -FilePath 'notepad.exe' -ArgumentList "`"$readmeFile`""
        } else {
            [void][System.Windows.MessageBox]::Show("Файл не найден:`n$readmeFile", 'T-REX метроном')
        }
    }
    $h.Add_Click($openReadme)
    $btnClose = New-Object System.Windows.Controls.Button
    $btnClose.Content = 'Закрыть'
    $btnClose.Margin = New-Object System.Windows.Thickness(0,14,0,0)
    $btnClose.Padding = New-Object System.Windows.Thickness(14,4,14,4)
    $btnClose.Width = 90
    $btnClose.Add_Click({ $aboutWin.Close() }.GetNewClosure())
    $sp.Children.Add($tb1); $sp.Children.Add($tb2); $sp.Children.Add($lnk); $sp.Children.Add($btnClose)
    $aboutWin.Content = $sp
    $aboutWin.Owner = $win
    $aboutWin.WindowStartupLocation = 'CenterOwner'
    [void]$aboutWin.ShowDialog()
})
$win.Add_MouseWheel({
    param($sender, $e)
    $op = $win.Opacity + ($(if ($e.Delta -gt 0) { 0.1 } else { -0.1 }))
    $win.Opacity = [Math]::Min(1.0, [Math]::Max(0.2, $op))
    $opDisplay.Text = "$([int][Math]::Round($win.Opacity * 100)) %"
})
(& $Find 'BtnClose').Add_Click({ $win.Close() })
$win.Add_Closed({
    # остановить аудиодвижок до всего остального: живой поток WasapiOut удерживал бы процесс
    # (в ps2exe-сборке — секунды после закрытого окна) от завершения
    if ($audio) { try { Stop-AudioEngine } catch { } }
    try {
        # Left Top Opacity% Bpm Beats Accents TimerInitial Div; "сильных нет" пишется как "-"
        $acc = '-'
        if ($state.Accents.Count -gt 0) { $acc = $state.Accents -join ',' }
        "$([int]$win.Left) $([int]$win.Top) $([int][Math]::Round($win.Opacity * 100)) $($state.Bpm) $($state.Beats) $acc $($state.TimerInitial) $($divNote[$state.Div])" |
            Set-Content -LiteralPath $settingsFile -Encoding ASCII
    } catch { }
    # лог тренировки здесь НЕ пишется: событие фиксируется в момент завершения (Write-TrainingLog),
    # закрытие по крестику/правому клику до завершения = тренировка не залогирована
    # отпустить mutex сразу: ps2exe-процесс ещё живёт секунды после закрытия окна,
    # и мгновенный перезапуск за это время не должен отсекаться как "второй экземпляр"
    try { $singleton.ReleaseMutex() } catch { }
    # вернуть системному таймеру штатное разрешение (парно к timeBeginPeriod в Start-Metro)
    if ($state.TimerResRaised) { try { $state.TimerResRaised = $false; [void][WinMM.Native]::timeEndPeriod(1) } catch { } }
})

Update-TimerDisplay
$win.Add_MouseRightButtonDown({ $win.Close() })
[void]$win.ShowDialog()
