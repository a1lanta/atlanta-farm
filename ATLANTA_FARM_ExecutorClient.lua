-- ATLANTA FARM V1.2 — клиентское меню для исполнения в контексте клиента Roblox.
-- Требует ATLANTA_FARM_Server, установленный в ВАШЕЙ игре.
-- Сам по себе этот файл не создает сервер, валюту и права администратора.
-- Никогда не запускайте чужие непроверенные loadstring-скрипты.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
if not player then warn("ATLANTA FARM: client-only script"); return end
local pg = player:WaitForChild("PlayerGui")
if pg:FindFirstChild("ATLANTA_FARM_V12") then
    warn("ATLANTA FARM: menu already launched — use the A button")
    return
end
local remote = ReplicatedStorage:FindFirstChild("AtlantaFarmRemote")
    or ReplicatedStorage:WaitForChild("AtlantaFarmRemote", 8)
if not remote or not remote:IsA("RemoteEvent") then
    warn("ATLANTA FARM: SERVER NOT INSTALLED in this place. Set up ATLANTA_FARM_Server in your own Roblox Studio experience first; an executor cannot add server scripts.")
    local hint = Instance.new("ScreenGui")
    hint.Name = "AtlantaFarmNoServerNotice"
    hint.ResetOnSpawn = false
    hint.Parent = pg
    local t = Instance.new("TextLabel")
    t.Size = UDim2.fromOffset(330, 85)
    t.AnchorPoint = Vector2.new(0.5, 0)
    t.Position = UDim2.new(0.5, 0, 0, 64)
    t.BackgroundColor3 = Color3.fromRGB(22, 27, 41)
    t.TextColor3 = Color3.fromRGB(240, 245, 255)
    t.Font = Enum.Font.GothamMedium
    t.TextSize = 13
    t.TextWrapped = true
    t.Text = "ATLANTA FARM: серверная часть не установлена.\nПодключи ATLANTA_FARM_Server в своей игре."
    t.Parent = hint
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 12)
    c.Parent = t
    task.delay(8, function() if hint then hint:Destroy() end end)
    return
end

local BG = Color3.fromRGB(14, 17, 26)
local CARD = Color3.fromRGB(27, 33, 47)
local CARD2 = Color3.fromRGB(33, 42, 59)
local BLUE = Color3.fromRGB(118, 177, 255)
local LIGHT = Color3.fromRGB(240, 245, 255)
local MUTED = Color3.fromRGB(149, 165, 187)
local GREEN = Color3.fromRGB(97, 221, 159)
local WARN = Color3.fromRGB(255, 184, 91)
local state = {active=false,speed=16,fly=5,autoReset=true,autoRejoin=false,coins=0,bag=0,bagLimit=50,resets=0,elapsed=0,perHour=0,status="Ожидаем сервер",role="Unknown",roleActions=false,standalone=true}
local authorized = false

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

local gui=ui("ScreenGui",{Name="ATLANTA_FARM_V12",ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=15},player:WaitForChild("PlayerGui"))
local opener=ui("TextButton",{
    Name="AtlantaLauncher",Text="A",Font=Enum.Font.GothamBlack,TextSize=23,TextColor3=LIGHT,
    BackgroundColor3=Color3.fromRGB(33,61,98),Size=UDim2.fromOffset(54,54),
    Position=UDim2.new(0,18,0.52,0),BorderSizePixel=0,Visible=false,AutoButtonColor=false,
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
label(top,"TG: @AtlantaRobuxShop   •   V1.2",38,15,11,BLUE,Enum.Font.GothamMedium)
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
local statsInfo={{"Collected","coins"},{"Coins / Hour","perHour"},{"Bag","bag"},{"Resets","resets"}}
for i,item in ipairs(statsInfo) do
    local col=(i-1)%2;local row=math.floor((i-1)/2)
    local cell=ui("Frame",{BackgroundColor3=CARD2,Position=UDim2.new(col*0.5,11+col*0,0,35+row*59),Size=UDim2.new(0.5,-17,0,52),BorderSizePixel=0},stats)
    corner(cell,9)
    label(cell,item[1],5,16,10,MUTED)
    statTexts[item[2]]=label(cell,"0",24,23,17,LIGHT,Enum.Font.GothamBold)
end
local timerRow=box(scroll,52)
label(timerRow,"SESSION TIME",5,18,11,MUTED,Enum.Font.GothamBold)
local timeText=label(timerRow,"00:00:00",23,22,16,LIGHT,Enum.Font.GothamBold)
local roleRow=box(scroll,52)
label(roleRow,"CURRENT ROLE",5,18,10,MUTED,Enum.Font.GothamBold)
local roleText=label(roleRow,"Unknown",23,21,13,LIGHT,Enum.Font.GothamBold)
local studioBox
if RunService:IsStudio() then
    studioBox=box(scroll,54)
    label(studioBox,"Тестовый сбор (Studio)",6,17,11,LIGHT)
    local spawnBtn=actionBtn(studioBox,"55 COINS",94)
    spawnBtn.Position=UDim2.new(1,-106,0,12)
    spawnBtn.MouseButton1Click:Connect(function() remote:FireServer("SpawnTest") end)
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
    if not authorized then return end
    isOpen=open
    if open then
        panel.Visible=true
        scale.Scale=math.max(0.2,scale.Scale*0.89)
        panel.BackgroundTransparency=0.6
        local target=math.clamp(math.min((Workspace.CurrentCamera.ViewportSize.X-20)/360,(Workspace.CurrentCamera.ViewportSize.Y-35)/590),0.62,1)
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
            remote:FireServer(action,current)
        end
    end)
end
sliderEvents(speedBar,16,25,"Speed",speedFill,speedKnob,speedValue,"")
sliderEvents(flyBar,1,10,"Fly",flyFill,flyKnob,flyValue," / 10")
farmButton.MouseButton1Click:Connect(function() remote:FireServer("ToggleFarm") end)
resetBtn.MouseButton1Click:Connect(function() remote:FireServer("AutoReset",not state.autoReset) end)
rejoinBtn.MouseButton1Click:Connect(function() remote:FireServer("AutoRejoin",not state.autoRejoin) end)

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
local function refresh()
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
    statTexts.coins.Text=tostring(state.coins)
    statTexts.perHour.Text=tostring(state.perHour)
    statTexts.bag.Text=string.format("%s/%s",tostring(state.bag),tostring(state.bagLimit))
    statTexts.resets.Text=tostring(state.resets)
    timeText.Text=timeFormat(state.elapsed)
    statusLabel.Text=tostring(state.status)
    roleText.Text=tostring(state.role)..(state.roleActions and "  •  Actions ON" or "  •  Actions OFF")
    footer.Text=state.standalone and "DEMO COINS ≠ MM2 balance  •  @AtlantaRobuxShop" or "Made by @AtlantaRobuxShop  •  /farm"
end
remote.OnClientEvent:Connect(function(event,payload)
    if event=="Authorized" then
        authorized=true;opener.Visible=true
    elseif event=="Denied" then
        authorized=false;opener.Visible=false;panel.Visible=false
    elseif event=="ToggleUI" then
        if authorized then show(not isOpen) end
    elseif event=="State" and type(payload)=="table" then
        for key,value in pairs(payload) do state[key]=value end
        refresh()
    end
end)
remote:FireServer("Hello")
refresh()
