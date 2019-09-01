os.loadAPI("redmsg")

target = 2
subj = "test"
text = "this is a test"

redmsg.Initialize("messages.txt")
print(redmsg.CreateAndSend(target, subj, text))


redmsg.Finalize()
