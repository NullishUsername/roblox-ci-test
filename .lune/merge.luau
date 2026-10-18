--!strict
-- Merges the Rojo-built code into the base place (the map exported from Studio),
-- so publishing doesn't wipe the builds.
--
-- Usage: lune run merge [base.rbxl] [code.rbxl] [game.rbxl]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local basePath = process.args[1] or "base.rbxl"
local codePath = process.args[2] or "code.rbxl"
local outPath = process.args[3] or "game.rbxl"

-- Only these folders are replaced. Everything else in the base place (the map,
-- builders' models, lighting, etc.) is left untouched.
-- Keep this in sync with default.project.json.
local MANAGED = {
	{ "ServerScriptService", "Server" },
	{ "ReplicatedStorage", "Shared" },
	{ "StarterPlayer", "StarterPlayerScripts", "Client" },
}

if not fs.isFile(basePath) then
	error(`Base place '{basePath}' not found. Export your place from Studio (File > Save to File As) and commit it.`)
end

local base = roblox.deserializePlace(fs.readFile(basePath))
local code = roblox.deserializePlace(fs.readFile(codePath))

local function pathString(path: { string }): string
	return table.concat(path, ".")
end

-- Returns the parent container of the last path element.
local function parentOf(root: any, path: { string }): any?
	local inst = root:GetService(path[1])
	for i = 2, #path - 1 do
		inst = inst:FindFirstChild(path[i])
		if inst == nil then
			return nil
		end
	end
	return inst
end

for _, path in MANAGED do
	local name = path[#path]

	local src = parentOf(code, path)
	local new = src and src:FindFirstChild(name)
	if new == nil then
		error(`Missing in Rojo build: {pathString(path)} (check default.project.json)`)
	end

	local dst = parentOf(base, path)
	if dst == nil then
		error(`Missing container in base place: {pathString(path)}`)
	end

	local old = dst:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	new:Clone().Parent = dst

	print(`  replaced {pathString(path)}`)
end

fs.writeFile(outPath, roblox.serializePlace(base))
print(`Merged {codePath} into {basePath} -> {outPath}`)
