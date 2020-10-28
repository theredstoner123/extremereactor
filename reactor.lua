--2:20
API = require("buttonAPI")
local filesystem = require("filesystem")
local component = require("component")
local keyboard = require("keyboard")
local event = require("event")
local gpu = component.gpu
local reactor = component.br_reactor

local versionType = "NEW"

local DEBUG = false
local debugList = {}
local debugVars = {}


local colors = { blue = 0x4286F4, purple = 0xB673d6, red = 0xC14141, green = 0xDA841,
  black = 0x000000, white = 0xFFFFFF, grey = 0x47494C, lightGrey = 0xBBBBBB}
-- set size of the screen for lvl 3
gpu.setResolution(132,38)
gpu.setBackground(colors.black)
gpu.fill(1, 1, 132, 38, " ")

local sections = {}
local graphs = {}
local infos = {}


-- defninitions
reactor["stats"] = {}
local running = true
local maxRF = 0
local reactorRodsLevel = {}
local currentRodLevel = 0
local currentRf = 0
local currentRfTick = 0
local currentFuel = 0
local rodCount = 0

local minPowerRod = 0
local maxPowerRod = 100


-- functions

function toint(n)
    local s = tostring(n)
    local i, j = s:find('%.')
    if i then
        return tonumber(s:sub(1, i-1))
    else
        return n
    end
end

function setSections()
  sections["graph"] = { x = 5, y = 3, width = 78, height= 33, title = "  INFOS  "}
  sections["controls"] = { x = 88, y = 3, width = 40, height = 20, title = "  CONTROLS  "}
  sections["info"] = { x = 88, y = 26, width = 40, height= 10, title = "  NUMBERS  "}
end

function setGraphs()
  graphs["tick"] = { x = 8, y = 6, width = 73, height= 8, title = "ENERGY LAST TICK"}
  graphs["stored"] = { x = 8, y = 16, width = 73, height = 8, title = "ENERGY STORED"}
  graphs["rods"] = { x = 8, y = 26, width = 73, height= 8, title = "CONTROL RODS LEVEL"}
end

function setInfos()
  infos["tick"] = { x = 92, y = 28, width = 73, height= 1, title = "RF PER TICK : ", unit = " RF"}
  infos["stored"] = { x = 92, y = 30, width = 73, height = 1, title = "ENERGY STORED : ", unit = " RF"}
  infos["rods"] = { x = 92, y = 32, width = 73, height= 1, title = "CONTROL ROD LEVEL : ", unit = "%"}
  infos["fuel"] = { x = 92, y = 34, width = 73, height= 1, title = "FUEL USAGE : ", unit = " Mb/t"}
end

function debugInfos()  
  debug["print"] = { x = 1, y = 38, width = 73, height= 1, title = "DBG : "}
end

function setButtons()
  API.setTable("ON", powerOn, 91, 5, 106, 7,"ON", {on = colors.green, off = colors.green})
  API.setTable("OFF", powerOff, 109, 5, 125, 7,"OFF", {on = colors.red, off = colors.red})

  API.setTable("lowerMinLimit", lowerMinLimit, 91, 15, 106, 17,"-10", {on = colors.blue, off = colors.blue})
  API.setTable("lowerMaxLimit", lowerMaxLimit, 109, 15, 125, 17,"-10", {on = colors.purple, off = colors.purple})

  API.setTable("augmentMinLimit", augmentMinLimit, 91, 19, 106, 21,"+10", {on = colors.blue, off = colors.blue})
  API.setTable("augmentMaxLimit", augmentMaxLimit, 109, 19, 125, 21,"+10", {on = colors.purple, off = colors.purple})
end

