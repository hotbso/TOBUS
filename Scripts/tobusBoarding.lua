if PLANE_ICAO == "A319" or PLANE_ICAO == "A20N" or PLANE_ICAO == "A321" or
   PLANE_ICAO == "A21N" or PLANE_ICAO == "A346" or PLANE_ICAO == "A339"
then

local VERSION = "1.6-hotbso"
logMsg("TOBUS " .. VERSION .. " startup")

 --http library import
local xml2lua = require("xml2lua")
local handler = require("xmlhandler.tree")
local socket = require "socket"
local http = require "socket.http"
local LIP = require("LIP")

local wait_until_speak = 0
local speak_string

local intended_no_pax_set = false

local tls_no_pax    --AirbusFBW/NoPax    -- dataref_table
local tank_content_array -- dataref_table
local units --simbrief
local operator --simbrief
local flightNo --simbrief
local intendedPassengerNumber --simbrief
local oew --simbrief
local paxWeight --simbrief pax weight
local taxiFuel --simbrief
local mzfw --simbrief
local mtow --simbrief
local MAX_PAX_NUMBER = 224

local SIMBRIEF_LOADED = false
local SETTINGS_FILENAME = "/tobus/tobus_settings.ini"
local SIMBRIEF_FLIGHTPLAN_FILENAME = "simbrief.xml"
local SIMBRIEF_ACCOUNT_NAME = ""
local HOPPIE_LOGON = ""
local RANDOMIZE_SIMBRIEF_PASSENGER_NUMBER = false
local USE_SECOND_DOOR = false
local CLOSE_DOORS = true
local LEAVE_DOOR1_OPEN = true
local SIMBRIEF_FLIGHTPLAN = {}

local jw1_connected = false     -- set if an opensam jw at the second door is detected
local opensam_door_status = nil
if nil ~= XPLMFindDataRef("opensam/jetway/door/status") then
	opensam_door_status = dataref_table("opensam/jetway/door/status")
end

