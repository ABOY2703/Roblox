-- Define request for HTTP calls. 'syn' is typical in exploit environments.
local request = syn and syn.request
-- Assert essential functions are available for the script to run correctly.
-- These functions are typically provided by Roblox exploits/executors.
assert(typeof(request) == 'function' and
       typeof(isfile) == 'function' and
       typeof(makefolder) == 'function' and
       typeof(isfolder) == 'function' and
       typeof(readfile) == 'function' and
       typeof(writefile) == 'function',
       "Missing necessary functions (request, isfile, makefolder, isfolder, readfile, writefile). This script requires an exploit/executor environment.")

-- Get core Roblox services and information
local game = game
local Players = game:FindService("Players")
local http = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService") -- Added for UI visibility toggle

-- Get current game instance details. These will be updated when the script runs on a new server.
local PlaceId = game.PlaceId
local PlaceIdString = tostring(PlaceId)

-- Define local storage paths for visited server IDs and custom code.
local folderpath = "ServerHopper"
local PlaceFolder = folderpath .. "\\" .. PlaceIdString
local JobIdStorage = PlaceFolder .. "\\JobIdStorage.json"
local CodeToExecute = PlaceFolder .. "\\Code.lua"

local data -- Will store the JSON data from JobIdStorage.json

-- Helper functions for JSON encoding and decoding using HttpService
local function jsone(str) return http:JSONEncode(str) end
local function jsond(str) return http:JSONDecode(str) end

-- --- UI Setup for Countdown ---
local countdownGui = Instance.new("ScreenGui")
countdownGui.Name = "ServerHopCountdown"
countdownGui.ZIndexBehavior = Enum.ZIndexBehavior.Global

local countdownText = Instance.new("TextLabel")
countdownText.Name = "CountdownText"
countdownText.Size = UDim2.new(0.2, 0, 0.05, 0) -- 20% width, 5% height of screen
countdownText.Position = UDim2.new(0.5, -countdownText.Size.X.Scale * 0.5 * 100, 0.05, 0) -- Top-center, slightly down
countdownText.Text = "Loading..."
countdownText.Font = Enum.Font.SourceSansBold
countdownText.TextSize = 24
countdownText.TextColor3 = Color3.new(1, 1, 1) -- White text
countdownText.TextStrokeColor3 = Color3.new(0, 0, 0) -- Black outline
countdownText.TextStrokeTransparency = 0.5
countdownText.BackgroundTransparency = 0.8
countdownText.BackgroundColor3 = Color3.new(0, 0, 0) -- Dark background
countdownText.CornerRadius = UDim.new(0.25, 0) -- Rounded corners
countdownText.BorderSizePixel = 0
countdownText.TextXAlignment = Enum.TextXAlignment.Center
countdownText.TextYAlignment = Enum.TextYAlignment.Center

countdownText.Parent = countdownGui

-- Function to toggle UI visibility (e.g., press 'H' key)
local ui_visible = true
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if input.KeyCode == Enum.KeyCode.H and not gameProcessedEvent then
        ui_visible = not ui_visible
        countdownGui.Enabled = ui_visible
        print("UI Visibility Toggled: " .. tostring(ui_visible))
    end
end)
-- --- End UI Setup ---

-- Ensure necessary folders exist. Create them if they don't.
if not isfolder(folderpath) then
    makefolder(folderpath)
    print("Created main folder: " .. folderpath)
end

if not isfolder(PlaceFolder) then
    makefolder(PlaceFolder)
    print("Created place-specific folder: " .. PlaceFolder)
end

-- Function to load or initialize the JobId storage file.
local function loadJobIdsData()
    if isfile(JobIdStorage) then
        -- Read and decode existing data
        local success, decoded_data = pcall(jsond, readfile(JobIdStorage))
        if success and typeof(decoded_data) == 'table' and decoded_data.JobIds then
            data = decoded_data
            print("Loaded JobIdStorage from: " .. JobIdStorage)
        else
            -- If file is corrupted or empty, re-initialize
            print("JobIdStorage file is corrupted or invalid. Re-initializing.")
            data = { JobIds = {} }
            writefile(JobIdStorage, jsone(data))
        end
    else
        -- If file doesn't exist, create it with an empty structure
        data = { JobIds = {} }
        writefile(JobIdStorage, jsone(data))
        print("Created new JobIdStorage file: " .. JobIdStorage)
    end
end

-- Load Job ID data at script start
loadJobIdsData()

-- Ensure the Code.lua file exists. If not, create an empty one.
-- The script will still proceed even if Code.lua is empty.
if not isfile(CodeToExecute) then
    writefile(CodeToExecute, "")
    print("Created Code.lua file: " .. CodeToExecute)
    print("Note: Code.lua is empty. Place custom Lua code in this file to execute it upon server entry.")
else
    print("Code.lua found at: " .. CodeToExecute)
end

-- Wait until the game is fully loaded and the local player is available.
repeat task.wait() until game:IsLoaded() and Players.LocalPlayer
local lp = Players.LocalPlayer -- Get the local player instance

