local routerID = -1
local mSide = ""
local startup = ""
local version = "1.1.2"
local unreadMsg = 0

-- Menu Functions --
-- These functions drive the visual GUI menus the user sees and interacts with. Some of them perform genuine work, but most simply are used to get input to pass off to another function, or to display the output gathered from other functions
function menu()
  rednet.open(mSide)
  resetConsole()
  printCenter("-- MENU --", 2)
  local cpuID = "Your ID: "..os.computerID()
  cPos(51-string.len(cpuID), 2)
  write(cpuID)
  local n=0
  cPos(2,2) write("        ") cPos(2,2)
  write(textutils.formatTime( os.time(), false))
  local timer = os.startTimer(5)
  while true do
    if unreadMsg ~= 0 then writeAt(unreadMsg.." msgs", 3, 18) end
    xCent=20
    yCent=8
    if n==0 then 
      printCenter("> Send Message <", yCent)
      printCenter("View Inbox", yCent+1)
      printCenter("Check for Messages", yCent+2)
      printCenter("Address Book", yCent+3)
      printCenter("Settings Menu", yCent+4)
      printCenter("End Program", yCent+5)
    elseif n==1 then
      printCenter("Send Message", yCent)
      printCenter("> View Inbox <", yCent+1)
      printCenter("Check for Messages", yCent+2)
      printCenter("Address Book", yCent+3)
      printCenter("Settings Menu", yCent+4)
      printCenter("End Program", yCent+5)
    elseif n==2 then
      printCenter("Send Message", yCent)
      printCenter("View Inbox", yCent+1)
      printCenter("> Check for Messages <", yCent+2)
      printCenter("Address Book", yCent+3)
      printCenter("Settings Menu", yCent+4)
      printCenter("End Program", yCent+5)
    elseif n==3 then
      printCenter("Send Message", yCent)
      printCenter("View Inbox", yCent+1)
      printCenter("Check for Messages", yCent+2)
      printCenter("> Address Book <", yCent+3)
      printCenter("Settings Menu", yCent+4)
      printCenter("End Program", yCent+5)
    elseif n==4 then
      printCenter("Send Message", yCent)
      printCenter("View Inbox", yCent+1)
      printCenter("Check for Messages", yCent+2)
      printCenter("Address Book", yCent+3)
      printCenter("> Settings Menu <", yCent+4)
      printCenter("End Program", yCent+5)
    elseif n==5 then
      printCenter("Send Message", yCent)
      printCenter("View Inbox", yCent+1)
      printCenter("Check for Messages", yCent+2)
      printCenter("Address Book", yCent+3)
      printCenter("Settings Menu", yCent+4)
      printCenter("> End Program <", yCent+5)
    end
    makeBorder()

    --a, b, text=os.pullEvent()
    a = ""
    while (a~="key") and (a~="rednet_message") and (a~="timer") do 
      a, b, text=os.pullEvent() 
    end
      --If the user presses a key
      if (a == "key") then
        if b==200 then n=(n-1)%6 end --up arrow
        if b==208 then n=(n+1)%6 end --down arrow
        if b==28 then break end  --enter
        --timer = os.startTimer(5)
      --If a message is received while the user is viewing the menu
      elseif (a == "rednet_message") then
	receiveImmediateMessage(a, b, text)
        timer = os.startTimer(5)
      elseif (a == "timer") then
        if b == timer then
          cPos(2,2) write("        ") cPos(2,2)
          write(textutils.formatTime( os.time(), false))
          timer = os.startTimer(5)
        end
      end
  end
    if n==0 then writeMessage(-1) end
    if n==1 then viewMessages() end
    if n==2 then receive() end
    if n==3 then addressBook() end
    if n==4 then settings() end
    if n==5 then exit() return true end
  return false
end

