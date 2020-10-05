## Purpose

These files are used in the development and testing of PoB-Item-Tester.

## Usage

The `test` batch files depend on paths within `TestItem.ini` so require that the main AHK script has run and detected PoB correctly. The build selected for testing is also read from the ini.

Current directory should always be PoB-Item-Tester root.

```bat
$ cd PoB-Item-Tester
$ cmd /c test\testitem.bat
...
Results output to: ...\PoB-Item-Tester\test\testitems\ring.txt.html
```
