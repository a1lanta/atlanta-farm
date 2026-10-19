bagCount = 0
		stats.coins = 0
        coinStat.Text = "0 / 50"
	end
	task.spawn(function()
		local humanoid = newChar:WaitForChild("Humanoid", 8)
		local newRoot = newChar:WaitForChild("HumanoidRootPart", 8)
		if not humanoid or not newRoot then return end
		modeStat.Text = (newChar.Name:lower():find("zomb") or newChar:GetAttribute("Zombie")) and "Zombie" or "Ready"
		if wasReset and cfg.autoEndGame and cfg.autoFarm then
			task.wait(0.8)
			attemptEndGame()
		end
	end)
end)

-- Some zombie morphs keep the player object but change the model or its name.
task.spawn(function()
	while gui.Parent do
		local c = character()
		if c then
			local zombieTag = c.Name:lower():find("zomb") or c:GetAttribute("Zombie")
			modeStat.Text = zombieTag and "Zombie" or "Ready"
		end
		task.wait(2)
	end
end)

task.spawn(function()
    while gui.Parent do
        local ok, err = pcall(function()
        if cfg.autoFarm and not resetRequested and not runningFling and liveHumanoid() then
			local coins = allCoins()
			-- Coin containers permit mid-round injection and zombie transforms even
			-- when the original RoundStart client event did not fire again.
			local canFarm = #coins > 0 and (roundActive or os.clock() - roundEndedAt > 2)
			if canFarm then
                local coin, dist = nearestCoin(coins)
                local hrp = root()
                if not coin then
                    targetStat.Text = "No safe candy"
                    setStatus("Waiting for a safe target", "warn")
                end
                if coin and hrp then
                    targetStat.Text = "Candy"
                    setStatus("Flying to safe candy", "good")
                    roundStat.Text = "In game"
                    local duration = math.clamp(dist / math.max(cfg.farmSpeed, 1), 0.04, 12)
					local direction = coin.Position - hrp.Position
					local horizontal = Vector3.new(direction.X, 0, direction.Z)
					local goal = (horizontal.Magnitude > 0.01)
						and CFrame.lookAt(coin.Position, coin.Position + horizontal.Unit)
						or CFrame.new(coin.Position)
					local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
						CFrame = goal
					})
					currentTween = tween
					tween:Play()
					local started = os.clock()
					local oldRoot = hrp
					while cfg.autoFarm and not resetRequested and not runningFling
						and root() == oldRoot and coin.Parent and os.clock() - started < duration + 0.5 do
						if not coin:FindFirstChild("TouchInterest") and (oldRoot.Position - coin.Position).Magnitude < 5 then
							break
						end
						if cfg.avoidMurderer then
							local mr = murdererRoot()
							if mr and ((oldRoot.Position - mr.Position).Magnitude < 24
								or (coin.Position - mr.Position).Magnitude < 35) then
                                targetStat.Text = "Avoiding killer"
                                setStatus("Murderer nearby • rerouting", "warn")
                                break -- immediately retarget to a safer coin cluster
							end
						end
						task.wait(0.045)
					end
					if currentTween == tween then
						stopMove()
					end
					if coin.Parent and (coin:FindFirstChild("TouchInterest") or
						(coin.Position - oldRoot.Position).Magnitude > 4) then
						-- A target that did not register a pickup must not stall the entire farm.
						ignoredCoinUntil[coin] = os.clock() + 2.0
					end
				end
            else
                targetStat.Text = "Waiting"
            end
        else
            targetStat.Text = "Idle"
        end
        end)
        if not ok then
            pcall(stopMove)
            warn("[NIGHTSHIFT] Farm recovered from error: " .. tostring(err))
            setStatus("Farm retry after error", "danger")
            task.wait(0.5)
        end
        task.wait(cfg.loopDelay)
    end
end)


task.spawn(function()
    while gui.Parent do
        local secs = math.floor(os.clock() - stats.started)
        timeStat.Text = string.format("%dm %ds", math.floor(secs / 60), secs % 60)
        task.wait(1)
	end
end)

-- Clean up service handlers on re-injection. Never leave orphan heartbeat handlers.
gui.Destroying:Connect(function()
    pcall(stopMove)
    pcall(stopFloating)
    pcall(restoreCollisions)
    local ch = LocalPlayer.Character
    local rp = ch and ch:FindFirstChild("HumanoidRootPart")
    local spin = rp and rp:FindFirstChild("AutoEndGameSpin")
    if spin then pcall(function() spin:Destroy() end) end
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
end)
print("[NIGHTSHIFT] UI + autofarm initialized successfully (v3.0)")

end -- launch
local ok, err = pcall(launch)
if not ok then
    warn("[NIGHTSHIFT] Startup error: " .. tostring(err))
end
