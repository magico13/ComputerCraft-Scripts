local clearTimer = nil
local saveTimer = nil
local heartbeatTimer = os.startTimer(60)
local run = true
local tx, ty = term.getSize()
local curY = 10

local world = {}
local worldFile = "world.txt"
local settingsFile = "mineSettings.txt"
local topLeft = vector.new(0, curY, 0)

local currentTool = "SELECT"
local toolData = {}

local waypoints = {}

--local turtleID = 4
local turtleStats = {}


local MineBlocks = {}
local ToMine = {}


function Exit()
  run = false
  m13.reset()
end

function YChange(btnID)
  if btnID == "bYDown" then
    curY = math.max(curY - 1, 0)
  elseif btnID == "bYUp" then
    curY = math.min(curY + 1, 255)
  end
  topLeft.y = curY
  resetScreen()
end

function resetScreen()
  m13.reset()
  --m13.makeBorder()
  
  m13.writeAt(curY, 2, 1)
  m13.writeAt(topLeft:tostring(), 7, 1)
  
  m13.writeAt(currentTool, 1, ty)
  
  showWorld()
  addButtons()
end

function addButtons()
  m13.newButtons()
  m13.addButton("bExit", "X", Exit, tx, 1, colors.black, colors.red, 1, 1)
  
  m13.addButton("bYDown", "-", YChange, 1, 1, colors.black, colors.white, 1, 1)
  m13.addButton("bYUp", "+", YChange, 5, 1, colors.black, colors.white, 1, 1)
  
  m13.addButton("bSelect", " ", changeTool, 1, 3, colors.blue, colors.blue, 1, 1)
  m13.addButton("bClear", " ", changeTool, 1, 4, colors.white, colors.white, 1, 1)
  m13.addButton("bMine", " ", changeTool, 1, 5, colors.red, colors.red, 1, 1)
  m13.addButton("bWayPoint", " ", changeTool, 1, 6, colors.lightblue, colors.lightBlue, 1, 1)
  m13.addButton("bGo", " ", changeTool, 1, 7, colors.green, colors.green, 1, 1)

  if currentTool == "MINE" then
    m13.addButton("bMineSend", "Send", sendMineInfo, m13.xRight("Send")-1, ty, colors.black, colors.red)
  elseif currentTool == "SELECT" then
    local count = 0
    for k,v in pairs(turtleStats) do
      if k then
        m13.addButton("bTurtle:"..k, k, selectTurtle, 1, 9+count, colors.black, getTurtleStatusColor(k), nil, 1, true)
        count = count + 1
      end
    end
  end
  
end

function changeTool(btnID)
  if btnID == "bSelect" then
    currentTool = "SELECT"
  elseif btnID == "bClear" then
    currentTool = "CLEAR"
  elseif btnID == "bMine" then
    currentTool = "MINE"
  elseif btnID == "bWayPoint" then
    currentTool = "WAYPOINT"
  elseif btnID == "bGo" then
    currentTool = "GO"
  end
  clearTimer = os.startTimer(0.01)
end

function loadWorldKnowledge()
  if fs.exists(worldFile) then
    local f = fs.open(worldFile, "r")
    world = textutils.unserialize(f.readAll())
    f.close()
  end
  if fs.exists(settingsFile) then
    local f = fs.open(settingsFile, "r")
    local settings = textutils.unserialize(f.readAll())
    f.close()
    topLeft = vector.new(settings.topLeft.x, settings.topLeft.y, settings.topLeft.z)
    curY = settings.topLeft.y
    waypoints = settings.waypoints
  end
end

function saveWorldKnowledge()
  local f = fs.open(worldFile, "w")
  f.write(textutils.serialize(world))
  f.close()
  
  f = fs.open(settingsFile, "w")
  settings = {}
  settings["topLeft"] = topLeft
  settings["waypoints"] = waypoints
  f.write(textutils.serialize(settings))
  f.close()
end

