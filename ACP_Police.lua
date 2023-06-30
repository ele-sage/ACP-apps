local sim = ac.getSim()
local car = ac.getCar(0)
local windowWidth = sim.windowWidth
local windowHeight = sim.windowHeight
local settingsOpen = false
local arrestLogsOpen = false
local camerasOpen = false
local settingsLoaded = true
local valideCar = {"chargerpolice_acpursuit", "crown_police"}

local sharedDataSettings = ac.connect({
	ac.StructItem.key('ACP_essential_settings'),
	showStats = ac.StructItem.boolean(),
	racesWon = ac.StructItem.int16(),
	racesLost = ac.StructItem.int16(),
	busted = ac.StructItem.int16(),
	statsSize = ac.StructItem.int16(),
	statsOffsetX = ac.StructItem.int16(),
	statsOffsetY = ac.StructItem.int16(),
	statsFont = ac.StructItem.int16(),
	current = ac.StructItem.int16(),
	colorHud = ac.StructItem.rgbm(),
	send = ac.StructItem.boolean(),
	timeMsg = ac.StructItem.int16(),
	msgOffsetY = ac.StructItem.int16(),
	msgOffsetX = ac.StructItem.int16(),
	fontSizeMSG = ac.StructItem.int16(),
	menuPos = ac.StructItem.vec2(),
	unit = ac.StructItem.string(4),
	unitMult = ac.StructItem.float(),
}, true, ac.SharedNamespace.Shared)

ui.setAsynchronousImagesLoading(true)
local imageSize = vec2(0,0)

local assetsFolder = ac.getFolder(ac.FolderID.ACApps) .. "/lua/ACP_essential/HudPolice/"
local hud = assetsFolder .. "hud.png"
local iconCams = assetsFolder .. "iconCams.png"
local iconLost = assetsFolder .. "iconLost.png"
local iconLogs = assetsFolder .. "iconLogs.png"
local iconMenu = assetsFolder .. "iconMenu.png"
local iconRadar = assetsFolder .. "iconRadar.png"
local iconArrest = assetsFolder .. "iconArrest.png"


local msgChase = {
    {
        msg = {"This is the police! Please pull over to the side of the road!","You are requested to stop your `CAR` immediately, pull over now!","Attention driver, pull over and cooperate with the authorities.","Stop your `CAR` and comply with the police, this is a warning!","Stop the `CAR`! pull over to the side of the road, and follow our instructions."}
    },
    {
        msg = {"** Pull over now, failure to comply may result in consequences.","** We have reason to believe that you are evading the police in your `CAR`, pull over immediately.","** Stop your `CAR`, this is your last warning before we take action.","** You have been warned, failure to stop will result in the use of force.","** Pull over now or face the consequences, you have been warned."}
    },
    {
        msg = {"** This is your final warning, pull over and comply with the police!","** Stop your `CAR`, any attempt to evade the police will result in immediate action!","** You are endangering the public, pull over now and cooperate!","** Failure to comply with police orders will result in the use of force!","** Stop the `CAR` immediately, you are putting yourself and others in danger!",}
    },
    {
        msg = {"*** The use of force may be necessary if you do not comply, pull over now!!","*** You are putting the lives of others in danger, pull over and face the consequences!!","*** Pull over and surrender now, resistance will not be tolerated!!","*** This is the last warning, pull over and face the consequences of your actions!!","*** Stop the `CAR` immediately, you are putting yourself and others in danger!!",}
    },
    {
        msg = {"*** We are taking control of the situation, pull over and surrender now!","*** You have left us no choice, pull over or we will be forced to act!","*** Stop the `CAR` immediately, you are risking the lives of others!","*** This is your final warning, pull over or face the consequences!","*** Stop the vehicle and surrender now, the use of force is authorized!",}
    },
    {
        msg = {"**** The situation is escalating, pull over and surrender yourself to the authorities!","**** Your actions have consequences, pull over and face them now!","**** This is your last chance to comply, stop the `CAR` immediately!","**** We have authorization to use force, pull over and surrender!","**** You are putting yourself and others in danger, pull over now and cooperate!",}
    },
    {
        msg = {"**** You are risking the lives of innocent people, pull over and surrender now!","**** The use of force is imminent, pull over and surrender yourself to the police!","**** This is your final warning, pull over or face the full force of the law!","**** We will use any means necessary to stop your `CAR`, pull over now!","**** You have been warned, pull over and face the consequences of your actions!",}
    },
    {
        msg = {"***** This is your final warning, stop your `CAR` or we will use total force!","***** The situation has escalated, you must stop your `CAR` immediately or face the consequences!","***** We have authorization to use all necessary means to stop your `CAR`, stop now!","***** This is your last warning, stop your `CAR` or we will use all necessary force!","***** Stop your `CAR` immediately, or you will be met with total force!",}
    }
}

