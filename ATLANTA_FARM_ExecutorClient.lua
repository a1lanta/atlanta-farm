local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TeleportService = game:GetService("TeleportService")
local TextChatService = game:GetService("TextChatService")
local player = Players.LocalPlayer
if not player then warn("ATLANTA FARM: client-only script"); return end
local pg = player:WaitForChild("PlayerGui")
-- Повторный запуск только открывает прежнее окно.
local old = pg:FindFirstChild("ATLANTA_FARM_V13")
if old then
    local window = old:FindFirstChild("MainWindow")
    if window then window.Visible = true end
    return
end
-- Удаляем только старые уведомления и устаревший GUI ATLANTA FARM.
for _, name in ipairs({"AtlantaFarmNoServerNotice", "ATLANTA_FARM_V12"}) do
    local object = pg:FindFirstChild(name)
    if object then object:Destroy() end
end
local remote = ReplicatedStorage:FindFirstChild("AtlantaFarmRemote")
if remote and not remote:IsA("RemoteEvent") then remote = nil end
local serverConnected = false

local BG = Color3.fromRGB(14, 17, 26)
local CARD = Color3.fromRGB(27, 33, 47)
local CARD2 = Color3.fromRGB(33, 42, 59)
local BLUE = Color3.fromRGB(118, 177, 255)
local LIGHT = Color3.fromRGB(240, 245, 255)
local MUTED = Color3.fromRGB(149, 165, 187)
local GREEN = Color3.fromRGB(97, 221, 159)
local WARN = Color3.fromRGB(255, 184, 91)
local state = {active=false,speed=16,fly=5,autoReset=false,autoRejoin=false,coins=0,bag=0,bagLimit="?",resets=0,elapsed=0,perHour=0,status="Локальный режим · GUI готов",role="Unknown",roleActions=false,standalone=true}
local authorized = true
local refresh
local startedAt = os.clock()
local lastSeenCoinAt = os.clock()
local visited = setmetatable({}, {__mode="k"})
local candidates = setmetatable({}, {__mode="k"})
local runningJob = 0

local function isCoin(part)
    if not part or not part:IsA("BasePart") then return false end
    if CollectionService:HasTag(part, "AtlantaCoin") or part:GetAttribute("AtlantaCoin") == true then return true end
    local function named(s)
        s = string.lower(s)
        return s == "coin" or s == "candy" or s:find("coin", 1, true) ~= nil
            or s:find("candy", 1, true) ~= nil or s:find("конфет", 1, true) ~= nil
            or s:find("монет", 1, true) ~= nil
    end
    if named(part.Name) then return true end
    local par = part.Parent
    if par and par:IsA("Model") and named(par.Name) then return true end
    return false
end
local function cacheCoin(obj)
    if isCoin(obj) then candidates[obj] = true end
end
for _, obj in ipairs(Workspace:GetDescendants()) do cacheCoin(obj) end
Workspace.DescendantAdded:Connect(cacheCoin)
CollectionService:GetInstanceAddedSignal("AtlantaCoin"):Connect(cacheCoin)

local function liveCharacter()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if hum and hum.Health > 0 and root then return char, hum, root end
end
local function applyWalkSpeed()
    local _, hum = liveCharacter()
    if hum then hum.WalkSpeed = state.speed end
end
player.CharacterAdded:Connect(function()
    task.wait(0.7)
    if not serverConnected then applyWalkSpeed() end
end)

local function visibleRole(plr)
    local char = plr.Character
    local role = plr:GetAttribute("AtlantaRole") or plr:GetAttribute("CurrentRole")
        or plr:GetAttribute("Role") or (char and (char:GetAttribute("AtlantaRole") or char:GetAttribute("Role")))
    if type(role) == "string" then return string.lower(role) end
    return ""
end
local function findDanger()
    if visibleRole(player) == "murderer" then return nil end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and visibleRole(plr) == "murderer" then
            local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if root then return root.Position end
        end
    end
end
local function closestCoin(root)
    local best, bestScore = nil, math.huge
    local danger = findDanger()
    for part in pairs(candidates) do
        if part and part.Parent and part:IsDescendantOf(Workspace) and isCoin(part)
            and os.clock() - (visited[part] or -100) > 18 then
            local distance = (part.Position-root.Position).Magnitude
            if distance < 600 then
                local bad = danger and (part.Position-danger).Magnitude < 30
                if not bad and distance < bestScore then best, bestScore = part, distance end
            end
        end
    end
    return best, danger
