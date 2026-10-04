--[[
	Remotes - one client->server action channel, one server->client event channel.

	Everything else rides on instance attributes, which replicate for free and are
	already throttled by the writers in Server/Attributes.lua. Keeping the remote
	surface tiny makes the protocol easy to reason about when you extend the game.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local FOLDER_NAME = "BlacksiteNet"

Remotes.Actions = {
	Join = "join", -- ask to be added to the active round
	Move = "move", -- sprint / crouch intent (the server turns this into WalkSpeed)
	Flash = "flash", -- flashlight toggled (the Hollow reacts to your beam)
	Spectate = "spectate", -- cycle spectator target
	Restart = "restart", -- ready up again from the results screen
	Debug = "debug", -- dev-only ping
}

Remotes.Events = {
	Toast = "toast", -- HUD message
	Hit = "hit", -- grabbed by the Hollow
	Scare = "scare", -- jump scare sting
	Phase = "phase", -- round phase changed
	Fade = "fade", -- request a black fade
	Reveal = "reveal", -- the Hollow just stepped into your light
	Shake = "shake", -- camera kick
	Sound = "sound", -- play a configured sound id at a position
}

--- Server only: build the remote folder.
--- Both entry points hand back the same shape: a handle whose metatable carries the
--- send helpers, so callers write remotes:toClient(...) anywhere.
local function handle(action, event)
	return setmetatable({ Action = action, Event = event }, { __index = Remotes })
end

function Remotes.ensure()
	local shared = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not shared then
		shared = Instance.new("Folder")
		shared.Name = FOLDER_NAME
		shared.Parent = ReplicatedStorage
	end

	local function get(name)
		local inst = shared:FindFirstChild(name)
		if not inst then
			inst = Instance.new("RemoteEvent")
			inst.Name = name
			inst.Parent = shared
		end
		return inst
	end

	return handle(get("Action"), get("Event"))
end

--- Client (and server) side: fetch the already-created remotes.
function Remotes.get()
	local shared = ReplicatedStorage:WaitForChild(FOLDER_NAME, 30)
	if not shared then
		return nil
	end
	return handle(shared:WaitForChild("Action", 30), shared:WaitForChild("Event", 30))
end

--- Fire an action at the server. Tolerates a missing remote (solo Studio testing).
function Remotes.fire(self, action, ...)
	if self.Action then
		self.Action:FireServer(action, ...)
	end
end

--- Fire an event at one client from the server.
function Remotes.toClient(self, player, event, ...)
	if self.Event then
		self.Event:FireClient(player, event, ...)
	end
end

function Remotes.toAll(self, event, ...)
	if self.Event then
		self.Event:FireAllClients(event, ...)
	end
end

return Remotes