local function format_ls_row(label, value, digit)
    return label .. string.rep(".", digit - #label - #value) .. " @" .. value .. "@ "
end

local function send_loadsheet(ls)
    if not SIMBRIEF_LOADED or HOPPIE_LOGON == "" then
        logMsg("LOADSHEET UNAVAIL DUE TO NO SIMBRIEF DATA OR MISSING HOPPIE LOGIN")
        return
    end

    local loadSheetContent = "/data2/313//NE/" .. table.concat({
        "Loadsheet @" .. ls.title .. "@ " .. os.date("%H:%M"),
        format_ls_row("ZFW",  ls.zfw, 9),
        format_ls_row("ZFWCG", ls.zfwcg, 9),
        format_ls_row("TOW", ls.tow, 9),
        format_ls_row("GWCG", ls.gwcg, 9),
        format_ls_row("F.BLK", ls.f_blk, 9),
    }, "\n")

    local payload = string.format("logon=%s&from=%s&to=%s&type=%s&packet=%s",
        HOPPIE_LOGON,
        operator .. "OPS",
        operator .. flightNo,
        'cpdlc',
        loadSheetContent:gsub("\n", "%%0A")
    )

    logMsg(payload)

    local msg, code = http.request{
            url = "https://www.hoppie.nl/acars/system/connect.html",
            method = "POST",
            headers = {
                ["Content-Type"] = "application/x-www-form-urlencoded",
                ["Content-Length"] = tostring(#payload),
            },
            source = ltn12.source.string(payload),
        }

    logMsg(string.format("Hoppie returns: '%s', code: %d", msg, code))
end

local function generateFinalLoadsheet()
    local cargo = math.ceil(get("AirbusFBW/FwdCargo") + get("AirbusFBW/AftCargo"))

    -- get("toliss_airbus/init/BlockFuel")
    local fob = 0
    for i = 0,8 do
        fob = fob + tank_content_array[i]
    end

    if units == "lbs" then
        fob = 100 * math.floor(fob * 2.20462 / 100)
    else
        fob =100 * math.floor(fob / 100)
    end

    local zfw = oew + cargo + tls_no_pax[0] * paxWeight
    local tow = zfw + fob - taxiFuel
    logMsg((tls_no_pax[0] * paxWeight))

    local ls = {}
    ls.title = "Final"
    ls.gwcg = string.format("%0.1f", get("AirbusFBW/CGLocationPercent"))
    ls.zfw = string.format("%0.1f", zfw / 1000)
    ls.tow = string.format("%0.1f",  tow / 1000)
    ls.zfwcg = string.format("%0.1f", 29.2)
    ls.f_blk = string.format("%d", fob)
    send_loadsheet(ls)
end

-- local function generateFinalLoadsheet()
    -- if SIMBRIEF_LOADED == true and HOPPIE_LOGON ~= "" then
        -- cargo = math.ceil(get("AirbusFBW/FwdCargo") + get("AirbusFBW/AftCargo"))

        -- if units == "lbs" then
            -- fob = 100* math.floor(get("toliss_airbus/init/BlockFuel") * 2.20462/100)
        -- else
            -- fob =100* math.floor(get("toliss_airbus/init/BlockFuel")/100)
        -- end

        -- gwMac = get("AirbusFBW/CGLocationPercent")
        -- zfw = oew + cargo + (tls_no_pax[0] * paxWeight)
        -- logMsg((tls_no_pax[0] * paxWeight))
        -- tow = zfw + fob - taxiFuel

        -- if zfw > mzfw or tow > mtow then
            -- local response, statusCode = http.request("http://www.hoppie.nl/acars/system/connect.html?logon=" .. HOPPIE_LOGON .. "&from=" .. operator .. "LC&to=" .. operator .. flightNo .. "&type=telex&packet=LOAD+DISCREPANCY:+RETURN+TO+GATE")
            -- logMsg("Hoppie Loadsheet Sent. Response:"..response.."Status Code:"..statusCode)
        -- else
            -- local response, statusCode = http.request("http://www.hoppie.nl/acars/system/connect.html?logon=" .. HOPPIE_LOGON .. "&from=" .. operator .. "LC&to=" .. operator .. flightNo .. "&type=telex&packet=FINAL+LOADSHEET%0A" .. operator .. flightNo .. "%0A" .. string.format("PAX:%d", tls_no_pax[0]) .. "%0A" .. string.format("TOW:%d", tow) .. "%0A" .. string.format("ZFW:%d", zfw) .. "%0A" .. string.format("GWCG:%.1f", gwMac) .. "%0A" .. string.format("FOB:%d", fob) .. "%0AUNIT:" .. units)
            -- logMsg("Hoppie Loadsheet Sent. Response:"..response.."Status Code:"..statusCode)
        -- end
    -- else
        -- logMsg("LOADSHEET UNAVAIL DUE TO NO SIMBRIEF DATA OR MISSING HOPPIE LOGIN")
    -- end
-- end

local function openDoorsForBoarding()
    passengerDoorArray[0] = 2
    if USE_SECOND_DOOR or jw1_connected then
        if PLANE_ICAO == "A319" or PLANE_ICAO == "A20N" or PLANE_ICAO == "A339" then
            passengerDoorArray[2] = 2
        end
        if PLANE_ICAO == "A321" or PLANE_ICAO == "A21N" or PLANE_ICAO == "A346" then
            passengerDoorArray[6] = 2
        end
    end
    cargoDoorArray[0] = 2
    cargoDoorArray[1] = 2
end

local function closeDoorsAfterBoarding()
    if not CLOSE_DOORS then return end

    if not LEAVE_DOOR1_OPEN then
        passengerDoorArray[0] = 0
    end

    if USE_SECOND_DOOR or jw1_connected then
        if PLANE_ICAO == "A319" or PLANE_ICAO == "A20N" or PLANE_ICAO == "A339" then
            passengerDoorArray[2] = 0
        end

        if PLANE_ICAO == "A321" or PLANE_ICAO == "A21N" or PLANE_ICAO == "A346" or PLANE_ICAO == "A339" then
            passengerDoorArray[6] = 0
        end
    end
    cargoDoorArray[0] = 0
    cargoDoorArray[1] = 0
end

local function setDefaultBoardingState()
    set("AirbusFBW/NoPax", 0)
    set("AirbusFBW/PaxDistrib", math.random(35, 60) / 100)
    passengersBoarded = 0
    boardingPaused = false
    boardingStopped = false
    boardingActive = true
end

local function playChimeSound(boarding)
    command_once( "AirbusFBW/CheckCabin" )
    if boarding then
        speak_string = "Boarding Completed"
    else
        speak_string = "Deboarding Completed"
    end

    wait_until_speak = os.time() + 0.5
    intended_no_pax_set = false
end

local function boardInstantly()
    set("AirbusFBW/NoPax", intendedPassengerNumber)
    passengersBoarded = intendedPassengerNumber
    boardingActive = false
    boardingCompleted = true
    playChimeSound(true)
    command_once("AirbusFBW/SetWeightAndCG")
    closeDoorsAfterBoarding()
    generateFinalLoadsheet()
end

local function deboardInstantly()
    set("AirbusFBW/NoPax", 0)
    deboardingActive = false
    deboardingCompleted = true
    playChimeSound(false)
    command_once("AirbusFBW/SetWeightAndCG")
    closeDoorsAfterBoarding()
end

local function setRandomNumberOfPassengers()
    local passengerDistributionGroup = math.random(0, 100)

    if passengerDistributionGroup < 2 then
        intendedPassengerNumber = math.random(math.floor(MAX_PAX_NUMBER * 0.22), math.floor(MAX_PAX_NUMBER * 0.54))
        return
    end

    if passengerDistributionGroup < 16 then
        intendedPassengerNumber = math.random(math.floor(MAX_PAX_NUMBER * 0.54), math.floor(MAX_PAX_NUMBER * 0.72))
        return
    end

    if passengerDistributionGroup < 58 then
        intendedPassengerNumber = math.random(math.floor(MAX_PAX_NUMBER * 0.72), math.floor(MAX_PAX_NUMBER * 0.87))
        return
    end

    intendedPassengerNumber = math.random(math.floor(MAX_PAX_NUMBER * 0.87), MAX_PAX_NUMBER)
end

local function startBoardingOrDeboarding()
    boardingPaused = false
    boardingActive = false
    boardingCompleted = false
    deboardingCompleted = false
    deboardingPaused = false
end

local function resetAllParameters()
    passengersBoarded = 0
    intendedPassengerNumber = math.floor(MAX_PAX_NUMBER * 0.66)
    boardingActive = false
    deboardingActive = false
    nextTimeBoardingCheck = os.time()
    boardingSpeedMode = 3
    if USE_SECOND_DOOR then
        secondsPerPassenger = 4
    else
        secondsPerPassenger = 6
    end
    jw1_connected = false
    boardingPaused = false
    deboardingPaused = false
    deboardingCompleted = false
    boardingCompleted = false
    isTobusWindowDisplayed = false
    isSettingsWindowDisplayed = false
end

-- frame loop, efficient coding please
function tobusBoarding()
    local now = os.time()

    if speak_string and now > wait_until_speak then
      XPLMSpeakString(speak_string)
      speak_string = nil
    end

    if boardingActive then
        if passengersBoarded < intendedPassengerNumber and now > nextTimeBoardingCheck then
            passengersBoarded = passengersBoarded + 1
            tls_no_pax[0] = passengersBoarded
            command_once("AirbusFBW/SetWeightAndCG")
            nextTimeBoardingCheck = os.time() + secondsPerPassenger + math.random(-2, 2)
        end

        if passengersBoarded == intendedPassengerNumber and not boardingCompleted then
            boardingCompleted = true
            boardingActive = false
            closeDoorsAfterBoarding()
            if not isTobusWindowDisplayed then
                buildTobusWindow()
            end
            playChimeSound(true)
            generateFinalLoadsheet()
        end

    elseif deboardingActive then
        if passengersBoarded > 0 and now >= nextTimeBoardingCheck then
            passengersBoarded = passengersBoarded - 1
            tls_no_pax[0] = passengersBoarded
            command_once("AirbusFBW/SetWeightAndCG")
            nextTimeBoardingCheck = os.time() + secondsPerPassenger + math.random(-2, 2)
        end

        if passengersBoarded == 0 and not deboardingCompleted then
            deboardingCompleted = true
            deboardingActive = false
            closeDoorsAfterBoarding()
            if not isTobusWindowDisplayed then
                buildTobusWindow()
            end
            playChimeSound(false)
        end
    end
end

local function readSettings()
    local f = io.open(SCRIPT_DIRECTORY..SETTINGS_FILENAME)
    if f == nil then return end

    f:close()
    local settings = LIP.load(SCRIPT_DIRECTORY..SETTINGS_FILENAME)

    settings.simbrief = settings.simbrief or {}    -- for backwards compatibility
    settings.hoppie = settings.hoppie or {}    -- for backwards compatibility
    settings.doors = settings.doors or {}

    if settings.simbrief.username ~= nil then
        SIMBRIEF_ACCOUNT_NAME = settings.simbrief.username
    end

    if settings.hoppie.logon ~= nil then
        HOPPIE_LOGON = settings.hoppie.logon
    end

    RANDOMIZE_SIMBRIEF_PASSENGER_NUMBER = settings.simbrief.randomizePassengerNumber or
                                                RANDOMIZE_SIMBRIEF_PASSENGER_NUMBER

    USE_SECOND_DOOR = settings.doors.useSecondDoor or USE_SECOND_DOOR
    CLOSE_DOORS = settings.doors.closeDoors or CLOSE_DOORS
    LEAVE_DOOR1_OPEN = settings.doors.leaveDoor1Open or LEAVE_DOOR1_OPEN

end

local function saveSettings()
    logMsg("tobus: saveSettings...")
    local newSettings = {}
    newSettings.simbrief = {}
    newSettings.simbrief.username = SIMBRIEF_ACCOUNT_NAME
    newSettings.simbrief.randomizePassengerNumber = RANDOMIZE_SIMBRIEF_PASSENGER_NUMBER

    newSettings.hoppie = {}
    newSettings.hoppie.logon = HOPPIE_LOGON

    newSettings.doors = {}
    newSettings.doors.useSecondDoor = USE_SECOND_DOOR
    newSettings.doors.closeDoors = CLOSE_DOORS
    newSettings.doors.leaveDoor1Open = LEAVE_DOOR1_OPEN
    LIP.save(SCRIPT_DIRECTORY..SETTINGS_FILENAME, newSettings)
    logMsg("tobus: done")
end

local function fetchData()
    if SIMBRIEF_ACCOUNT_NAME == nil then
      logMsg("No simbrief username has been configured")
      return false
    end

    local response, statusCode = http.request("http://www.simbrief.com/api/xml.fetcher.php?username=" .. SIMBRIEF_ACCOUNT_NAME)

    if statusCode ~= 200 then
      logMsg("Simbrief API is not responding")
      return false
    end

    local f = io.open(SCRIPT_DIRECTORY..SIMBRIEF_FLIGHTPLAN_FILENAME, "w")
    f:write(response)
    f:close()

    logMsg("Simbrief XML data downloaded")
    SIMBRIEF_LOADED = true
    return true
end

local function readXML()
    local xfile = xml2lua.loadFile(SCRIPT_DIRECTORY..SIMBRIEF_FLIGHTPLAN_FILENAME)
    local parser = xml2lua.parser(handler)
    parser:parse(xfile)

    SIMBRIEF_FLIGHTPLAN["Status"] = handler.root.OFP.fetch.status

    if SIMBRIEF_FLIGHTPLAN["Status"] ~= "Success" then
      logMsg("XML status is not success")
      return false
    end

    intendedPassengerNumber = tonumber(handler.root.OFP.weights.pax_count)
    units = tostring(handler.root.OFP.params.units)
    operator = tostring(handler.root.OFP.general.icao_airline)
    flightNo = tonumber(handler.root.OFP.general.flight_number)
    oew = tonumber(handler.root.OFP.weights.oew)
    paxWeight = tonumber(handler.root.OFP.weights.pax_weight)
    taxiFuel = tonumber(handler.root.OFP.fuel.taxi)
    mzfw = tonumber(handler.root.OFP.weights.max_zfw)
    mtow = tonumber(handler.root.OFP.weights.max_tow)
    MAX_PAX_NUMBER = tonumber(handler.root.OFP.aircraft.max_passengers)
    if RANDOMIZE_SIMBRIEF_PASSENGER_NUMBER then
        local f = 0.01 * math.random(92, 103) -- lua 5.1: random take integer args!
	    intendedPassengerNumber = math.floor(intendedPassengerNumber * f)
        if intendedPassengerNumber > MAX_PAX_NUMBER then intendedPassengerNumber = MAX_PAX_NUMBER end
        logMsg(string.format("randomized intendedPassengerNumber: %d", intendedPassengerNumber))
    end
end


-- init random
math.randomseed(os.time())

if not SUPPORTS_FLOATING_WINDOWS then
    -- to make sure the script doesn't stop old FlyWithLua versions
    logMsg("imgui not supported by your FlyWithLua version")
    return
end


if PLANE_ICAO == "A319" then
    MAX_PAX_NUMBER = 145
elseif PLANE_ICAO == "A321" or PLANE_ICAO == "A21N" then
    local a321EngineType = get("AirbusFBW/EngineTypeIndex")
    if a321EngineType == 0 or a321EngineType == 1 then
        MAX_PAX_NUMBER = 220
    else
        MAX_PAX_NUMBER = 224
    end
elseif PLANE_ICAO == "A20N" then
    MAX_PAX_NUMBER = 188
elseif PLANE_ICAO == "A339" then
    MAX_PAX_NUMBER = 375
elseif PLANE_ICAO == "A346" then
    MAX_PAX_NUMBER = 440
end

logMsg(string.format("tobus: plane: %s, MAX_PAX_NUMBER: %d", PLANE_ICAO, MAX_PAX_NUMBER))

-- init gloabl variables
readSettings()

local function delayed_init()
    if tls_no_pax ~= nil then return end
    tls_no_pax = dataref_table("AirbusFBW/NoPax")
    passengerDoorArray = dataref_table("AirbusFBW/PaxDoorModeArray")
    cargoDoorArray = dataref_table("AirbusFBW/CargoDoorModeArray")
    tank_content_array = dataref_table("toliss_airbus/fuelTankContent_kgs")
    resetAllParameters()
end

function tobusOnBuild(tobus_window, x, y)
    if boardingActive and not boardingCompleted then
        imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF95FFF8)
        imgui.TextUnformatted(string.format("Boarding in progress %s / %s boarded", passengersBoarded, intendedPassengerNumber))
        imgui.PopStyleColor()
    end

    if deboardingActive and not deboardingCompleted then
        imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF95FFF8)
        imgui.TextUnformatted(string.format("Deboarding in progress %s / %s deboarded", passengersBoarded, intendedPassengerNumber))
        imgui.PopStyleColor()
    end

    if boardingCompleted then
        imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF43B54B)
        imgui.TextUnformatted("Boarding completed!!!")
        imgui.PopStyleColor()
    end

    if deboardingCompleted then
        imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF43B54B)
        imgui.TextUnformatted("Deboarding completed!!!")
        imgui.PopStyleColor()
    end

    if not (boardingActive or deboardingActive) then
        local pn = tls_no_pax[0]
        if not intended_no_pax_set or passengersBoarded ~= pn  then
            intendedPassengerNumber = pn
            passengersBoarded = pn
        end

        local passengeraNumberChanged, newPassengerNumber
        = imgui.SliderInt("Passengers number", intendedPassengerNumber, 0, MAX_PAX_NUMBER, "Value: %d")

        if passengeraNumberChanged then
            intendedPassengerNumber = newPassengerNumber
            intended_no_pax_set = true
        end
        imgui.SameLine()

        if imgui.Button("Get from simbrief") then
            if fetchData() then
                readXML()
                intended_no_pax_set = true
            end
        end

        if imgui.Button("Set random passenger number") then
            setRandomNumberOfPassengers()
            intended_no_pax_set = true
        end

    end

    if not boardingActive and not deboardingActive then
        imgui.SameLine()

        if not deboardingPaused then
            if imgui.Button("Start Boarding") then
                set("AirbusFBW/NoPax", 0)
                set("AirbusFBW/PaxDistrib", math.random(35, 60) / 100)
                passengersBoarded = 0
                startBoardingOrDeboarding()
                boardingActive = true
                nextTimeBoardingCheck = os.time()
                openDoorsForBoarding()
                if boardingSpeedMode == 1 then
                    boardInstantly()
                else
                    logMsg(string.format("start boarding with %0.1f s/pax", secondsPerPassenger))
                end
            end
        end

        imgui.SameLine()

        if not boardingPaused then
            if imgui.Button("Start Deboarding") then
                passengersBoarded = intendedPassengerNumber
                startBoardingOrDeboarding()
                deboardingActive = true
                nextTimeBoardingCheck = os.time()
                openDoorsForBoarding()
                if boardingSpeedMode == 1 then
                    deboardInstantly()
                end
            end
        end
    end

    if boardingActive then
        imgui.SameLine()
        if imgui.Button("Pause Boarding") then
            boardingActive = false
            boardingPaused = true
            boardingInformationMessage = "Boarding paused."
        end
    elseif boardingPaused then
        imgui.SameLine()
        if imgui.Button("Resume Boarding") then
            boardingActive = true
            boardingPaused = false
        end
    end

    if deboardingActive then
        imgui.SameLine()
        if imgui.Button("Pause Deboarding") then
            deboardingActive = false
            deboardingPaused = true
        end
    elseif deboardingPaused then
        imgui.SameLine()
        if imgui.Button("Resume Deboarding") then
            deboardingActive = true
            deboardingPaused = false
        end
    end

    if boardingPaused or deboardingPaused or boardingCompleted or deboardingCompleted then
        imgui.SameLine()
        if imgui.Button("Reset") then
            resetAllParameters()
            closeDoorsAfterBoarding()
        end
    end

    if not boardingActive and not deboardingActive then
        if imgui.RadioButton("Instant", boardingSpeedMode == 1) then
            boardingSpeedMode = 1
        end

        local fastModeMinutes, realModeMinutes, label, spp

        jw1_connected = (opensam_door_status ~= nil and opensam_door_status[1] == 1)
        if jw1_connected then
            if not USE_SECOND_DOOR then
                imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF43B54B)
                imgui.TextUnformatted("A second jetway is connected, using both doors")
                imgui.PopStyleColor()
            end
        end

        -- fast mode
        if USE_SECOND_DOOR or jw1_connected then
            spp = 2
        else
            spp = 3
        end

        fastModeMinutes = math.floor((intendedPassengerNumber * spp) / 60 + 0.5)
        if fastModeMinutes ~= 0 then
            label = string.format("Fast (%d minutes)", fastModeMinutes)
        else
            label = "Fast (less than a minute)"
        end

        if imgui.RadioButton(label,boardingSpeedMode == 2) then
            boardingSpeedMode = 2
        end

        if boardingSpeedMode == 2 then  -- regardless whether the button was changed or not
            secondsPerPassenger = spp
        end

        -- real mode
        if USE_SECOND_DOOR or jw1_connected then
            spp = 4
        else
            spp = 6
        end

        realModeMinutes = math.floor((intendedPassengerNumber * spp) / 60 + 0.5)
        if realModeMinutes ~= 0 then
            label = string.format("Real (%d minutes)", realModeMinutes)
        else
            label = "Real (less than a minute)"
        end

        if imgui.RadioButton(label, boardingSpeedMode == 3) then
            boardingSpeedMode = 3
        end

        if boardingSpeedMode == 3 then
            secondsPerPassenger = spp
        end
    end

    imgui.Separator()

    if imgui.TreeNode("Settings") then
        local changed, newval
        changed, newval = imgui.InputText("Simbrief Username", SIMBRIEF_ACCOUNT_NAME, 255)
        if changed then
            SIMBRIEF_ACCOUNT_NAME = newval
        end

        changed, newval = imgui.InputText("Hoppie Logon", HOPPIE_LOGON, 255)
        if changed then
            HOPPIE_LOGON = newval
        end

        changed, newval = imgui.Checkbox("Simulate some passengers not showing up after simbrief import",
                                         RANDOMIZE_SIMBRIEF_PASSENGER_NUMBER)
        if changed then
            RANDOMIZE_SIMBRIEF_PASSENGER_NUMBER = newval
        end

        changed, newval = imgui.Checkbox(
            "Use front and back door for boarding and deboarding (only front door by default)", USE_SECOND_DOOR)
        if changed then
            USE_SECOND_DOOR = newval
            logMsg("USE_SECOND_DOOR set to " .. tostring(USE_SECOND_DOOR))
        end

        changed, newval = imgui.Checkbox(
            "Close doors after boarding/deboading", CLOSE_DOORS)
        if changed then
            CLOSE_DOORS = newval
            logMsg("CLOSE_DOORS set to " .. tostring(CLOSE_DOORS))
        end

        changed, newval = imgui.Checkbox(
            "Leave door1 open after boarding/deboading", LEAVE_DOOR1_OPEN)
        if changed then
            LEAVE_DOOR1_OPEN = newval
            logMsg("LEAVE_DOOR1_OPEN set to " .. tostring(LEAVE_DOOR1_OPEN))
        end

        if imgui.Button("Save Settings") then
            saveSettings()
        end
        imgui.TreePop()
    end