function writeMessage(dest)
  resetConsole()
  printCenter("-- Message Writer --", 2)
  makeBorder()
  cPos(2, 4)
  if dest == -1 then
    write("Destination: ")
    dest = read()
    if dest == "" then 
      cPos(2,5)
      write("You must enter a destination!")
      sleep(1)
      return
    end
    local a, name = compareAddress(dest)
    if (a == "number") and not name then popup("UNKNOWN ADDRESS!", true) sleep(1.5) return end
  else
    local a, name = compareAddress(dest)
    if (a == "string") and name then write("Reply to "..name) 
    else write("Reply to "..dest) end
    sleep(.1)
  end
  cPos(2,5)
  write("Message:")
  cPos(2,6)
  local event, char = 0
  local msg = ""
  while char ~= 28 do
    event, char = os.pullEvent()
    if event == "char" then 
      msg = msg..char
      write(char)
    elseif event == "key" then
      if char == 14 then
        msg = string.sub(msg, 1, string.len(msg)-1)
        local x,y = term.getCursorPos()
        if x==2 then
          x=50
          if y>6 then y=y-1 else y=6 x=2 end
        else
          x=x-1
        end
        cPos(x,y)
        write(" ")

	x,y = term.getCursorPos()
        if x==2 then
          x=50
          if y>6 then y=y-1 else y=6 x=2 end
        else
          x=x-1
        end
        cPos(x,y)
      end
    end
    local x,y = term.getCursorPos()
    if x>50 then cPos(2, y+1) end
  end
  resetConsole()
  printCenter("-- Message Review --", 2)
  cPos(2, 4)
  local a, name = compareAddress(dest)
  if (a == "string") and name then write("To "..name..":")
  elseif (a == "number") and name then write("To "..dest..":") dest = name
  elseif (a == "number") and not name then popup("UNKNOWN ADDRESS!") sleep(1.5) return --Fix for sending to an invalid name
  else write("To "..dest..":") end
  cPos(2, 5)
  write(msg)
  --makeBorder()
  cPos(2, 16)

  write("Is this ok to be sent? Y/n? ")
  
  local input = string.upper(read())
  if input == "N" then
    cPos(1,16)
    term.clearLine()
    printCenter("Message discarded!", 16)
    makeBorder()
    sleep(1)
    return false
  else
    send(dest, msg)
    return true
  end
end

function viewMessages()
  rednet.open(mSide)
  local path = "/RedSage/messages/"
  if not fs.isDir(path) then fs.makeDir(path) end
  local i=1
  while true do
    unreadMsg = 0
    local MessageList = fs.list(path)
    resetConsole()
    local numMsgs = table.getn(MessageList)
    if numMsgs == 0 then
      printCenter("No Messages!", 9)
      cPos(52,1)
      read()
      return
    end
    h = fs.open(path..MessageList[i], "r")
    local contents = h.readAll()
    local sBegin, sEnd = string.find(MessageList[i], "##")
    local sender = string.sub(MessageList[i], 1, sBegin-1)
    local a, senderPlain = compareAddress(sender)
    if (a == "string") and senderPlain then 
      printCenter("From "..senderPlain..":", 2)
    else
      printCenter("From ID "..sender..":", 2)
    end
    printCenter("-- Inbox --", 1)
    
    local counter = i.."/"..numMsgs
    cPos(52-string.len(counter), 1)
    write(counter)
    cPos(1, 4)
    print(contents)
    h.close()
    a, b, text=os.pullEvent()
    while (a~="key") and (a~="rednet_message") do a, b, text=os.pullEvent() end
    --When the user presses a key
    if (a=="key") then
      if b==203 then --if left arrow is pressed
        if i>1 then i=(i-1) else i=1 end 
      end
      if b==205 then --if right arrow is pressed
        if i<numMsgs then 
          i=(i+1) 
        else 
          i=numMsgs
        end 
      end
      if b==19 then writeMessage(sender) end --"r" key
      --if b==200 then term.scroll(-10) end --up arrow, not working
      --if b==208 then term.scroll(10) end --down arrow, not working
      if b==28 then break end --if enter is pressed
      if b==211 then --if delete is pressed
        resetConsole()
        printCenter("Really delete? (y/N) ", 9)
        local input = string.upper(read())
        if input == "Y" then
          fs.delete(path..MessageList[i])
          printCenter("MESSAGE DELETED", 9)
          if i>1 then i=i-1 end
        else
          printCenter("Message not deleted", 9)
        end
        sleep(1)   
      end
    --If a message is received while the user is viewing messages
    elseif (a == "rednet_message") then
	receiveImmediateMessage(a, b, text)
    end
  end
  return
end

