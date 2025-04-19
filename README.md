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
	- Import your passenger number from current simbrief flightplan!!!
	- Choose speed of the boarding (Real, Fast and Instant).

- Start boarding/deboarding.
- Edit script settings such as:
	- Set your Simbrief username
	- Set your Hoppie logon code
 	- Set method for receiving your loadsheet (CPDLC or Telex)
	- Turning on option that simulates some passengers not showing up after simbrief import
	- Using front and back door for boarding / deboarding in addition to front door (default is front door only)

In addition to that it automatically:

- Randomizes (also smartly randomize) the passenger distribution so it won't be always the same which will result in different trim values every flight!
- Opens passenger/cargo doors when boarding is started and closes them after its finished.
- Adjusts payload of the aircraft to match the boarding status.

After you start boarding/deboarding process you can close the window (the process will run in background) and you can follow the progress of boarding/deboarding by hovering over the bottom left side of the screen.

After the boarding/deboarding will finish the application window will show itself, and boarding chime will ring informing you that boarding has completed.

## Loadsheet Caveats
- Currently supported airframes: all narrow bodies and the A339
- Passenger weight must stay at the default of 100 kg
- Cargo is currently unsupported
- If you use Telex as delivery method you must send a PDC request prior to boarding completion. If you're not connected to a network use a fake station name like *XXXX* in order to not disturb the online systems.
  
## INSTALLATION
1. Install current version of FlyWithLua NG+, if you don't have it already.
2. Extract the zip in the "<X-Plane-Folder>/Resources/plugins/FlyWithLua/" folder. Be sure that you have all the needed files in the MODULE folder because there are essential for the script to work.
3. Enjoy!!!
   
It should be compatible with every Toliss version.