function addToWorldKnowledge(loc)
  loc = vector.new(loc.x, loc.y, loc.z)
  world[loc:tostring()] = true
end

function showWorld()
  --world goes from 2,2 to x-1, y-1
  --north (face 2, z-) on top
  --west (face 1, x-)
  --east (face 3, x+)
  --south (face 0, z+)
  
  for x=2, tx-1 do
    for y=2, ty-1 do
      m13.cPos(x, y)
      local color = colors.gray
      local colorTxt = colors.white
      local pos = getWorldPosition(x, y)
      local txt = " "
      if world[pos:tostring()] then --we have knowledge of what's there
        color = colors.white
      else --we don't know
        color = colors.gray
      end
      
      if redmsg.VectorInTable(waypoints, pos) then --its a waypoint
          color = colors.lightBlue
      end
      
      for index, tData in pairs(turtleStats) do
        if tData.position.x == pos.x and tData.position.z == pos.z then
          if tData.position.y > pos.y then txt = "^"
          elseif tData.position.y < pos.y then txt = "v"
          end
          color = getTurtleStatusColor(index)
        end
      end
      
      for index, data in pairs(ToMine) do
        if data.x == pos.x and data.y == pos.y and data.z == pos.z then
          color = colors.orange
          break
        end
      end
      
      for index, data in pairs(MineBlocks) do
        if data.x == pos.x and data.y == pos.y and data.z == pos.z then
          color = colors.red
          break
        end
      end
      
      
      
      local preTxt, preBack = m13.setColors(colorTxt, color)
      term.write(txt)
      m13.setColors(preTxt, preBack)
    end
  end
  
end

function getTurtleStatusColor(tID)
  local tData = turtleStats[tID]
  local color = colors.green
  if tData.busy == "yes" then color = colors.yellow end
  if tData.missing then color = colors.red end
  return color
end

function sendMineInfo(btnID)
  --send the list of blocks to mine to the closest turtle
  if not MineBlocks[1] then return end
  local closest = findClosestTurtle(MineBlocks[1])
  if closest >= 0 then
    redmsg.CreateAndSend(closest, "MINE:MINE", textutils.serialize(MineBlocks))
    JoinLists(ToMine, MineBlocks)
    MineBlocks = {}
  end
  resetScreen()
end

--joins "other" table into "final" table
-- lists, not dictionaries
function JoinLists(final, other)
  for k, v in pairs(other) do
    table.insert(final, v)
  end
end

function findClosestTurtle(block) -- eventually add ability to track if busy
  closest = 9999999
  closestID = -1
  for k,v in pairs(turtleStats) do
    if v.busy ~= "yes" and not v.missing and minDist(block, v.position) < closest then
      closest = minDist(block, v.position)
      closestID = k
    end
  end
  return closestID
end

function minDist(v1, v2)
  return math.abs(v1.x-v2.x) + math.abs(v1.y-v2.y) + math.abs(v1.z-v2.z)
end
-- gets the world position based on the screen position
function getWorldPosition(x, y)
  return (topLeft + vector.new(x-2, 0, y-2))
end

function UpdateTurtleData(tID, tData)
  if not turtleStats[tID] then
    turtleStats[tID] = {
      ["position"] = vector.new(0, 0, 0),
      ["fuel"] = 0,
      ["busy"]="no",
      ["inventory"]={},
      ["lastUpdate"]=0,
      ["missing"]=false,
    }
  end
  if tData.position then
    turtleStats[tID].position = vector.new(tData.position.x, tData.position.y, tData.position.z)
  end
  if tData.fuel then
    turtleStats[tID].fuel = tonumber(tData.fuel)
  end
  if tData.busy then turtleStats[tID].busy = tData.busy end
  if tData.inventory then
    for i=1,16 do
      if tData.inventory[i] then
        turtleStats[tID].inventory[i] = tData.inventory[i]
      end
    end
  end
  
  turtleStats[tID].lastUpdate = GetAbsoluteTicks()
  turtleStats[tID].missing = false
  
  
  addToWorldKnowledge(tData.position) -- update the world because this position is confirmed clear
