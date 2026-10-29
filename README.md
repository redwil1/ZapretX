# ZapretX

A Windows GUI for [bol-van/zapret](https://github.com/bol-van/zapret) — DPI circumvention via TCP/QUIC packet mangling (WinDivert). Dark, Amnezia-style interface instead of the usual batch-file-and-console-window workflow.

![platform](https://img.shields.io/badge/platform-Windows-blue) ![license](https://img.shields.io/badge/license-GPL--3.0-green)

## What it does

Zapret doesn't give you a VPN — it reshapes your own traffic (fake packets, TTL tricks, fragmentation, SNI mangling) so DPI middleboxes stop recognizing and blocking it. ZapretX wraps the official `winws`/`winws2` engines in:

- **Multiple strategies** you can try one by one — not every ISP's DPI reacts the same way to the same trick.
- **Favorites** — mark the one that actually works for your provider so you don't have to re-test after every reboot.
- **System tray** — minimizes instead of sitting in the taskbar; closing the window keeps the bypass running in the background.
- A UI that doesn't look like a leftover `.bat` file.

## Strategies included

| # | Name | What it targets |
|---|------|------------------|
| 1 | Классическая (Classic) | YouTube / general sites — `winws.exe`, official preset1 |
| 2 | Lua-движок (Lua engine) | Same goal, different engine — try if #1 doesn't help |
| 3 | Только WireGuard (WireGuard-only) | Narrow preset that leaves other sites alone — for VPN traffic (e.g. AmneziaWG) |

## Requirements

- Windows 10/11
- PowerShell 5.1 (included with Windows) — the app is a WPF GUI written in PowerShell, no separate runtime to install
- Administrator rights to start/stop the `ZapretRW` Windows service (you'll get a UAC prompt when toggling a strategy)

## Running it

Double-click **`ZapretRW.cmd`**. (Double-clicking `ZapretRW.ps1` itself just opens it in Notepad — that's Windows' default for PowerShell scripts.)

The launcher runs:

```
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ZapretRW.ps1
```

`-ExecutionPolicy Bypass` is needed because a folder downloaded from GitHub is marked as coming from the internet, and Windows would otherwise refuse to run the script. To get a desktop icon, right-click `ZapretRW.cmd` → *Send to* → *Desktop (create shortcut)*.

## How it works under the hood

Each strategy runs as a Windows service named `ZapretRW`, created fresh by `strategy1.cmd` / `strategy2.cmd` / `strategy3.cmd` and torn down by `off.cmd`. The GUI just reflects real `Get-Service` state plus a small marker file (`active.txt`) — there's no hidden "fake connected" state.

## Credit

All of the actual DPI-bypass engine (`winws.exe`, `winws2.exe`, WinDivert, the strategy presets and filter lists) is the unmodified official build from [bol-van/zapret](https://github.com/bol-van/zapret), licensed GPL-3.0. This repo only adds the GUI/service layer around it.

## Disclaimer

For personal, lawful use to access content you're otherwise entitled to reach. You're responsible for how you use this in your jurisdiction.
