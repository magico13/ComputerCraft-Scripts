

--dig a basic tunnel
-- assumes its in the middle already
--digs forward, down, and up
--comes back at the end

--settings
local depth = 16


--stuff
local curDepth = 0

function Main()
  while curDepth < depth do
    OneSet()
  end
  print("Done, returning.")
  turtle.up()
  turtle.turnRight()
  turtle.turnRight()
  while curDepth > 0 do
    VerifyCeiling()
    if turtle.forward() then
      curDepth = curDepth - 1
      if CheckIfTorch(curDepth) then AddTorch() end
    end
  end
  --turtle.up()
end

function OneSet()
  turtle.dig()
  if turtle.forward() then
    curDepth = curDepth + 1
    turtle.digDown()
    turtle.digUp()
  end
end

function CheckIfTorch(dep)
  return ((dep + 5) % 8) == 0
end

function VerifyCeiling()
  turtle.placeUp()
end

function AddTorch()
  --if not turtle.detectUp() then
    print("placing torch")
    turtle.turnRight()
    turtle.turnRight()
    turtle.select(16)
    turtle.place()
    turtle.select(1)
    turtle.turnRight()
    turtle.turnRight()
  --end
end


Main()