end

function SecondsBetween(t1, t2)
  --t1 and t2 must be given in absolute times (os.day()*24000 + (os.time()*1000 + 18000)%24000)
  
  local ticks = t2 - t1
  
  return ticks / 20 --20 ticks per second
end

function GetAbsoluteTicks(day, t)
  if not day then day = os.day() end
  if not t then t = os.time() end
  
  local ticks = (day*24000) + ((t*1000 + 18000)%24000)
  return ticks
end

function QueueSave(t)
  if not saveTimer then
    saveTimer = os.startTimer(t)
  end
end

function selectTurtle(name)
  print("selecting "..name )
  local id = string.sub(name, string.find(name, ":")+1)
  id = tonumber(id)
  --center the screen on the turtle
  topLeft = vector.new(math.floor(turtleStats[id].position.x - (tx-2)/2), turtleStats[id].position.y, math.floor(turtleStats[id].position.z - (ty-2)/2))
  curY = topLeft.y
  resetScreen()
end

-- MAIN --

world[vector.new(0, 10, 0):tostring()] = true

loadWorldKnowledge()

if not os.loadAPI("m13") then
  print("Error loading m13 API")
  return
end
if not os.loadAPI("redmsg") then
  print("Error loading redmsg API")
  return
end

local modemSide = redmsg.Initialize()


print("Contacting turtles...")

--get all turtles that are ready to go
--send out a request
redmsg.CreateAndSend(-1, "MINE:INITIALIZE", "", { "NOSAVE", "NOCONFIRM" } )
local message = redmsg.ReceiveMessage(1)
while message do
  tID, sID, subj, body = redmsg.GetComponents(message)
  if subj == "MINE:REGISTER" then
    UpdateTurtleData(tonumber(sID), textutils.unserialize(body))
    print("Registered "..sID)
  end
  message = redmsg.ReceiveMessage(1)
end

sleep(0.2)
resetScreen()

while run do
  local event, a1, a2, a3 = os.pullEvent()
  if event == "mouse_click" then
    local btnName = m13.buttonClicked(a2, a3)
    local func = m13.getFunc(btnName)
    if func then
      func(btnName)
    else
      --not a button, probably clicking in area
      if a2 > 1 and a2 < tx then
        if a3 > 1 and a3 < ty then
          --definitely within the area
          if currentTool == "SELECT" then -- select a block/turtle
            
          elseif currentTool == "CLEAR" then -- set the block to cleared
            if a1 == 1 then
              world[getWorldPosition(a2, a3):tostring()] = true
              resetScreen()
            else
              world[getWorldPosition(a2, a3):tostring()] = false
              resetScreen()
            end
            QueueSave(5)
          elseif currentTool == "MINE" then -- designate the block to be mined
            local pos = getWorldPosition(a2, a3)
            if a1 == 1 then
              if not toolData[0] then
                --first click
                toolData[0] = pos
                table.insert(MineBlocks, pos)
              else
                --second click, make "cube"
                local xStep = 1
                local yStep = 1
                local zStep = 1
                if toolData[0].x > pos.x then xStep = -1 end
                if toolData[0].y > pos.y then yStep = -1 end
                if toolData[0].z > pos.z then zStep = -1 end
                
                for x=toolData[0].x, pos.x, xStep do
                  for y=toolData[0].y, pos.y, yStep do
                    for z=toolData[0].z, pos.z, zStep do
                      local v = vector.new(x, y, z)
                      if not redmsg.VectorInTable(MineBlocks, v) and not redmsg.VectorInTable(ToMine, v) then
                        table.insert(MineBlocks, v)
                      end
                    end
                  end
                end
                toolData[0] = nil
              end
              --if not redmsg.VectorInTable(MineBlocks, pos) then
               -- table.insert(MineBlocks, pos)
               -- resetScreen()
              --end
              resetScreen()
            else
              local index = redmsg.VectorInTable(MineBlocks, pos)
              if index then
                table.remove(MineBlocks, index)
                resetScreen()
              end
            end
          elseif currentTool == "WAYPOINT" then -- set the block as a waypoint
            local pos = getWorldPosition(a2, a3)
            if a1 == 1 then
              if not redmsg.VectorInTable(waypoints, pos) then
                table.insert(waypoints, pos)
                resetScreen()
              end
            else
              local index = redmsg.VectorInTable(waypoints, pos)
              if index then
                table.remove(waypoints, index)
                resetScreen()
              end
            end
            QueueSave(5)
          elseif currentTool == "GO" then -- move to the selected space (must be CLEARed first)
            local pos = getWorldPosition(a2, a3)
           -- if world[pos] then --must be cleared
              local totalTable = {}
              totalTable.tgt = pos
              totalTable.waypoints = waypoints
              local closestID = findClosestTurtle(pos)
              if closestID >= 0 then
                redmsg.CreateAndSend(closestID, "MINE:GO", textutils.serialize(totalTable))
              end
         --   end
          end
        end
      end
    end
  end
  
  if event == "rednet_message" then
    message = redmsg.ProcessReceived(a1, a2)
    tgtID, sID, subject, body = redmsg.GetComponents(message)
    