function printBorders(sectionName)
  local s = sections[sectionName]

  -- set border
  gpu.setBackground(colors.grey)
  gpu.fill(s.x, s.y, s.width, 1, " ")
  gpu.fill(s.x, s.y, 1, s.height, " ")
  gpu.fill(s.x, s.y + s.height, s.width, 1, " ")
  gpu.fill(s.x + s.width, s.y, 1, s.height + 1, " ")

  -- set title
  gpu.setBackground(colors.black)
  gpu.set(s.x + 2, s.y, s.title)
end

function printGraphs(graphName)
  local g = graphs[graphName]

  -- set graph
  gpu.setBackground(colors.lightGrey)
  gpu.fill(g.x, g.y, g.width, g.height, " ")

  -- set title
  gpu.setBackground(colors.black)
  gpu.set(g.x, g.y - 1, g.title)
end

function printActiveGraphs(activeGraph)
  local g = activeGraph

  -- set graph
  gpu.setBackground(colors.green)
  gpu.fill(g.x, g.y, g.width, g.height, " ")
  gpu.setBackground(colors.black)
end

function printStaticControlText()
  gpu.setForeground(colors.blue)
  gpu.set(97,12, "MIN")
  gpu.setForeground(colors.purple)
  gpu.set(116,12, "MAX")
  gpu.setForeground(colors.white)
  gpu.set(102,10, "AUTO-CONTROL")
  gpu.set(107,13, "--")
end

function printControlInfos()
  gpu.setForeground(colors.blue)
  gpu.set(97,13, minPowerRod .. "% ")
  gpu.setForeground(colors.purple)
  gpu.set(116,13, maxPowerRod .. "% ")
  gpu.setForeground(colors.white)
end

function printInfos(infoName)
  local maxLength = 15
  local i = infos[infoName]
  local spaces = string.rep(" ", maxLength - string.len(reactor.stats[infoName] .. i.unit))
  gpu.set(i.x, i.y , i.title .. reactor.stats[infoName] .. i.unit .. spaces)
end

function getInfoFromReactor()
  local reactorEnergyStats = reactor.getEnergyStats()
  local reactorFuelStats = reactor.getFuelStats()
  --reactorRodsLevel = reactor.getControlRodsLevels()

  reactor.stats["tick"] = toint(math.ceil(reactorEnergyStats["energyProducedLastTick"]))
  reactor.stats["stored"] = toint(reactorEnergyStats["energyStored"])
  reactor.stats["rodCount"] = toint(reactor.getNumberOfControlRods())
  for i=0, reactor.stats["rodCount"] do 
	reactorRodsLevel[i] = reactor.getControlRodLevel(i)
  end
  
  local rodLevelSum = 0
  for key,value in pairs(reactorRodsLevel) do 
    rodLevelSum = rodLevelSum + value
  end
  reactor.stats["rodLevelSum"] = toint(rodLevelSum)
  reactor.stats["rods"] = toint(rodLevelSum/rodCount)
  reactor.stats["fuel"] = round(reactorFuelStats["fuelConsumedLastTick"], 2)
  currentRf = reactor.stats["stored"]
end

function getInfoFromReactorOLD()
  reactor.stats["tick"] = toint(math.ceil(reactor.getEnergyProducedLastTick()))
  reactor.stats["stored"] = toint(reactor.getEnergyStored())
  reactor.stats["rods"] = toint(math.ceil(reactor.getControlRodLevel(0)))
  reactor.stats["fuel"] = round(reactor.getFuelConsumedLastTick(), 2)
  currentRf = reactor.stats["stored"]
end

function augmentMinLimit()
  modifyRods("min", 10)
end

function lowerMinLimit()
  modifyRods("min", -10)
end

function augmentMaxLimit()
  modifyRods("max", 10)
end

function lowerMaxLimit()
  modifyRods("max", -10)
end

function powerOn()
  reactor.setActive(true)
end

function powerOff()
  reactor.setActive(false)
end

