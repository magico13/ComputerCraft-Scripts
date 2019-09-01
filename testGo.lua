
-- a test script
os.loadAPI("lps")

waypoints = {}
table.insert(waypoints, vector.new(-252, 89, 96)) -- top of tower, 1
table.insert(waypoints, vector.new(-273, 78, 100)) --top of west house, 2
table.insert(waypoints, vector.new(-252, 81, 89)) -- top of small tower, 3
table.insert(waypoints, vector.new(-262, 80, 73)) -- top of rubber tree, 4
table.insert(waypoints, vector.new(-260, 80, 90)) -- space, 5
table.insert(waypoints, vector.new(-258, 66, 92)) -- ground, 6
table.insert(waypoints, vector.new(-258, 67, 101)) -- ground2, 7

if (lps.locateVec() - waypoints[6]):length() == 0 then
  tgt = waypoints[7]
else
  tgt = waypoints[6]
end

print(lps.locateVec():tostring())
print(lps.facing())

--success = lps.goWaypointsClosest(tgt, waypoints)
success = lps.goVec(tgt)
if success then
  print("success")
else
  print("failure")
end