end

local function moveTo(root, point, duration, job)
    if job ~= runningJob or not state.active or not root.Parent then return false end
    local look = root.CFrame.LookVector
    local forward = Vector3.new(look.X,0,look.Z)
    if forward.Magnitude < 0.01 then forward = Vector3.new(0,0,-1) else forward = forward.Unit end
    local goal = CFrame.new(point, point + forward)
    local tw = TweenService:Create(root, TweenInfo.new(math.clamp(duration,0.12,4),Enum.EasingStyle.Linear), {CFrame=goal})
    tw:Play()
    while tw.PlaybackState == Enum.PlaybackState.Playing do
        if job ~= runningJob or not state.active or not root.Parent then tw:Cancel();return false end
        task.wait(0.035)
    end
    return tw.PlaybackState == Enum.PlaybackState.Completed
end
local function groundBelow(char, target)
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Exclude
    p.FilterDescendantsInstances = {char}
    local ray = Workspace:Raycast(target + Vector3.new(0,15,0), Vector3.new(0,-80,0), p)
    return ray and ray.Position.Y + 3 or target.Y
end
local function visitCoin(part, job)
    local char, hum, root = liveCharacter()
    if not char or not part or not part.Parent then return false end
    local target = part.Position
    local flyRate = 14 + state.fly*10 -- client-local units/second
    local original = root.Position
    local upY = math.max(original.Y + 3, target.Y + 3)
    local cruise = Vector3.new(original.X, upY, original.Z)
    local above = Vector3.new(target.X, upY, target.Z)
    local function go(point)
        local dist = (root.Position-point).Magnitude
        return moveTo(root, point, dist/flyRate, job)
    end
    hum:ChangeState(Enum.HumanoidStateType.Physics)
    local ok = go(cruise) and go(above)
    if ok and part.Parent then
        ok = go(target + Vector3.new(0,1.1,0))
    end
    if ok then task.wait(0.12) end
    -- Сначала пробуем приземлиться; возвращаем управление персонажем в любом случае.
    if root.Parent and job == runningJob and state.active then
        go(Vector3.new(root.Position.X, groundBelow(char,target), root.Position.Z))
    end
    if hum.Parent then hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
    if ok then
        visited[part] = os.clock()
        lastSeenCoinAt = os.clock()
        -- В локальном режиме учитываем ПОСЕЩЕНИЯ, не начисленную сервером валюту.
        state.coins += 1
        state.status = "Посещение монеты #" .. tostring(state.coins)
    end
    return ok
end
local function runLocalFarm(job)
    while state.active and job == runningJob and not serverConnected do
        local _, hum, root = liveCharacter()
        if not root then
            state.status = "Ожидание появления персонажа"
            task.wait(0.7)
        else
            local part, danger = closestCoin(root)
            if part then
                state.status = danger and "Ищу монеты вдали от Murderer" or "Лечу к монете"
                visitCoin(part, job)
                task.wait(0.15)
            else
                state.status = danger and "Безопасных монет не найдено" or "Монеты не найдены в Workspace"
                task.wait(1.1)
            end
        end
        if state.autoRejoin and os.clock()-lastSeenCoinAt > 180 and not RunService:IsStudio() then
            state.status = "Пробую переподключиться"
            pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
            lastSeenCoinAt = os.clock()
        end
    end
end
local function send(action, value)
    if serverConnected and remote then
        remote:FireServer(action, value)
        return
    end
    if action == "ToggleFarm" then
        state.active = not state.active
        runningJob += 1
        local job = runningJob
        if state.active then
            state.status = "Локальный поиск монет"
            task.spawn(runLocalFarm,job)
        else
            state.status = "Фарм остановлен"
            local _,hum = liveCharacter()
            if hum then hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
        end
    elseif action == "Speed" then
        state.speed = math.clamp(tonumber(value) or 16, 16, 25)
        applyWalkSpeed()
    elseif action == "Fly" then
        state.fly = math.clamp(tonumber(value) or 5, 1, 10)
    elseif action == "AutoReset" then
        state.autoReset = not not value
        state.status = "Auto Reset: нужен счётчик мешка от сервера игры"
    elseif action == "AutoRejoin" then
        state.autoRejoin = not not value
    end
    if refresh then refresh() end
end

local function ui(className, props, parent)
    local inst = Instance.new(className)
    for key, value in pairs(props or {}) do inst[key] = value end
    if parent then inst.Parent = parent end
    return inst