function modifyRods(limit, number)
	local tempLevel = 0

	if limit == "min" then
		tempLevel = minPowerRod + number
		if tempLevel <= 0 then
			minPowerRod = 0
		end

		if tempLevel >= maxPowerRod then
			minPowerRod = maxPowerRod -10
		end

		if tempLevel < maxPowerRod and tempLevel > 0 then
			minPowerRod = tempLevel
		end
	else
		tempLevel = maxPowerRod + number
		if tempLevel <= minPowerRod then
			maxPowerRod = minPowerRod +10
		end

		if tempLevel >= 100 then
			maxPowerRod = 100
		end

		if tempLevel > minPowerRod and tempLevel < 100 then
			maxPowerRod = tempLevel
		end
	end

  setInfoToFile()
  calculateAdjustRodsLevel()
end

-- Calculate and adjusts the level of the rods
function calculateAdjustRodsLevel()
	local rfTotalMax = 10000000
	currentRf = reactor.stats["stored"]
	rodCount = reactor.stats["rodCount"]

	differenceMinMax = maxPowerRod - minPowerRod

	local maxPower = (rfTotalMax/100) * maxPowerRod
	local minPower = (rfTotalMax/100) * minPowerRod

	if currentRf >= maxPower then
		currentRf = maxPower
	end

	if currentRf <= minPower then
		currentRf = minPower
	end

	currentRf = toint(currentRf - (rfTotalMax/100) * minPowerRod)
	local rfInBetween = (rfTotalMax/100) * differenceMinMax
  local rodLevel = toint(math.ceil((currentRf/rfInBetween)^0.25*100*rodCount))
  
  if versionType == "NEW" then
    AdjustRodsLevel(rodLevel)
  else
    AdjustRodsLevelOLD(rodLevel)
  end
end

--new adjustment protocol--

local lastRodIndex

function AdjustRodsLevel(rodLevelNewSum)
rodCount = reactor.stats["rodCount"]
rodLevelSum = reactor.stats["rodLevelSum"]
local adjValue = rodLevelNewSum - rodLevelSum

if adjValue > 0 then
local actingAdjValue = 0
actingAdjValue = math.abs(adjValue)
local i=0;
  for i=0,rodCount-1 do
  if actingAdjValue > 0 then
	local tempCRL = reactorRodsLevel[i]
	
	if tempCRL <= actingAdjValue then
		reactor.setControlRodLevel(i,0)
		actingAdjValue = actingAdjValue - tempCRL
	end
	
	if tempCRL > actingAdjValue then
		reactor.setControlRodLevel(i,(tempCRL - actingAdjValue))
		actingAdjValue = 0
	end
  end
  
  lastRodIndex = i
  end
end

if adjValue < 0 then
local actingAdjValue = 0
actingAdjValue = math.abs(adjValue)

  for i=lastRodIndex,0,-1 do
  if actingAdjValue > 0 then
	local tempCRL = reactorRodsLevel[i]
	
	if 100-tempCRL <= actingAdjValue then
		reactor.setControlRodLevel(i,100)
		actingAdjValue = actingAdjValue - (100 - tempCRL)
	end
	
	if 100-tempCRL > actingAdjValue then
		reactor.setControlRodLevel(i,(tempCRL + actingAdjValue))
		actingAdjValue = 0
	end
  end
  end
end
	
end

function AdjustRodsLevelOLD(rodLevel)
  reactor.setAllControlRodLevels(rodLevel)
end

function printDebug()  
  local maxLength = 132
  local i = debug["print"]
  local rodsvalues = ""
  
  rodsvalues = "[0]" .. reactorRodsLevel[0] .. "[1]" .. reactorRodsLevel[1] .. "[2]" .. reactorRodsLevel[2] .. "[Z]" .. reactor.stats["rods"]

  local debugInformations = "maxRF:" .. maxRF .. ", RodsLev:" .. rodsvalues .. ", curRodLev:" .. currentRodLevel .. ", curRf:" .. currentRf .. ", curRfT:" .. currentRfTick .. ", min-max:" .. minPowerRod .. "-" .. maxPowerRod
  local spaces = string.rep(" ", maxLength - string.len(debugInformations))
  gpu.set(i.x, i.y , i.title .. debugInformations .. spaces)
