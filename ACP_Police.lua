ac.log("Police script")

local sim = ac.getSim()
local car = ac.getCar(0)
local valideCar = {"chargerpolice_acpursuit", "crown_police", "bk_for_f450_21"}
local carID = ac.getCarID(0)

local windowWidth = sim.windowWidth
local windowHeight = sim.windowHeight
local settingsOpen = false
local arrestLogsOpen = false
local camerasOpen = false

local cspVersion = ac.getPatchVersionCode()
local cspMinVersion = 2144
local fontMultiplier = windowHeight/1440

local firstload = true
local cspAboveP218 = cspVersion >= 2363
ac.log("Police script")
if not(carID == valideCar[1] or carID == valideCar[2] or carID == valideCar[3]) or cspVersion < cspMinVersion then return end

local msgArrest = {
    msg = {"`NAME` has been arrested for Speeding. The individual was driving a `CAR`.",
	"We have apprehended `NAME` for Speeding. The suspect was behind the wheel of a `CAR`.",
	"The driver of a `CAR`, identified as `NAME`, has been arrested for Speeding.",
	"`NAME` has been taken into custody for Illegal Racing. The suspect was driving a `CAR`.",
	"We have successfully apprehended `NAME` for Illegal Racing. The individual was operating a `CAR`.",
	"The driver of a `CAR`, identified as `NAME`, has been arrested for Illegal Racing.",
	"`NAME` has been apprehended for Speeding. The suspect was operating a `CAR` at the time of the arrest.",
	"We have successfully detained `NAME` for Illegal Racing. The individual was driving a `CAR`.",
	"`NAME` driving a `CAR` has been arrested for Speeding",
	"`NAME` driving a `CAR` has been arrested for Illegal Racing."}
}

local msgLost = {
	msg = {"We've lost sight of the suspect. The vehicle involved is described as a `CAR` driven by `NAME`.",
	"Attention all units, we have lost visual contact with the suspect. The vehicle involved is a `CAR` driven by `NAME`.",
	"We have temporarily lost track of the suspect. The vehicle description is a `CAR` with `NAME` as the driver.",
	"Visual contact with the suspect has been lost. The suspect is driving a `CAR` and identified as `NAME`.",
	"We have lost the suspect's visual trail. The vehicle in question is described as a `CAR` driven by `NAME`.",
	"Suspect have been lost, Vehicle Description:`CAR` driven by `NAME`",
	"Visual contact with the suspect has been lost. The suspect is driving a `CAR` and identified as `NAME`.",
	"We have lost the suspect's visual trail. The vehicle in question is described as a `CAR` driven by `NAME`.",}
}

local msgEngage = {
    msg = {"Control! I am engaging on a `CAR` traveling at `SPEED`","Pursuit in progress! I am chasing a `CAR` exceeding `SPEED`","Control, be advised! Pursuit is active on a `CAR` driving over `SPEED`","Attention! Pursuit initiated! Im following a `CAR` going above `SPEED`","Pursuit engaged! `CAR` driving at a high rate of speed over `SPEED`","Attention all units, we have a pursuit in progress! Suspect driving a `CAR` exceeding `SPEED`","Attention units! We have a suspect fleeing in a `CAR` at high speed, pursuing now at `SPEED`","Engaging on a high-speed chase! Suspect driving a `CAR` exceeding `SPEED`!","Attention all units! we have a pursuit in progress! Suspect driving a `CAR` exceeding `SPEED`","High-speed chase underway, suspect driving `CAR` over `SPEED`","Control, `CAR` exceeding `SPEED`, pursuit active.","Engaging on a `CAR` exceeding `SPEED`, pursuit initiated."}
}

------------------------------------------------------------------------- JSON Utils -------------------------------------------------------------------------

local json = {}

-- Internal functions.

local function kind_of(obj)
  if type(obj) ~= 'table' then return type(obj) end
  local i = 1
  for _ in pairs(obj) do
    if obj[i] ~= nil then i = i + 1 else return 'table' end
  end
  if i == 1 then return 'table' else return 'array' end
end

local function escape_str(s)
  local in_char  = {'\\', '"', '/', '\b', '\f', '\n', '\r', '\t'}
  local out_char = {'\\', '"', '/',  'b',  'f',  'n',  'r',  't'}
  for i, c in ipairs(in_char) do
    s = s:gsub(c, '\\' .. out_char[i])
  end
  return s
end

-- Returns pos, did_find; there are two cases:
-- 1. Delimiter found: pos = pos after leading space + delim; did_find = true.
-- 2. Delimiter not found: pos = pos after leading space;     did_find = false.
-- This throws an error if err_if_missing is true and the delim is not found.
local function skip_delim(str, pos, delim, err_if_missing)
  pos = pos + #str:match('^%s*', pos)
  if str:sub(pos, pos) ~= delim then
    if err_if_missing then
      error('Expected ' .. delim .. ' near position ' .. pos)
    end
    return pos, false
  end
  return pos + 1, true
end

-- Expects the given pos to be the first character after the opening quote.
-- Returns val, pos; the returned pos is after the closing quote character.
local function parse_str_val(str, pos, val)
  val = val or ''
  local early_end_error = 'End of input found while parsing string.'
  if pos > #str then error(early_end_error) end
  local c = str:sub(pos, pos)
  if c == '"'  then return val, pos + 1 end
  if c ~= '\\' then return parse_str_val(str, pos + 1, val .. c) end
  -- We must have a \ character.
  local esc_map = {b = '\b', f = '\f', n = '\n', r = '\r', t = '\t'}
  local nextc = str:sub(pos + 1, pos + 1)
  if not nextc then error(early_end_error) end
  return parse_str_val(str, pos + 2, val .. (esc_map[nextc] or nextc))
end

-- Returns val, pos; the returned pos is after the number's final character.
local function parse_num_val(str, pos)
  local num_str = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
  local val = tonumber(num_str)
  if not val then error('Error parsing number at position ' .. pos .. '.') end
  return val, pos + #num_str
end


-- Public values and functions.

