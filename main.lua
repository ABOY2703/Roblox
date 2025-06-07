local plr = game.Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local PlaceId = game.PlaceId
local JobId = game.JobId

-- Function to find a suitable server to hop to
local function pickServer()
	local servers = {}
	local cursor = ""
	repeat
		local success, result = pcall(function()
			return game:HttpGet("https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100&cursor=" .. cursor)
		end)
		if success then
			local data = HttpService:JSONDecode(result)
			for _, srv in ipairs(data.data) do
				if srv.id ~= JobId and srv.playing < srv.maxPlayers then
					table.insert(servers, srv.id)
				end
			end
			cursor = data.nextPageCursor
		else
			warn("Server fetch failed:", result)
			break
		end
	until not cursor or #servers > 0

	return #servers > 0 and servers[math.random(1, #servers)] or nil
end

-- Function to perform the teleport to a new server
local function teleportWithScripts()
	local teleportData = {__shouldLoadScripts = true}
	local srv = pickServer()
	if srv then
		TeleportService:TeleportToPlaceInstance(PlaceId, srv, plr, teleportData)
	else
		warn("Fallback teleport being used")
		task.wait(1)
		TeleportService:Teleport(PlaceId, plr, teleportData)
	end
end

-- Variables (updated for 2-minute hop)
local totalTime = 120 -- 2 minutes (120 seconds)
local fastHop = false -- This flag can still be used for testing if you put it back in the GUI

-- Countdown Handler (will now trigger teleport every 2 minutes)
task.spawn(function()
	while true do -- Changed to an infinite loop so it repeats after each hop
		totalTime = 120 -- Reset timer for the next cycle
		while totalTime > 0 do
			-- The original script had a 'fastHop' check here.
			-- If you're removing the GUI, you might not need this.
			-- If 'fastHop' is to be used for testing, it needs to be defined
			-- and possibly controlled by an external input if no GUI.
			-- if fastHop and totalTime > 60 then
			--    totalTime = 60
			-- end
			-- (Code to update timerTxt or any visual indicator would go here if you have a GUI)
			task.wait(1)
			totalTime -= 1
		end
		teleportWithScripts()
		-- After teleport, the script will re-execute itself in the new server
		-- because of the __shouldLoadScripts flag, so this loop will effectively
		-- restart with the new instance of the script.
		-- A small wait here can prevent immediate re-execution if teleport fails,
		-- but the script's nature is to restart entirely in the new server.
		task.wait(5) -- Give a small buffer time in case of a failed teleport before attempting to re-loop (though script usually restarts)
	end
end)
