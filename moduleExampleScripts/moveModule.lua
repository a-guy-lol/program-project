local mv = loadstring(game:HttpGet("https://raw.githubusercontent.com/a-guy-lol/program-project/refs/heads/main/modules/moveVelocityModule.lua"))()

mv:SetConfig({
	minSpeed = 20,
	maxSpeed = 50,
	brakeStart = 50,
	arrivalDist = 0.9,
	smoothRate = 14,
})

-- mv:Enable() creates BodyVelocity + noclip and freezes you in place until Goto is called
mv:Enable()

-- mv:Goto(pos) moves you toward a position; you can call it again to retarget mid-move
mv:Goto(Vector3.new(100, 20, -50))
-- mv:StopGoto() stops the current movement but keeps BodyVelocity active (still frozen)
mv:StopGoto()
-- After being stopped it instantly changes pathes and goes to new position
mv:Goto(Vector3.new(130, 30, -80))


task.wait(0.7)


-- mv:Disable() removes BodyVelocity + noclip and restores normal humanoid movement
task.wait(0.7)
mv:Disable() -- Disable when you dont want to use goto anymore.