function json.stringify(obj, as_key)
  local s = {}  -- We'll build the string as an array of strings to be concatenated.
  local kind = kind_of(obj)  -- This is 'array' if it's an array or type(obj) otherwise.
  if kind == 'array' then
    if as_key then error('Can\'t encode array as key.') end
    s[#s + 1] = '['
    for i, val in ipairs(obj) do
      if i > 1 then s[#s + 1] = ', ' end
      s[#s + 1] = json.stringify(val)
    end
    s[#s + 1] = ']'
  elseif kind == 'table' then
    if as_key then error('Can\'t encode table as key.') end
    s[#s + 1] = '{'
    for k, v in pairs(obj) do
      if #s > 1 then s[#s + 1] = ', ' end
      s[#s + 1] = json.stringify(k, true)
      s[#s + 1] = ':'
      s[#s + 1] = json.stringify(v)
    end
    s[#s + 1] = '}'
  elseif kind == 'string' then
    return '"' .. escape_str(obj) .. '"'
  elseif kind == 'number' then
    if as_key then return '"' .. tostring(obj) .. '"' end
    return tostring(obj)
  elseif kind == 'boolean' then
    return tostring(obj)
  elseif kind == 'nil' then
    return 'null'
  else
    error('Unjsonifiable type: ' .. kind .. '.')
  end
  return table.concat(s)
end

json.null = {}  -- This is a one-off table to represent the null value.

function json.parse(str, pos, end_delim)
  pos = pos or 1
  if pos > #str then error('Reached unexpected end of input.') end
  local pos = pos + #str:match('^%s*', pos)  -- Skip whitespace.
  local first = str:sub(pos, pos)
  if first == '{' then  -- Parse an object.
    local obj, key, delim_found = {}, true, true
    pos = pos + 1
    while true do
      key, pos = json.parse(str, pos, '}')
      if key == nil then return obj, pos end
      if not delim_found then error('Comma missing between object items.') end
      pos = skip_delim(str, pos, ':', true)  -- true -> error if missing.
      obj[key], pos = json.parse(str, pos)
      pos, delim_found = skip_delim(str, pos, ',')
    end
  elseif first == '[' then  -- Parse an array.
    local arr, val, delim_found = {}, true, true
    pos = pos + 1
    while true do
      val, pos = json.parse(str, pos, ']')
      if val == nil then return arr, pos end
      if not delim_found then error('Comma missing between array items.') end
      arr[#arr + 1] = val
      pos, delim_found = skip_delim(str, pos, ',')
    end
  elseif first == '"' then  -- Parse a string.
    return parse_str_val(str, pos + 1)
  elseif first == '-' or first:match('%d') then  -- Parse a number.
    return parse_num_val(str, pos)
  elseif first == end_delim then  -- End of an object or array.
    return nil, pos + 1
  else  -- Parse true, false, or null.
    local literals = {['true'] = true, ['false'] = false, ['null'] = json.null}
    for lit_str, lit_val in pairs(literals) do
      local lit_end = pos + #lit_str - 1
      if str:sub(pos, lit_end) == lit_str then return lit_val, lit_end + 1 end
    end
    local pos_info_str = 'position ' .. pos .. ': ' .. str:sub(pos, pos + 10)
    error('Invalid json syntax starting at ' .. pos_info_str)
  end
end

--return json of playerData with only the data needed for the leaderboard
-- data are keys of the playerData table
local function dataStringify(data)
	local str = '{"' .. ac.getUserSteamID() .. '": '
	local name = ac.getDriverName(0)
	data['Name'] = name
	str = str .. json.stringify(data) .. '}'
	return str
end


------------------------------------------------------------------------- Web Utils -------------------------------------------------------------------------

local settings = {
	essentialSize = 20,
	policeSize = 20,
	hudOffsetX = 0,
	hudOffsetY = 0,
	fontSize = 20,
	current = 1,
	colorHud = rgbm(1,0,0,1),
	timeMsg = 10,
	msgOffsetY = 10,
	msgOffsetX = windowWidth/2,
	fontSizeMSG = 30,
	menuPos = vec2(0, 0),
	unit = "km/h",
	unitMult = 1,
	starsSize = 20,
	starsPos = vec2(windowWidth, 0),
}

local settingsJSON = {
	essentialSize = 20,
	policeSize = 20,
	hudOffsetX = 0,
	hudOffsetY = 0,
	fontSize = 20,
	current = 1,
	colorHud = "1,0,0,1",
	timeMsg = 10,
	msgOffsetY = 10,
	msgOffsetX = "1280",
	fontSizeMSG = 30,
	menuPos = vec2(0, 0),
	unit = "km/h",
	unitMult = 1,
	starsSize = 20,
	starsPos = vec2(windowWidth, 0),
}


local function stringToVec2(str)
	if str == nil then return vec2(0, 0) end
	local x = string.match(str, "([^,]+)")
	local y = string.match(str, "[^,]+,(.+)")
	return vec2(tonumber(x), tonumber(y))
end

local function vec2ToString(vec)
	return tostring(vec.x) .. ',' .. tostring(vec.y)
end

local function stringToRGBM(str)
	local r = string.match(str, "([^,]+)")
	local g = string.match(str, "[^,]+,([^,]+)")
	local b = string.match(str, "[^,]+,[^,]+,([^,]+)")
	local m = string.match(str, "[^,]+,[^,]+,[^,]+,(.+)")
	return rgbm(tonumber(r), tonumber(g), tonumber(b), tonumber(m))
end

local function rgbmToString(rgbm)
	return tostring(rgbm.r) .. ',' .. tostring(rgbm.g) .. ',' .. tostring(rgbm.b) .. ',' .. tostring(rgbm.mult)
end

local function parsesettings(table)
	settings.essentialSize = table.essentialSize
	settings.policeSize = table.policeSize
	settings.hudOffsetX = table.hudOffsetX
	settings.hudOffsetY = table.hudOffsetY
	settings.fontSize = table.fontSize
	settings.current = table.current
	settings.colorHud = stringToRGBM(table.colorHud)
	settings.timeMsg = table.timeMsg
	settings.msgOffsetY = table.msgOffsetY
	settings.msgOffsetX = table.msgOffsetX
	settings.fontSizeMSG = table.fontSizeMSG
	settings.menuPos = stringToVec2(table.menuPos)
	settings.unit = table.unit
	settings.unitMult = table.unitMult
	settings.starsSize = table.starsSize or 20
	if table.starsPos == nil then
		settings.starsPos = vec2(windowWidth, 0)
	else
		settings.starsPos = stringToVec2(table.starsPos)
	end
end


ui.setAsynchronousImagesLoading(true)
local imageSize = vec2(0,0)

local hudImg = {
	base = "https://i.postimg.cc/h4sPMmvp/hudBase.png",
	arrest = "https://i.postimg.cc/DwJv2YgM/icon-Arrest.png",
	cams = "https://i.postimg.cc/15zRdzNP/iconCams.png",
	logs = "https://i.postimg.cc/VNXztr29/iconLogs.png",
	lost = "https://i.postimg.cc/DyYf3KqG/iconLost.png",
	menu = "https://i.postimg.cc/SxByj71N/iconMenu.png",
	radar = "https://i.postimg.cc/4dZsQ4TD/icon-Radar.png",
}

local cameras = {
	{
		name = "BOBs SCRAPYARD",
		pos = vec3(-3564, 31.5, -103),
		dir = -8,
		fov = 60,
	},
	{
		name = "ARENA",
		pos = vec3(-2283, 115.5, 3284),
		dir = 128,
		fov = 70,
	},
	{
		name = "BANK",
		pos = vec3(-716, 151, 3556.4),
		dir = 12,
		fov = 95,
	},
	{
		name = "STREET RUNNERS",
		pos = vec3(-57.3, 103.5, 2935.5),
		dir = 16,
		fov = 67,
	},
	{
		name = "ROAD CRIMINALS",
		pos = vec3(-2332, 101.1, 3119.2),
		dir = 121,
		fov = 60,
	},
	{
		name = "RECKLESS RENEGADES",
		pos = vec3(-2993.7, -24.4, -601.7),
		dir = -64,
		fov = 60,
	},
	{
		name = "MOTION MASTERS",
		pos = vec3(-2120.4, -11.8, -1911.5),
		dir = 102,
		fov = 60,
	},
}

local pursuit = {
	suspect = nil,
	enable = false,
	maxDistance = 250000,
	minDistance = 40000,
	nextMessage = 30,
	level = 1,
	id = -1,
	timerArrest = 0,
	hasArrested = false,
	startedTime = 0,
	timeLostSight = 0,
	lostSight = false,
	engage = false,
}

local arrestations = {}

local textSize = {}

local textPos = {}

local iconPos = {}

local playerData = {}

---------------------------------------------------------------------------------------------- Firebase ----------------------------------------------------------------------------------------------

local urlAppScript = 'https://script.google.com/macros/s/AKfycbwenxjCAbfJA-S90VlV0y7mEH75qt3TuqAmVvlGkx-Y1TX8z5gHtvf5Vb8bOVNOA_9j/exec'
local firebaseUrl = 'https://acp-server-97674-default-rtdb.firebaseio.com/'
local firebaseUrlData = 'https://acp-server-97674-default-rtdb.firebaseio.com/PlayersData/'
local firebaseUrlsettings = 'https://acp-server-97674-default-rtdb.firebaseio.com/Settings'

local function updateSheets()
	local str = '{"category" : "Arrestations"}'
	web.post(urlAppScript, str, function(err, response)
		if err then
			print(err)
			return
		else
			print(response.body)
		end
	end)
end

local function addPlayerToDataBase()
	local steamID = ac.getUserSteamID()
	local name = ac.getDriverName(0)
	local str = '{"' .. steamID .. '": {"Name":"' .. name .. '","Getaway": 0,"Drift": 0,"Overtake": 0,"Wins": 0,"Losses": 0,"Busted": 0,"Arrests": 0,"Theft": 0}}'
	web.request('PATCH', firebaseUrl .. "Players.json", str, function(err, response)
		if err then
			print(err)
			return
		end
	end)
end

local function getFirebase()
	local url = firebaseUrl .. "Players/" .. ac.getUserSteamID() .. '.json'
	web.get(url, function(err, response)
		if err then
			print(err)
			return
		else
			if response.body == 'null' then
				addPlayerToDataBase(ac.getUserSteamID())
			else
				local jString = response.body
				playerData = json.parse(jString)
				if playerData.Name ~= ac.getDriverName(0) then
					playerData.Name = ac.getDriverName(0)
				end
			end
			ac.log('Player data loaded')
		end
	end)
end

local function updatefirebase()
	local str = '{"' .. ac.getUserSteamID() .. '": ' .. json.stringify(playerData) .. '}'
	web.request('PATCH', firebaseUrl .. "Players.json", str, function(err, response)
		if err then
			print(err)
			return
		else
			print(response.body)
		end
	end)
end

local function updatefirebaseData(node, data)
	local str = dataStringify(data)
	web.request('PATCH', firebaseUrlData .. node .. ".json", str, function(err, response)
		if err then
			print(err)
			return
		else
			print(response.body)
			updateSheets()
		end
	end)
end

local function addPlayersettingsToDataBase(steamID)
	local str = '{"' .. steamID .. '": {"essentialSize":20,"policeSize":20,"hudOffsetX":0,"hudOffsetY":0,"fontSize":20,"current":1,"colorHud":"1,0,0,1","timeMsg":10,"msgOffsetY":10,"msgOffsetX":' .. windowWidth/2 .. ',"fontSizeMSG":30,"menuPos":"0,0","unit":"km/h","unitMult":1}}'
	web.request('PATCH', firebaseUrlsettings .. ".json", str, function(err, response)
		if err then
			print(err)
			return
		end
	end)
end

local function loadsettings()
	local url = firebaseUrlsettings .. "/" .. ac.getUserSteamID() .. '.json'
	web.get(url, function(err, response)
		if err then
			print(err)
			return
		else
			if response.body == 'null' then
				addPlayersettingsToDataBase(ac.getUserSteamID())
			else
				ac.log("settings loaded")
				local jString = response.body
				local table = json.parse(jString)
				parsesettings(table)
			end
		end
	end)
end

local function updatesettings()
	local str = '{"' .. ac.getUserSteamID() .. '": ' .. json.stringify(settingsJSON) .. '}'
	web.request('PATCH', firebaseUrlsettings .. ".json", str, function(err, response)
		if err then
			print(err)
			return
		end
	end)
end

local function onsettingsChange()
	settingsJSON.colorHud = rgbmToString(settings.colorHud)
	settingsJSON.menuPos = vec2ToString(settings.menuPos)
	settingsJSON.essentialSize = settings.essentialSize
	settingsJSON.policeSize = settings.policeSize
	settingsJSON.hudOffsetX = settings.hudOffsetX
	settingsJSON.hudOffsetY = settings.hudOffsetY
	settingsJSON.fontSize = settings.fontSize
	settingsJSON.current = settings.current
	settingsJSON.timeMsg = settings.timeMsg
	settingsJSON.msgOffsetY  = settings.msgOffsetY
	settingsJSON.msgOffsetX  = settings.msgOffsetX
	settingsJSON.fontSizeMSG = settings.fontSizeMSG
	settingsJSON.unit = settings.unit
	settingsJSON.unitMult = settings.unitMult
	settingsJSON.starsSize = settings.starsSize
	settingsJSON.starsPos = vec2ToString(settings.starsPos)
	updatesettings()
end

---------------------------------------------------------------------------------------------- settings ----------------------------------------------------------------------------------------------

local acpPolice = ac.OnlineEvent({
    message = ac.StructItem.string(110),
	messageType = ac.StructItem.int16(),
	yourIndex = ac.StructItem.int16(),
}, function (sender, data)
	if data.yourIndex == car.sessionID and data.messageType == 0 and pursuit.suspect ~= nil and sender == pursuit.suspect then
		pursuit.hasArrested = true
		ac.log("ACP Police: Police received")
	end
end)

local starsUI = {
	starsPos = vec2(windowWidth - (settings.starsSize or 20)/2, settings.starsSize or 20)/2,
	starsSize = vec2(windowWidth - (settings.starsSize or 20)*2, (settings.starsSize or 20)*2),
	startSpace = (settings.starsSize or 20)/4,
}

local function resetStarsUI()
	if settings.starsPos == nil then
		settings.starsPos = vec2(windowWidth, 0)
	end
	if settings.starsSize == nil then
		settings.starsSize = 20
	end
	starsUI.starsPos = vec2(settings.starsPos.x - settings.starsSize/2, settings.starsPos.y + settings.starsSize/2)
	starsUI.starsSize = vec2(settings.starsPos.x - settings.starsSize*2, settings.starsPos.y + settings.starsSize*2)
	starsUI.startSpace = settings.starsSize/1.5
end

local function updatePos()
	imageSize = vec2(windowHeight/80 * settings.policeSize, windowHeight/80 * settings.policeSize)
	iconPos.arrest1 = vec2(imageSize.x - imageSize.x/12, imageSize.y/3.2)
	iconPos.arrest2 = vec2(imageSize.x/1.215, imageSize.y/5)
	iconPos.lost1 = vec2(imageSize.x - imageSize.x/12, imageSize.y/2.35)
	iconPos.lost2 = vec2(imageSize.x/1.215, imageSize.y/3.2)
	iconPos.logs1 = vec2(imageSize.x/1.215, imageSize.y/1.88)
	iconPos.logs2 = vec2(imageSize.x/1.39, imageSize.y/2.35)
	iconPos.menu1 = vec2(imageSize.x - imageSize.x/12, imageSize.y/1.88)
	iconPos.menu2 = vec2(imageSize.x/1.215, imageSize.y/2.35)
	iconPos.cams1 = vec2(imageSize.x/1.215, imageSize.y/2.35)
	iconPos.cams2 = vec2(imageSize.x/1.39, imageSize.y/3.2)

	textSize.size = vec2(imageSize.x*3/5, settings.fontSize/2)
	textSize.box = vec2(imageSize.x*3/5, settings.fontSize/1.3)
	textSize.window1 = vec2(settings.hudOffsetX+imageSize.x/9.5, settings.hudOffsetY+imageSize.y/5.3)
	textSize.window2 = vec2(imageSize.x*3/5, imageSize.y/2.8)

	textPos.box1 = vec2(0, 0)
	textPos.box2 = vec2(textSize.size.x, textSize.size.y*1.8)
	textPos.addBox = vec2(0, textSize.size.y*1.8)
	settings.fontSize = settings.policeSize * fontMultiplier

	resetStarsUI()
end

local function showStarsPursuit()
	local starsColor = rgbm(1, 1, 1, os.clock()%2 + 0.3)
	resetStarsUI()
	for i = 1, 5 do
		if i > pursuit.level/2 then
			ui.drawIcon(ui.Icons.StarEmpty, starsUI.starsPos, starsUI.starsSize, rgbm(1, 1, 1, 0.2))
		else
			ui.drawIcon(ui.Icons.StarFull, starsUI.starsPos, starsUI.starsSize, starsColor)
		end
		starsUI.starsPos.x = starsUI.starsPos.x - settings.starsSize - starsUI.startSpace
		starsUI.starsSize.x = starsUI.starsSize.x - settings.starsSize - starsUI.startSpace
	end
end

local showPreviewMsg = false
local showPreviewStars = false
COLORSMSGBG = rgbm(0.5,0.5,0.5,0.5)

local function initsettings()
	if settings.unit then
		settings.fontSize = settings.policeSize * fontMultiplier
		if settings.unit ~= "km/h" then settings.unitMult = 0.621371 end
		settings.policeSize = settings.policeSize * windowHeight/1440
		settings.fontSize = settings.policeSize * windowHeight/1440
		imageSize = vec2(windowHeight/80 * settings.policeSize, windowHeight/80 * settings.policeSize)
		updatePos()
	end
end

local function previewMSG()
	ui.beginTransparentWindow("previewMSG", vec2(0, 0), vec2(windowWidth, windowHeight))
	ui.pushDWriteFont("Orbitron;Weight=800")
	local tSize = ui.measureDWriteText("Messages from Police when being chased", settings.fontSizeMSG)
	local uiOffsetX = settings.msgOffsetX - tSize.x/2
	local uiOffsetY = settings.msgOffsetY
	ui.drawRectFilled(vec2(uiOffsetX - 5, uiOffsetY-5), vec2(uiOffsetX + tSize.x + 5, uiOffsetY + tSize.y + 5), COLORSMSGBG)
	ui.dwriteDrawText("Messages from Police when being chased", settings.fontSizeMSG, vec2(uiOffsetX, uiOffsetY), rgbm.colors.cyan)
	ui.popDWriteFont()
	ui.endTransparentWindow()
end

local function previewStars()
	ui.beginTransparentWindow("previewStars", vec2(0, 0), vec2(windowWidth, windowHeight))
	showStarsPursuit()
	ui.endTransparentWindow()
end

local function uiTab()
	ui.text('On Screen Message : ')
	settings.timeMsg = ui.slider('##' .. 'Time Msg On Screen', settings.timeMsg, 1, 15, 'Time Msg On Screen' .. ': %.0fs')
	settings.fontSizeMSG = ui.slider('##' .. 'Font Size MSG', settings.fontSizeMSG, 10, 50, 'Font Size' .. ': %.0f')
	ui.text('Stars : ')
	settings.starsPos.x = ui.slider('##' .. 'Stars Offset X', settings.starsPos.x, 0, windowWidth, 'Stars Offset X' .. ': %.0f')
	settings.starsPos.y = ui.slider('##' .. 'Stars Offset Y', settings.starsPos.y, 0, windowHeight, 'Stars Offset Y' .. ': %.0f')
	settings.starsSize = ui.slider('##' .. 'Stars Size', settings.starsSize, 10, 50, 'Stars Size' .. ': %.0f')
	ui.newLine()
	ui.text('Offset : ')
	settings.msgOffsetY = ui.slider('##' .. 'Msg On Screen Offset Y', settings.msgOffsetY, 0, windowHeight, 'Msg On Screen Offset Y' .. ': %.0f')
	settings.msgOffsetX = ui.slider('##' .. 'Msg On Screen Offset X', settings.msgOffsetX, 0, windowWidth, 'Msg On Screen Offset X' .. ': %.0f')
    ui.newLine()
	ui.text('Preview : ')
	ui.sameLine()
    if ui.button('Message') then
		showPreviewMsg = not showPreviewMsg
		showPreviewStars = false
	end
	ui.sameLine()
	if ui.button('Stars') then
		showPreviewStars = not showPreviewStars
		showPreviewMsg = false
	end
    if showPreviewMsg then previewMSG()
	elseif showPreviewStars then previewStars() end
	if ui.button('Offset X to center') then settings.msgOffsetX = windowWidth/2 end
	ui.newLine()
end

local function settingsWindow()
	imageSize = vec2(windowHeight/80 * settings.policeSize, windowHeight/80 * settings.policeSize)
	ui.dwriteTextAligned("settings", 40, ui.Alignment.Center, ui.Alignment.Center, vec2(windowWidth/6.5,60), false, rgbm.colors.white)
	ui.drawLine(vec2(0,60), vec2(windowWidth/6.5,60), rgbm.colors.white, 1)
	ui.newLine(20)
	ui.sameLine(10)
	ui.beginGroup()
	ui.text('Unit : ')
	ui.sameLine(160)
	if ui.selectable('mph', settings.unit == 'mph',_, ui.measureText('km/h')) then
		settings.unit = 'mph'
		settings.unitMult = 0.621371
	end
	ui.sameLine(200)
	if ui.selectable('km/h', settings.unit == 'km/h',_, ui.measureText('km/h')) then
		settings.unit = 'km/h'
		settings.unitMult = 1
	end
	ui.sameLine(windowWidth/6.5 - 120)
	if ui.button('Close', vec2(100, windowHeight/50)) then
		settingsOpen = false
		onsettingsChange()
	end
	ui.text('HUD : ')
	settings.hudOffsetX = ui.slider('##' .. 'HUD Offset X', settings.hudOffsetX, 0, windowWidth, 'HUD Offset X' .. ': %.0f')
	settings.hudOffsetY = ui.slider('##' .. 'HUD Offset Y', settings.hudOffsetY, 0, windowHeight, 'HUD Offset Y' .. ': %.0f')
	settings.policeSize = ui.slider('##' .. 'HUD Size', settings.policeSize, 10, 50, 'HUD Size' .. ': %.0f')
	settings.fontSize = settings.policeSize * fontMultiplier
    ui.setNextItemWidth(300)
    ui.newLine()
    uiTab()
	updatePos()
	ui.endGroup()
end

---------------------------------------------------------------------------------------------- Utils ----------------------------------------------------------------------------------------------

local function formatMessage(message)
	local msgToSend = message
	if pursuit.suspect == nil then
		msgToSend = string.gsub(msgToSend,"`CAR`", "No Car")
		msgToSend = string.gsub(msgToSend,"`NAME`", "No Name")
		msgToSend = string.gsub(msgToSend,"`SPEED`", "No Speed")
		return msgToSend
	end
	msgToSend = string.gsub(msgToSend,"`CAR`", string.gsub(string.gsub(ac.getCarName(pursuit.suspect.index), "%W", " "), "  ", ""))
	msgToSend = string.gsub(msgToSend,"`NAME`", "@" .. ac.getDriverName(pursuit.suspect.index))
	msgToSend = string.gsub(msgToSend,"`SPEED`", string.format("%d ", ac.getCarSpeedKmh(pursuit.suspect.index) * settings.unitMult) .. settings.unit)
	return msgToSend
end

---------------------------------------------------------------------------------------------- HUD ----------------------------------------------------------------------------------------------

local policeLightsPos = {
	vec2(0,0),
	vec2(windowWidth/10,windowHeight),
	vec2(windowWidth-windowWidth/10,0),
	vec2(windowWidth,windowHeight)
}

local function showPoliceLights()
	local timing = math.floor(os.clock()*2 % 2)
	if timing == 0 then
		ui.drawRectFilledMultiColor(policeLightsPos[1], policeLightsPos[2], rgbm(1,0,0,0.5), rgbm(0,0,0,0), rgbm(0,0,0,0), rgbm(1,0,0,0.5))
		ui.drawRectFilledMultiColor(policeLightsPos[3], policeLightsPos[4], rgbm(0,0,0,0), rgbm(0,0,1,0.5), rgbm(0,0,1,0.5), rgbm(0,0,0,0))
	else
		ui.drawRectFilledMultiColor(policeLightsPos[1], policeLightsPos[2], rgbm(0,0,1,0.5), rgbm(0,0,0,0), rgbm(0,0,0,0), rgbm(0,0,1,0.5))
		ui.drawRectFilledMultiColor(policeLightsPos[3], policeLightsPos[4], rgbm(0,0,0,0), rgbm(1,0,0,0.5), rgbm(1,0,0,0.5), rgbm(0,0,0,0))
	end
end

local chaseLVL = {
	message = "",
	messageTimer = 0,
	color = rgbm(1,1,1,1),
}

local function resetChase()
	pursuit.enable = false
	pursuit.nextMessage = 30
	pursuit.lostSight = false
	pursuit.timeLostSight = 2
end

local function lostSuspect()
	resetChase()
	pursuit.lostSight = false
	pursuit.timeLostSight = 0
	pursuit.level = 1
	ac.sendChatMessage(formatMessage(msgLost.msg[math.random(#msgLost.msg)]))
	pursuit.suspect = nil
	if cspAboveP218 then
		ac.setExtraSwitch(0, false)
	end
end

local iconsColorOn = {
	[1] = rgbm(1,0,0,1),
	[2] = rgbm(1,1,1,1),
	[3] = rgbm(1,1,1,1),
	[4] = rgbm(1,1,1,1),
	[5] = rgbm(1,1,1,1),
	[6] = rgbm(1,1,1,1),
}

local playersInRange = {}

local function drawImage()
	iconsColorOn[2] = rgbm(0.99,0.99,0.99,1)
	iconsColorOn[3] = rgbm(0.99,0.99,0.99,1)
	iconsColorOn[4] = rgbm(0.99,0.99,0.99,1)
	iconsColorOn[5] = rgbm(0.99,0.99,0.99,1)
	iconsColorOn[6] = rgbm(0.99,0.99,0.99,1)
	local uiStats = ac.getUI()

	if ui.rectHovered(iconPos.arrest2, iconPos.arrest1) then
		iconsColorOn[2] = rgbm(1,0,0,1)
		if pursuit.suspect and pursuit.suspect.speedKmh < 50 and car.speedKmh < 20 and uiStats.isMouseLeftKeyClicked then
			pursuit.hasArrested = true
		end
	elseif ui.rectHovered(iconPos.cams2, iconPos.cams1) then
		iconsColorOn[3] = rgbm(1,0,0,1)
		if uiStats.isMouseLeftKeyClicked then
			if camerasOpen then camerasOpen = false
			else
				camerasOpen = true
				arrestLogsOpen = false
				if settingsOpen then
					onsettingsChange()
					settingsOpen = false
				end
			end
		end
	elseif ui.rectHovered(iconPos.lost2, iconPos.lost1) then
		iconsColorOn[4] = rgbm(1,0,0,1)
		if pursuit.suspect and uiStats.isMouseLeftKeyClicked then
			lostSuspect()
		end
	elseif ui.rectHovered(iconPos.logs2, iconPos.logs1) then
		iconsColorOn[5] = rgbm(1,0,0,1)
		if uiStats.isMouseLeftKeyClicked then
			if arrestLogsOpen then arrestLogsOpen = false
			else
				arrestLogsOpen = true
				camerasOpen = false
				if settingsOpen then
					onsettingsChange()
					settingsOpen = false
				end
			end
		end
	elseif ui.rectHovered(iconPos.menu2, iconPos.menu1) then
		iconsColorOn[6] = rgbm(1,0,0,1)
		if uiStats.isMouseLeftKeyClicked then
			if settingsOpen then
				onsettingsChange()
				settingsOpen = false
			else
				settingsOpen = true
				arrestLogsOpen = false
				camerasOpen = false
			end
		end
	end
	ui.image(hudImg.base, imageSize, rgbm.colors.white)
	ui.drawImage(hudImg.radar, vec2(0,0), imageSize, iconsColorOn[1])
	ui.drawImage(hudImg.arrest, vec2(0,0), imageSize, iconsColorOn[2])
	ui.drawImage(hudImg.cams, vec2(0,0), imageSize, iconsColorOn[3])
	ui.drawImage(hudImg.lost, vec2(0,0), imageSize, iconsColorOn[4])
	ui.drawImage(hudImg.logs, vec2(0,0), imageSize, iconsColorOn[5])
	ui.drawImage(hudImg.menu, vec2(0,0), imageSize, iconsColorOn[6])
end

local function playerSelected(player)
	if player.speedKmh > 50 then
		pursuit.suspect = player
		pursuit.nextMessage = 30
		pursuit.level = 1
		local msgToSend = "Officer " .. ac.getDriverName(0) .. " is chasing you. Run! "
		pursuit.startedTime = settings.timeMsg
		pursuit.engage = true
		acpPolice{message = msgToSend, messageType = 0, yourIndex = ac.getCar(pursuit.suspect.index).sessionID}
		if cspAboveP218 then
			ac.setExtraSwitch(0, true)
		end
	end
end

local function hudInChase()
	ui.pushDWriteFont("Orbitron;Weight=Black")
	ui.sameLine(20)
	ui.beginGroup()
	ui.newLine(1)
	local textPursuit = "LVL : " .. math.floor(pursuit.level/2)
	ui.dwriteTextWrapped(ac.getDriverName(pursuit.suspect.index) .. '\n'
						.. string.gsub(string.gsub(ac.getCarName(pursuit.suspect.index), "%W", " "), "  ", "")
						.. '\n' .. string.format("Speed: %d ", pursuit.suspect.speedKmh * settings.unitMult) .. settings.unit
						.. '\n' .. textPursuit, settings.fontSize/2, rgbm.colors.white)
	ui.dummy(vec2(imageSize.x/5,imageSize.y/20))
	ui.newLine(30)
	ui.sameLine()
	if ui.button('Cancel Chase', vec2(imageSize.x/5, imageSize.y/20)) then
		lostSuspect()
	end
	ui.endGroup()
	ui.popDWriteFont()
end

local function drawText()
	local uiStats = ac.getUI()
	ui.pushDWriteFont("Orbitron;Weight=Bold")
	ui.dwriteDrawText("RADAR ACTIVE", settings.fontSize/2, vec2((textPos.box2.x - ui.measureDWriteText("RADAR ACTIVE", settings.fontSize/2).x)/2, 0), rgbm(1,0,0,1))
	ui.popDWriteFont()
	ui.pushDWriteFont("Orbitron;Weight=Regular")
	ui.dwriteDrawText("NEARBY VEHICULE SPEED SCANNING", settings.fontSize/3, vec2((textPos.box2.x - ui.measureDWriteText("NEARBY VEHICULE SPEED SCANNING", settings.fontSize/3).x)/2, settings.fontSize/1.5), rgbm(1,0,0,1))

	local colorText = rgbm(1,1,1,1)
	textPos.box1 = vec2(0, textSize.size.y*2.5)
	ui.dummy(vec2(textPos.box2.x,settings.fontSize))
	for i = 1, #playersInRange do
		colorText = rgbm(1,1,1,1)
		ui.drawRect(vec2(textPos.box2.x/9,textPos.box1.y), vec2(textPos.box2.x*8/9, textPos.box1.y + textPos.box2.y), rgbm(1,1,1,0.1), 1)
		if ui.rectHovered(textPos.box1, textPos.box1 + textPos.box2) then
			colorText = rgbm(1,0,0,1)
			if uiStats.isMouseLeftKeyClicked then
				playerSelected(playersInRange[i].player)
			end
		end
		ui.dwriteDrawText(playersInRange[i].text, settings.fontSize/2, vec2((textPos.box2.x - ui.measureDWriteText(ac.getDriverName(playersInRange[i].player.index) .. " - 000 " .. settings.unit, settings.fontSize/2).x)/2, textPos.box1.y + textSize.size.y/5), colorText)
		textPos.box1 = textPos.box1 + textPos.addBox
		ui.dummy(vec2(textPos.box2.x, i * settings.fontSize/5))
	end
	ui.popDWriteFont()
end

local function radarUI()
	ui.toolWindow('radarText', textSize.window1, textSize.window2, true, function ()
		ui.childWindow('childradar', textSize.window2, true , function ()
			if pursuit.suspect then hudInChase()
			else drawText() end
		end)
	end)
	ui.transparentWindow('radar', vec2(settings.hudOffsetX, settings.hudOffsetY), imageSize, true, function ()
		drawImage()
	end)
end

local function hidePlayers()
	local hideRange = 500
	for i = ac.getSim().carsCount - 1, 0, -1 do
		local player = ac.getCar(i)
		local playerCarID = ac.getCarID(i)
		if player.isConnected and ac.getCarBrand(i) ~= "traffic" then
			if playerCarID ~= valideCar[1] and playerCarID ~= valideCar[2] and playerCarID ~= valideCar[3] then
				if player.position.x > car.position.x - hideRange and player.position.z > car.position.z - hideRange and player.position.x < car.position.x + hideRange and player.position.z < car.position.z + hideRange then
					ac.hideCarLabels(i, false)
				else
					ac.hideCarLabels(i, true)
				end
			end
		end
	end
end

local function radarUpdate()
	if firstload and not pursuit.suspect then return end
	local radarRange = 250
	local previousSize = #playersInRange

	local j = 1
	for i = ac.getSim().carsCount - 1, 0, -1 do
		local player = ac.getCar(i)
		local playerCarID = ac.getCarID(i)
		if player.isConnected and ac.getCarBrand(i) ~= "traffic" then
			if playerCarID ~= valideCar[1] and playerCarID ~= valideCar[2] and playerCarID ~= valideCar[3] then
				if player.position.x > car.position.x - radarRange and player.position.z > car.position.z - radarRange and player.position.x < car.position.x + radarRange and player.position.z < car.position.z + radarRange then
					playersInRange[j] = {}
					playersInRange[j].player = player
					playersInRange[j].text = ac.getDriverName(player.index) .. string.format(" - %d ", player.speedKmh * settings.unitMult) .. settings.unit
					j = j + 1
					if j == 9 then break end
				end
			end
		end
	end
	for i = j, previousSize do playersInRange[i] = nil end
end

---------------------------------------------------------------------------------------------- Chase ----------------------------------------------------------------------------------------------

local function inRange()
	local distance_x = pursuit.suspect.position.x - car.position.x
	local distance_z = pursuit.suspect.position.z - car.position.z
	local distanceSquared = distance_x * distance_x + distance_z * distance_z
	if(distanceSquared < pursuit.minDistance) then
		pursuit.enable = true
		pursuit.lostSight = false
		pursuit.timeLostSight = 2
	elseif (distanceSquared < pursuit.maxDistance) then resetChase()
	else
		if not pursuit.lostSight then
			pursuit.lostSight = true
			pursuit.timeLostSight = 2
		else
			pursuit.timeLostSight = pursuit.timeLostSight - ui.deltaTime()
			if pursuit.timeLostSight < 0 then lostSuspect() end
		end
	end
end

local function sendChatToSuspect()
	if pursuit.enable then
		if 0 < pursuit.nextMessage then
			pursuit.nextMessage = pursuit.nextMessage - ui.deltaTime()
		elseif pursuit.nextMessage < 0 then
			local nb = tostring(pursuit.level)
			acpPolice{message = nb, messageType = 1, yourIndex = ac.getCar(pursuit.suspect.index).sessionID}
			if pursuit.level < 10 then
				pursuit.level = pursuit.level + 1
				chaseLVL.messageTimer = settings.timeMsg
				chaseLVL.message = "CHASE LEVEL " .. math.floor(pursuit.level/2)
				if pursuit.level > 8 then
					chaseLVL.color = rgbm.colors.red
				elseif pursuit.level > 6 then
					chaseLVL.color = rgbm.colors.orange
				elseif pursuit.level > 4 then
					chaseLVL.color = rgbm.colors.yellow
				else
					chaseLVL.color = rgbm.colors.white
				end
			end
			pursuit.nextMessage = 30
		end
	end
end

local function showPursuitMsg()
	local text = ""
	if chaseLVL.messageTimer > 0 then
		chaseLVL.messageTimer = chaseLVL.messageTimer - ui.deltaTime()
		text = chaseLVL.message
	end
	if pursuit.startedTime > 0 then
		if pursuit.suspect then
			text = "You are chasing " .. ac.getDriverName(pursuit.suspect.index) .. " driving a " .. string.gsub(string.gsub(ac.getCarName(pursuit.suspect.index), "%W", " "), "  ", "") .. " ! Get him! "
		end
		if pursuit.startedTime > 6 then showPoliceLights() end
		if pursuit.engage and pursuit.startedTime < 8 then
			ac.sendChatMessage(formatMessage(msgEngage.msg[math.random(#msgEngage.msg)]))
			pursuit.engage = false
		end
	end
	if text ~= "" then
		local textLenght = ui.measureDWriteText(text, settings.fontSizeMSG)
		local rectPos1 = vec2(settings.msgOffsetX - textLenght.x/2, settings.msgOffsetY)
		local rectPos2 = vec2(settings.msgOffsetX + textLenght.x/2, settings.msgOffsetY + settings.fontSizeMSG)
		local rectOffset = vec2(10, 10)
		if ui.time() % 1 < 0.5 then
			ui.drawRectFilled(rectPos1 - vec2(10,0), rectPos2 + rectOffset, COLORSMSGBG, 10)
		else
			ui.drawRectFilled(rectPos1 - vec2(10,0), rectPos2 + rectOffset, rgbm(0,0,0,0.5), 10)
		end
		ui.dwriteDrawText(text, settings.fontSizeMSG, rectPos1, chaseLVL.color)
	end
end

local function arrestSuspect()
	if pursuit.hasArrested and pursuit.suspect then
		local msgToSend = formatMessage(msgArrest.msg[math.random(#msgArrest.msg)])
		table.insert(arrestations, msgToSend .. os.date("\nDate of the Arrestation: %c"))
		ac.sendChatMessage(msgToSend .. "\nPlease Get Back Pit, GG!")
		pursuit.id = pursuit.suspect.sessionID
		if playerData.Arrests == nil then playerData.Arrests = 0 end
		playerData.Arrests = playerData.Arrests + 1
		pursuit.startedTime = 0
		pursuit.suspect = nil
		pursuit.timerArrest = 1
	elseif pursuit.hasArrested then
		if pursuit.timerArrest > 0 then
			pursuit.timerArrest = pursuit.timerArrest - ui.deltaTime()
		else
			acpPolice{message = "BUSTED!", messageType = 2, yourIndex = pursuit.id}
			pursuit.timerArrest = 0
			pursuit.suspect = nil
			pursuit.id = -1
			pursuit.hasArrested = false
			pursuit.startedTime = 0
			pursuit.enable = false
			pursuit.level = 1
			pursuit.nextMessage = 20
			pursuit.lostSight = false
			pursuit.timeLostSight = 0
			local data = {
				["Arrests"] = playerData.Arrests,
			}
			updatefirebase()
			updatefirebaseData("Arrests", data)
		end
	end
end

local function chaseUpdate()
	if pursuit.startedTime > 0 then pursuit.startedTime = pursuit.startedTime - ui.deltaTime()
	else pursuit.startedTime = 0 end
	if pursuit.suspect then
		sendChatToSuspect()
		inRange()
	end
	arrestSuspect()
end

---------------------------------------------------------------------------------------------- Menu ----------------------------------------------------------------------------------------------

local function arrestLogsUI()
	ui.dwriteTextAligned("Arrestation Logs", 40, ui.Alignment.Center, ui.Alignment.Center, vec2(windowWidth/4,60), false, rgbm.colors.white)
	ui.drawLine(vec2(0,60), vec2(windowWidth/4,60), rgbm.colors.white, 1)
	ui.newLine(15)
	ui.sameLine(10)
	ui.beginGroup()
	local allMsg = ""
	ui.dwriteText("Click on the button next to the message you want to copy.", 15, rgbm.colors.white)
	ui.sameLine(windowWidth/4 - 120)
	if ui.button('Close', vec2(100, windowHeight/50)) then arrestLogsOpen = false end
	for i = 1, #arrestations do
		if ui.smallButton("#" .. i .. ": ", vec2(0,10)) then
			ui.setClipboardText(arrestations[i])
		end
		ui.sameLine()
		ui.dwriteTextWrapped(arrestations[i], 15, rgbm.colors.white)
	end
	if #arrestations == 0 then
		ui.dwriteText("No arrestation logs yet.", 15, rgbm.colors.white)
	end
	ui.newLine()
	if ui.button("Set all messages to ClipBoard") then
		for i = 1, #arrestations do
			allMsg = allMsg .. arrestations[i] .. "\n\n"
		end
		ui.setClipboardText(allMsg)
	end
	ui.endGroup()
end

local buttonPos = windowWidth/65

local function camerasUI()
	ui.dwriteTextAligned("Surveillance Cameras", 40, ui.Alignment.Center, ui.Alignment.Center, vec2(windowWidth/6.5,60), false, rgbm.colors.white)
	ui.drawLine(vec2(0,60), vec2(windowWidth/6.5,60), rgbm.colors.white, 1)
	ui.newLine(20)
	ui.beginGroup()
	ui.sameLine(buttonPos)
	if ui.button('Close', vec2(windowWidth/6.5 - buttonPos*2,30)) then camerasOpen = false end
	ui.newLine()
	for i = 1, #cameras do
		local h = math.rad(cameras[i].dir + ac.getCompassAngle(vec3(0, 0, 1)))
		ui.newLine()
		ui.sameLine(buttonPos)
		if ui.button(cameras[i].name, vec2(windowWidth/6.5 - buttonPos*2,30)) then
			ac.setCurrentCamera(ac.CameraMode.Free)
			ac.setCameraPosition(cameras[i].pos)
			ac.setCameraDirection(vec3(math.sin(h), 0, math.cos(h))) 
			ac.setCameraFOV(cameras[i].fov)
		end
	end
	if ac.getSim().cameraMode == ac.CameraMode.Free then
		ui.newLine()
		ui.newLine()
		ui.sameLine(buttonPos)
        if ui.button('Police car camera', vec2(windowWidth/6.5 - buttonPos*2,30)) then ac.setCurrentCamera(ac.CameraMode.Cockpit) end
    end
end


local initialized = false
local menuSize = {vec2(windowWidth/4, windowHeight/3), vec2(windowWidth/6.4, windowHeight/2.2)}
local buttonPressed = false

local function moveMenu()
	if ui.windowHovered() and ui.mouseDown() then buttonPressed = true end
	if ui.mouseReleased() then buttonPressed = false end
	if buttonPressed then settings.menuPos = settings.menuPos + ui.mouseDelta() end
end

---------------------------------------------------------------------------------------------- updates ----------------------------------------------------------------------------------------------

function script.drawUI()
	if carID ~= valideCar[1] and carID ~= valideCar[2] and carID ~= valideCar[3] or cspVersion < cspMinVersion then return end
	if initialized and settings.policeSize then
		if firstload then
			firstload = false
			initsettings()
		end
		radarUI()
		if pursuit.suspect then showStarsPursuit() end
		showPursuitMsg()
		if settingsOpen then
			ui.toolWindow('settings', settings.menuPos, menuSize[2], true, function ()
				ui.childWindow('childsettings', menuSize[2], true, function () settingsWindow() moveMenu() end)
			end)
		elseif arrestLogsOpen then
			ui.toolWindow('ArrestLogs', settings.menuPos, menuSize[1], true, function ()
				ui.childWindow('childArrestLogs', menuSize[1], true, function () arrestLogsUI() moveMenu() end)
			end)
		elseif camerasOpen then
			ui.toolWindow('Cameras', settings.menuPos, menuSize[2], true, function ()
				ui.childWindow('childCameras', menuSize[2], true, function () camerasUI() moveMenu() end)
			end)
		end
	end
end

ac.onCarJumped(0, function (carid)
	if carID == valideCar[1] or carID == valideCar[2] or carID == valideCar[3]then
		if pursuit.suspect then lostSuspect() end
	end
end)

function script.update(dt)
	if carID ~= valideCar[1] and carID ~= valideCar[2] and carID ~= valideCar[3] or cspVersion < cspMinVersion then return end
	if not initialized then
		loadsettings()
		getFirebase()
		initialized = true
	else
		radarUpdate()
		chaseUpdate()
		--hidePlayers()
	end
end

if carID == valideCar[1] or carID == valideCar[2] or carID == valideCar[3] and cspVersion >= cspMinVersion then
	ui.registerOnlineExtra(ui.Icons.Settings, "Settings", nil, settingsWindow, nil, ui.OnlineExtraFlags.Tool, 'ui.WindowFlags.AlwaysAutoResize')
end