end
local function corner(obj, radius) ui("UICorner", {CornerRadius=UDim.new(0,radius or 12)}, obj) end
local function stroke(obj, color, alpha)
    ui("UIStroke", {Color=color or Color3.fromRGB(64,84,119),Transparency=alpha or 0.6,Thickness=1},obj)
end
local function animate(object, duration, goal, style)
    local tween = TweenService:Create(object,TweenInfo.new(duration,style or Enum.EasingStyle.Quart,Enum.EasingDirection.Out),goal)
    tween:Play()
    return tween
end
local function label(parent, txt, y, height, size, color, weight)
    return ui("TextLabel", {
        BackgroundTransparency=1, Text=txt, Font=weight or Enum.Font.Gotham,
        TextSize=size or 13, TextColor3=color or LIGHT, TextXAlignment=Enum.TextXAlignment.Left,
        Position=UDim2.fromOffset(12,y), Size=UDim2.new(1,-24,0,height), TextTruncate=Enum.TextTruncate.AtEnd,
    },parent)
end
local function box(parent,height)
    local frame=ui("Frame",{BackgroundColor3=CARD,Size=UDim2.new(1,-10,0,height),BorderSizePixel=0},parent)
    corner(frame,11)
    return frame
end
local function actionBtn(parent, txt, width)
    local b=ui("TextButton",{Text=txt,AutoButtonColor=false,Font=Enum.Font.GothamBold,
        TextColor3=LIGHT,TextSize=12,BackgroundColor3=CARD2,Size=UDim2.fromOffset(width or 72,30),BorderSizePixel=0},parent)
    corner(b,9)
    b.MouseEnter:Connect(function() animate(b,0.14,{BackgroundColor3=Color3.fromRGB(55,74,105)}) end)
    b.MouseLeave:Connect(function() animate(b,0.14,{BackgroundColor3=CARD2}) end)
    return b
end

local gui=ui("ScreenGui",{Name="ATLANTA_FARM_V13",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=15},player:WaitForChild("PlayerGui"))
local opener=ui("TextButton",{
    Name="AtlantaLauncher",Text="A",Font=Enum.Font.GothamBlack,TextSize=23,TextColor3=LIGHT,
    BackgroundColor3=Color3.fromRGB(33,61,98),Size=UDim2.fromOffset(54,54),
    Position=UDim2.new(0,18,0.52,0),BorderSizePixel=0,Visible=true,AutoButtonColor=false,
},gui)
corner(opener,19)
stroke(opener,BLUE,0.2)

local panel=ui("Frame",{
    Name="MainWindow",BackgroundColor3=BG,Size=UDim2.fromOffset(350,565),
    AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
    BorderSizePixel=0,Visible=false,ClipsDescendants=true,
},gui)
corner(panel,17)
stroke(panel,Color3.fromRGB(75,98,137),0.25)
local scale=ui("UIScale",{Scale=1},panel)

local top=ui("Frame",{BackgroundColor3=BG,Size=UDim2.new(1,0,0,67),BorderSizePixel=0},panel)
label(top,"ATLANTA FARM",11,24,19,LIGHT,Enum.Font.GothamBlack)
label(top,"TG: @AtlantaRobuxShop   •   V1.3",38,15,11,BLUE,Enum.Font.GothamMedium)
local close=actionBtn(top,"—",34)
close.Position=UDim2.new(1,-44,0,19)

local scroll=ui("ScrollingFrame",{
    BackgroundTransparency=1,Position=UDim2.fromOffset(10,71),Size=UDim2.new(1,-15,1,-83),
    ScrollBarThickness=3,ScrollBarImageColor3=BLUE,CanvasSize=UDim2.new(),
    AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,
    BorderSizePixel=0,
},panel)
ui("UIListLayout",{Padding=UDim.new(0,8),HorizontalAlignment=Enum.HorizontalAlignment.Center,
    SortOrder=Enum.SortOrder.LayoutOrder},scroll)
ui("UIPadding",{PaddingBottom=UDim.new(0,10)},scroll)

local farmRow=box(scroll,59)
label(farmRow,"AUTO FARM",8,20,14,LIGHT,Enum.Font.GothamBold)
label(farmRow,"Полёт → сбор → приземление",30,16,10,MUTED)
local farmButton=actionBtn(farmRow,"OFF",62)
farmButton.Position=UDim2.new(1,-74,0,14)

