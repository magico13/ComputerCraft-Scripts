local mailServer = 3

os.loadAPI("redmsg")
local side=redmsg.Initialize("messages.txt")

if not side then return end

print(redmsg.CreateAndSend(mailServer, "REGISTER", ""))

redmsg.Finalize(side)