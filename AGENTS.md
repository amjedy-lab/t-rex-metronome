# AGENTS.md — T-REX Metronome

Instructions for AI coding agents working in this repository.

## What this is

A single-file Windows desktop widget (metronome + practice timer): PowerShell + WPF.
The XAML lives in a here-string inside `TimerMetronome.ps1` and is loaded with
`XamlReader.Load` + `FindName`. The script is compiled into a portable `t_rex_metr.exe`
with ps2exe. UI state is kept in `$state`; user settings in `tm_settings.txt`;
the training log is JSONL (append-only).

## Hard constraints

- The source must stay **Windows PowerShell 5.1-compatible** (ps2exe compiles under
  5.1). No PowerShell 7-only syntax.
- Encoding: **UTF-8 with BOM** (otherwise Cyrillic turns into garbage in the exe).
- One file: UI, logic and sound synthesis all live in `TimerMetronome.ps1`.
  Wav sounds are generated at first launch — do not commit binaries.
- `tm_div_*.png` and `T-REX.ico` must stay next to the script; icon frames for csc
  must be classic BMP (see `make_icon.ps1`).
- Bump the version in the window header on every user-visible change.

## Build & test

1. Close all running instances first (`Get-Process t_rex_metr` must return nothing):
   rebuilding over a running exe silently keeps the old binary.
2. Build: `pwsh -NoProfile -ExecutionPolicy Bypass -File build_exe.ps1`
   (requires the ps2exe module).
3. Test both the `.ps1` and the built exe under PowerShell 5.1 and pwsh 7.

## Repo hygiene

Gitignored local files (never publish): `tm_settings.txt`, `tm_trainings.jsonl`,
generated `tm_*.wav`, built `t_rex_metr.exe`, `backup_*/`, internal notes.
Public docs: bilingual `readme.md`; GitHub Releases carry the exe.