local msgLost = {
		msg = {"We've lost sight of the suspect. The vehicle involved is described as a `CAR` driven by `NAME`.",
		"Suspect is no longer in view. The vehicle in question is a `CAR` with `NAME` behind the wheel.",
		"Attention all units, we have lost visual contact with the suspect. The vehicle involved is a `CAR` driven by `NAME`.",
		"We have temporarily lost track of the suspect. The vehicle description is a `CAR` with `NAME` as the driver.",
		"Suspect has evaded our pursuit. The vehicle in question is a `CAR` with `NAME` at the helm.",
		"Visual contact with the suspect has been lost. The suspect is driving a `CAR` and identified as `NAME`.",
		"Attention, suspect is no longer in our line of sight. The vehicle involved is a `CAR` with `NAME` as the driver.",
		"We have lost the suspect's visual trail. The vehicle in question is described as a `CAR` driven by `NAME`.",
		"The suspect is no longer visible. The vehicle involved is a `CAR` with `NAME` behind the wheel.",
		"Suspect have been lost, Vehicle Description:`CAR` driven by `NAME`",}
}

local msgEngage = {
    msg = {"Control! I am engaging on a `CAR` traveling at `SPEED`","Pursuit in progress! I am chasing a `CAR` exceeding `SPEED`","Control, be advised! Pursuit is active on a `CAR` driving over `SPEED`","Attention! Pursuit initiated! Im following a `CAR` going above `SPEED`","Pursuit engaged! `CAR` driving at a high rate of speed over `SPEED`","Attention all units, we have a pursuit in progress! Suspect driving a `CAR` exceeding `SPEED`","Attention units! We have a suspect fleeing in a `CAR` at high speed, pursuing now at `SPEED`","Engaging on a high-speed chase! Suspect driving a `CAR` exceeding `SPEED`!","Attention all units! we have a pursuit in progress! Suspect driving a `CAR` exceeding `SPEED`","High-speed chase underway, suspect driving `CAR` over `SPEED`","Control, `CAR` exceeding `SPEED`, pursuit active.","Engaging on a `CAR` exceeding `SPEED`, pursuit initiated."}
}

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
	timeInPursuit = 0,
	nextMessage = 20,
	level = 1,
	id = -1,
	timerArrest = 0,
	hasArrested = false,
}

local arrestations = {}

local textSize = {}

local textPos = {}

local iconPos = {}

---------------------------------------------------------------------------------------------- Settings ----------------------------------------------------------------------------------------------

local acpPolice = ac.OnlineEvent({
    message = ac.StructItem.string(110),
	messageType = ac.StructItem.int16(),
	yourIndex = ac.StructItem.int16(),
}, function (sender, data) end)

local function updatePos()
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

	textSize.size = vec2(imageSize.x*3/5, SETTINGS.statsFont/2)
	textSize.box = vec2(imageSize.x*3/5, SETTINGS.statsFont/1.3)
	textSize.window1 = vec2(SETTINGS.statsOffsetX+imageSize.x/9.5, SETTINGS.statsOffsetY+imageSize.y/5.3)
	textSize.window2 = vec2(imageSize.x*3/5, imageSize.y/2.8)

	textPos.box1 = vec2(0, 0)
	textPos.box2 = vec2(textSize.size.x, textSize.size.y*1.95)
	textPos.addBox = vec2(0, textSize.size.y*1.95)
end

local showPreviewMsg = false
COLORSMSGBG = rgbm(0.5,0.5,0.5,0.5)