end

local winCloseInProgess = false

function tobusOnClose()
    isTobusWindowDisplayed = false
    winCloseInProgess = false
end

function buildTobusWindow()
    delayed_init()

    if (isTobusWindowDisplayed) then
        return
    end
	tobus_window = float_wnd_create(900, 280, 1, true)

    local leftCorner, height, width = XPLMGetScreenBoundsGlobal()

    float_wnd_set_position(tobus_window, width / 2 - 375, height / 2)
	float_wnd_set_title(tobus_window, "TOBUS - Your Toliss Boarding Companion " .. VERSION)
	float_wnd_set_imgui_builder(tobus_window, "tobusOnBuild")
    float_wnd_set_onclose(tobus_window, "tobusOnClose")

    isTobusWindowDisplayed = true
end

function showTobusWindow()
    if isTobusWindowDisplayed then
        if not winCloseInProgess then
            winCloseInProgess = true
            float_wnd_destroy(tobus_window) -- marks for destroy, destroy is async
        end
        return
    end

    buildTobusWindow()
end

add_macro("TOBUS - Your Toliss Boarding Companion", "buildTobusWindow()")
create_command("FlyWithLua/TOBUS/Toggle_tobus", "Show TOBUS window", "showTobusWindow()", "", "")
do_every_frame("tobusBoarding()")
readSettings()

end