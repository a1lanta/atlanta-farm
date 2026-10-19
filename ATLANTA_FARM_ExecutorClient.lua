HALLOWEN MM2 V1.8 • Optimized Candy Farm Edition • @AtlantaRobuxShop
-- Standalone CLIENT UI for testing within a Roblox experience.
-- Works only to the extent permitted by the place / local runtime.
-- Does not claim server-confirmed coin collection, universal End Round or auto-injection after a crash.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer
if not player then warn("HALLOWEN MM2 V1.8 must run on the client") return end
local pg = player:WaitForChild("PlayerGui")
local guiName = "HALLOWEN_MM2_V18"
local current = pg:FindFirstChild(guiName)
if current then
    local panel = current:FindFirstChild("MainWindow")
    if panel then panel.Visible = true end
    return
end
for _, oldName in ipairs({"HALLOWEN_MM2_V18","ATLANTA_FARM_V17","ATLANTA_FARM_V16","ATLANTA_FARM_V15","ATLANTA_FARM_V14","ATLANTA_FARM_V13","ATLANTA_FARM_V12","AtlantaFarmNoServerNotice"}) do
    local old = pg:FindFirstChild(oldName)
    if old then old:Destroy() end
end

local BG = Color3.fromRGB(17,15,24)
local CARD = Color3.fromRGB(29,25,37)
local CARD2 = Color3.fromRGB(43,36,49)
local ORANGE = Color3.fromRGB(242,154,82)
local PURPLE = Color3.fromRGB(165,133,199)
local LIGHT = Color3.fromRGB(242,238,246)
local MUTED = Color3.fromRGB(172,163,183)
local GOOD = Color3.fromRGB(146,220,170)
local WARNING = Color3.fromRGB(245,124,113)

local state = {
    active = false, speed = 10, antiFling = true, antiAfk = true,
    noclip = false, airWalk = true, avoidMurderer = true, autoReset = false, autoRejoin = false,
    visiting = false, visits = 0, candies = 0, coins = 0, failures = 0, resets = 0,
    bag = "?", bagLimit = "?", status = "Готово · Hallowen MM2 готов", role = "Unknown",
    currentTarget = nil, nearestDistance = 0
}
local alive = true
local startedAt = os.clock()
local token = 0
local lastReset = -math.huge
local resetPending = false
local visited = setmetatable({}, {__mode="k"})
local cachedCoins = setmetatable({}, {__mode="k"})
local savedCollision = setmetatable({}, {__mode="k"})
local savedOtherCollision = setmetatable({}, {__mode="k"})
local listeners = {}
local refresh
local updateNoclip
local updateAntiFling
local targetHighlight
local targetBillboard
local lastAntiFlingSweep = 0
local gui

local function bind(signal, fn)
    local c = signal:Connect(fn)
    table.insert(listeners, c)
    return c
end
local function charParts()
    local char = player.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if hum and root and hum.Health > 0 then return char,hum,root end
    return nil
end
local function applySpeed()
    local _,hum = charParts()
    if hum then hum.WalkSpeed = state.speed end
end
local function isCoin(part)
    if not part or not part:IsA("BasePart") then return false end
    if CollectionService:HasTag(part,"AtlantaCoin") or part:GetAttribute("AtlantaCoin") == true then return true end
    local function coinName(s)
        s = string.lower(s)
        return s == "coin" or s == "candy" or s == "green" or s == "purple" or s == "cyan" or s:find("coin",1,true) ~= nil
            or s:find("candy",1,true) ~= nil or s:find("конфет",1,true) ~= nil
            or s:find("монет",1,true) ~= nil
    end
    if not coinName(part.Name) and not (part.Parent and coinName(part.Parent.Name)) then return false end
    local parent = part.Parent
    while parent and parent ~= Workspace do
        if parent:IsA("Model") and parent:FindFirstChildOfClass("Humanoid") then return false end
        parent = parent.Parent
    end
    return true
end
local function cacheCoin(part)
    if isCoin(part) then cachedCoins[part] = true end
end
for _,obj in ipairs(Workspace:GetDescendants()) do cacheCoin(obj) end
bind(Workspace.DescendantAdded, cacheCoin)
bind(CollectionService:GetInstanceAddedSignal("AtlantaCoin"),cacheCoin)

local function visibleRole(plr)
    local char=plr.Character
    local role=plr:GetAttribute("AtlantaRole") or plr:GetAttribute("CurrentRole") or plr:GetAttribute("Role")
        or (char and (char:GetAttribute("AtlantaRole") or char:GetAttribute("CurrentRole") or char:GetAttribute("Role")))
    if type(role)~="string" then return "" end
    return string.lower(role)
end
local function visibleKnife(plr)
    local char=plr.Character
    if not char then return false end
    for _,obj in ipairs(char:GetChildren()) do
        if obj:IsA("Tool") then
            local name=string.lower(obj.Name)
            if name == "knife" or name == "murderknife" then return true end
        end
    end
    return false
end
local function murderLocations()
    local places={}
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=player and (visibleRole(plr)=="murderer" or visibleRole(plr)=="murder" or visibleKnife(plr)) then
            local ch=plr.Character
            local root=ch and ch:FindFirstChild("HumanoidRootPart")
            local hum=ch and ch:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health>0 then table.insert(places,root.Position) end
        end
    end
    return places
end
local function unsafeTarget(pos, points)
    if not state.avoidMurderer or visibleRole(player)=="murderer" then return false end
    for _,danger in ipairs(points or murderLocations()) do
        if Vector2.new(pos.X-danger.X,pos.Z-danger.Z).Magnitude < 28 then return true end
    end
    return false