end

function draw()
  if maxRF < reactor.stats["tick"] then
    maxRF = reactor.stats["tick"]
  end

  if currentRfTick ~= reactor.stats["tick"] then
    currentRfTick = reactor.stats["tick"]
    local max = math.ceil(graphs["tick"].width * (currentRfTick/maxRF))
    local currentRFTickObj = {x = graphs["tick"].x, y = graphs["tick"].y, width = max, height = graphs["tick"].height}
    printInfos("tick")
    printGraphs("tick")
    printActiveGraphs(currentRFTickObj)
  end

  if currentRF ~= reactor.stats["stored"] then
    currentRF = reactor.stats["stored"]
    local max = math.ceil(graphs["stored"].width * (currentRF/10000000))
    local currentRFObj = {x = graphs["stored"].x, y = graphs["stored"].y, width = max, height = graphs["stored"].height}
    printInfos("stored")
    printGraphs("stored")
    printActiveGraphs(currentRFObj)
  end

  if currentRodLevel ~= reactor.stats["rods"] then
    currentRodLevel = reactor.stats["rods"]
    local max = math.ceil(graphs["rods"].width * (currentRodLevel/100))
    local currentRodObj = {x = graphs["rods"].x, y = graphs["rods"].y, width = max, height = graphs["rods"].height}
    printInfos("rods")
    printGraphs("rods")
    printActiveGraphs(currentRodObj)
  end

  if currentFuel ~= reactor.stats["fuel"] then
    currentFuel = reactor.stats["fuel"]
    printInfos("fuel")
  end
  printControlInfos()
  if DEBUG == true then
    printDebug()
  end
end

function startup()
  getInfoFromFile()
  if versionType == "NEW" then
    getInfoFromReactor()
  else
    getInfoFromReactorOLD()
  end
  setSections()
  setGraphs()
  setInfos()
  setButtons()
  if DEBUG == true then
    debugInfos()
    printDebug()
  end

  for name, data in pairs(sections) do
    printBorders(name)
  end
  for name, data in pairs(graphs) do
    printGraphs(name)
  end
  for name, data in pairs(infos) do
    printInfos(name)
  end
  printStaticControlText()


end


-- helpers
function round(val, decimal)
  if (decimal) then
    return math.floor( (val * 10^decimal) + 0.5) / (10^decimal)
  else
    return math.floor(val+0.5)
  end
end

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return false else return true end
end

function getInfoFromFile()
	 if file_exists("reactor.txt") then
	 	file = io.open("reactor.txt","w")
    file:write("0", "\n")
    file:write("100", "\n")
    file:close()
	else
		file = io.open("reactor.txt","r")
		minPowerRod = tonumber(file:read("*l"))
		maxPowerRod = tonumber(file:read("*l"))
    file:close()
	end
end

function setInfoToFile()
  file = io.open("reactor.txt","w")
  file:write(minPowerRod, "\n")
  file:write(maxPowerRod, "\n")
  file:flush()
  file:close()
end

function testVersion()
  reactor.getEnergyStats()
end

function setOldVersion()
  versionType = "OLD"
end
-- starting
xpcall(testVersion, setOldVersion)
startup()
API.screen()

event.listen("touch", API.checkxy)

while event.pull(0.1, "interrupted") == nil do
  if versionType == "NEW" then
    if reactor.mbIsConnected() == true and reactor.mbIsAssembled() == true then
      getInfoFromReactor()
    end
  else
    getInfoFromReactorOLD()
  end
  calculateAdjustRodsLevel()
  draw()
  local event, address, arg1, arg2, arg3 = event.pull(1)
  if type(address) == "string" and component.isPrimary(address) then
    if event == "key_down" and arg2 == keyboard.keys.q then
      os.exit()
    end
  end
end