local speedBox=box(scroll,101)
label(speedBox,"Character Speed",8,20,13,LIGHT,Enum.Font.GothamBold)
local speedValue=ui("TextLabel",{Text="16",Font=Enum.Font.GothamBold,TextSize=14,TextColor3=BLUE,
    TextXAlignment=Enum.TextXAlignment.Right,BackgroundTransparency=1,Position=UDim2.new(1,-72,0,9),Size=UDim2.fromOffset(60,20)},speedBox)
local speedBar=ui("Frame",{Active=true,BackgroundColor3=CARD2,Position=UDim2.new(0,12,0,41),Size=UDim2.new(1,-24,0,8),BorderSizePixel=0},speedBox)
corner(speedBar,5)
local speedFill=ui("Frame",{BackgroundColor3=BLUE,Size=UDim2.fromScale(0,1),BorderSizePixel=0},speedBar)
corner(speedFill,5)
local speedKnob=ui("Frame",{Active=true,BackgroundColor3=LIGHT,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0,0.5),Size=UDim2.fromOffset(18,18),BorderSizePixel=0},speedBar)
corner(speedKnob,10)
label(speedBox,"16 · Normal     |     25 · Max (может быть опасно)",59,18,10,MUTED)

local speedWarning=label(speedBox,"⚠ 21–25: высокая скорость, возможны сбои",75,13,9,WARN)
speedWarning.Visible=false

local flyBox=box(scroll,79)
label(flyBox,"Fly Speed",8,20,13,LIGHT,Enum.Font.GothamBold)
local flyValue=ui("TextLabel",{Text="5 / 10",Font=Enum.Font.GothamBold,TextSize=13,TextColor3=BLUE,
    TextXAlignment=Enum.TextXAlignment.Right,BackgroundTransparency=1,Position=UDim2.new(1,-80,0,9),Size=UDim2.fromOffset(68,20)},flyBox)
local flyBar=ui("Frame",{Active=true,BackgroundColor3=CARD2,Position=UDim2.new(0,12,0,46),Size=UDim2.new(1,-24,0,8),BorderSizePixel=0},flyBox)
corner(flyBar,5)
local flyFill=ui("Frame",{BackgroundColor3=BLUE,Size=UDim2.fromScale(0,1),BorderSizePixel=0},flyBar)
corner(flyFill,5)
local flyKnob=ui("Frame",{Active=true,BackgroundColor3=LIGHT,AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0,0.5),Size=UDim2.fromOffset(18,18),BorderSizePixel=0},flyBar)
corner(flyKnob,10)

local resetRow=box(scroll,52)
label(resetRow,"Auto Reset",8,19,13,LIGHT,Enum.Font.GothamBold)
label(resetRow,"Когда мешок полностью собран",29,14,10,MUTED)
local resetBtn=actionBtn(resetRow,"ON",62)
resetBtn.Position=UDim2.new(1,-74,0,10)

local rejoinRow=box(scroll,52)
label(rejoinRow,"Auto Rejoin",8,19,13,LIGHT,Enum.Font.GothamBold)
label(rejoinRow,"Если монет нет 180 секунд",29,14,10,MUTED)
local rejoinBtn=actionBtn(rejoinRow,"OFF",62)
rejoinBtn.Position=UDim2.new(1,-74,0,10)

local stats=box(scroll,161)
label(stats,"ANALYTICS",8,20,13,LIGHT,Enum.Font.GothamBold)
local statTexts={}
local visitTitle
local statsInfo={{"Collected","coins"},{"Coins / Hour","perHour"},{"Bag","bag"},{"Resets","resets"}}
for i,item in ipairs(statsInfo) do
    local col=(i-1)%2;local row=math.floor((i-1)/2)
    local cell=ui("Frame",{BackgroundColor3=CARD2,Position=UDim2.new(col*0.5,11+col*0,0,35+row*59),Size=UDim2.new(0.5,-17,0,52),BorderSizePixel=0},stats)
    corner(cell,9)
    local titleLabel = label(cell,item[1],5,16,10,MUTED)
    if item[2] == "coins" then visitTitle = titleLabel end
    statTexts[item[2]]=label(cell,"0",24,23,17,LIGHT,Enum.Font.GothamBold)
