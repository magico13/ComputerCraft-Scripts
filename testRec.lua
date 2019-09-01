os.loadAPI("redmsg")
side=redmsg.Initialize("messages.txt", true)

if not side then return end

local msg = redmsg.ReceiveMessage()
if msg then
  for key,value in pairs(msg) do
    if type(value) == "table" then
      for k2, v2 in pairs(value) do
        print (k2, " -- ", v2)
      end
    else
      print(key, " - ", value)
    end
  end
end

redmsg.Finalize(side)