end
-- Prioritize the closest candy. Ordinary coins are a fallback when no candy is available.
local function isCandy(part)
    local node=part
    for _=1,4 do
        if not node or node==Workspace then break end
        local name=string.lower(node.Name)
        if name:find("candy",1,true) or name:find("конфет",1,true)
            or name=="green" or name=="purple" or name=="cyan" then
            return true
        end
        node=node.Parent
    end
    return false
end
local function chooseCoin(root)
    local bestCandy, bestCoin=nil,nil
    local candyDist,coinDist=math.huge,math.huge
    local threats=murderLocations()
    local total,eligibleCandies=0,0
    for part in pairs(cachedCoins) do
        if part and part.Parent and part:IsDescendantOf(Workspace) and isCoin(part)
            and os.clock()-(visited[part] or -100)>15 then
            total+=1
            local distance=(part.Position-root.Position).Magnitude
            if distance<450 and not unsafeTarget(part.Position,threats) then
                if isCandy(part) then
                    eligibleCandies+=1
                    if distance<candyDist then bestCandy,candyDist=part,distance end
                elseif distance<coinDist then
                    bestCoin,coinDist=part,distance
                end
            end
        end
    end
    return bestCandy or bestCoin,total,#threats>0, bestCandy~=nil,eligibleCandies
end
local function groundGoal(part,char)
    local ray=RaycastParams.new()
    ray.FilterType=Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances={char,part}
    ray.RespectCanCollide=true
    local target=part.Position
    local hit=Workspace:Raycast(target+Vector3.new(0,4,0), Vector3.new(0,-42,0),ray)
    if hit then return Vector3.new(target.X,hit.Position.Y+2.8,target.Z) end
    return target
end
local function clearLine(char,from,to)
    local ray=RaycastParams.new()
    ray.FilterType=Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances={char}
    ray.RespectCanCollide=true
    return Workspace:Raycast(from,to-from,ray)==nil
end
local function routeTo(char,root,goal)
    local path=PathfindingService:CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=true,WaypointSpacing=4})
    local ok=pcall(function() path:ComputeAsync(root.Position,goal) end)
    if ok and path.Status == Enum.PathStatus.Success then
        local waypoints=path:GetWaypoints()
        if #waypoints>0 then return waypoints end
    end
    -- Direct walking only if the route is unobstructed. Never jump through a wall by CFrame.
    if clearLine(char,root.Position+Vector3.new(0,1,0),goal+Vector3.new(0,1,0)) then
        return {{Position=goal,Action=Enum.PathWaypointAction.Walk}}
    end
    return nil
end
local function waitForStep(part,waypoint,job)
    local char,hum,root=charParts()
    if not char then return false end
    local goal=waypoint.Position
    if waypoint.Action==Enum.PathWaypointAction.Jump then hum.Jump=true end
    local prevDistance=(root.Position-goal).Magnitude
    local lastProgress=os.clock()
    local began=os.clock()
    local lastCommand=-math.huge
    local timeout=math.clamp(prevDistance/math.max(1,state.speed)*3+5,7,120)
    while alive and state.active and job==token do
        char,hum,root=charParts()
        if not char then return false end
        if not part or not part.Parent then return false end
        if unsafeTarget(part.Position) then state.status="У монеты Murderer · ищу другую" return false end
        local distance=(root.Position-goal).Magnitude
        local toCoin=(root.Position-part.Position).Magnitude
        if toCoin<5.2 then return true end
        if distance<2.7 then return true end
        if distance < prevDistance-0.6 then prevDistance=distance;lastProgress=os.clock() end
        if os.clock()-lastProgress>2.8 or os.clock()-began>timeout then
            state.status="Маршрут заблокирован · перестраиваю"
            return false
        end
        if os.clock()-lastCommand>1.2 then
            lastCommand=os.clock()
            hum:MoveTo(goal)
        end
        task.wait(0.09)
    end
    return false
end
-- Constant-speed, straight-line Air Walk: no path replanning, teleport jumps or CFrame tweens.
-- The player's humanoid remains unanchored. Local server corrections can still occur.
local function glideToCoin(part,job)
    state.visiting=true
    state.currentTarget=part
    local arrived=false
    local char,hum,root=charParts()
    if char and part and part.Parent and not unsafeTarget(part.Position) then
        local goal=part.Position+Vector3.new(0,0.7,0)
        local oldAutoRotate=hum.AutoRotate
        hum.AutoRotate=false
        state.status="Air Walk → "..(isCandy(part) and "ближайшая конфета" or "монета")
        while alive and state.active and state.airWalk and job==token do
            char,hum,root=charParts()
            if not char then break end
            if not part or not part.Parent then
                if root and (root.Position-goal).Magnitude<6 then arrived=true end
                break
            end
            goal=part.Position+Vector3.new(0,0.7,0)
            state.nearestDistance=math.floor((goal-root.Position).Magnitude+0.5)
            if unsafeTarget(goal) or unsafeTarget(root.Position) then
                state.status="Murderer рядом · меняю цель"
                break
            end
            local vector=goal-root.Position
            local distance=vector.Magnitude
            if distance<=2.7 then
                arrived=true
                break
            end
            local dt=RunService.Heartbeat:Wait()
            if not alive or job~=token or not state.active then break end
            local length=math.min(distance, math.max(1,state.speed)*math.clamp(dt,0.001,0.05))
            local nextPos=root.Position+vector.Unit*length
            if unsafeTarget(nextPos) then
                state.status="Murderer на маршруте · меняю цель"
                break
            end
            updateNoclip()
            local flat=Vector3.new(vector.X,0,vector.Z)
            if flat.Magnitude>0.05 then
                root.CFrame=CFrame.lookAt(nextPos,nextPos+flat.Unit)
            else
                root.CFrame=CFrame.new(nextPos)*root.CFrame.Rotation
            end
            root.AssemblyLinearVelocity=Vector3.zero
            root.AssemblyAngularVelocity=Vector3.zero
        end
        if hum and hum.Parent then hum.AutoRotate=oldAutoRotate end
    elseif part and part.Parent then
        state.status="Murderer рядом с конфетой · пропускаю"
    end
    state.visiting=false
    state.currentTarget=nil
    state.nearestDistance=0
    updateNoclip()
    if arrived then
        state.visits+=1
        if isCandy(part) then state.candies+=1 else state.coins+=1 end
        visited[part]=os.clock()
        state.status=(isCandy(part) and "Конфета" or "Монета").." посещена · начисление проверяет игра"
        task.wait(0.18)
    else
        state.failures+=1
        if part then visited[part]=os.clock()-8 end
    end
    return arrived
