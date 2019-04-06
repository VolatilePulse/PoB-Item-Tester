@echo off

powershell -Command "(New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/xanthics/PoE_Weighted_Search/master/mods.json', 'ItemTester\mods.json')"