end
local timerRow=box(scroll,52)
label(timerRow,"SESSION TIME",5,18,11,MUTED,Enum.Font.GothamBold)
local timeText=label(timerRow,"00:00:00",23,22,16,LIGHT,Enum.Font.GothamBold)
local roleRow=box(scroll,52)
label(roleRow,"CURRENT ROLE",5,18,10,MUTED,Enum.Font.GothamBold)
local roleText=label(roleRow,"Unknown",23,21,13,LIGHT,Enum.Font.GothamBold)
local studioBox
if RunService:IsStudio() and remote then
    studioBox=box(scroll,54)
    label(studioBox,"Тестовый сбор (Studio)",6,17,11,LIGHT)
    local spawnBtn=actionBtn(studioBox,"55 COINS",94)
    spawnBtn.Position=UDim2.new(1,-106,0,12)
    spawnBtn.MouseButton1Click:Connect(function() send("SpawnTest") end)
end
local statusBox=box(scroll,62)
label(statusBox,"STATUS",5,17,10,BLUE,Enum.Font.GothamBold)
local statusLabel=label(statusBox,"Готов",25,29,11,LIGHT,Enum.Font.GothamMedium)
local footer=ui("TextLabel",{BackgroundTransparency=1,Text="Made by @AtlantaRobuxShop  •  /farm",
    Font=Enum.Font.Gotham,TextSize=11,TextColor3=MUTED,
    Size=UDim2.new(1,-10,0,22)},scroll)

local isOpen=false
local function recomputeScale()
    local camera=Workspace.CurrentCamera
    if not camera then return end
    local size=camera.ViewportSize
    local factor=math.clamp(math.min((size.X-20)/360,(size.Y-35)/590),0.62,1)
    scale.Scale=factor
end
if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(recomputeScale) end
recomputeScale()

local function show(open)
    isOpen=open
    if open then
        panel.Visible=true
        scale.Scale=math.max(0.2,scale.Scale*0.89)
        panel.BackgroundTransparency=0.6
        local camera = Workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(420, 700)
        local target=math.clamp(math.min((viewport.X-20)/360,(viewport.Y-35)/590),0.62,1)
        animate(scale,0.25,{Scale=target})
        animate(panel,0.22,{BackgroundTransparency=0})
    else
        animate(panel,0.17,{BackgroundTransparency=0.5})
        task.delay(0.17,function() if not isOpen then panel.Visible=false end end)
    end
end
opener.MouseButton1Click:Connect(function() show(not isOpen) end)
close.MouseButton1Click:Connect(function() show(false) end)

local function updateSlider(bar,fill,knob,txt,value,min,max,suffix)
    local ratio=(value-min)/(max-min)
    fill.Size=UDim2.fromScale(ratio,1)
    knob.Position=UDim2.fromScale(ratio,0.5)
    txt.Text=tostring(value)..(suffix or "")
end
local function sliderEvents(bar,min,max,action,fill,knob,txt,suffix)
    local isDragging=false
    local current=min
    local function update(input)
        local ratio=math.clamp((input.Position.X-bar.AbsolutePosition.X)/math.max(1,bar.AbsoluteSize.X),0,1)
        current=math.floor(min+ratio*(max-min)+0.5)
        updateSlider(bar,fill,knob,txt,current,min,max,suffix)
    end
    local activeInput
    local function onBegin(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            isDragging=true
            activeInput=input
            update(input)
        end
    end
    bar.InputBegan:Connect(onBegin)
    knob.InputBegan:Connect(onBegin)
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType==Enum.UserInputType.MouseMovement or (input.UserInputType==Enum.UserInputType.Touch and input==activeInput)) then update(input) end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if isDragging and (input.UserInputType==Enum.UserInputType.MouseButton1 or (input.UserInputType==Enum.UserInputType.Touch and input==activeInput)) then
            isDragging=false
            send(action,current)
        end
    end)
end
sliderEvents(speedBar,16,25,"Speed",speedFill,speedKnob,speedValue,"")
sliderEvents(flyBar,1,10,"Fly",flyFill,flyKnob,flyValue," / 10")
farmButton.MouseButton1Click:Connect(function() send("ToggleFarm") end)
resetBtn.MouseButton1Click:Connect(function() send("AutoReset",not state.autoReset) end)
rejoinBtn.MouseButton1Click:Connect(function() send("AutoRejoin",not state.autoRejoin) end)

