local mailServer = 3

os.loadAPI("redmsg")
local side=redmsg.Initialize("messages.txt", true)

if not side then return end

if redmsg.CreateAndSend(mailServer, "GET MESSAGES", "") then
  print("Connected to mail server.")
else
  print("Cannot reach mail server.")
  return
end

while true do

msg = redmsg.ReceiveMessage(1, nil, nil)
if not msg then break end
redmsg.Print(redmsg.UnserializeMessage(msg.body))

end

redmsg.Finalize(side)