if PLANE_ICAO == "A319" or PLANE_ICAO == "A20N" or PLANE_ICAO == "A321" or
   PLANE_ICAO == "A21N" or PLANE_ICAO == "A346" or PLANE_ICAO == "A339"
then

local MY_PLANE_ICAO = PLANE_ICAO    -- may be stale now for A321 / A21N
local VERSION = "3.0.0-hotbso"

 --http library import
local socket = require "socket"
local http = require "socket.http"
local LIP = require("LIP")

local kg2lbs = 2.204622
local wait_until_speak = 0
local speak_string

local intended_no_pax_set = false

local tls_no_pax    --AirbusFBW/NoPax    -- dataref_table
local tank_content_array -- dataref_table
local units --simbrief
local operator --simbrief
local intendedPassengerNumber --simbrief
local taxiFuel --simbrief
local mzfw --simbrief
local mtow --simbrief
local MAX_PAX_NUMBER = 224

local fmgs_flight_no = "" -- FMGS flight number
local fmgs_init_ts = 1E20
local prelim_loadsheet_sent = false

local SIMBRIEF_LOADED = false
local SETTINGS_FILENAME = "/tobus/tobus_settings.ini"
local HOPPIE_LOGON = ""
local HOPPIE_CPDLC = true
local RANDOMIZE_SIMBRIEF_PASSENGER_NUMBER = false
local USE_SECOND_DOOR = false
local CLOSE_DOORS = true
local LEAVE_DOOR1_OPEN = true

local jw1_connected = false     -- set if an opensam jw at the second door is detected
local opensam_door_status = nil
if nil ~= XPLMFindDataRef("opensam/jetway/door/status") then
	opensam_door_status = dataref_table("opensam/jetway/door/status")
end

