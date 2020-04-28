-- A program that automatically caches messages sent to registered computers using the RedMsg protocol ("redmsg")
-- These computers can then retrieve the messages later if they couldn't initially be delivered
-- Can be configured to only cache messages when they haven't been confirmed received, or always

local storageDir = "/mailData/" -- storage directory
local registeredComs = {} -- list of registered computers
local comSettings = {} -- dictionary of computer settings (tables)
  -- settings [comID]:
    -- active (Is the computer using our service right now)
    -- deleteReceived (should we not store received messages?)
local messageStore = {} -- dictionary of stored messages

-- The main function
function Main()
  --Load the redmsg API
  os.loadAPI("redmsg")
  
  if redmsg.UpdateAPI() then --reload the API to make sure we're totally up to date
    os.unloadAPI("redmsg")
    os.loadAPI("redmsg")
  end
  
  --Initialize
  modemSide = redmsg.Initialize(nil, true) -- we don't save our own messages

  Load()
  MakeDirs()

  ReceiveLoop()
  
  Save()

  redmsg.Finalize(modemSide)
end

-- The receive loop
-- listens for incoming messages (to store, or for registration/deregistration)
function ReceiveLoop()
  while true do
    sender, msgSrl, protocol = rednet.receive() --listen for messages
    message = redmsg.UnserializeMessage(msgSrl)
    if not redmsg.IsDuplicate(message.mID) then
      resp = redmsg.ProcessReceived(send, msgSrl, nil, nil)
      if not resp then --not for us, we route it, so we should also check if we should save it
        if not redmsg.IsAnyResponse(message) then -- we don't save response messages
          if TryToSave(message) then
            Save() --Added a new message, so save
          end
        else --it isn't for us, but it IS a response, we should check if we should be removing a message
          if TryToRemoveFromResponse(message) then
            Save() --Removed a message, so save
          end
        end
      else -- this message is for us, so we need to process it
        if not redmsg.IsAnyResponse(message) then
          ProcessOurMessage(message)
          Save() --We probably changed things, so save
        end
      end
    end
  end
end

-- Processes messages that we receive directly, then acts on the message (register, change settings, etc)
function ProcessOurMessage(message)
  if message.subject == "REGISTER" then -- The computer wants to register with us
    print(message.sourceID.." is trying to register.")
    if TryRegisterComputer(message.sourceID) then print("Success") else print("Failure") end
  elseif message.subject == "DEREGISTER" then -- The computer wants to deregister
    print(message.sourceID.." is trying to deregister.")
    if TryDeRegisterComputer(message.sourceID) then print("Success") else print("Failure") end
  elseif message.subject == "GET MESSAGES" then --Send the messages, removing from list if set to
    print(message.sourceID.." is asking for their messages.")
    if TryDeliverMessages(message.sourceID) then print("Success") else print("Not all messages sent successfully.") end
  --elseif message.subject == "CHANGE SETTINGS" then
    --TODO: implement changing the settings. The changes must be in the body in setting:value form 
  else
    print("Received message but can't process it. Sender:"..message.sourceID.." Subject: "..message.subject)
  end
end

function TryDeliverMessages(comID)
  if IsActive(comID) then
    msgTable = messageStore[comID]
    toRemove = {}
    failed = false
    for index, msg in ipairs(msgTable) do
      sleep(0.1)
      if redmsg.CreateAndSend(comID, "MAIL MESSAGE", redmsg.SerializeMessage(msg)) then
        if comSettings[comID].deleteReceived then
          table.insert(toRemove, msg.mID)
        end
      else
        failed = true
        break
      end
    end
    for index, msgID in pairs(toRemove) do
      removeIndex = FindIndexByMessageID(message.sourceID, msgID)
      table.remove(messageStore[message.sourceID], removeIndex)
    end
    return not failed
  end
end

