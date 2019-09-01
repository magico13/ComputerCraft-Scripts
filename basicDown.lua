local filename = "downloadAll.lua"
local address = "http://magico13.net/files/minecraft/CC/"..filename

local dwn = http.get(address)
local file = fs.open(filename, "w")
file.write(dwn.readAll())

dwn.close()
file.close()