local plane_db = {
    A319_160 = {
        cfg = "A319_160",
        max_pax = 160,
        oew = 40820,
        cg_data = {
            pax_tab   = {   0,   20,   40,   60,   80,  100,  120,  140,  160},
            zfwcg_035 = {28.6, 25.6, 23.7, 22.7, 22.6, 23.2, 24.4, 26.2, 28.6},
            zfwcg_050 = {28.6, 28.6, 28.6, 28.6, 28.6, 28.6, 28.6, 28.6, 28.6},
            zfwcg_060 = {28.6, 32.1, 31.9, 32.5, 32.6, 32.2, 31.4, 30.2, 28.6}
        }
    },

    A319 = {
        cfg = "A319",
        max_pax = 145,
        oew = 40820,
        cg_data = {
            pax_tab   = {   0,   20,   40,   60,   80,  100,  120,  145},
            zfwcg_035 = {28.6, 25.6, 23.8, 23.1, 23.2, 24.1, 25.7, 28.6},
            zfwcg_050 = {28.6, 28.6, 28.6, 28.6, 28.6, 28.6, 28.6, 28.6},
            zfwcg_060 = {28.6, 30.6, 31.8, 32.3, 32.2, 31.6, 30.5, 28.6}
        }
    },

    A20N = {
        cfg = "A20N",
        max_pax = 188,
        oew = 44220,
        cg_data = {
            pax_tab   = {   0,   25,   50,   75,  100,  125,  150,  175,  188},
            zfwcg_035 = {29.5, 25.4, 22.9, 21.7, 21.8, 22.8, 24.8, 27.5, 29.2},
            zfwcg_050 = {29.5, 29.4, 29.4, 29.3, 29.3, 29.3, 29.3, 29.2, 29.2},
            zfwcg_060 = {29.5, 32.1, 33.7, 34.4, 34.3, 33.6, 32.2, 30.5, 29.2}
        }
    },

    A321 = {
        cfg = "A321",
        max_pax = 220,
        oew = 47780,
        cg_data = {
            pax_tab   = {   0,   25,   50,   75,  100,  125,  150,  175,  200,  220},
            zfwcg_035 = {27.5, 22.5, 19.2, 17.4, 17.2, 17.5, 19.1, 21.5, 24.8, 27.9},
            zfwcg_050 = {27.5, 27.6, 27.6, 27.7, 27.7, 27.7, 27.8, 27.8, 27.8, 27.9},
            zfwcg_060 = {27.5, 30.9, 33.1, 34.3, 34.5, 34.4, 33.4, 31.9, 29.8, 27.9}
        }
    },

    A21N = {
        cfg = "A21N",
        max_pax = 244,
        oew = 49580,
        cg_data = {
            pax_tab   = {   0,   25,   50,   75,  100,  125,  150,  175,  200,  225, 244},
            zfwcg_035 = {29.1, 24.3, 20.9, 18.9, 18.0, 18.1, 19.0, 20.8, 23.2, 26.2, 28.9},
            zfwcg_050 = {29.1, 29.1, 29.1, 29.1, 29.0, 29.0, 29.0, 29.0, 29.0, 29.0, 28.9},
            zfwcg_060 = {27.5, 32.3, 34.5, 35.8, 36.4, 36.3, 35.7, 34.5, 32.8, 30.8, 29.1}
        }
    },

    -- without third door
    A21N_200 = {
        cfg = "A21N",
        max_pax = 200,
        oew = 49580,
        cg_data = {
            pax_tab   = {   0,   25,   50,   75,  100,  125,  150,  175,  200},
            zfwcg_035 = {29.1, 24.4, 21.4, 19.9, 19.7, 20.9, 22.5, 25.3, 29.0},
            zfwcg_050 = {29.1, 29.1, 29.1, 29.1, 29.0, 29.0, 29.0, 29.0, 29.0},
            zfwcg_060 = {29.1, 32.2, 34.2, 35.2, 35.3, 34.6, 33.3, 31.4, 29.0}
        }
    },

    A339 = {
        cfg = "A339",
        max_pax = 375,
        oew = 134500,
        cg_data = {
            pax_tab   = {   0,   25,   50,   75,  100,  125,  150,  175,  200,  225,  250,  275,  300,  325,  350,  375},
            zfwcg_035 = {27.5, 26.0, 24.8, 23.8, 23.1, 22.6, 22.2, 22.1, 22.2, 22.5, 22.9, 23.5, 24.3, 25.2, 26.3, 27.5},
            zfwcg_050 = {27.5, 27.5, 27.5, 27.5, 27.5, 27.5, 27.5, 27.5, 27.5, 27.5, 27.5, 27.5, 27.5, 27.5, 27.5, 27.5},
            zfwcg_060 = {27.5, 28.5, 29.4, 30.0, 30.5, 30.9, 31.1, 31.2, 31.1, 30.9, 30.6, 30.2, 29.7, 29.0, 28.3, 27.5}
        }
    },

    A346 = {
        cfg = "A346",
        max_pax = 440,
        oew = 185500,
        -- volunteers welcome for building the cg table
    }
}

local plane_data    -- of the current plane
local log_msg       -- forward

-- gaussian distribution
local function gauss(mu, sigma)
    -- central limit theorem with a sum of 12 should be good enough here
    local s = 0
    for i = 1, 12 do
        s = s + math.random()
    end
    return sigma * (s - 6) + mu
end

local function clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

-- stepwise linear interpolation
local function tab_interpolate(pax_tab, zfwcg_tab, pax_no)
    local n = #pax_tab
    if pax_no >= pax_tab[n] then
        return zfwcg_tab[n]
    end

    for i = 1, n - 1 do
        local pax0 = pax_tab[i]
        local pax1 = pax_tab[i + 1]
        if pax0 <= pax_no and pax_no < pax1 then
            local x = (pax_no - pax0) / (pax1 - pax0)
            return zfwcg_tab[i] + x * (zfwcg_tab[i + 1] - zfwcg_tab[i])
        end
    end
end

