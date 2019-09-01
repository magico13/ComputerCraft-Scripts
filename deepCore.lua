-- like Core, except it will report the blocks at each level

-- Settings --
local logFile = "Log_deepCore.txt"
local limitDepth = 3
local patchSlot = 1 --set to 0 to disable
local ignoreListHuman = {
  "air",
  "grass",
  "dirt",
  "stone",
  "cobblestone",
  "gravel",
  "sand",
  "andesite",
  "limestone",
  "diorite",
}

--Globals--
local blockData = {}
local depth = 0
local maxDepth = 0
local ignoreList = {}


function Main()
  os.loadAPI("blockDB")
  --print(blockDB.GetVersion())
  blockDB.UpdateDB()
  
  ConvertIgnoreList()
  print("Ready to mine!")
  while LayerCycle() do
    print("Depth: "..depth)
  end
  print("Reached bottom")
  maxDepth = depth
  while depth > 0 do
    if turtle.up() then
      depth = depth - 1
    end
  end
  print("Returned to surface from a depth of "..maxDepth)
  
  WriteMineLog()
  
  Patch()
  
  print("Entering interactive mode.")
  depth = 1
  RefreshScreen(depth)
  while true do
    local event, key = os.pullEvent("key_up")
    if key == keys.backspace then 
      term.clear()
      term.setCursorPos(1, 1)
      break
    elseif key == keys.down then 
      depth = depth + 1 
      depth = math.min(depth, maxDepth)
      RefreshScreen(depth)
    elseif key == keys.up then
      depth = depth -1
      depth = math.max(depth, 1)
      RefreshScreen(depth)
    elseif key == keys.zero then
      blockDB.UpdateDB()
      RefreshScreen(depth)
    end
  end
end

--Converts the ignore list from the human form to the robot form
function ConvertIgnoreList()
  for k,v in pairs(ignoreListHuman) do
    names = blockDB.GetMachineName(v)
    for key,value in pairs(names) do
      table.insert(ignoreList, value)
    end
  end
end

function Patch()
  if (patchSlot > 0) then
    turtle.select(patchSlot)
    turtle.placeDown()
  end
end

function WriteMineLog()
  f = fs.open(logFile, "w")
  f.write(textutils.serialize(blockData))
  f.close()
end

function RefreshScreen(curDepth)
  term.clear()
  term.setCursorPos(1, 1)
  term.write("depth: "..curDepth)
  term.setCursorPos(1, 2)
  name = blockDB.GetHumanName(blockData[curDepth].center) or blockData[curDepth].center
  term.write("center: "..name)
  term.setCursorPos(1, 3)
  name = blockDB.GetHumanName(blockData[curDepth].front) or blockData[curDepth].front
  term.write("front: "..name)
  term.setCursorPos(1, 4)
  name = blockDB.GetHumanName(blockData[curDepth].right) or blockData[curDepth].right
  term.write("right: "..name)
  term.setCursorPos(1, 5)
  name = blockDB.GetHumanName(blockData[curDepth].back) or blockData[curDepth].back
  term.write("back: "..name)
  term.setCursorPos(1, 6)
  name = blockDB.GetHumanName(blockData[curDepth].left) or blockData[curDepth].left
  term.write("left: "..name)
  term.setCursorPos(1, 10)
  term.write("Press 0 to reload blockDB")
  term.setCursorPos(1, 11)
  term.write("Press backspace to exit...")

end

--Dig down, go down, then turn around and grab important stuff plus map it
function LayerCycle()
  blockData[depth+1] = {}
  if turtle.detectDown() then
    _v, tab = turtle.inspectDown()
    blockData[depth+1].center = tab.name..":"..tab.metadata
    
    if not turtle.digDown() then 
      return false -- time to go up
    end
  end
  if not blockData[depth+1].center then blockData[depth+1].center = "minecraft:air" end
  
  if not turtle.down() then
    return false --time to go up
  end
  depth = depth + 1
  --we now have gone down one
  
  --do a full turn around
  --front first, then right
  sides = {"front", "right", "back", "left"}
  
  for i=1,4 do 
    _v, tab = turtle.inspect()
    if _v then
      blockData[depth][sides[i]] = tab.name..":"..tab.metadata
    else
      blockData[depth][sides[i]] = "minecraft:air"
    end
    if not ElementInTable(ignoreList, blockData[depth][sides[i]]) then
      turtle.dig()
    end
    turtle.turnRight()
  end
  
  if limitDepth > 0 and depth >= limitDepth then
    return false
  end
  
  return true
end


-- Returns whether the provided element is located in the table
function ElementInTable(tab, element)
  for _, value in pairs(tab) do
    if value == element then
      return true
    end
  end
  return false
end


-- Execution --
Main()