@echo off
set ARGS=--wf-raw-part=@"%~dp0windivert.filter\windivert_part.wireguard.txt" --lua-init=@"%~dp0lua\zapret-lib.lua" --lua-init=@"%~dp0lua\zapret-antidpi.lua" --lua-init=@"%~dp0lua\zapret-auto.lua" --filter-l7=wireguard --payload=wireguard_initiation --lua-desync=repeater:instances=2:repeats=3 --lua-desync=luaexec:code="desync.rnd=brandom(math.random(32,64))" --lua-desync=fake:blob=rnd

net stop ZapretRW >nul 2>&1
sc delete ZapretRW >nul 2>&1
sc create ZapretRW binPath= "\"%~dp0winws2.exe\" %ARGS%" DisplayName= "Zapret RW - WireGuard" start= demand
sc description ZapretRW "Zapret RW: strategy3 wireguard-only (bol-van/zapret official preset2_wireguard)"
sc start ZapretRW
echo 3 > "%~dp0active.txt"