function settings()
  local settingPath = "/RedSage/settings.txt"
  resetConsole()
  printCenter("-- Settings --", 2)
  local n=0
  while true do
    if n==0 then
      printCenter("> Router ID: "..routerID.." <", 9)
      printCenter("Start with Computer: "..tostring(startup), 10)
      printCenter("Exit ", 11)
    elseif n==1 then
      printCenter("Router ID: "..routerID, 9)
      printCenter("> Start with Computer: "..tostring(startup).." <", 10)
      printCenter("Exit ", 11)
    elseif n==2 then
      printCenter("Router ID: "..routerID, 9)
      printCenter("Start with Computer: "..tostring(startup), 10)
      printCenter("> Exit <", 11)
    end

    makeBorder() 
    a, b, text=os.pullEvent()
    while (a~="key") and (a~="rednet_message") do a, b, text=os.pullEvent() end
      if (a == "key") then
        if b==200 then n=(n-1)%3 end
        if b==208 then n=(n+1)%3 end
        if b==28 then break end
      elseif (a == "rednet_message") then
	receiveImmediateMessage(a, b, text)
        printCenter(" ", 8)
        printCenter(" ", 12)
      end
    end
    if n==0 then 
     cPos(3, 16)
      write("Enter new router ID: ")
      local oldRouter = routerID
      local input = read()
      local empty=false      
      if input == "" then empty=true end
      if not empty then routerID = tonumber(input) end

      if empty then
        rednet.open(mSide)
        resetConsole()
        if oldRouter>=0 then
          rednet.send(oldRouter, "%^&DEREGISTER")
          local _, rgstrMsg, _ = rednet.receive(.5)
          if rgstrMsg=="#R34DEREGISTERED" then printCenter("Successfully deregistered from "..oldRouter, 8)
          else printCenter("Couldn't deregister from "..oldRouter, 8)
          end
        else printCenter("Old router ID was: "..oldRouter, 8)
        end
        if automaticRegistration() then printCenter("Successfully registered with "..routerID, 9) end

        h = fs.open(settingPath, "w")
        h.writeLine(tostring(routerID))
        h.writeLine(tostring(startup))
        h.close()
	sleep(1)
        return
      end

      if oldRouter ~= routerID then
        rednet.open(mSide)
        resetConsole()
        if oldRouter>=0 then
          rednet.send(oldRouter, "%^&DEREGISTER")
          local _, rgstrMsg, _ = rednet.receive(.5)
          if rgstrMsg=="#R34DEREGISTERED" then printCenter("Successfully deregistered from "..oldRouter, 8)
          else printCenter("Couldn't deregister from "..oldRouter, 8)
          end
        else printCenter("Old router ID was: "..oldRouter, 8)
        end
        if routerID>=0 then
          rednet.send(routerID, "%^&REGISTER")
          _, rgstrMsg, _ = rednet.receive(.5)
          if rgstrMsg=="#R34REGISTERED" then printCenter("Successfully registered with "..routerID, 9)
          else printCenter("Couldn't register with "..routerID, 9)
          end
        else printCenter("New router ID is: "..routerID, 9)
        end
        sleep(2)
      end
      h = fs.open(settingPath, "w")
      h.writeLine(tostring(routerID))
      h.writeLine(tostring(startup))
      h.close()
      
      settings()
    end
    if n==1 then 
     cPos(3, 16)
      write("Start RedSage with computer? (y/N): ")
      local input = string.lower(read())
      if input == "y" or input == "yes" or input == "true" then toggleStartup(true)
      else if startup == "true" then toggleStartup(false) end
      end
      h = fs.open(settingPath, "w")
      h.writeLine(tostring(routerID))
      h.writeLine(tostring(startup))
      h.close()
      settings()
    end
    if n==2 then return end
end

function addressBook()
  resetConsole()
  printCenter("-- Address Book --", 2)
  local n=0
  while true do
    if n==0 then
      printCenter("> View Address Book <", 9)
      printCenter("Add Contact", 10)
      printCenter("Remove Contact", 11)
      printCenter("Exit", 12)
    elseif n==1 then
      printCenter("View Address Book", 9)
      printCenter("> Add Contact <", 10)
      printCenter("Remove Contact", 11)
      printCenter("Exit", 12)
    elseif n==2 then
      printCenter("View Address Book", 9)
      printCenter("Add Contact", 10)
      printCenter("> Remove Contact <", 11)
      printCenter("Exit", 12)
    elseif n==3 then
      printCenter("View Address Book", 9)
      printCenter("Add Contact", 10)
      printCenter("Remove Contact", 11)
      printCenter("> Exit <", 12)
    end
    makeBorder()
    event, b, text=os.pullEvent()
    while (event~="key") and (event~="rednet_message") do event, b, text=os.pullEvent() end
      --If the user presses a key
      if (event == "key") then
        if b==200 then n=(n-1)%4 end --up arrow
        if b==208 then n=(n+1)%4 end --down arrow
        if b==28 then break end  --enter
      --If a message is received while the user is viewing the menu
      elseif (event == "rednet_message") then
	receiveImmediateMessage(event, b, text)
      end
  end
    if n==0 then viewAddressBook() end
    if n==1 then addContact() end
    if n==2 then removeContact() end
    if n==3 then return end
  addressBook()