-- Parent the GUI to the player's PlayerGui once the LocalPlayer exists
countdownGui.Parent = lp:WaitForChild("PlayerGui")
print("Game loaded and LocalPlayer ready. Starting server hopper loop.")
print("Press 'H' to toggle the countdown display.")

-- Main loop for continuous server hopping
while true do
    -- Get the JobId of the server we are currently on.
    local currentJobId = game.JobId
    PlaceId = game.PlaceId -- Ensure PlaceId is correct for the current game instance

    -- Add the current server's JobId to our visited list if it's new.
    if not table.find(data['JobIds'], currentJobId) then
        table.insert(data['JobIds'], currentJobId)
        writefile(JobIdStorage, jsone(data)) -- Save updated data immediately
        print(string.format("Now in JobId: %s. Added to visited list for PlaceId: %d.", currentJobId, PlaceId))
    else
        print(string.format("Currently in JobId: %s (already in visited list for PlaceId: %d).", currentJobId, PlaceId))
    end

    -- Execute any custom Lua code from Code.lua.
    print("Attempting to execute custom code from Code.lua...")
    local succ, err = pcall(function()
        local code_content = readfile(CodeToExecute)
        if #code_content > 0 then
            loadstring(code_content)() -- Execute the code string
        else
            print("Code.lua is empty. Skipping custom code execution.")
        end
    end)
    if not succ then
        -- Print error to console if Code.lua execution fails
        rconsoleprint("An error occurred during Code.lua execution:\n" .. err)
    else
        print("Custom code execution finished.")
    end

    -- Determine a random delay between 5 and 10 minutes (300 to 600 seconds).
    local delay_seconds = math.random(300, 600)
    print(string.format("Next server hop attempt in approx. %.1f minutes (%.0f seconds)...", delay_seconds / 60, delay_seconds))

    -- --- Countdown Logic ---
    for i = delay_seconds, 1, -1 do
        local minutes = math.floor(i / 60)
        local seconds = i % 60
        countdownText.Text = string.format("Next Hop: %02d:%02d", minutes, seconds)
        task.wait(1) -- Update every second
    end
    countdownText.Text = "Hopping now..."
    task.wait(2) -- Small wait before initiating hop
    -- --- End Countdown Logic ---

    -- Start searching for a new server to hop to.
    print("Searching for available public servers to hop to, prioritizing smaller ones...")
    local potential_servers = {} -- List to store suitable server objects (id and playing count)
    local cursor = ''   -- Cursor for paginated API requests
    local max_pages_to_check = 5 -- Limit the number of pages to check to avoid excessive requests
    local pages_checked = 0

    -- Loop to fetch server pages until suitable servers are found or no more pages.
    while true do
        pages_checked = pages_checked + 1
        if pages_checked > max_pages_to_check then
            print(string.format("Reached maximum pages (%d) to check. Stopping server search.", max_pages_to_check))
            break
        end

        local url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100"):format(PlaceId)
        if cursor ~= '' then
            url = url .. "&cursor=" .. cursor
        end

        local req_success, req_result = pcall(request, {Url = url}) -- Use pcall for request
        if not req_success or not req_result or not req_result.Body then
            print("Failed to fetch server list or empty response body. Retrying...")
            task.wait(1) -- Wait briefly before retrying request
            break -- Or continue if you want to keep trying indefinitely on request failure
        end

        local body_success, body = pcall(jsond, req_result.Body)
        if not body_success or not body or not body.data then
            print("Failed to parse server list JSON or response has no 'data'. Stopping search.")
            break -- No valid data, stop searching
        end
        
        -- Iterate through the data received from the API
        for i, v in next, body.data do
            -- Check if the server is valid, not full, and not already visited.
            if typeof(v) == 'table' and tonumber(v.playing) and tonumber(v.maxPlayers) and v.playing < v.maxPlayers and not table.find(data['JobIds'], v.id) then
                -- Store the server's ID and player count
                table.insert(potential_servers, {id = v.id, playing = v.playing})
            end
        end
        
        cursor = body.nextPageCursor or '' -- Update cursor for the next page, or set to empty if no more pages.

        if cursor == '' then
            print("No more server pages to check.")
            break -- All pages checked, no suitable servers found
        end

        task.wait(0.5) -- Small wait between API requests to avoid hitting rate limits.
    end

    -- Now, sort the potential_servers by the number of players (ascending, smallest first)
    table.sort(potential_servers, function(a, b)
        return a.playing < b.playing
    end)

    -- Attempt to teleport to the smallest suitable server.
    if #potential_servers > 0 then
        local smallest_server = potential_servers[1] -- The first one after sorting is the smallest
        local target_server_id = smallest_server.id
        print(string.format("Teleporting to the smallest available server (Players: %d): %s...", smallest_server.playing, target_server_id))
        TeleportService:TeleportToPlaceInstance(PlaceId, target_server_id, lp)
        -- Upon successful teleport, the current script instance will terminate,
        -- and a new instance will start on the destination server.
    else
        print("No new suitable (small) servers found for this PlaceId. Will re-attempt search after the next delay.")
        countdownText.Text = "No servers found. Retrying..."
        task.wait(3) -- Give some time for the message to be seen
        -- If no servers are found, the loop will continue, and after the next delay,
        -- it will search again.
    end
end