end

local function walkToCoin(part,job)
    state.visiting=true
    state.currentTarget=part
    local arrived=false
    for attempt=1,3 do
        if not alive or not state.active or job~=token or not part or not part.Parent then break end
        local char,hum,root=charParts()
        if not char then break end
        if unsafeTarget(part.Position) then
            state.status="Обхожу Murderer · обычные игроки не мешают"
            break
        end
        local goal=groundGoal(part,char)
        state.nearestDistance=math.floor((goal-root.Position).Magnitude+0.5)
        local route=routeTo(char,root,goal)
        if not route then
            state.status="Нет безопасного пешего маршрута к монете"
            break
        end
        state.status="Бегу к монете · маршрут "..tostring(attempt).."/3"
        local routeOk=true
        for index,waypoint in ipairs(route) do
            if index>1 or #route==1 then
                if not waitForStep(part,waypoint,job) then routeOk=false;break end
            end
            local _,_,newRoot=charParts()
            if newRoot and (newRoot.Position-part.Position).Magnitude<5.2 then break end
        end
        local _,_,newRoot=charParts()
        if newRoot and (newRoot.Position-part.Position).Magnitude<6.8 then
            arrived=true
            break
        end
        if routeOk then break end
        task.wait(0.15)
    end
    state.visiting=false
    state.currentTarget=nil
    state.nearestDistance=0
    if arrived then
        state.visits+=1
        if isCandy(part) then state.candies+=1 else state.coins+=1 end
        visited[part]=os.clock()
        state.status="Цель посещена · начисление проверяет игра"
        task.wait(0.2)
    else
        state.failures+=1
        visited[part]=os.clock()-8
    end
    return arrived
end
local function farmLoop(job)
    while alive and state.active and job==token do
        local _,hum,root=charParts()
        if not root then
            state.status="Ожидаю персонажа"
            task.wait(0.5)
        else
            local coin,n,hasThreat,preferCandy,eligibleCandies=chooseCoin(root)
            if coin then
                if state.airWalk then glideToCoin(coin,job) else walkToCoin(coin,job) end
                task.wait(0.13)
            else
                if n==0 then
                    state.status="Конфеты и монеты не найдены в Workspace"
                elseif eligibleCandies and eligibleCandies>0 then
                    state.status="Жду ближайшую безопасную конфету"
                elseif hasThreat then
                    state.status="Жду цель подальше от Murderer"
                else
                    state.status="Нет доступных целей"
                end
                task.wait(0.9)
            end
        end
    end
    state.visiting=false
    local _,hum=charParts()
    if hum then hum:MoveTo(hum.Parent:FindFirstChild("HumanoidRootPart") and hum.Parent.HumanoidRootPart.Position or hum.Parent:GetPivot().Position) end
end

updateNoclip=function()
    local char=player.Character
    if not char then return end
    -- Air Walk temporarily enables noclip only during movement. Idle players keep floor collision.
    local useNoclip=state.noclip or (state.active and state.airWalk and state.visiting)
    for _,part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if useNoclip then
                if savedCollision[part]==nil then savedCollision[part]=part.CanCollide end
                part.CanCollide=false
                if part.Name~="HumanoidRootPart" then part.LocalTransparencyModifier=0.45 end
            elseif savedCollision[part]~=nil then
                part.CanCollide=savedCollision[part]
                savedCollision[part]=nil
                part.LocalTransparencyModifier=0
            end
        end
    end