end

function addContact()
  cPos(3,15)
  write("New Contact computer ID number: ")
  local newID = read()
  cPos(3,16)
  write("New Contact name: ")
  local name = read()
  if (tonumber(newID)) and (tonumber(newID) > -1) and (name ~= "") then 
    addToAddressBook(newID, name) 
    popup("Contact Added!", true) 
  else 
    popup("ERROR! Invalid entry!", true) 
  end
  sleep(1)
  return
end

function removeContact()
  cPos(3,16)
  write("Computer ID or Name to remove: ")
  local id = read()
  if id ~= "" then 
    local removed = removeFromAddressBook(id)
    --resetConsole()
    if removed then popup("Contact Removed!", true) else popup("Contact Not Found!", true) end
    sleep(1)
  end
end

function viewAddressBook()
  local path = "/RedSage/AddressBook.txt"
  resetConsole()
  printCenter("-- Address Book --", 2)
  if not fs.exists(path) then printCenter("Address Book is empty!", 9) makeBorder() read() return end
  local h = fs.open(path, "r")
  cPos(17, 4)
  write("ID #")
  cPos(27, 4)
  write("Name")
  --printCenter("ID #        Name", 3)
  for i=5, 16 do
    local txt = h.readLine()
    if txt ~= nil then
      local a, b = string.find(txt, ":")
      local num = string.sub(txt, 2, a-1)
      local name = string.sub(txt, b+1, string.len(txt)-2)
      cPos(18, i)
      write(num)
      cPos(25, i)
      write(name)
     -- printCenter(num.."   "..name, i) 
    end
  end
  h.close()
  makeBorder()
  cPos(52, 25)
  read()
end
-- End Menu Functions --
--------------------------------------------------------------------------

-- Utility Functions --
-- These functions generally operate behind the scenes and do most of the real work of the program, while the other functions tend to be more about running the menus and getting user input
function cPos(x, y)
  term.setCursorPos(x, y)
end

function xCenter(str)
  local x,y = term.getSize()
  return ((x-string.len(str))/2)+1
end

function printCenter(str, y)
  cPos(xCenter(str), y)
  term.clearLine()
  write(str)
end

function writeAt(str, x, y)
  cPos(x, y)
  write(str)
end

function exit()
  rednet.close(mSide)
  resetConsole()
  printCenter("Exiting...",9)
  sleep(.5)
  term.clear()
  cPos(1,1)
end

function toggleStartup(newState)
  if newState then
    h = fs.open("startup", "w")
    if fs.exists("/redsage") then
      h.writeLine("shell.run(\"redsage\")")
    else
      h.writeLine("shell.run(\"/rom/programs/redsage\")")
    end
    h.close()
    startup = "true"
  else
    fs.delete("startup")
    startup = "false"
  end
end

function getSettings()
  local settingPath = "/RedSage/settings.txt"
  if fs.exists(settingPath) then
    h = fs.open(settingPath, "r")
    routerID = tonumber(h.readLine())
    startup = h.readLine()
    h.close()
  else
    rednet.open(mSide)
    resetConsole()
    printCenter("-- First Run --", 2)
    makeBorder()
    cPos(2, 4)
    write("Start RedSage with computer? (y/N): ")
    input = string.lower(read())
    if input == "y" or input == "yes" or input == "true" then toggleStartup(true)
    else startup="false" end

    -- Automatic registration with closest router --
    if automaticRegistration() then write("Registered with router "..routerID) end

    if not fs.isDir("/RedSage") then fs.makeDir("/RedSage") end
    h = fs.open(settingPath, "w")
    h.writeLine(tostring(routerID))
    h.writeLine(startup)
    h.close()
    h = fs.open("/RedSage/AddressBook.txt", "w")
    h.close()
  end
end

