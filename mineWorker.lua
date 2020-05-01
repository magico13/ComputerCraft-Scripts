local _lastID = -1
local isBusy = 0
local waypoints_c = {}
local caches_c = {}

function SendBlocksMined(tgt, blocks)
  redmsg.CreateAndSend(tgt, "MINE:MINED", textutils.serialize(blocks), { "NOSAVE", "NOCONFIRM" })
end


function MineBlocks(blocks)
  local lastAttempts = {}
  local mineDelay = 0.5
  local recentlyMined = {}
  local n = table.getn(blocks)
  while n > 0 do
    toRemove = {}
    nextToABlock = false
    local pos = lps.locateVec()
    for _i = n,1,-1 do --loop backwards to handle nilling any mined blocks
      local block = blocks[_i]
      local d = lps.minDist(pos, block)
      if d == 0 then --if we are in the block then we mined it
        blocks[_i] = 0 
        table.insert(recentlyMined, block)
      elseif lps.minDist(pos, block) == 1 then --it's next to us
        if block.y > pos.y then --it's up
          while turtle.detectUp() do --handle gravel
            turtle.digUp()
            os.sleep(mineDelay)
          end
        elseif block.y < pos.y then --it's down
          while turtle.detectDown() do
            turtle.digDown()
          end
        elseif block.x > pos.x then --it's east
          lps.face(3)
          while turtle.detect() do
            turtle.dig()
            os.sleep(mineDelay)
          end
        elseif block.x < pos.x then --it's west
          lps.face(1)
          while turtle.detect() do
            turtle.dig()
            os.sleep(mineDelay)
          end
        elseif block.z > pos.z then --it's south
          lps.face(0)
          while turtle.detect() do
            turtle.dig()
            os.sleep(mineDelay)
          end
        elseif block.z < pos.z then --it's north
          lps.face(2)
          while turtle.detect() do
            turtle.dig()
            os.sleep(mineDelay)
          end
        end
        nextToABlock = true
        table.insert(recentlyMined, block)
        blocks[_i] = 0
        lastAttempts = {}
        --break --don't break, we might be next to other blocks
      end
    end
    if nextToABlock then
      --compact the table by removing nil values
      for i=n,1,-1 do
        if blocks[i] == 0 then table.remove(blocks, i) end
      end
      -- ArrayRemove(blocks, function(t, i, j)
      --   return (t[i]~=nil)
      -- end);
      print(table.getn(blocks).." blocks remaining")
      -- We've mined all the blocks around us, update controller
      -- This sends less packets than doing it per block
      SendBlocksMined(sender, recentlyMined)
      recentlyMined = {}
      SendUpdate(_lastID)
    end

    n = table.getn(blocks)

    if InventorySlotsUsed() == 16 then
      DropOffAtCache()
    elseif not nextToABlock and n > 0 then
      --we need to move
      --find the closest block
      local closest = blocks[1]
      local closeDist = lps.minDist(blocks[1], pos)
      for _i, block in pairs(blocks) do
        local d = lps.minDist(block, pos)
        if d < closeDist then
          closest = block
          closeDist = d
        end
      end --for
      --now we have the closest block, but we need to go next to it
      
      vectors = {
        vector.new(1, 0, 0),
        vector.new(-1, 0, 0),
        vector.new(0, 1, 0),
        vector.new(0, -1, 0),
        vector.new(0, 0, 1),
        vector.new(0, 0, -1),
      }
      
      local newClosest = nil
      for k,v in pairs(vectors) do
        local closeVec = vector.new(closest.x, closest.y, closest.z)+v
        if not lps.VectorInSet(closeVec, lastAttempts) then --don't repeat
          local d = lps.minDist(closeVec, pos)
          if d < closeDist then
            newClosest = closeVec
            closeDist = d 
          end
        end
      end
      
      if not newClosest then return false end
      
      table.insert(lastAttempts, newClosest)
      lps.goWaypointsClosest(newClosest, waypoints_c, 10)
      --lps.goVec(newClosest, 10) -- go to the closest block
    end --if not nextToABlock
    
  end
  return true
end

function DropOffAtCache()
  -- When the inventory is too full, we have to drop stuff off at the closest cache
  print("Dropping off at cache")
  local pos = lps.locateVec()
  if not caches_c then return end
  local closest = caches_c[1]
  local closeDist = lps.minDist(caches_c[1], pos)
  for _i, block in pairs(caches_c) do
    local d = lps.minDist(block, pos)
    if d < closeDist then
      closest = block
      closeDist = d
    end
  end
  tgt = closest + vector.new(0, 1, 0)
  -- have closest cache, now travel to the space right above it
  if lps.goWaypointsClosest(tgt, waypoinst_c) then
    DumpInventoryBelow()
  end
  --randVec = vector.new(math.random(5)-3, math.random(2), math.random(5)-3)
  -- move somewhere else
  --lps.goVec(tgt + randVec)
end

function DumpInventoryBelow()
  print("Dumping inventory")
  for slot=1,16 do
    turtle.select(slot)
    turtle.dropDown()
  end
  turtle.select(1)
