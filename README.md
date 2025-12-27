# TOBUS mod
**This is a mod of TOBUS by @piotr-tomczyk who is unreachable and seems to have other prorities now. I took the liberty to add some functionality and keep this tool alive.**

Credits:

- Script creation by @piotr-tomczyk
- Initial loadsheet by @Tom_David
- Manta32 for cpdlc code released with MIT license, see copyright notice below

```
ToLoadHUB
Author: Manta32
Special thanks to: Giulio Cataldo for the night spent suffering with me
Initial project by: @piotr-tomczyk aka @travisair
Thanks to: @hotbso for the idea
Extra thanks to: @Qlaudie73 for the new features, and @Pilot4XP for the valuable information
License: MIT License
```

--------------------------------------------------------------------------------------------------------------------------------


## DESCRIPTION
This script simulates the boarding process for your ToLiss fleet. It pulls data from simbrief,
simulates timing of passenger boarding applying some variation (late booking, no-show) and send a final loadsheet (see some caveats below).

It adds an tab to FlightWithLua Macros tab, that when opened presents you with an window that lets you:

- Select a passenger number that you want to board/deboard.
	- Select that number randomly (it's not just 0 - 100 random generator, I put some scaling into this random values in order for them to reflect passenger numbers much better).
	- Import your passenger number automatically from simbrief_hub.
	- Choose speed of the boarding
- Start boarding/deboarding.
- Edit script settings such as:
	- Set your Hoppie logon code
 	- Set method for receiving your loadsheet (CPDLC or Telex)
	- Turning on option that simulates some passengers not showing up after simbrief import
	- Using front and back door for boarding / deboarding in addition to front door (default is front door only)

In addition to that it automatically:

- Randomizes the passenger number and distribution so you have small differences between OFP, prelim loadsheet and final loadsheet.
- Opens passenger/cargo doors when boarding is started and closes them after its finished.
- Adjusts payload of the aircraft to match the boarding status.

After you start boarding/deboarding process you can close the window and the process will continue in the background.

After the boarding/deboarding finishes a chime will ring and the cabin crew will inform you that boarding/deboarding has completed.

## Command interface
The script adds commands:
```FlyWithLua/TOBUS/start_boarding``` and ```FlyWithLua/TOBUS/start_deboarding```.

After initial configuration these allow to run the script without opening the TOBUS window at all.

## Loadsheet Caveats
- Currently supported airframes: all narrow bodies and the A339
- Passenger weight must stay at the default of 100 kg
- Cargo is currently unsupported
- If you use Telex as delivery method you must send a PDC request prior to boarding completion. If you're not connected to a network use a fake station name like *XXXX* in order to not disturb the online systems.
  
## INSTALLATION
1. Install current version of FlyWithLua NG+, if you don't have it already.
2. For Simbrief integration to work install the [simbrief_hub](https://github.com/hotbso/simbrief_hub?tab=readme-ov-file#simbrief_hub) plugin 1.0.1 or later.
3. Extract the zip in the "<X-Plane-Folder>/Resources/plugins/FlyWithLua/" folder. Be sure that you have all the needed files in the MODULE folder because there are essential for the script to work.

It should be compatible with every Toliss version.