function automaticRegistration()
  local reply = ""
  local replyID = -1
  local dist = 99999
  local minDist =  99999
  local IDtoKeep = -1
  rednet.broadcast("%^&wtbREGISTRATION")
  while replyID do
    replyID, reply, dist = rednet.receive(.5)
    if reply == "%^&wtsREGISTRATION" then
      if dist<minDist then IDtoKeep=replyID minDist=dist end
    end
  end
  routerID=IDtoKeep
  if routerID == -1 then 
    cPos(2,6) 
    write("No router in area! Enter an ID manually in") 
    cPos(2,7) 
    write("settings, or build a router setup!")
  else
    rednet.send(routerID, "%^&REGISTER")
    local id, msg, _ = rednet.receive(.3)
    cPos(2, 5)
    if msg == "#R34REGISTERED" then return true end
  end
  sleep(1)
  return false
end

-- visual utility 
function resetConsole()
  term.clear()
  printCenter("RedSage version "..version, 18)
  cPos(1,1)
  return
end

function makeBorder()
  for i=1, 20 do
    cPos(1, i)
    term.write("|")
    cPos(51, i)
    term.write("|")
  end
  cPos(1, 1)
  term.write("*-------------------------------------------------*")
  cPos(1, 3)
  term.write("*-------------------------------------------------*")
  cPos(1, 17)
  term.write("*-------------------------------------------------*")
  cPos(1, 19)
  term.write("*-------------------------------------------------*")
end

function popup(text)
  local length = string.len(text)
  local horzEdge = "*"
  local empty = "|"
  for i=1, length+2 do
    horzEdge = horzEdge.."-"
    empty = empty.." "
  end
  content = "| "..text.." |"
  horzEdge = horzEdge.."*"
  empty = empty.."|"
  writeAt(horzEdge, xCenter(horzEdge), 8)
  writeAt(empty, xCenter(empty), 9)
  writeAt(content, xCenter(content),  10)
  writeAt(empty, xCenter(empty), 11)
  writeAt(horzEdge, xCenter(horzEdge), 12)
  return
end

-- message related utility
function send(destID, msgTxt)
  rednet.open(mSide)
  if routerID ~= -1 then
    local msg = destID.."##"..msgTxt.."&&"..os.computerID()
    rednet.send(routerID, msg)
    local rID, rMsg, rDist = rednet.receive(1)
    if (rID == routerID) then
      if rMsg == "#R01" then
        popup("Message sent!")
      else
        popup("Unknown error!")
      end
    else
      popup("Error! Did not receive reply from router!")
      --printCenter("Contact system administrator!", 10)
    end
  else
    local msg = msgTxt.."&&"..os.computerID()
    popup("Message sent directly to other computer!")
    rednet.send(tonumber(destID), msg)
    local id, msg, _ = rednet.receive(.5)
    if ((id == destID) and (msg == "#R55")) then 
      popup("Message successfully delivered!")
    else 
      popup("Delivery cannot be ensured!")
    end
  end
  sleep(2)
  return
end

function receive()
  if (routerID < 0) then
    resetConsole()
    printCenter("This function is only available", 8)
    printCenter("when connected to a router!", 9)
    printCenter("Returning to Main Menu...", 11)
    sleep(2)
    return
  end
  popup("Checking for messages...")
  rednet.open(mSide)
  rednet.send(routerID, "%^&MCHECK")
  local msg = ""
  local id = -1
  local numMsg = 0
  while msg do
    id, msg, _ = rednet.receive(.5)
    if (id == routerID) then
      local sender, finalMsg = processMessage(msg)
      saveMessage(sender, finalMsg)
      rednet.send(routerID, "#R55")
      numMsg = numMsg+1
    end
  end
  for i=8, 12 do cPos(2, i) term.clearLine() end
  makeBorder()
  if numMsg == 0 then
    popup("No new messages.", true)
  elseif numMsg == 1 then
    popup("1 new message!", true)
  else
    popup(numMsg.." new messages!", true)
  end
  unreadMsg = numMsg
  sleep(2)
end

function receiveImmediateMessage(event, id, msgTxt)
  if (id == routerID) or (msgTxt ~= "PING") then
    if string.find(msgTxt, "##") then
      return
    end
    local sender, finalMsg = processMessage(msgTxt)
    if sender == nil then
      return
    end
    saveMessage(sender, finalMsg)
    rednet.send(id, "#R55")
    local a, name = compareAddress(sender)
    if (a == "string") and name then
    	popup("Message received from "..name.."!")
    else
        popup("Message received from ID "..sender.."!")
    end
    sleep(1)
    unreadMsg = unreadMsg + 1
    --popup(unreadMsg.." unread messages!")
  end