local function initSettings()
	ac.log(sharedDataSettings.showStats)
	if not sharedDataSettings.showStats then
		settingsLoaded = false
		SETTINGS = {
			showStats = true,
			racesWon = 0,
			racesLost = 0,
			busted = 0,
			statsSize = 20,
			statsOffsetX = 0,
			statsOffsetY = 0,
			statsFont = 20,
			current = 1,
			colorHud = rgbm(1,0,0,1),
			timeMsg = 10,
			msgOffsetY = 10,
			msgOffsetX = windowWidth/2,
			fontSizeMSG = 30,
			menuPos = vec2(0, 0),
			unit = "km/h",
			unitMult = 1,
		}
	else SETTINGS = sharedDataSettings end
	if SETTINGS.unit ~= "km/h" then SETTINGS.unitMult = 0.621371 end
	SETTINGS.statsFont = SETTINGS.statsSize * windowHeight/1440
	imageSize = vec2(windowHeight/80 * SETTINGS.statsSize, windowHeight/80 * SETTINGS.statsSize)
	updatePos()
	ac.log(rgbm.colors.cyan)
end

local function previewMSG()
	ui.beginTransparentWindow("previewMSG", vec2(0, 0), vec2(windowWidth, windowHeight))
	ui.pushDWriteFont("Orbitron;Weight=800")
	local tSize = ui.measureDWriteText("Messages from Police when being chased", SETTINGS.fontSizeMSG)
	local uiOffsetX = SETTINGS.msgOffsetX - tSize.x/2
	local uiOffsetY = SETTINGS.msgOffsetY
	ui.drawRectFilled(vec2(uiOffsetX - 5, uiOffsetY-5), vec2(uiOffsetX + tSize.x + 5, uiOffsetY + tSize.y + 5), COLORSMSGBG)
	ui.dwriteDrawText("Messages from Police when being chased", SETTINGS.fontSizeMSG, vec2(uiOffsetX, uiOffsetY), rgbm.colors.cyan)
	ui.popDWriteFont()
	ui.endTransparentWindow()
end

local function uiTab()
	ui.text('On Screen Message : ')
	SETTINGS.timeMsg = ui.slider('##' .. 'Time Msg On Screen', SETTINGS.timeMsg, 1, 15, 'Time Msg On Screen' .. ': %.0fs')
	SETTINGS.fontSizeMSG = ui.slider('##' .. 'Font Size MSG', SETTINGS.fontSizeMSG, 10, 50, 'Font Size' .. ': %.0f')
	ui.newLine()
	ui.text('Offset : ')
	SETTINGS.msgOffsetY = ui.slider('##' .. 'Msg On Screen Offset Y', SETTINGS.msgOffsetY, 0, windowHeight, 'Msg On Screen Offset Y' .. ': %.0f')
	SETTINGS.msgOffsetX = ui.slider('##' .. 'Msg On Screen Offset X', SETTINGS.msgOffsetX, 0, windowWidth, 'Msg On Screen Offset X' .. ': %.0f')
    ui.newLine()
	ui.text('Preview : ')
    if ui.button('Message') then showPreviewMsg = not showPreviewMsg end
    if showPreviewMsg then previewMSG() end
	ui.sameLine()
	if ui.button('Offset X to center') then SETTINGS.msgOffsetX = windowWidth/2 end
	ui.newLine()
end

local function settings()
	imageSize = vec2(windowHeight/80 * SETTINGS.statsSize, windowHeight/80 * SETTINGS.statsSize)
	ui.dwriteTextAligned("Settings", 40, ui.Alignment.Center, ui.Alignment.Center, vec2(windowWidth/6.5,60), false, rgbm.colors.white)
	ui.drawLine(vec2(0,60), vec2(windowWidth/6.5,60), rgbm.colors.white, 1)
	ui.newLine(20)
	ui.sameLine(10)
	ui.beginGroup()
	if ui.checkbox('Show HUD', SETTINGS.showStats) then SETTINGS.showStats = not SETTINGS.showStats end
	ui.sameLine(120)
	ui.text('Unit : ')
	ui.sameLine(160)
	if ui.selectable('mph', SETTINGS.unit == 'mph',_, ui.measureText('km/h')) then
		SETTINGS.unit = 'mph'
		SETTINGS.unitMult = 0.621371
	end
	ui.sameLine(200)
	if ui.selectable('km/h', SETTINGS.unit == 'km/h',_, ui.measureText('km/h')) then
		SETTINGS.unit = 'km/h'
		SETTINGS.unitMult = 1
	end
	ui.sameLine(windowWidth/6.5 - 120)
	if ui.button('Close', vec2(100, windowHeight/50)) then settingsOpen = false end
	SETTINGS.statsOffsetX = ui.slider('##' .. 'HUD Offset X', SETTINGS.statsOffsetX, 0, windowWidth, 'HUD Offset X' .. ': %.0f')
	SETTINGS.statsOffsetY = ui.slider('##' .. 'HUD Offset Y', SETTINGS.statsOffsetY, 0, windowHeight, 'HUD Offset Y' .. ': %.0f')
	SETTINGS.statsSize = ui.slider('##' .. 'HUD Size', SETTINGS.statsSize, 10, 50, 'HUD Size' .. ': %.0f')
	local fontMultiplier = windowHeight/1440
	SETTINGS.statsFont = SETTINGS.statsSize * fontMultiplier
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
	msgToSend = string.gsub(msgToSend,"`SPEED`", string.format("%d ", ac.getCarSpeedKmh(pursuit.suspect.index) * SETTINGS.unitMult) .. SETTINGS.unit)
	return msgToSend