end

function InventorySlotsUsed()
  local used = 0
  for slot=1,16 do
    if turtle.getItemCount(slot) > 0 then used = used + 1 end
 end
 return used
end

function ArrayRemove(t, fnKeep)
  -- https://stackoverflow.com/questions/12394841/safely-remove-items-from-an-array-table-while-iterating
  local j, n = 1, #t;

  for i=1,n do
      if (fnKeep(t, i, j)) then
          -- Move i's kept value to j's position, if it's not already there.
          if (i ~= j) then
              t[j] = t[i];
              t[i] = nil;
          end
          j = j + 1; -- Increment position of where we'll place the next kept value.
      else
          t[i] = nil;
      end
  end

  return t;
end

function SendRegister(tgtID)
  print("Attempting to register with "..tgtID)
  local redData = CompileData()
  if redmsg.CreateAndSend(tgtID, "MINE:REGISTER", textutils.serialize(redData), { "NOSAVE" }) then
    print("AOS with "..tgtID)
    lps.SetupRedMsg(tgtID)
  else
    print(tgtID.." didn't respond")
  end
end


function CompileData()
  local redData = {}
  redData.fuel = turtle.getFuelLevel()
  redData.position = lps.locateVec()
  redData.busy = isBusy
  redData.inventory = InventorySlotsUsed()
  
  -- for slot=1,16 do
  --    table.insert(redData.inventory, turtle.getItemCount(slot))
  -- end
  
  return redData
end

-- sends an update message containing info like:
-- position
-- fuel level
-- busy status
-- inventory contents
function SendUpdate(tgtID)
  local redData = CompileData()
  
  if not redmsg.CreateAndSend(tonumber(tgtID), "MINE:UPDATE", textutils.serialize(redData), { "NOSAVE" }) then
    print(tgtID.." didn't respond to update...")
  end
end

-- MAIN --

if not os.loadAPI("redmsg") then
  print("Error loading redmsg API")
  return
end

if not os.loadAPI("lps") then
  print("Error loading lps API")
  return
end

-- initialize redmsg
local side = redmsg.Initialize()
if not side then
  print("Couldn't initialize redmsg. Missing modem?")
  return
end

print("I think I'm at: "..lps.locateVec():tostring().." f:"..lps.facing())

local args = {...}
if # args > 0 and args[1] == "cached" then
  lps.fileInitialize()
else
  print("Use cached location? (Y/n)")
  local resp = read()
  if resp and resp == "n" then
    print("Enter location:")
    print("x:")
    local x = tonumber(read())
    print("y:")
    local y = tonumber(read())
    print("z:")
    local z = tonumber(read())
    print("facing:")
    local face = tonumber(read())
    
    if x and y and z and face then
      lps.Initialize(x, y, z, face)
    else
      print("Invalid position data")
      return
    end
  else
    lps.fileInitialize()
  end
end

if not lps.IsInitialized() then
  print("Position not initialized! Exiting.")
  return
end

--lps.SetupRedMsg(redmsgID)
--lps.SendRedMsgUpdate()
math.randomseed(os.time())
print("Initialized")

while true do
  print("Waiting for message...")
  isBusy = 0
  local message = redmsg.ReceiveMessage()
  target, sender, subject, body = redmsg.GetComponents(message)
  
  if tonumber(target) < 0 then --broadcast, might be registration
    print("Got broadcast")
    if subject == "MINE:INITIALIZE" then --is registration
      dataTable = textutils.unserialize(body)
      waypoints_c = dataTable.waypoints
      caches_c = dataTable.caches
      SendRegister(sender)
    end
  end
  
  if target == os.getComputerID() then
    _lastID = tonumber(sender)
    -- sent to us specifically
    if subject == "MINE:GO" then
      tgtTable = textutils.unserialize(body)
      tgt = vector.new(tgtTable.tgt.x, tgtTable.tgt.y, tgtTable.tgt.z)
      waypoints_c = tgtTable.waypoints
      print("Going to "..tgt:tostring())
      isBusy = 1
      SendUpdate(sender)
      madeIt = lps.goWaypointsClosest(tgt, waypoints_c)
      print("Success? ", madeIt)
      isBusy = 0
      SendUpdate(sender)
    elseif subject == "MINE:MINE" then
      print("Attempting to mine some blocks")
      local blocks = textutils.unserialize(body)
      isBusy = 1
      SendUpdate(sender)
      MineBlocks(blocks)
      isBusy = 0
      SendUpdate(sender)
    elseif subject == "MINE:HEARTBEAT" then
      print("heartbeat")
      dataTable = textutils.unserialize(body)
      waypoints_c = dataTable.waypoints
      caches_c = dataTable.caches
      os.sleep(math.random(20)/10)
      SendUpdate(tonumber(sender))
    elseif subject == "END" then
      print("Received END message")
      break
    end
  end

  if InventorySlotsUsed() == 16 then
    DropOffAtCache()
  end
end

redmsg.Finalize(side)