end
updateAntiFling=function(force)
    -- Optimized sweep: avoid scanning every character each frame.
    local now=os.clock()
    if force or state.antiFling or next(savedOtherCollision)~=nil then
        if force or now-lastAntiFlingSweep>1.1 then
            lastAntiFlingSweep=now
            for _,other in ipairs(Players:GetPlayers()) do
                if other~=player and other.Character then
                    for _,part in ipairs(other.Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            if state.antiFling then
                                if savedOtherCollision[part]==nil then savedOtherCollision[part]=part.CanCollide end
                                part.CanCollide=false
                            elseif savedOtherCollision[part]~=nil then
                                part.CanCollide=savedOtherCollision[part]
                                savedOtherCollision[part]=nil
                            end
                        end
                    end
                end
            end
        end
    end
    local _,_,root=charParts()
    if state.antiFling and root then
        local v=root.AssemblyLinearVelocity
        local planar=Vector3.new(v.X,0,v.Z)
        if planar.Magnitude>math.max(160,state.speed*3) then
            root.AssemblyLinearVelocity=Vector3.new(0,math.clamp(v.Y,-80,80),0)
        end
        if root.AssemblyAngularVelocity.Magnitude>45 then
            root.AssemblyAngularVelocity=Vector3.zero
        end
    end
end
local function send(action,value)
    if action=="Speed" then
        state.speed=math.clamp(math.floor((tonumber(value) or 10)+0.5),1,100)
        applySpeed()
        state.status=state.speed>16 and "Высокая скорость: возможны сбои и откат сервером" or "Скорость установлена: "..state.speed
    elseif action=="ToggleFarm" then
        state.active=not state.active
        token+=1
        if state.active then
            state.status=state.airWalk and "Air Walk: лечу к ближайшей конфете" or "Ищу пеший маршрут"
            local job=token
            task.spawn(function() farmLoop(job) end)
        else
            state.status="Auto Farm выключен"
        end
    elseif action=="AirWalk" then
        state.airWalk=not not value
        token+=1
        state.status=state.airWalk and "Air Walk ON · плавный полёт к ближайшей цели" or "Air Walk OFF · пеший маршрут"
        if state.active then
            local job=token
            task.spawn(function() farmLoop(job) end)
        end
    elseif action=="AntiFling" then
        state.antiFling=not not value
        updateAntiFling(true)
        state.status=state.antiFling and "Anti-Fling ON · локальная защита" or "Anti-Fling OFF"
    elseif action=="AntiAfk" then
        state.antiAfk=not not value
        state.status=state.antiAfk and "Anti-AFK ON · попытка активности при Idled" or "Anti-AFK OFF"
    elseif action=="Noclip" then
        state.noclip=not not value
        updateNoclip()
        state.status=state.noclip and "Noclip ON · ручной режим" or "Noclip OFF · Air Walk включает его только во время движения"
    elseif action=="AvoidMurderer" then
        state.avoidMurderer=not not value
        state.status="Avoid Murderer "..(state.avoidMurderer and "ON" or "OFF")
    elseif action=="AutoReset" then
        state.autoReset=not not value
        state.status=state.autoReset and "Auto Reset ON · нужны атрибуты мешка" or "Auto Reset OFF"
    elseif action=="AutoRejoin" then
        state.autoRejoin=not not value
        state.status=state.autoRejoin and "Rejoin ON · только когда клиент ещё работает" or "Rejoin OFF"
        if state.autoRejoin then
            local q=queue_on_teleport
            if type(q)~="function" and type(syn)=="table" then q=syn.queue_on_teleport end
            if type(q)=="function" then pcall(q,'loadstring(game:HttpGet("https://raw.githubusercontent.com/a1lanta/atlanta-farm/main/ATLANTA_FARM_ExecutorClient.lua"))()') end
        end
    elseif action=="EndRound" then
        state.status="End Round недоступен без API сервера этой игры"
    end
    if refresh then refresh() end
end

local function ui(kind, props, parent)
    local obj=Instance.new(kind)
    for key,value in pairs(props or {}) do obj[key]=value end
    if parent then obj.Parent=parent end
    return obj
end
local function round(obj,r)
    ui("UICorner",{CornerRadius=UDim.new(0,r or 10)},obj)
    return obj
end
local function border(obj,color,trans)
    ui("UIStroke",{Color=color or ORANGE,Transparency=trans or 0.75,Thickness=1},obj)
end
local function tween(obj,time,goal)
    local t=TweenService:Create(obj,TweenInfo.new(time,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),goal)
    t:Play()
    return t
end
local function updateTargetESP()
    if not targetHighlight then
        targetHighlight=Instance.new("Highlight")
        targetHighlight.Name="HalloweenMM2TargetESP"
        targetHighlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
        targetHighlight.FillColor=ORANGE
        targetHighlight.OutlineColor=PURPLE
        targetHighlight.FillTransparency=0.2
        targetHighlight.OutlineTransparency=0
        targetHighlight.Enabled=false
        targetHighlight.Parent=Workspace
    end
    if not targetBillboard then
        targetBillboard=Instance.new("BillboardGui")
        targetBillboard.Name="HalloweenMM2TargetLabel"
        targetBillboard.Size=UDim2.fromOffset(150,34)
        targetBillboard.StudsOffset=Vector3.new(0,2.8,0)
        targetBillboard.AlwaysOnTop=true
        targetBillboard.Enabled=false
        targetBillboard.Parent=gui
        local bg=Instance.new("Frame")
        bg.Name="BG"
        bg.Size=UDim2.fromScale(1,1)
        bg.BackgroundColor3=BG
        bg.BackgroundTransparency=0.18
        bg.BorderSizePixel=0
        bg.Parent=targetBillboard
        round(bg,8)
        border(bg,ORANGE,0.15)
        local lbl=Instance.new("TextLabel")
        lbl.Name="Text"
        lbl.BackgroundTransparency=1
        lbl.Size=UDim2.new(1,-8,1,-4)
        lbl.Position=UDim2.fromOffset(4,2)
        lbl.Font=Enum.Font.GothamBold
        lbl.TextColor3=LIGHT
        lbl.TextScaled=true
        lbl.Text="TARGET"
        lbl.Parent=bg
    end
    local target=state.currentTarget
    if target and target.Parent and target:IsA("BasePart") then
        targetHighlight.Adornee=target
        targetHighlight.Enabled=true
        targetBillboard.Adornee=target
        targetBillboard.Enabled=true
        local lbl=targetBillboard.BG.Text
        lbl.Text=(isCandy(target) and "🎃 NEAREST CANDY" or "COIN").." · "..tostring(state.nearestDistance or 0).."m"
    else
        targetHighlight.Enabled=false
        targetHighlight.Adornee=nil
        targetBillboard.Enabled=false
        targetBillboard.Adornee=nil
    end
end
local function text(parent,s,x,y,w,h,size,color,bold)
    return ui("TextLabel",{
        BackgroundTransparency=1,Text=s,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize=size or 12,TextColor3=color or LIGHT,TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd,
        Position=UDim2.new(0,x,0,y),Size=UDim2.new(1,w,0,h),
    },parent)
end
local function button(parent,label,x,y,w,h)
    local b=ui("TextButton",{
        Text=label,BackgroundColor3=CARD2,TextColor3=LIGHT,Font=Enum.Font.GothamBold,
        TextSize=12,Size=UDim2.fromOffset(w,h),Position=UDim2.new(1,x,0,y),
        BorderSizePixel=0,AutoButtonColor=false,
    },parent)
    round(b,9)
    bind(b.MouseEnter,function() tween(b,0.15,{BackgroundColor3=Color3.fromRGB(66,47,64)}) end)
    bind(b.MouseLeave,function() tween(b,0.15,{BackgroundColor3=CARD2}) end)
    return b
end
local function card(parent,h)
    local item=ui("Frame",{BackgroundColor3=CARD,Size=UDim2.new(1,-12,0,h),BorderSizePixel=0},parent)
    round(item,11)
    border(item,PURPLE,0.9)
    return item
end
gui=ui("ScreenGui",{Name=guiName,ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=60},pg)
local opener=ui("TextButton",{
    Name="HalloweenLauncher",Text="🎃",Font=Enum.Font.GothamBlack,TextSize=23,TextColor3=LIGHT,
    BackgroundColor3=Color3.fromRGB(91,55,83),BorderSizePixel=0,
    Size=UDim2.fromOffset(54,54),Position=UDim2.new(0,16,0.48,0),AutoButtonColor=false,
},gui)
round(opener,16)
border(opener,ORANGE,0.2)
local panel=ui("Frame",{
    Name="MainWindow",BackgroundColor3=BG,BorderSizePixel=0,ClipsDescendants=true,
    Size=UDim2.fromOffset(372,534),AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.fromScale(0.5,0.5),Visible=false,
},gui)
round(panel,16)
border(panel,ORANGE,0.40)
local scale=ui("UIScale",{Scale=1},panel)
local strip=ui("Frame",{BackgroundColor3=ORANGE,BorderSizePixel=0,Size=UDim2.new(1,0,0,3)},panel)
local header=ui("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,72),Active=true},panel)
text(header,"🎃",14,12,-330,34,24,ORANGE,true).Size=UDim2.fromOffset(30,30)
text(header,"HALLOWEN MM2",46,11,-120,28,19,LIGHT,true)
text(header,"TELEGRAM  •  @AtlantaRobuxShop",46,42,-100,18,10,ORANGE,false)
text(header,"✈",-88,13,-16,28,18,PURPLE,true).TextXAlignment=Enum.TextXAlignment.Right
local close=button(header,"✕",-44,17,30,30)
local tabs=ui("Frame",{BackgroundTransparency=1,Position=UDim2.fromOffset(12,74),Size=UDim2.new(1,-24,0,38)},panel)
local tabNames={"ФАРМ","ЗАЩИТА","СТАТИСТИКА"}
local tabButtons={}
local pages={}
for i,name in ipairs(tabNames) do
    local b=ui("TextButton",{
        BackgroundColor3=(i==1 and Color3.fromRGB(79,50,60) or CARD),BorderSizePixel=0,
        Position=UDim2.new((i-1)/3,4,0,0),Size=UDim2.new(1/3,-8,1,0),
        Text=name,TextSize=11,Font=Enum.Font.GothamBold,
        TextColor3=(i==1 and ORANGE or MUTED),AutoButtonColor=false,
    },tabs)
    round(b,9)
    tabButtons[i]=b
    local page=ui("ScrollingFrame",{
        Name="Page"..i,BackgroundTransparency=1,BorderSizePixel=0,
        Position=UDim2.fromOffset(10,118),Size=UDim2.new(1,-20,1,-156),
        ScrollBarThickness=3,ScrollBarImageColor3=ORANGE,
        AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),
        ScrollingDirection=Enum.ScrollingDirection.Y,Visible=(i==1),
    },panel)
    ui("UIListLayout",{Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center},page)
    ui("UIPadding",{PaddingBottom=UDim.new(0,12)},page)
    pages[i]=page
end
local function showTab(idx)
    for i,pgPage in ipairs(pages) do
        pgPage.Visible=(i==idx)
        tween(tabButtons[i],0.15,{
            BackgroundColor3=(i==idx and Color3.fromRGB(79,50,60) or CARD),
            TextColor3=(i==idx and ORANGE or MUTED),
        })
    end
end
for i,b in ipairs(tabButtons) do bind(b.MouseButton1Click,function() showTab(i) end) end
local foot=ui("TextLabel",{
    BackgroundTransparency=1,Text="🎃 TELEGRAM  •  @AtlantaRobuxShop  •  ✈",Font=Enum.Font.GothamBold,
    TextSize=10,TextColor3=MUTED,Position=UDim2.new(0,12,1,-30),Size=UDim2.new(1,-24,0,24)
},panel)

-- Farm page: no fake flight speed control. Character speed is EXACTLY 1..100.
local farmCard=card(pages[1],72)
text(farmCard,"AUTO CANDY FARM",12,8,-98,24,14,LIGHT,true)
text(farmCard,"Ближайшие конфеты → затем монеты",12,35,-84,23,10,MUTED)
local farmBtn=button(farmCard,"OFF",-77,19,64,32)
local airRow=card(pages[1],65)
text(airRow,"AIR WALK",12,6,-93,24,13,LIGHT,true)
text(airRow,"Плавный полёт к ближайшей конфете с поворотом",12,31,-82,20,10,MUTED)
local airBtn=button(airRow,"ON",-77,15,64,32)
local speedCard=card(pages[1],132)
text(speedCard,"СКОРОСТЬ ПЕРСОНАЖА",12,6,-110,24,12,LIGHT,true)
local speedInput=ui("TextBox",{
    BackgroundColor3=CARD2,BorderSizePixel=0,Font=Enum.Font.GothamBold,TextSize=15,
    TextColor3=ORANGE,Text="10",ClearTextOnFocus=false,
    Position=UDim2.new(1,-72,0,8),Size=UDim2.fromOffset(60,28),
},speedCard)
round(speedInput,8)
local speedBar=ui("Frame",{
    BackgroundColor3=CARD2,BorderSizePixel=0,Active=true,
    Position=UDim2.new(0,14,0,57),Size=UDim2.new(1,-28,0,9),
},speedCard)
round(speedBar,5)
local speedFill=ui("Frame",{BackgroundColor3=ORANGE,BorderSizePixel=0,Size=UDim2.fromScale(0,1)},speedBar)
round(speedFill,5)
local speedKnob=ui("Frame",{
    BackgroundColor3=LIGHT,BorderSizePixel=0,Active=true,
    AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(20,20),Position=UDim2.fromScale(0,0.5),
},speedBar)
round(speedKnob,11)
text(speedCard,"1 — медленно     •     16 — стандарт     •     100 — максимум",12,77,-24,18,10,MUTED)
local speedWarn=text(speedCard,"⚠ Более 16 — возможны откаты и проблемы движения",12,103,-24,18,10,WARNING)
local safeRow=card(pages[1],65)
text(safeRow,"ИЗБЕГАТЬ MURDERER",12,6,-93,24,13,LIGHT,true)
text(safeRow,"Обычные игроки не блокируют монеты",12,31,-82,20,10,MUTED)
local safeBtn=button(safeRow,"ON",-77,15,64,32)
local resetRow=card(pages[1],65)
text(resetRow,"AUTO RESET",12,6,-93,24,13,LIGHT,true)
text(resetRow,"При полном мешке, если счётчик доступен",12,31,-88,20,10,MUTED)
local resetBtn=button(resetRow,"OFF",-77,15,64,32)
local rejoinRow=card(pages[1],65)
text(rejoinRow,"AUTO REJOIN",12,6,-93,24,13,LIGHT,true)
text(rejoinRow,"Попытка входа при ошибке соединения",12,31,-88,20,10,MUTED)
local rejoinBtn=button(rejoinRow,"OFF",-77,15,64,32)
local endRow=card(pages[1],58)
text(endRow,"END ROUND",12,7,-100,24,13,LIGHT,true)
text(endRow,"Для реального завершения нужен серверный API",12,32,-95,17,10,MUTED)
local endBtn=button(endRow,"END",-77,14,64,32)

-- Protection tab: all requested switches visible immediately, not buried below stats.
local antiCard=card(pages[2],82)
text(antiCard,"ANTI FLING",12,7,-94,24,14,LIGHT,true)
text(antiCard,"Снижает толчки и резкие вращения",12,32,-80,19,11,MUTED)
text(antiCard,"Локальная защита, не от любого оружия",12,51,-25,17,10,ORANGE)
local antiBtn=button(antiCard,"ON",-77,20,64,33)
local afkCard=card(pages[2],82)
text(afkCard,"ANTI-AFK",12,7,-94,24,14,LIGHT,true)
text(afkCard,"Пробует отправить действие при Idled",12,32,-80,19,11,MUTED)
text(afkCard,"Зависит от клиента Roblox",12,51,-25,17,10,ORANGE)
local afkBtn=button(afkCard,"ON",-77,20,64,33)
local noclipCard=card(pages[2],82)
text(noclipCard,"NOCLIP",12,7,-94,24,14,LIGHT,true)
text(noclipCard,"Air Walk сам включает Noclip на время движения",12,32,-80,19,11,MUTED)
text(noclipCard,"Здесь — ручной Noclip вне фарма (риск падения)",12,51,-25,17,10,WARNING)
local noclipBtn=button(noclipCard,"OFF",-77,20,64,33)
local tips=card(pages[2],80)
text(tips,"ЗАЩИТА ОТ ЗАСТРЕВАНИЯ",12,6,-24,24,12,LIGHT,true)
text(tips,"Air Walk: плавный полёт к ближайшей цели без бега.",12,31,-24,19,11,MUTED)
text(tips,"ESP показывает текущую ближайшую цель.",12,51,-24,19,10,MUTED)

-- Statistics tab: client visits are NOT server-confirmed money.
local statRow=card(pages[3],150)
text(statRow,"АНАЛИТИКА СЕССИИ",12,6,-24,22,13,LIGHT,true)
local statVisits=text(statRow,"Посещено монет: 0",12,33,-24,22,13,ORANGE,true)
local statCandies=text(statRow,"Конфет посещено: 0",12,60,-24,21,12,LIGHT)
local statFail=text(statRow,"Неудачных маршрутов: 0",12,87,-24,21,12,LIGHT)
local statTime=text(statRow,"Время: 00:00:00",12,114,-24,21,12,MUTED)
local statBag=card(pages[3],67)
local bagValue=text(statBag,"Мешок: ? / ?",12,8,-24,25,13,LIGHT,true)
text(statBag,"Если игра не раскрывает счётчик, будет ?",12,37,-24,20,10,MUTED)
local statRole=card(pages[3],67)
local roleValue=text(statRole,"Роль: Unknown",12,8,-24,24,13,LIGHT,true)
text(statRole,"Обнаружение убийцы зависит от видимых данных",12,37,-24,20,10,MUTED)
local statusCard=card(pages[3],88)
text(statusCard,"СТАТУС",12,6,-24,20,11,ORANGE,true)
local statusText=text(statusCard,"Готово",12,30,-24,50,12,LIGHT)
statusText.TextWrapped=true
statusText.TextTruncate=Enum.TextTruncate.None

local function setButton(btn,on)
    btn.Text=on and "ON" or "OFF"
    btn.TextColor3=on and GOOD or LIGHT
end
local function showSpeed()
    local ratio=(state.speed-1)/99
    speedFill.Size=UDim2.fromScale(ratio,1)
    speedKnob.Position=UDim2.fromScale(ratio,0.5)
    if not speedInput:IsFocused() then speedInput.Text=tostring(state.speed) end
    speedInput.TextColor3=(state.speed>16) and WARNING or ORANGE
    speedWarn.Visible=state.speed>16
end
refresh=function()
    setButton(farmBtn,state.active)
    setButton(airBtn,state.airWalk)
    setButton(safeBtn,state.avoidMurderer)
    setButton(resetBtn,state.autoReset)
    setButton(rejoinBtn,state.autoRejoin)
    setButton(antiBtn,state.antiFling)
    setButton(afkBtn,state.antiAfk)
    setButton(noclipBtn,state.noclip)
    showSpeed()
    statVisits.Text="Всего посещено: "..state.visits
    statCandies.Text="Конфет посещено: "..state.candies
    statFail.Text="Неудачных маршрутов: "..state.failures
    local seconds=math.max(0,math.floor(os.clock()-startedAt))
    statTime.Text=string.format("Время: %02d:%02d:%02d",math.floor(seconds/3600),math.floor(seconds/60)%60,seconds%60)
    bagValue.Text="Мешок: "..tostring(state.bag).." / "..tostring(state.bagLimit)
    roleValue.Text="Роль: "..tostring(state.role)
    statusText.Text=tostring(state.status)
    updateTargetESP()
end

-- Smooth responsive opening, with a small clickable launcher on mobile.
local isOpen=false
local function targetScale()
    local cam=Workspace.CurrentCamera
    local s=cam and cam.ViewportSize or Vector2.new(400,750)
    return math.clamp(math.min((s.X-20)/390,(s.Y-35)/550),0.61,1)
end
local function show(open)
    isOpen=open
    if open then
        panel.Visible=true
        panel.BackgroundTransparency=0.6
        scale.Scale=targetScale()*0.90
        tween(scale,0.22,{Scale=targetScale()})
        tween(panel,0.22,{BackgroundTransparency=0})
    else
        tween(panel,0.16,{BackgroundTransparency=0.55})
        task.delay(0.17,function() if alive and not isOpen then panel.Visible=false end end)
    end
end
bind(opener.MouseButton1Click,function() show(not isOpen) end)
bind(close.MouseButton1Click,function() show(false) end)
bind(farmBtn.MouseButton1Click,function() send("ToggleFarm") end)
bind(airBtn.MouseButton1Click,function() send("AirWalk",not state.airWalk) end)
bind(safeBtn.MouseButton1Click,function() send("AvoidMurderer",not state.avoidMurderer) end)
bind(resetBtn.MouseButton1Click,function() send("AutoReset",not state.autoReset) end)
bind(rejoinBtn.MouseButton1Click,function() send("AutoRejoin",not state.autoRejoin) end)
bind(endBtn.MouseButton1Click,function() send("EndRound") end)
bind(antiBtn.MouseButton1Click,function() send("AntiFling",not state.antiFling) end)
bind(afkBtn.MouseButton1Click,function() send("AntiAfk",not state.antiAfk) end)
bind(noclipBtn.MouseButton1Click,function() send("Noclip",not state.noclip) end)

local sliderHeld=false
local activeTouch
local function sliderUpdate(input)
    local x=input.Position.X
    local ratio=math.clamp((x-speedBar.AbsolutePosition.X)/math.max(1,speedBar.AbsoluteSize.X),0,1)
    send("Speed",math.floor(1+ratio*99+0.5))
end
local function startSlider(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        sliderHeld=true
        activeTouch=input.UserInputType==Enum.UserInputType.Touch and input or nil
        sliderUpdate(input)
    end
end
bind(speedBar.InputBegan,startSlider)
bind(speedKnob.InputBegan,startSlider)
bind(UserInputService.InputChanged,function(input)
    if sliderHeld and (input.UserInputType==Enum.UserInputType.MouseMovement or (input.UserInputType==Enum.UserInputType.Touch and input==activeTouch)) then
        sliderUpdate(input)
    end
end)
bind(UserInputService.InputEnded,function(input)
    if sliderHeld and (input.UserInputType==Enum.UserInputType.MouseButton1 or (input.UserInputType==Enum.UserInputType.Touch and input==activeTouch)) then
        sliderHeld=false
        activeTouch=nil
    end
end)
bind(speedInput.FocusLost,function()
    send("Speed",math.clamp(tonumber(speedInput.Text) or state.speed,1,100))
    speedInput.Text=tostring(state.speed)
end)

local dragging=false
local dragInput=nil
local dragFrom=nil
local panelFrom=nil
bind(header.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        dragging=true
        dragInput=input.UserInputType==Enum.UserInputType.Touch and input or nil
        dragFrom=input.Position
        panelFrom=panel.Position
    end
end)
bind(UserInputService.InputChanged,function(input)
    if dragging and dragFrom and (input.UserInputType==Enum.UserInputType.MouseMovement or (input.UserInputType==Enum.UserInputType.Touch and input==dragInput)) then
        local delta=input.Position-dragFrom
        panel.Position=UDim2.new(panelFrom.X.Scale,panelFrom.X.Offset+delta.X,panelFrom.Y.Scale,panelFrom.Y.Offset+delta.Y)
    end
end)
bind(UserInputService.InputEnded,function(input)
    if dragging and (input.UserInputType==Enum.UserInputType.MouseButton1 or (input.UserInputType==Enum.UserInputType.Touch and input==dragInput)) then
        dragging=false;dragInput=nil
    end
end)
bind(UserInputService.InputBegan,function(input,processed)
    if not processed and input.KeyCode==Enum.KeyCode.RightShift then show(not isOpen) end
end)
bind(player.Chatted,function(msg)
    if string.lower(msg)=="/farm" then show(not isOpen) end
end)
pcall(function()
    local cmd=Instance.new("TextChatCommand")
    cmd.Name="AtlantaFarmToggleV17"
    cmd.PrimaryAlias="/farm"
    cmd.Parent=TextChatService:FindFirstChild("TextChatCommands") or TextChatService
    bind(cmd.Triggered,function() show(not isOpen) end)
end)

bind(player.CharacterAdded,function()
    task.wait(0.6)
    if not alive then return end
    applySpeed()
    if resetPending then state.resets+=1;resetPending=false end
    updateNoclip()
end)
applySpeed()
local lastProtection=0
bind(RunService.Heartbeat,function(dt)
    if not alive then return end
    lastProtection+=dt
    if lastProtection>0.45 then
        lastProtection=0
        if state.antiFling or next(savedOtherCollision)~=nil then updateAntiFling() end
        if state.noclip or state.visiting then updateNoclip() end
        updateTargetESP()
    end
end)
bind(player.Idled,function()
    if not state.antiAfk then return end
    local camera=Workspace.CurrentCamera
    local cf=camera and camera.CFrame or CFrame.new()
    local ok=pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0,0),cf)
    end)
    state.status=ok and "Anti-AFK: попытка активности отправлена" or "Anti-AFK: среда не разрешает отправку"
    refresh()