-- Checks to see if we should save this message (they're registered with us and their settings allow it)
-- Returns success
function TryToSave(message)
  if IsActive(message.targetID) then -- they haven't paused service
    --table.insert(messageStore[message.targetID].messages, redmsg.SerializeMessage(message)) -- add to their list of messages
    table.insert(messageStore[message.targetID], message) -- add to their list of messages
    print("Saved message "..message.mID)
    return true
  end
  return false
end

-- Tries to remove a message from the store based on a response message
-- Returns success
function TryToRemoveFromResponse(response)
  comID = response.sourceID
  msgID = response.body
  return TryToRemove(comID, msgID, true)
end

-- Tries to remove a message for a given computer by mID (and if it's due to being requested or because of a response)
-- Returns success
function TryToRemove(comID, msgID, bcReceived) -- Try to remove a message, possibly because it was received
  if IsActive(comID) then -- they're registered and active
    if not bcReceived or (bcReceived and comSettings[comID].deleteReceived) then
      index = FindIndexByMessageID(comID, msgID)
      if index then
        print("Removing "..msgID)
        table.remove(messageStore[comID], index)
        return true
      else
        return false
      end
    end
  end
  return false
end

-- Finds the index of a message for a particular computer
function FindIndexByMessageID(comID, msgID)
  tableToCheck = messageStore[comID]
  if not tableToCheck then return nil end
  for index, msg in pairs(tableToCheck) do
    -- key is the index, value is the message
    --if redmsg.UnserializeMessage(msg).mID == msgID then
    if msg.mID == msgID then
      return index
    end
  end
  return nil
end

function FindKeyByValue(tab, search) -- for an array this returns the index
  for key, value in pairs(tab) do
    if value == search then return key end
  end
  return nil
end

-- Checks if the comID is an active user
function IsActive(comID)
  if redmsg.ElementInTable(registeredComs, comID)
  and comSettings[comID].active
  then return true
  else return false
  end
end

-- Make the data directory, if needed
function MakeDirs()
  fs.makeDir(storageDir) --silently does nothing if already exists
end

-- Load the list of registered computers
function LoadRegistered()
  if fs.exists(storageDir.."registeredComs.txt") then
    f = fs.open(storageDir.."registeredComs.txt", "r")
    registeredComs = textutils.unserialize(f.readAll())
    f.close()
    print("Registered:")
    for k,v in pairs(registeredComs) do
      print(v)
    end
  end
end

-- Save the list of registered computers
function SaveRegistered()
  f = fs.open(storageDir.."registeredComs.txt", "w")
  f.write(textutils.serialize(registeredComs))
  f.close()
end

-- Load the comSettings
function LoadSettings()
  if fs.exists(storageDir.."comSettings.txt") then
    f = fs.open(storageDir.."comSettings.txt", "r")
    comSettings = textutils.unserialize(f.readAll())
    f.close()
  end
end

-- Save the comSettings
function SaveSettings()
  f = fs.open(storageDir.."comSettings.txt", "w")
  f.write(textutils.serialize(comSettings))
  f.close()
end

-- Load the messageStore
function LoadMessages()
  if fs.exists(storageDir.."messageStore.txt") then
    f = fs.open(storageDir.."messageStore.txt", "r")
    messageStore = textutils.unserialize(f.readAll())
    f.close()
  end
end

-- Save the messageStore
function SaveMessages()
  f = fs.open(storageDir.."messageStore.txt", "w")
  f.write(textutils.serialize(messageStore))
  f.close()
end

-- Triggers all the individual save operations
function Save()
  SaveRegistered()
  SaveSettings()
  SaveMessages()
end

-- Triggers all the individual load operations
function Load()
  LoadRegistered()
  LoadSettings()
  LoadMessages()
end

-- Registers a computer and initializes settings and such
function TryRegisterComputer(comID)
  if not redmsg.ElementInTable(registeredComs, comID) then
    table.insert(registeredComs, comID)
    comSettings[comID] = { active = true, deleteReceived = true }
    messageStore[comID] = {}
    return true
  end
  return false
end

-- DeRegisters a computer. 
-- WARNING: Removes all settings and data
-- Pausing service will let you stop storing messages without losing any data
function TryDeRegisterComputer(comID)
  if redmsg.ElementInTable(registeredComs, comID) then
    table.remove(registeredComs, FindKeyByValue(registeredComs, comID))
    comSettings[comID] = nil
    messageStore[comID] = nil
    return true
  end
  return false
end






-- Execute --
Main()
-- End Execute --