end

---------------------------------------------------------------------------------------------- HUD ----------------------------------------------------------------------------------------------

local chaseLVL = {
	message = "",
	messageTimer = 0,
}

local function resetChase()
	pursuit.enable = false
	pursuit.nextMessage = 20
	pursuit.level = 1
end

local function lostSuspect()
	resetChase()
	pursuit.suspect = nil
	ac.setExtraSwitch(0, false)
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
		iconsColorOn[2] = rgbm(0,1,1,1)
		if pursuit.suspect and car.speedKmh < 20 and uiStats.isMouseLeftKeyClicked then
			pursuit.hasArrested = true
		end
	elseif ui.rectHovered(iconPos.cams2, iconPos.cams1) then
		iconsColorOn[3] = rgbm(0,1,1,1)
		if uiStats.isMouseLeftKeyClicked then
			if camerasOpen then camerasOpen = false
			else
				camerasOpen = true
				arrestLogsOpen = false
				settingsOpen = false
			end
		end
	elseif ui.rectHovered(iconPos.lost2, iconPos.lost1) then
		iconsColorOn[4] = rgbm(0,1,1,1)
		if pursuit.suspect and uiStats.isMouseLeftKeyClicked then
			ac.sendChatMessage(formatMessage(msgLost.msg[math.random(#msgLost.msg)]))
			lostSuspect()
		end
	elseif ui.rectHovered(iconPos.logs2, iconPos.logs1) then
		iconsColorOn[5] = rgbm(0,1,1,1)
		if uiStats.isMouseLeftKeyClicked then
			if arrestLogsOpen then arrestLogsOpen = false
			else
				arrestLogsOpen = true
				camerasOpen = false
				settingsOpen = false
			end
		end
	elseif ui.rectHovered(iconPos.menu2, iconPos.menu1) then
		iconsColorOn[6] = rgbm(0,1,1,1)
		if uiStats.isMouseLeftKeyClicked then
			if settingsOpen then settingsOpen = false
			else
				settingsOpen = true
				arrestLogsOpen = false
				camerasOpen = false
			end
		end
	end
	ui.image(hud, imageSize, rgbm.colors.white)
	ui.drawImage(iconRadar, vec2(0,0), imageSize, iconsColorOn[1])
	ui.drawImage(iconArrest, vec2(0,0), imageSize, iconsColorOn[2])
	ui.drawImage(iconCams, vec2(0,0), imageSize, iconsColorOn[3])
	ui.drawImage(iconLost, vec2(0,0), imageSize, iconsColorOn[4])
	ui.drawImage(iconLogs, vec2(0,0), imageSize, iconsColorOn[5])
	ui.drawImage(iconMenu, vec2(0,0), imageSize, iconsColorOn[6])
end

local function playerSelected(player)
	if pursuit.suspect == player then
		pursuit.suspect = nil
		ac.setExtraSwitch(0, false)
	else
		pursuit.suspect = player
		pursuit.timeInPursuit = os.clock()
		pursuit.nextMessage = 20
		pursuit.level = 1
		ac.setExtraSwitch(0, true)
		ac.sendChatMessage(formatMessage(msgEngage.msg[math.random(#msgEngage.msg)]))
	end
end

local function hudInChase()
	ui.pushDWriteFont("Orbitron;Weight=Black")
	ui.sameLine(20)
	ui.beginGroup()
	ui.newLine(1)
	local textPursuit = "LVL : " .. pursuit.level - 1
	ui.dwriteTextWrapped(ac.getDriverName(pursuit.suspect.index) .. '\n'
						.. string.gsub(string.gsub(ac.getCarName(pursuit.suspect.index), "%W", " "), "  ", "")
						.. '\n' .. string.format("Speed: %d ", pursuit.suspect.speedKmh * SETTINGS.unitMult) .. SETTINGS.unit
						.. '\n' .. textPursuit, SETTINGS.statsFont/2, rgbm.colors.white)
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
	ui.pushDWriteFont("Orbitron;Weight=Bold")
	ui.dwriteDrawText("RADAR ACTIVE", SETTINGS.statsFont/2, vec2((textPos.box2.x - ui.measureDWriteText("RADAR ACTIVE", SETTINGS.statsFont/2).x)/2, 0), rgbm(1,0,0,1))
	ui.popDWriteFont()
	ui.pushDWriteFont("Orbitron;Weight=Regular")
	ui.dwriteDrawText("NEARBY VEHICULE SPEED SCANNING", SETTINGS.statsFont/3, vec2((textPos.box2.x - ui.measureDWriteText("NEARBY VEHICULE SPEED SCANNING", SETTINGS.statsFont/3).x)/2, SETTINGS.statsFont/1.5), rgbm(1,0,0,1))

	local uiStats = ac.getUI()
	local colorText = rgbm(1,1,1,1)
	textPos.box1 = vec2(0, textSize.size.y*2.4)
	ui.newLine(30)
	for i = 1, #playersInRange do
		colorText = rgbm(1,1,1,1)
		ui.drawRect(vec2(textPos.box2.x/9,textPos.box1.y), vec2(textPos.box2.x*8/9, textPos.box1.y + textPos.box2.y), rgbm(1,1,1,0.1), 1)
		if ui.rectHovered(textPos.box1, textPos.box1 + textPos.box2) then
			colorText = rgbm(0,1,1,1)
			if uiStats.isMouseLeftKeyClicked then
				playerSelected(playersInRange[i].player)
			end
		end
		textPos.box1 = textPos.box1 + textPos.addBox
		ui.dwriteTextAligned(playersInRange[i].text, SETTINGS.statsFont/2, ui.Alignment.Center, ui.Alignment.Center, textSize.box, false, colorText)
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
	ui.transparentWindow('radar', vec2(SETTINGS.statsOffsetX, SETTINGS.statsOffsetY), imageSize, true, function ()
		drawImage()
	end)
end

local function radarUpdate()
	local radarRange = 250
	local previousSize = #playersInRange

	local j = 1
	for i = ac.getSim().carsCount - 1, 0, -1 do
		local player = ac.getCar(i)
		if player.isConnected and (not player.isHidingLabels) then
			if player.index ~= car.index then
				if player.position.x > car.position.x - radarRange and player.position.z > car.position.z - radarRange and player.position.x < car.position.x + radarRange and player.position.z < car.position.z + radarRange then
					playersInRange[j] = {}
					playersInRange[j].player = player
					playersInRange[j].text = ac.getDriverName(player.index) .. string.format(" - %d ", player.speedKmh * SETTINGS.unitMult) .. SETTINGS.unit
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
	elseif (distanceSquared < pursuit.maxDistance) then
		pursuit.timeInPursuit = os.clock()
		resetChase()
	else
		if pursuit.suspect.rpm > 400 and pursuit.suspect.speedKmh > 20 then
			local msgToSend = formatMessage(msgLost.msg[math.random(#msgLost.msg)])
			ac.sendChatMessage(msgToSend)
		end
		lostSuspect()
	end
end

local function sendChatToSuspect()
	if pursuit.enable then
		if os.clock() - pursuit.timeInPursuit > pursuit.nextMessage then
			local msgToSend = formatMessage(msgChase[pursuit.level].msg[math.random(#msgChase[pursuit.level].msg)])
			chaseLVL.message = string.format("Level %d⭐", pursuit.level)
			chaseLVL.messageTimer = SETTINGS.timeMsg
			if pursuit.level < 5 then
				acpPolice{message = msgToSend, messageType = 1, yourIndex = ac.getCar(pursuit.suspect.index).sessionID}
			else
				ac.sendChatMessage(msgToSend)
			end
			pursuit.nextMessage = pursuit.nextMessage + 20
			if pursuit.level < 8 then
				pursuit.level = pursuit.level + 1
			end
		end
	end
end

local function showPursuitMsg()
	if chaseLVL.messageTimer > 0 then
		chaseLVL.messageTimer = chaseLVL.messageTimer - ui.deltaTime()
		local text = chaseLVL.message
		local textLenght = ui.measureDWriteText(text, SETTINGS.fontSizeMSG)
		local rectPos1 = vec2(SETTINGS.msgOffsetX - textLenght.x/2, SETTINGS.msgOffsetY)
		local rectPos2 = vec2(SETTINGS.msgOffsetX + textLenght.x/2, SETTINGS.msgOffsetY + SETTINGS.fontSizeMSG)
		local rectOffset = vec2(10, 10)
		if ui.time() % 1 < 0.5 then
			ui.drawRectFilled(rectPos1 - vec2(10,0), rectPos2 + rectOffset, COLORSMSGBG, 10)
		else
			ui.drawRectFilled(rectPos1 - vec2(10,0), rectPos2 + rectOffset, rgbm(0,0,0,0.5), 10)
		end
		ui.dwriteDrawText(text, SETTINGS.fontSizeMSG, rectPos1, rgbm.colors.cyan)
	end
end

local function arrestSuspect()
	if pursuit.hasArrested and pursuit.suspect then
		local msgToSend = formatMessage(msgArrest.msg[math.random(#msgArrest.msg)])
		table.insert(arrestations, msgToSend .. os.date("\nDate of the Arrestation: %c"))
		ac.sendChatMessage(msgToSend .. "\nPlease Get Back Pit, GG!")
		pursuit.id = pursuit.suspect.sessionID
		pursuit.suspect = nil
		ac.setExtraSwitch(0, false)
		pursuit.timerArrest = 1
	end
	if pursuit.hasArrested then
		if pursuit.timerArrest > 0 then
			pursuit.timerArrest = pursuit.timerArrest - ui.deltaTime()
		else
			acpPolice{message = "Arrest", messageType = 2, yourIndex = pursuit.id}
			pursuit.timerArrest = 0
			pursuit.suspect = nil
			pursuit.id = -1
			pursuit.hasArrested = false
		end
	end
end

local function chaseUpdate()
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
local menuSize = {vec2(windowWidth/4, windowHeight/3), vec2(windowWidth/6.5, windowHeight/2.9)}
local buttonPressed = false

local function moveMenu()
	if ui.windowHovered() and ui.mouseDown() then buttonPressed = true end
	if ui.mouseReleased() then buttonPressed = false end
	if buttonPressed then SETTINGS.menuPos = SETTINGS.menuPos + ui.mouseDelta() end
end

---------------------------------------------------------------------------------------------- updates ----------------------------------------------------------------------------------------------

function script.drawUI()
	if settingsLoaded and initialized then
		radarUI()
		showPursuitMsg()
		if settingsOpen then
			ui.toolWindow('Settings', SETTINGS.menuPos, menuSize[2], true, function ()
				ui.childWindow('childSettings', menuSize[2], true, function () settings() moveMenu() end)
			end)
		elseif arrestLogsOpen then
			ui.toolWindow('ArrestLogs', SETTINGS.menuPos, menuSize[1], true, function ()
				ui.childWindow('childArrestLogs', menuSize[1], true, function () arrestLogsUI() moveMenu() end)
			end)
		elseif camerasOpen then
			ui.toolWindow('Cameras', SETTINGS.menuPos, menuSize[2], true, function ()
				ui.childWindow('childCameras', menuSize[2], true, function () camerasUI() moveMenu() end)
			end)
		end
	end
end

function script.update(dt)
	if ac.getCarID(0) ~= valideCar[1] and ac.getCarID(0) ~= valideCar[2] then return end
	if not initialized then
		initialized = true
        initSettings()
	else
		if settingsLoaded then
			if not pursuit.suspect then radarUpdate() end
			chaseUpdate()
			sharedDataSettings = SETTINGS
		end
	end
end