--    print("got message from "..sID)
    if tgtID == os.getComputerID() then
      if subject == "LPSUpdate" then
        UpdateTurtleData(tonumber(sID), textutils.unserialize(body))
        resetScreen()
        QueueSave(5)
      elseif subject == "BlockMined" then
        local pos = textutils.unserialize(body)
        world[vector.new(pos.x, pos.y, pos.z):tostring()] = true
        local index = redmsg.VectorInTable(ToMine, pos)
        if index then
          table.remove(ToMine, index)
        end
        resetScreen()
        QueueSave(5)
      elseif subject == "MINE:UPDATE" then
        UpdateTurtleData(tonumber(sID), textutils.unserialize(body))
        resetScreen() --not getting post work updates for some reason...
        --print("got update")
        --redmsg.Print(message)
      end
    end
  end
  
  if event == "key" then
    deltaVec = vector.new(0, 0, 0)
    if a1 == keys.left then deltaVec = vector.new(-1, 0 , 0) end
    if a1 == keys.right then deltaVec = vector.new(1, 0 , 0) end
    if a1 == keys.up then deltaVec = vector.new(0, 0 , -1) end
    if a1 == keys.down then deltaVec = vector.new(0, 0 , 1) end
    topLeft = topLeft + deltaVec
    
    if a1 == keys.equals then YChange("bYUp") end
    if a1 == keys.minus then YChange("bYDown") end
    
    resetScreen()
  end
  
  if event == "timer" then
    if a1 == clearTimer then
      resetScreen()
    end
    if a1 == saveTimer then
      saveWorldKnowledge()
      saveTimer = nil
    end
    if a1 == heartbeatTimer then
      --send update request
      for i, t in pairs(turtleStats) do 
        if redmsg.CreateAndSend(i, "MINE:HEARTBEAT", "", { "NOSAVE" }) then
          --we just got a reply, so we should listen for the full update
          local message = redmsg.ReceiveMessage(0.5) --for some reason this isn't returning a response
          tgtID, sID, subject, body = redmsg.GetComponents(message)
          --redmsg.Print(message)
          if tgtID == os.getComputerID() then
            if subject == "MINE:UPDATE" then
              UpdateTurtleData(tonumber(sID), textutils.unserialize(body))
            end
          end
        end
      end
      
      local curTime = GetAbsoluteTicks()
      print(curTime)
      for i, t in pairs(turtleStats) do
        if SecondsBetween(t.lastUpdate, curTime) > 60 then
          --we haven't been updated recently
          t.missing = true
        end
      end
      heartbeatTimer = os.startTimer(60)
      resetScreen()
    end
  end
end


saveWorldKnowledge()
redmsg.Finalize(modemSide)

