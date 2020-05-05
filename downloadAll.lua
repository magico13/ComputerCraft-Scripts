--downloads all the basic files
fileListCommon = {
  "redmsg",
  --"testRec.lua",
  --"blockDB",
  --"sendMsg",
}

fileListTurtle = {
  --"deepCore.lua",
  "mineWorker.lua",
  "lps",
}

fileListCom = {
  --"testRegister.lua",
  --"testGetMsg.lua",
  --"mailServer.lua",
  "m13",
  "mineControl",
}


function Main()
  print("Getting common programs")
  if not DownloadList(fileListCommon) then return false end
  
  if turtle then
    print("Getting turtle programs")
    if not DownloadList(fileListTurtle) then return false end
  else
    print("Getting computer programs")
    if not DownloadList(fileListCom) then return false end
  end
  
end

function DownloadList(list)
  for k,v in pairs(list) do
    if not DownloadFile(v) then
      print("Error downloading "..v)
      return false
    else
      print("Got "..v)
    end
  end
  return true
end

function DownloadFile(filename)
  address = "https://raw.githubusercontent.com/magico13/ComputerCraft-Scripts/master/"..filename
  success = false
  
  dwn = http.get(address)
  if dwn.getResponseCode() == 200 then
    file = fs.open(filename, "w")
    file.write(dwn.readAll())
    file.close()
    success = true
  end
  dwn.close()
  
  return success
end

Main()