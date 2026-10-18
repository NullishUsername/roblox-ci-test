-- Shows the deployed commit in the corner of the screen, so you can see a CI deploy landed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildInfo = require(ReplicatedStorage.Shared.BuildInfo)

local gui = Instance.new("ScreenGui")
gui.Name = "BuildLabel"
gui.ResetOnSpawn = false

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(1, 1)
label.Position = UDim2.new(1, -8, 1, -8)
label.Size = UDim2.fromOffset(260, 24)
label.BackgroundTransparency = 0.4
label.BackgroundColor3 = Color3.new(0, 0, 0)
label.TextColor3 = Color3.new(1, 1, 1)
label.TextScaled = true
label.Font = Enum.Font.Code
label.Text = `ooh you like boys... :3 build {BuildInfo.commit}`
label.Parent = gui

gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