end

function processMessage(message)
  local bBegin, bEnd = string.find(message, "&&")
  if not bBegin then
    return nil, nil
  end
  local sender = string.sub(message, bEnd+1)
  local finalMsg = string.sub(message, 1, bBegin-1)
  return sender, finalMsg
end

function saveMessage(sender, finalMsg)
  local path = "/RedSage/messages/"
  if not fs.isDir(path) then fs.makeDir(path) end
  h = fs.open(path..sender.."##"..string.sub(finalMsg, 1, 15), "w")
  h.write(finalMsg)
  h.close()
end

-- Addressbook utilities
function addToAddressBook(id, name)
  local path = "/RedSage/AddressBook.txt"
  if not fs.exists(path) then
    local h = fs.open(path, "w")
    h.close()
  end
  local h = fs.open(path, "a")
  h.writeLine("#"..id..":"..name.."#*")
  h.close()
end

function removeFromAddressBook(toRemove)
  local path = "/RedSage/AddressBook.txt"
  local tmp  = "/RedSage/tmp"
  local tR = tonumber(toRemove)
  local found = false
  if tR == nil then 
    tR = ":"..toRemove.."#*"
  else 
    tR = "#"..toRemove..":"
  end
  local curLine = 0
  local h1 = fs.open(path, "r")
  local h2 = fs.open(tmp, "w")
  local txt = ""
  while true do
    curLine=curLine+1
    txt = h1.readLine()
    if txt == nil then break end
    if not string.find(txt, tR) then h2.writeLine(txt) else found = true end
  end
  h1.close()
  h2.close()
  fs.delete(path)
  fs.copy(tmp, path)
  fs.delete(tmp)
  return found
end

function compareAddress(toCompare)
  local path = "/RedSage/AddressBook.txt"
  local txt = ""
  local desType = nil
  local value = nil
  local search = nil

  local tC = tonumber(toCompare)
  if tC == nil then 
    tC = ":"..toCompare.."#*" 
    desType = "number"
  else 
    tC = "#"..toCompare..":" 
    desType = "string" 
  end
  if not fs.exists(path) then local h = fs.open(path, "w") h.close() end
  local h = fs.open(path, "r")

  while true do
    txt = h.readLine()
    if txt == nil then break end
    local b, e = string.find(txt, tC)
    if b then 
      if desType == "number" then value = string.sub(txt, 2, b-1) break
      elseif desType == "string" then value = string.sub(txt, e+1, string.len(txt)-2) break
      end
    end
  end
  h.close()
  return desType, value
end
-- End Utility Functions --
----------------------------------------------------------------------------

-- Begin Main --
local sides={"top", "left", "right", "back", "front", "bottom"}
for i=1, 6 do
 if peripheral.getType( sides[i] ) == "modem" then mSide = sides[i] end
end
getSettings()
while true do
  if menu() then break end
end

-- TODO:
-- Messages in order of received
-- Read/unread messages
-- Archiving of messages out of inbox and into different folder
-- Mouse Support!
-- client can view if message is received, if not then save it
-- add contacts from inbox

-- Counter of how many unread messages there are. Sort of done!
-- display time in the corner DONE! For main menu
-- Make popup not use printCenter? DONE! Using new writeAt(str, x, y) function
-- FIX CRASH WHEN SENDING MESSAGE WITH NAME NOT IN ADDRESSBOOK! Prevented!

-- Changelog --
-- v1.1.2 --
-- Removed makeBorder() from message review as it was cutting of letters.
-- Fixed crash in server when sending messages using a name not in the addressbook.
-- Added clock to top left of main menu
-- popup() no longer uses printCenter. Now just writes over existing text.
-- added counter of unread messages. Resets when inbox is opened.
-- v1.1.1 --
-- A few more checks to see if the addressbook exists, and if not then to make it.
-- v1.1 --
-- Added automatic receiving of messages while in menus and inbox 
-- Improved direct message sending (WIP)
-- Made it so you can't check for messages if using an id less than 0
-- Added automatic router registration from setting menu
-- Preliminary Address Book. Only supports about 12 addresses in the viewer. Theoretically unlimited practical addresses though.

