local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildInfo = require(ReplicatedStorage.Shared.BuildInfo)

print(`[CI test] Server running build {BuildInfo.commit} (built {BuildInfo.builtAt})`)

-- Also visible from Studio's Explorer / properties on Workspace
workspace:SetAttribute("BuildCommit", BuildInfo.commit)