-- get the ZFWCG
local function get_zfwcg(cg_data)
    local pax_distrib = get("AirbusFBW/PaxDistrib")
    local pax_no = get("AirbusFBW/NoPax")

    local zfwcg_050 = tab_interpolate(cg_data.pax_tab, cg_data.zfwcg_050, pax_no)

    local zfwcg
    if pax_distrib <= 0.5 then
        local f = (pax_distrib - 0.35) / (0.5 - 0.35)
        local zfwcg_035 = tab_interpolate(cg_data.pax_tab, cg_data.zfwcg_035, pax_no)
        zfwcg = (1 - f) * zfwcg_035 + f * zfwcg_050
    else
        local f = (pax_distrib - 0.5) / (0.6 - 0.5)
        local zfwcg_060 = tab_interpolate(cg_data.pax_tab, cg_data.zfwcg_060, pax_no)
        zfwcg = (1 - f) * zfwcg_050 + f * zfwcg_060
    end

    return pax_no, pax_distrib, zfwcg
end

local function format_ls_row(label, value, digit)
    return label .. string.rep(".", digit - #label - #value) .. " @" .. value .. "@ "
end

local function send_loadsheet(ls_content)

    ls_content = ls_content:gsub("\n", "%%0A")

    local payload
    if HOPPIE_CPDLC then
        payload = string.format("logon=%s&from=%s&to=%s&type=%s&packet=%s",
            HOPPIE_LOGON,
            operator .. "OPS",
            fmgs_flight_no,
            'cpdlc',
            "/data2/313//NE/" .. ls_content)
    else
        payload = string.format("logon=%s&from=%s&to=%s&type=%s&packet=%s",
            HOPPIE_LOGON,
            operator .. "OPS",
            fmgs_flight_no,
            'telex',
            ls_content)
    end

    log_msg(payload:gsub("logon=[^&]+", "logon=***"))

    local msg, code = http.request{
            url = "https://www.hoppie.nl/acars/system/connect.html",
            method = "POST",
            headers = {
                ["Content-Type"] = "application/x-www-form-urlencoded",
                ["Content-Length"] = tostring(#payload),
            },
            source = ltn12.source.string(payload),
        }

    log_msg(string.format("Hoppie returns: '%s', code: %d", msg, code))
end

local function generate_final_loadsheet()
    if not SIMBRIEF_LOADED or HOPPIE_LOGON == "" then
        log_msg("LOADSHEET UNAVAIL DUE TO NO SIMBRIEF DATA OR MISSING HOPPIE LOGIN")
        return
    end

    local cargo_kg = math.ceil(get("AirbusFBW/FwdCargo") + get("AirbusFBW/AftCargo"))

    local fob_kg = 0
    for i = 0,8 do
        fob_kg = fob_kg + tank_content_array[i]
    end

    local fob_uu
    if units == "lbs" then
        fob_uu = 100 * math.floor(fob_kg * kg2lbs / 100 + 0.35)    -- conservative rounding
    else
        fob_uu = 100 * math.floor(fob_kg / 100 + 0.35)
    end

    local zfw_kg = plane_data.oew + cargo_kg + tls_no_pax[0] * 100 -- hard coded pax weight of 100kg by ToLiss
    local zfw_uu = zfw_kg
    if units == "lbs" then
        zfw_uu = zfw_kg * kg2lbs
    end

    log_msg(string.format("fob_kg: %d, fob_uu: %d, zfw_kg: %d, zfw_uu: %d",
            fob_kg, fob_uu, zfw_kg, zfw_uu))

    local tow_uu = zfw_uu + fob_uu - taxiFuel

    local zfwcg = "EFB"
    if cargo_kg <= 20 then  -- cargo is currently unsupported, account for rounding errors
        local cg_data = plane_data.cg_data
        if cg_data ~= nil then
            local pn, pd
            pn, pd, zfwcg = get_zfwcg(cg_data)
            log_msg(string.format("get_zfwcg: %s, distrib: %0.1f, pax_no: %d, zfwcg: %0.1f",
                                   plane_data.cfg, pd, pn, zfwcg))
            zfwcg = string.format("%0.1f", zfwcg)
        end
    end

    local ls = {    -- in user units
        title = "Final",
        gwcg = string.format("%0.1f", get("AirbusFBW/CGLocationPercent")),
        zfw = string.format("%0.1f", zfw_uu / 1000),
        zfwcg = zfwcg, -- meaning: ls.zfwcg = zfwcg
        tow = string.format("%0.1f", tow_uu / 1000),
        fob = string.format("%d", fob_uu),
        pax = string.format("%d", tls_no_pax[0])
    }

    if zfw_uu > mzfw or tow_uu > mtow then
        ls.msg = "LOAD+DISCREPANCY:+RETURN+TO+GATE"
    else
        ls.msg = nil
    end

    local ls_content = table.concat({
        "Loadsheet @" .. ls.title .. "@ " .. os.date("%H:%M"),
        format_ls_row("PAX", ls.pax, 9),
        format_ls_row("ZFW",  ls.zfw, 9),
        format_ls_row("ZFWCG", ls.zfwcg, 9),
        format_ls_row("TOW", ls.tow, 9),
        format_ls_row("GWCG", ls.gwcg, 9),
        format_ls_row("FOB", ls.fob, 9),
        format_ls_row("UNITS", units, 9),
    }, "\n")

    if ls.msg ~= nil then
        ls_content = ls_content .. "\n" .. ls.msg
    end

    send_loadsheet(ls_content)
end

local function generate_prelim_loadsheet()
    if not SIMBRIEF_LOADED or HOPPIE_LOGON == "" then
        log_msg("LOADSHEET UNAVAIL DUE TO NO SIMBRIEF DATA OR MISSING HOPPIE LOGIN")
        return
    end

    local block_fuel_kg = get("toliss_airbus/init/BlockFuel")
    local zfw_kg = plane_data.oew + intendedPassengerNumber * 100 -- hard coded pax weight of 100kg by ToLiss
    local zfwcg = get("toliss_airbus/init/ZFWCG")

    local block_fuel_uu
    if units == "lbs" then
        block_fuel_uu = 100 * math.floor(block_fuel_kg * kg2lbs / 100 + 0.35)    -- conservative rounding
    else
        block_fuel_uu = 100 * math.floor(block_fuel_kg / 100 + 0.35)
    end

    local zfw_uu = zfw_kg
    if units == "lbs" then
        zfw_uu = zfw_kg * kg2lbs
    end

    log_msg(string.format("block_fuel_kg: %d, block_fuel_uu: %d, zfw_kg: %d, zfw_uu: %d",
            block_fuel_kg, block_fuel_uu, zfw_kg, zfw_uu))

    local tow_uu = zfw_uu + block_fuel_uu - taxiFuel

    local ls = {    -- in user units
        title = "Prelim",
        -- gwcg = string.format("%0.1f", get("AirbusFBW/CGLocationPercent")),
        zfw = string.format("%0.1f", zfw_uu / 1000),
        zfwcg = string.format("%0.1f", zfwcg), -- meaning: ls.zfwcg = zfwcg
        tow = string.format("%0.1f", tow_uu / 1000),
        fob = string.format("%d", block_fuel_uu),
        pax = string.format("%d", intendedPassengerNumber)
    }

    if zfw_uu > mzfw or tow_uu > mtow then
        ls.msg = "LOAD+DISCREPANCY:+CHECK"
    else
        ls.msg = nil
    end

    local ls_content = table.concat({
        "Loadsheet @" .. ls.title .. "@ " .. os.date("%H:%M"),
        format_ls_row("PAX", ls.pax, 9),
        format_ls_row("ZFW",  ls.zfw, 9),
        format_ls_row("ZFWCG", ls.zfwcg, 9),
        format_ls_row("TOW", ls.tow, 9),
        -- format_ls_row("GWCG", ls.gwcg, 9),
        format_ls_row("BFUEL", ls.fob, 9),
        format_ls_row("UNITS", units, 9),
    }, "\n")

    if ls.msg ~= nil then
        ls_content = ls_content .. "\n" .. ls.msg
    end

    send_loadsheet(ls_content)
end

local function openDoorsForBoarding()
    passengerDoorArray[0] = 2
    if USE_SECOND_DOOR or jw1_connected then
        if MY_PLANE_ICAO == "A319" or MY_PLANE_ICAO == "A20N" or MY_PLANE_ICAO == "A339" then
            passengerDoorArray[2] = 2
        end
        if MY_PLANE_ICAO == "A321" or MY_PLANE_ICAO == "A21N" or MY_PLANE_ICAO == "A346" then
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
        if MY_PLANE_ICAO == "A319" or MY_PLANE_ICAO == "A20N" or MY_PLANE_ICAO == "A339" then
            passengerDoorArray[2] = 0
        end

        if MY_PLANE_ICAO == "A321" or MY_PLANE_ICAO == "A21N" or MY_PLANE_ICAO == "A346" or MY_PLANE_ICAO == "A339" then
            passengerDoorArray[6] = 0
        end
    end
    cargoDoorArray[0] = 0
    cargoDoorArray[1] = 0
end

local function setDefaultBoardingState()
    set("AirbusFBW/NoPax", 0)
    set("AirbusFBW/PaxDistrib", clamp(gauss(0.5, 0.1), 0.35, 0.6))
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
    boardingActive = true
    boardingCompleted = false
    command_once("AirbusFBW/SetWeightAndCG")    -- that runs async so we need postprocessing in the draw loop
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
        if passengersBoarded < intendedPassengerNumber and now >= nextTimeBoardingCheck then
            passengersBoarded = passengersBoarded + 1
            tls_no_pax[0] = passengersBoarded
            command_once("AirbusFBW/SetWeightAndCG")
            -- accumulated boarding time has a standard deviation ~sqrt(pax_no) hence we clamp on the high side
            nextTimeBoardingCheck = os.time() + secondsPerPassenger * clamp(gauss(1.0, 0.2), 0.8, 1.15)
        end

        if passengersBoarded == intendedPassengerNumber and not boardingCompleted then
            boardingCompleted = true
            boardingActive = false
            closeDoorsAfterBoarding()
            -- if not isTobusWindowDisplayed then
                -- buildTobusWindow()
            -- end
            playChimeSound(true)
            generate_final_loadsheet()
        end

    elseif deboardingActive then
        if passengersBoarded > 0 and now >= nextTimeBoardingCheck then
            passengersBoarded = passengersBoarded - 1
            tls_no_pax[0] = passengersBoarded
            command_once("AirbusFBW/SetWeightAndCG")
            nextTimeBoardingCheck = os.time() + secondsPerPassenger * clamp(gauss(1.0, 0.2), 0.8, 1.15)
        end

        if passengersBoarded == 0 and not deboardingCompleted then
            deboardingCompleted = true
            deboardingActive = false
            closeDoorsAfterBoarding()
            -- if not isTobusWindowDisplayed then
                -- buildTobusWindow()
            -- end
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

    if settings.hoppie.logon ~= nil then
        HOPPIE_LOGON = settings.hoppie.logon
    end

    if settings.hoppie.cpdlc ~= nil then
        HOPPIE_CPDLC = settings.hoppie.cpdlc
    end

    if settings.simbrief.randomizePassengerNumber ~= nil then
        RANDOMIZE_SIMBRIEF_PASSENGER_NUMBER = settings.simbrief.randomizePassengerNumber
    end

    if settings.doors.useSecondDoor ~= nil then
        USE_SECOND_DOOR = settings.doors.useSecondDoor
    end

    if settings.doors.closeDoors ~= nil then
        CLOSE_DOORS = settings.doors.closeDoors
    end

    if settings.doors.leaveDoor1Open ~= nil then
        LEAVE_DOOR1_OPEN = settings.doors.leaveDoor1Open
    end
end

local function saveSettings()
    log_msg("tobus: saveSettings...")
    local newSettings = {}
    newSettings.simbrief = {}
    newSettings.simbrief.randomizePassengerNumber = RANDOMIZE_SIMBRIEF_PASSENGER_NUMBER

    newSettings.hoppie = {}
    newSettings.hoppie.logon = HOPPIE_LOGON
    newSettings.hoppie.cpdlc = HOPPIE_CPDLC

    newSettings.doors = {}
    newSettings.doors.useSecondDoor = USE_SECOND_DOOR
    newSettings.doors.closeDoors = CLOSE_DOORS
    newSettings.doors.leaveDoor1Open = LEAVE_DOOR1_OPEN
    LIP.save(SCRIPT_DIRECTORY..SETTINGS_FILENAME, newSettings)
    log_msg("tobus: done")
end

local function fetchData()
    if XPLMFindDataRef("sbh/seqno") == nil then
      log_msg("simbrief_hub plugin is not loaded")
      return false
    end

    local seqno = get("sbh/seqno")
    if seqno == 0 then
      log_msg("simbrief data not loaded")
      return false
    end

    log_msg("simbrief_hub seqno: " .. tostring(seqno))

    intendedPassengerNumber = tonumber(get("sbh/pax_count"))
    units = get("sbh/units")
    operator = get("sbh/icao_airline")
    taxiFuel = tonumber(get("sbh/fuel_taxi"))
    mzfw = tonumber(get("sbh/max_zfw"))
    mtow = tonumber(get("sbh/max_tow"))

    local max_pax = get("sbh/max_passengers")
    log_msg(string.format("max_pax: '%s'", max_pax))
    MAX_PAX_NUMBER = tonumber(max_pax)
    if MY_PLANE_ICAO == "A319" and MAX_PAX_NUMBER == 160 then
        plane_data = plane_db["A319_160"]
        log_msg("A319 with MAX_PAX_NUMBER 160 variant loaded")
    end

    if MAX_PAX_NUMBER ~= plane_data.max_pax then
        log_msg(string.format("max. pax no mismatch: ofp: %d config: %d", MAX_PAX_NUMBER, plane_data.max_pax))
    end

    if RANDOMIZE_SIMBRIEF_PASSENGER_NUMBER then
        local f = clamp(gauss(1.0, 0.025), 0.96, 1.04)
	    intendedPassengerNumber = math.floor(intendedPassengerNumber * f)
        if intendedPassengerNumber > MAX_PAX_NUMBER then intendedPassengerNumber = MAX_PAX_NUMBER end
        log_msg(string.format("randomized intendedPassengerNumber: %d", intendedPassengerNumber))
    end
    SIMBRIEF_LOADED = true
    return true
end

local function delayed_init()
    if tls_no_pax ~= nil then return end

    local plane_icao = get("sim/aircraft/view/acf_ICAO")
    local i0 = string.find(plane_icao, "\0")
    if i0 ~= nil then
        MY_PLANE_ICAO = string.sub(plane_icao, 1, i0 - 1)
    else
        MY_PLANE_ICAO = plane_icao
    end

    if MY_PLANE_ICAO == "A320" then -- for A20N ceo mod
        MY_PLANE_ICAO = "A20N"
    end

    tls_no_pax = dataref_table("AirbusFBW/NoPax")
    passengerDoorArray = dataref_table("AirbusFBW/PaxDoorModeArray")
    cargoDoorArray = dataref_table("AirbusFBW/CargoDoorModeArray")
    tank_content_array = dataref_table("toliss_airbus/fuelTankContent_kgs")

    if MY_PLANE_ICAO == "A21N" and get("AirbusFBW/A321ExitConfig") == 3 then    -- no door 3
        plane_data = plane_db["A21N_200"]
        log_msg("A21N with MAX_PAX_NUMBER 200 variant loaded")
    else
        plane_data = plane_db[MY_PLANE_ICAO]
        log_msg(MY_PLANE_ICAO .. " variant loaded")
    end

    MAX_PAX_NUMBER = plane_data.max_pax

    log_msg(string.format("tobus: plane: '%s', MAX_PAX_NUMBER: %d", MY_PLANE_ICAO, MAX_PAX_NUMBER))

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
                    log_msg(string.format("start boarding with %0.1f s/pax", secondsPerPassenger))
                end

                toggleTobusWindow()
                return
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

        changed, newval = imgui.InputText("Hoppie Logon", HOPPIE_LOGON, 255)
        if changed then
            HOPPIE_LOGON = newval
        end

        imgui.TextUnformatted("Deliver loadsheet via: ")
        imgui.SameLine()
        if imgui.RadioButton("CPDLC", HOPPIE_CPDLC) then
            HOPPIE_CPDLC = true
        end

        imgui.SameLine()

        if imgui.RadioButton("Telex", not HOPPIE_CPDLC) then
            HOPPIE_CPDLC = false
        end

        if not HOPPIE_CPDLC then
            imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF00AAFF)
            imgui.SameLine();
            imgui.TextUnformatted("You MUST send a PDC reqequest prior to boarding for a Telex to arrive")
            imgui.TextUnformatted("If you are not connected to VATSIM/IVAO use a fake station name, e.g. XXXX")
            imgui.PopStyleColor()
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
            log_msg("USE_SECOND_DOOR set to " .. tostring(USE_SECOND_DOOR))
        end

        changed, newval = imgui.Checkbox(
            "Close doors after boarding/deboading", CLOSE_DOORS)
        if changed then
            CLOSE_DOORS = newval
            log_msg("CLOSE_DOORS set to " .. tostring(CLOSE_DOORS))
        end

        changed, newval = imgui.Checkbox(
            "Leave door1 open after boarding/deboading", LEAVE_DOOR1_OPEN)
        if changed then
            LEAVE_DOOR1_OPEN = newval
            log_msg("LEAVE_DOOR1_OPEN set to " .. tostring(LEAVE_DOOR1_OPEN))
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

function toggleTobusWindow()
    if isTobusWindowDisplayed then
        if not winCloseInProgess then
            winCloseInProgess = true
            float_wnd_destroy(tobus_window) -- marks for destroy, destroy is async
        end
        return
    end

    buildTobusWindow()
end

-- low freq actions
function tobus_often()
    local now = os.time()

    -- check if FMGS was inited
    if fmgs_flight_no == "" then
        fmgs_flight_no = get("toliss_airbus/init/flight_no")
        if fmgs_flight_no ~= "" then
            log_msg("FMGS inited: " .. fmgs_flight_no)
            fmgs_init_ts = now
            prelim_loadsheet_sent = false
        end
    elseif not prelim_loadsheet_sent and now > fmgs_init_ts + 5 then
        delayed_init()
        fetchData()
        intended_no_pax_set = true
        if SIMBRIEF_LOADED then
            log_msg("Send prelim loadsheet")
            generate_prelim_loadsheet()
            prelim_loadsheet_sent = true
        end
    end

    -- for debugging plane_data tables
    if false then
        if plane_data == nil then return end
        local pax_no, pax_distrib, zfwcg = get_zfwcg(plane_data.cg_data)
        log_msg(string.format("%s, distrib: %0.3f, pax_no: %0.1f, ZFWCG: %0.1f",plane_data.cfg, pax_distrib, pax_no, zfwcg))
    end
end

function log_msg(str) -- custom log function
  local temp = os.date("*t", os.time())
  logMsg(string.format("tobus: %02d:%02d:%02d %s", temp.hour, temp.min, temp.sec, str))
end

-- main
log_msg("TOBUS " .. VERSION .. " startup")
math.randomseed(os.time())

if not SUPPORTS_FLOATING_WINDOWS then
    -- to make sure the script doesn't stop old FlyWithLua versions
    log_msg("imgui not supported by your FlyWithLua version")
    return
end

readSettings()

add_macro("TOBUS - Your Toliss Boarding Companion", "buildTobusWindow()")
create_command("FlyWithLua/TOBUS/Toggle_tobus", "Toggle TOBUS window", "toggleTobusWindow()", "", "")

do_every_frame("tobusBoarding()")
do_often("tobus_often()")

end