end)

local lastRejoin=-math.huge
pcall(function()
    bind(GuiService.ErrorMessageChanged,function(message)
        if not alive or not state.autoRejoin or RunService:IsStudio() or type(message)~="string" then return end
        local m=string.lower(message)
        if not (m:find("disconnect",1,true) or m:find("connection",1,true) or m:find("соединен",1,true)) then return end
        if os.clock()-lastRejoin<70 then return end
        lastRejoin=os.clock()
        state.status="Пробую переподключиться..."
        refresh()
        task.defer(function() pcall(function() TeleportService:Teleport(game.PlaceId,player) end) end)
    end)
end)

-- Bag statistics are ONLY available when this specific game exposes these attributes.
task.spawn(function()
    while alive and gui.Parent do
        task.wait(1)
        if not alive then break end
        local bag=player:GetAttribute("AtlantaBag")
        local limit=player:GetAttribute("AtlantaBagLimit")
        state.bag=type(bag)=="number" and bag or "?"
        state.bagLimit=type(limit)=="number" and limit or "?"
        state.role=player:GetAttribute("AtlantaRole") or player:GetAttribute("CurrentRole") or player:GetAttribute("Role") or "Unknown"
        if state.autoReset and state.active and not state.visiting and type(bag)=="number"
            and type(limit)=="number" and limit>0 and bag>=limit and os.clock()-lastReset>18 then
            lastReset=os.clock()
            local _,hum=charParts()
            if hum then
                resetPending=true
                state.status="Полный мешок · перерождение (если разрешено игрой)"
                hum.Health=0
            end
        end
        refresh()
    end
end)

task.spawn(function()
    while alive and gui.Parent do
        task.wait(8)
        if not alive then break end
        local now=os.clock()
        for part in pairs(cachedCoins) do
            if (not part) or (not part.Parent) or (not part:IsDescendantOf(Workspace)) then
                cachedCoins[part]=nil
                visited[part]=nil
            elseif (visited[part] or 0)>0 and now-(visited[part] or 0)>120 then
                visited[part]=nil
            end
        end
        for part in pairs(savedCollision) do
            if (not part) or (not part.Parent) then savedCollision[part]=nil end
        end
        for part in pairs(savedOtherCollision) do
            if (not part) or (not part.Parent) then savedOtherCollision[part]=nil end
        end
        if state.active and not state.visiting and not charParts() then
            state.status="Ожидаю новый раунд / персонажа"
        end
        refresh()
    end
end)

bind(gui.Destroying,function()
    alive=false;state.active=false;token+=1
    state.noclip=false;state.antiFling=false
    updateNoclip();updateAntiFling(true)
    if targetHighlight then targetHighlight:Destroy() end
    if targetBillboard then targetBillboard:Destroy() end
    for _,c in ipairs(listeners) do pcall(function() c:Disconnect() end) end
end)
refresh()
show(true)
