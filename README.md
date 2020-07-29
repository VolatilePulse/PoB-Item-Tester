# Path of Building Item Tester ![Discord Banner 3](https://discordapp.com/api/guilds/520831275393613824/widget.png?style=shield)
AHK and Lua scripts to automate comparing PoE items from in game or trade sites against your current build with the power of PoB - without needing to run it.

#### Features:
* Quickly see the impact of items from trade sites without launching PoB
* Update your build from pathofexile.com in PoB with a single keypress
* Generate a weighted DPS trade search to help find the strongest items for your build (utilising a 3rd-party website, see below)

Simply run `TestItem.ahk` to get started.

#### Requirements
* [Autohotkey v1](https://www.autohotkey.com/) is required. Do not install v2.
* Path of Building is required (supports both the portable and installer versions).
  * [Path of Building](https://github.com/Openarl/PathOfBuilding) or [Path of Building (Community Fork)](https://github.com/PathOfBuildingCommunity) 

## Item Testing
With the AHK script running...
* Copy the item to the clipboard. Use the official trade site's Copy button, or ingame simply press Ctrl-C over the item.
* Press Ctrl-Windows-C.
* Alternatively, press Ctrl-Windows-Alt-C to launch the build picker before performing the test.
* A pop-up will show the item preview from inside Path of Building, including showing how your stats will be affected.

Testing items on the official trade site:
![Screenshot of the item tester in action](https://raw.githubusercontent.com/VolatilePulse/PoB-Item-Tester/master/imgs/sshot-tester.png)

## Build Update
With the AHK script running...
* Press Ctrl-Windows-U and wait a moment.
* Altneratively, invoking the build picker during item testing (with Ctrl-Windows-Alt-C) will allow you to select "Update build before continuing".
* The script will re-import your build from pathofexile.com, using the existing import settings in Path of Building.
* **Beware! This will overwrite local changes to your build**

## DPS Search
With the AHK script running...
* Press Ctrl-Windows-D.
* Alternatively, press Ctrl-Windows-Alt-D to launch the build picker before performing the test.
* A browser will open `http://gw2crafts.net/pobsearch/modsearch.html`, including the results of various mod tests. The name of your build and current skill are also included only so you can verify the test was performed on the right skill.
* Check the flags located further down the page and alter if desired. The script makes a guess from your skills and config but it's unlikely to get it 100% right.
* Press the Generate button and a link to the official trade site will appear.
* Sometimes this link will have to be opened twice due to an issue on the official trade site.

Note: This webservice is created and maintained by [Xanthics](https://github.com/xanthics). See [its repository](https://github.com/xanthics/PoE_Weighted_Search) for more details.
Without this service this functionality would not be possible.

A generated DPS search:
![Screenshot of the DPS search result](https://raw.githubusercontent.com/VolatilePulse/PoB-Item-Tester/master/imgs/sshot-dps.png)

## Thanks
This tool could not exist without the amazing Path of Building, without PoE_Weighted_Search... and of course without Grinding Gear Games.