-- Перетаскивание окна (ПК и тач).
local moving=false;local firstPoint;local firstPosition
local function dragStart(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        moving=true;firstPoint=input.Position;firstPosition=panel.Position
    end
end
top.InputBegan:Connect(dragStart)
UserInputService.InputChanged:Connect(function(input)
    if moving and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
        local delta=input.Position-firstPoint
        panel.Position=UDim2.new(firstPosition.X.Scale,firstPosition.X.Offset+delta.X,firstPosition.Y.Scale,firstPosition.Y.Offset+delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then moving=false end
end)

local function timeFormat(t)
    t=math.floor(t or 0)
    return string.format("%02d:%02d:%02d",math.floor(t/3600),math.floor(t/60)%60,t%60)
end
refresh = function()
    farmButton.Text=state.active and "ON" or "OFF"
    farmButton.TextColor3=state.active and GREEN or LIGHT
    resetBtn.Text=state.autoReset and "ON" or "OFF"
    resetBtn.TextColor3=state.autoReset and GREEN or LIGHT
    rejoinBtn.Text=state.autoRejoin and "ON" or "OFF"
    rejoinBtn.TextColor3=state.autoRejoin and GREEN or LIGHT
    updateSlider(speedBar,speedFill,speedKnob,speedValue,state.speed,16,25,"")
    speedValue.TextColor3=(state.speed>20) and WARN or BLUE
    speedWarning.Visible=state.speed>20
    updateSlider(flyBar,flyFill,flyKnob,flyValue,state.fly,1,10," / 10")
    if visitTitle then visitTitle.Text = serverConnected and "Collected" or "Visits (not coins)" end
    -- В локальном режиме это скорость ПОСЕЩЕНИЙ, а не реальная игровая валюта.
    if statsInfo[2] and statTexts.perHour then
        local hourTitle = statTexts.perHour.Parent:FindFirstChildWhichIsA("TextLabel")
        if hourTitle and hourTitle ~= statTexts.perHour then
            hourTitle.Text = serverConnected and "Coins / Hour" or "Visits / Hour"
        end
    end
    statTexts.coins.Text=tostring(state.coins)
    statTexts.perHour.Text=tostring(state.perHour)
    statTexts.bag.Text=string.format("%s/%s",tostring(state.bag),tostring(state.bagLimit))
    statTexts.resets.Text=tostring(state.resets)
    timeText.Text=timeFormat(state.elapsed)
    statusLabel.Text=tostring(state.status)
    roleText.Text=serverConnected and (tostring(state.role)..(state.roleActions and "  •  Actions ON" or "  •  Actions OFF")) or tostring(player:GetAttribute("AtlantaRole") or player:GetAttribute("CurrentRole") or player:GetAttribute("Role") or "Unknown")
    footer.Text=serverConnected and "Server mode  •  @AtlantaRobuxShop" or "Local mode · visits ≠ balance  •  @AtlantaRobuxShop"
end
if remote then remote.OnClientEvent:Connect(function(event,payload)
    if event=="Authorized" then
        serverConnected=true
        state.active=false
        runningJob += 1
        state.status="Сервер ATLANTA FARM подключён"
        opener.Visible=true
    elseif event=="Denied" then
        serverConnected=false
        state.status="Локальный режим: сервер отклонил доступ"
    elseif event=="ToggleUI" then
        if authorized then show(not isOpen) end
    elseif event=="State" and type(payload)=="table" then
        for key,value in pairs(payload) do state[key]=value end
        refresh()
    end
end)
remote:FireServer("Hello") end

-- Открываем окно немедленно: не ждём наличие сервера или авторизацию.
refresh()
show(true)

-- Простейшие удобные способы открыть окно заново.
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.RightShift then show(not isOpen) end
end)
player.Chatted:Connect(function(message)
    if string.lower(message) == "/farm" then show(not isOpen) end
end)
-- Новый чат Roblox также поддерживает отдельную слеш-команду.
pcall(function()
    local cmd = Instance.new("TextChatCommand")
    cmd.Name = "AtlantaFarmCommand"
    cmd.PrimaryAlias = "/farm"
    cmd.Parent = TextChatService:WaitForChild("TextChatCommands", 2) or TextChatService
    cmd.Triggered:Connect(function() show(not isOpen) end)
end)
task.spawn(function()
    while gui.Parent do
        task.wait(1)
        if not serverConnected then
            state.elapsed = os.clock()-startedAt
            state.perHour = (state.elapsed > 0) and math.floor(state.coins/state.elapsed*3600 + 0.5) or 0
            -- Авто сброс мешка не пытается угадать ёмкость или ломать чужую механику.
            local bag = player:GetAttribute("AtlantaBag")
            local limit = player:GetAttribute("AtlantaBagLimit")
            if type(bag)=="number" then state.bag=bag end
            if type(limit)=="number" then state.bagLimit=limit end
            refresh()
        end
    end
end)
