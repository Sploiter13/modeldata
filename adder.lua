--!native
--!optimize 2

---- environment ----
local assert, typeof, tonumber = assert, typeof, tonumber
local pcall, pairs, ipairs = pcall, pairs, ipairs
local task_wait, task_spawn = task.wait, task.spawn
local table_insert, table_remove = table.insert, table.remove
local string_sub, string_lower, string_upper = string.sub, string.lower, string.upper
local math_floor, math_min, math_max = math.floor, math.min, math.max
local vector_create = vector.create

local game = game
local workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MouseService = game:GetService("MouseService")

---- severe globals guards ----
local getmouseposition_fn = getmouseposition
if typeof(getmouseposition_fn) ~= "function" then
	getmouseposition_fn = function()
		return MouseService:GetMouseLocation()
	end
end

local isleftpressed_fn = isleftpressed
assert(typeof(isleftpressed_fn) == "function", "Missing isleftpressed()")
assert(typeof(DrawingImmediate) == "table", "Missing DrawingImmediate")

local getpressedkey_fn = getpressedkey
local getpressedkeys_fn = getpressedkeys
assert(typeof(getpressedkey_fn) == "function", "Missing getpressedkey()")
assert(typeof(getpressedkeys_fn) == "function", "Missing getpressedkeys()")

local override_local_data = override_local_data
local add_model_data = add_model_data
local edit_model_data = edit_model_data
local remove_model_data = remove_model_data
assert(typeof(add_model_data) == "function", "Missing add_model_data()")
assert(typeof(edit_model_data) == "function", "Missing edit_model_data()")
assert(typeof(remove_model_data) == "function", "Missing remove_model_data()")
assert(typeof(override_local_data) == "function", "Missing override_local_data()")

---- constants ----
local DEFAULT_NAMES = {
	HumanoidRootPart = { "HumanoidRootPart", "Root" },
	R6 = {
		Head = { "Head" },
		Torso = { "Torso", "Body" },
		["Left Arm"] = { "Left Arm", "LeftArm" },
		["Right Arm"] = { "Right Arm", "RightArm" },
		["Left Leg"] = { "Left Leg", "LeftLeg" },
		["Right Leg"] = { "Right Leg", "RightLeg" },
	},
	R15 = {
		Head = { "Head" },
		UpperTorso = { "UpperTorso" },
		LowerTorso = { "LowerTorso" },
		LeftUpperArm = { "LeftUpperArm" },
		LeftLowerArm = { "LeftLowerArm" },
		LeftHand = { "LeftHand" },
		RightUpperArm = { "RightUpperArm" },
		RightLowerArm = { "RightLowerArm" },
		RightHand = { "RightHand" },
		LeftUpperLeg = { "LeftUpperLeg" },
		LeftLowerLeg = { "LeftLowerLeg" },
		LeftFoot = { "LeftFoot" },
		RightUpperLeg = { "RightUpperLeg" },
		RightLowerLeg = { "RightLowerLeg" },
		RightFoot = { "RightFoot" },
	},
}

local R6_KEYS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local R15_KEYS = {
	"Head",
	"UpperTorso", "LowerTorso",
	"LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"RightUpperLeg", "RightLowerLeg", "RightFoot",
}

---- variables ----
local PARTCFG = {
	R6 = {
		Head = "Head",
		Torso = "Torso",
		["Left Arm"] = "Left Arm",
		["Right Arm"] = "Right Arm",
		["Left Leg"] = "Left Leg",
		["Right Leg"] = "Right Leg",
	},
	R15 = {
		Head = "Head",
		UpperTorso = "UpperTorso",
		LowerTorso = "LowerTorso",
		LeftUpperArm = "LeftUpperArm",
		LeftLowerArm = "LeftLowerArm",
		LeftHand = "LeftHand",
		RightUpperArm = "RightUpperArm",
		RightLowerArm = "RightLowerArm",
		RightHand = "RightHand",
		LeftUpperLeg = "LeftUpperLeg",
		LeftLowerLeg = "LeftLowerLeg",
		LeftFoot = "LeftFoot",
		RightUpperLeg = "RightUpperLeg",
		RightLowerLeg = "RightLowerLeg",
		RightFoot = "RightFoot",
	},
}

local Watched: {[string]: Instance} = {}
local WatchEnabled: {[string]: boolean} = {}
local ScanStacks: {[string]: {Instance}} = {}
local Registered: {[string]: {inst: Instance, humanoid: Instance}} = {}

type Node = {
	inst: Instance,
	id: string,
	name: string,
	class: string,
	depth: number,
	expandable: boolean,
}

local UI = {
	pos = vector_create(70, 110, 0),
	size = vector_create(640, 430, 0),
	pad = 8,
	header_h = 26,
	row_h = 18,
	indent = 16,
	scroll_w = 10,
	btn_watch_w = 78,
	btn_addas_w = 62,
	btn_gap = 6,
	font = "Tamzen",
	font_size = 13,
	col_bg = Color3.new(0.06, 0.06, 0.08),
	col_header = Color3.new(0.12, 0.12, 0.16),
	col_border = Color3.new(0.65, 0.65, 0.78),
	col_text = Color3.new(0.92, 0.92, 0.92),
	col_dim = Color3.new(0.75, 0.75, 0.80),
	col_btn_on = Color3.new(0.20, 0.75, 0.35),
	col_btn_off = Color3.new(0.75, 0.25, 0.25),
	col_btn_neutral = Color3.new(0.20, 0.55, 0.85),
	col_scroll_track = Color3.new(0.03, 0.03, 0.04),
	col_scroll_thumb = Color3.new(0.45, 0.45, 0.52),
	col_cfg_bg = Color3.new(0.08, 0.08, 0.10),
	col_cfg_field_bg = Color3.new(0.05, 0.05, 0.07),
	col_menu_bg = Color3.new(0.08, 0.08, 0.11),
}

local ui_open = true
local ui_minimized = false
local dragging = false
local drag_dx, drag_dy = 0, 0
local nodes: {Node} = {}
local expanded: {[string]: boolean} = {}
local scroll = 0
local content_h = 0
local last_left = false
local rebuild_requested = true
local rebuild_running = false
local last_rebuild = 0

local config_open = false
local config_tab = 0
local focused_field: { tab: number, key: string }? = nil

local pressed_prev: {[string]: boolean} = {}
local hold_next_at: {[string]: number} = {}
local INITIAL_REPEAT = 0.35
local REPEAT_RATE = 0.04

local selected_part: Instance? = nil
local selected_part_id: string? = nil
local sel_visible = false
local sel_min = vector_create(0, 0, 0)
local sel_max = vector_create(0, 0, 0)
local SEL_OUTLINE = Color3.new(0.35, 0.65, 1.0)
local SEL_FILL = Color3.new(0.15, 0.35, 0.8)
local SEL_THICKNESS = 2
local SEL_FILL_ALPHA = 0.12
local SEL_OUTLINE_ALPHA = 0.95

local addas_open = false
local addas_target: Instance? = nil
local addas_pos = vector_create(0, 0, 0)
local addas_items: {string} = {}
local addas_item_h = 18
local addas_w = 210
local addas_h = 0

---- functions ----
local function clamp(x: number, a: number, b: number): number
	if x < a then return a end
	if x > b then return b end
	return x
end

local function point_in(px: number, py: number, x: number, y: number, w: number, h: number): boolean
	return (px >= x and px <= x + w and py >= y and py <= y + h)
end

local function get_id(obj: Instance): string
	return (obj and obj.Data) or tostring(obj)
end

local function get_children_safe(inst: Instance): {Instance}
	local ok, res = pcall(function()
		return inst:GetChildren()
	end)
	if ok and res then
		return res
	end
	return {}
end

local function truncate_to_px(text: string, max_px: number, font_size: number): string
	local char_w = math_max(6, math_floor(font_size * 0.55))
	local max_chars = math_max(0, math_floor(max_px / char_w))
	if #text <= max_chars then
		return text
	end
	if max_chars <= 3 then
		return string_sub(text, 1, max_chars)
	end
	return string_sub(text, 1, max_chars - 3) .. "..."
end

local function is_container_class(class: string): boolean
	return (class == "Workspace") or (class == "Folder") or (class == "Model") or (class == "Players") or (class == "Player")
end

local function is_selectable_part_class(class: string): boolean
	return (class == "Part") or (class == "MeshPart")
end

local function build_name_candidates(custom_name: string?, defaults: {string}): {string}
	local out = {}
	if typeof(custom_name) == "string" and custom_name ~= "" then
		out[#out + 1] = custom_name
	end
	for i = 1, #defaults do
		out[#out + 1] = defaults[i]
	end
	return out
end

local function find_first_child_any_ci(model: Instance, names: {string}): Instance?
	if not model or model.ClassName ~= "Model" then
		return nil
	end
	if typeof(names) ~= "table" then
		return nil
	end

	local children = get_children_safe(model)
	local map: {[string]: Instance} = {}
	for i = 1, #children do
		local c = children[i]
		if c then
			local okn, n = pcall(function()
				return c.Name
			end)
			if okn and typeof(n) == "string" then
				map[string_lower(n)] = c
			end
		end
	end

	for i = 1, #names do
		local n = names[i]
		if typeof(n) == "string" and n ~= "" then
			local inst = map[string_lower(n)]
			if inst then
				return inst
			end
		end
	end
	return nil
end

local function try_get_humanoid(model: Instance): Instance?
	if not model or model.ClassName ~= "Model" then
		return nil
	end
	local ok, hum = pcall(function()
		return model:FindFirstChildOfClass("Humanoid")
	end)
	if ok then
		return hum
	end
	return nil
end

local function detect_rig_kind(model: Instance): number
	if not model or model.ClassName ~= "Model" then
		return 0
	end

	local upper = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R15.UpperTorso, DEFAULT_NAMES.R15.UpperTorso))
	local lower = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R15.LowerTorso, DEFAULT_NAMES.R15.LowerTorso))
	if upper or lower then
		return 1
	end
	return 0
end

local function get_entity_parts(model: Instance): ({[string]: Instance?}, number)
	local parts: {[string]: Instance?} = {}
	if not model or model.ClassName ~= "Model" then
		return parts, 0
	end

	local rig = detect_rig_kind(model)
	parts.HumanoidRootPart = find_first_child_any_ci(model, DEFAULT_NAMES.HumanoidRootPart)

	if rig == 0 then
		parts.Head = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R6.Head, DEFAULT_NAMES.R6.Head))
		parts.Torso = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R6.Torso, DEFAULT_NAMES.R6.Torso))
		parts.LeftArm = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R6["Left Arm"], DEFAULT_NAMES.R6["Left Arm"]))
		parts.RightArm = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R6["Right Arm"], DEFAULT_NAMES.R6["Right Arm"]))
		parts.LeftLeg = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R6["Left Leg"], DEFAULT_NAMES.R6["Left Leg"]))
		parts.RightLeg = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R6["Right Leg"], DEFAULT_NAMES.R6["Right Leg"]))
		return parts, 0
	end

	parts.Head = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R15.Head, DEFAULT_NAMES.R15.Head))
	parts.UpperTorso = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R15.UpperTorso, DEFAULT_NAMES.R15.UpperTorso))
	parts.LowerTorso = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R15.LowerTorso, DEFAULT_NAMES.R15.LowerTorso))
	parts.LeftUpperArm = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R15.LeftUpperArm, DEFAULT_NAMES.R15.LeftUpperArm))
	parts.LeftLowerArm = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R15.LeftLowerArm, DEFAULT_NAMES.R15.LeftLowerArm))
	parts.LeftHand = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R15.LeftHand, DEFAULT_NAMES.R15.LeftHand))
	parts.RightUpperArm = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R15.RightUpperArm, DEFAULT_NAMES.R15.RightUpperArm))
	parts.RightLowerArm = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R15.RightLowerArm, DEFAULT_NAMES.R15.RightLowerArm))
	parts.RightHand = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R15.RightHand, DEFAULT_NAMES.R15.RightHand))
	parts.LeftUpperLeg = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R15.LeftUpperLeg, DEFAULT_NAMES.R15.LeftUpperLeg))
	parts.LeftLowerLeg = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R15.LeftLowerLeg, DEFAULT_NAMES.R15.LeftLowerLeg))
	parts.LeftFoot = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R15.LeftFoot, DEFAULT_NAMES.R15.LeftFoot))
	parts.RightUpperLeg = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R15.RightUpperLeg, DEFAULT_NAMES.R15.RightUpperLeg))
	parts.RightLowerLeg = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R15.RightLowerLeg, DEFAULT_NAMES.R15.RightLowerLeg))
	parts.RightFoot = find_first_child_any_ci(model, build_name_candidates(PARTCFG.R15.RightFoot, DEFAULT_NAMES.R15.RightFoot))
	return parts, 1
end

local function build_model_data(model: Instance, userid: number, username: string, displayname: string, teamname: string): (string?, {[string]: any}?, Instance?)
	if not model or model.ClassName ~= "Model" then
		return nil, nil, nil
	end

	local hum = try_get_humanoid(model)
	if not hum then
		return nil, nil, nil
	end

	local parts, rig = get_entity_parts(model)
	if not parts.Head or not parts.HumanoidRootPart then
		return nil, nil, nil
	end

	local health, max_health = 100, 100
	pcall(function()
		health = hum.Health
		max_health = hum.MaxHealth
	end)

	local key = tostring(model)
	local primary = model.PrimaryPart or parts.HumanoidRootPart
	local torso = parts.Torso or parts.UpperTorso or parts.LowerTorso
	local left_arm = parts.LeftArm or parts.LeftUpperArm or parts.LeftLowerArm or parts.LeftHand
	local right_arm = parts.RightArm or parts.RightUpperArm or parts.RightLowerArm or parts.RightHand
	local left_leg = parts.LeftLeg or parts.LeftUpperLeg or parts.LeftLowerLeg or parts.LeftFoot
	local right_leg = parts.RightLeg or parts.RightUpperLeg or parts.RightLowerLeg or parts.RightFoot

	local data: {[string]: any} = {
		Username = username,
		Displayname = displayname,
		Userid = userid,
		Character = model,
		PrimaryPart = primary,
		Humanoid = hum,
		Head = parts.Head,
		Torso = torso,
		LeftArm = left_arm,
		RightArm = right_arm,
		LeftLeg = left_leg,
		RightLeg = right_leg,
		UpperTorso = parts.UpperTorso,
		LowerTorso = parts.LowerTorso,
		LeftUpperArm = parts.LeftUpperArm,
		LeftLowerArm = parts.LeftLowerArm,
		LeftHand = parts.LeftHand,
		RightUpperArm = parts.RightUpperArm,
		RightLowerArm = parts.RightLowerArm,
		RightHand = parts.RightHand,
		LeftUpperLeg = parts.LeftUpperLeg,
		LeftLowerLeg = parts.LeftLowerLeg,
		LeftFoot = parts.LeftFoot,
		RightUpperLeg = parts.RightUpperLeg,
		RightLowerLeg = parts.RightLowerLeg,
		RightFoot = parts.RightFoot,
		BodyHeightScale = 1,
		RigType = rig,
		Toolname = "Unknown",
		Teamname = teamname,
		Whitelisted = false,
		Archenemies = false,
		Aimbot_Part = parts.Head,
		Aimbot_TP_Part = parts.Head,
		Triggerbot_Part = parts.Head,
		Health = health,
		MaxHealth = max_health,
	}

	return key, data, hum
end

local function try_register_model(model: Instance)
	if not model or model.ClassName ~= "Model" then
		return
	end

	local lp = Players.LocalPlayer
	local lc = lp and lp.Character
	if lc and model == lc then
		return
	end

	local hum = try_get_humanoid(model)
	if not hum then
		return
	end

	local id, data, humanoid = build_model_data(model, -1, tostring(model), model.Name, "NPC")
	if not id or not data or not humanoid then
		return
	end

	if not Registered[id] then
		local ok = pcall(function()
			add_model_data(data, id)
		end)
		if ok then
			Registered[id] = { inst = model, humanoid = humanoid }
		end
	else
		pcall(function()
			edit_model_data({ Health = humanoid.Health, MaxHealth = humanoid.MaxHealth }, id)
		end)
	end
end

local function try_register_player(plr: Instance)
	if not plr or plr.ClassName ~= "Player" then
		return
	end

	local lp = Players.LocalPlayer
	if lp and plr == lp then
		return
	end

	local ch = plr.Character
	if not ch then
		return
	end

	local lc = lp and lp.Character
	if lc and ch == lc then
		return
	end

	local hum = try_get_humanoid(ch)
	if not hum then
		return
	end

	local teamname = "No Team"
	pcall(function()
		local t = plr.Team
		if t then teamname = tostring(t) end
	end)

	local id, data, humanoid = build_model_data(ch, plr.UserId, plr.Name, plr.DisplayName, teamname)
	if not id or not data or not humanoid then
		return
	end

	if not Registered[id] then
		local ok = pcall(function()
			add_model_data(data, id)
		end)
		if ok then
			Registered[id] = { inst = ch, humanoid = humanoid }
		end
	else
		pcall(function()
			edit_model_data({ Health = humanoid.Health, MaxHealth = humanoid.MaxHealth }, id)
		end)
	end
end

local function watcher_cleanup()
	for key, entry in pairs(Registered) do
		if typeof(entry) ~= "table" then
			Registered[key] = nil
			pcall(function()
				remove_model_data(key)
			end)
			continue
		end

		local inst = entry.inst
		local hum = entry.humanoid
		local dead = false

		local ok_inst = pcall(function()
			return inst and (inst.Parent ~= nil)
		end)
		local ok_hum = pcall(function()
			return hum and (hum.Parent ~= nil)
		end)

		if (not ok_inst) or (not ok_hum) then
			dead = true
		elseif (not inst) or (not hum) then
			dead = true
		else
			local ok_hp, hp = pcall(function()
				return hum.Health
			end)
			if (not ok_hp) or (typeof(hp) ~= "number") or (hp <= 0) then
				dead = true
			end
		end

		if dead then
			pcall(function()
				remove_model_data(key)
			end)
			Registered[key] = nil
		else
			pcall(function()
				edit_model_data({ Health = hum.Health, MaxHealth = hum.MaxHealth }, key)
			end)
		end
	end
end

local function update_local_override()
	local plr = Players.LocalPlayer
	if not plr then return end
	local ch = plr.Character
	if not ch then return end
	local hum = try_get_humanoid(ch)
	if not hum then return end
	local parts, rig = get_entity_parts(ch)
	if not parts.Head then return end

	local root = parts.HumanoidRootPart

	local data = {
		LocalPlayer = plr,
		Displayname = plr.DisplayName,
		Username = plr.Name,
		Userid = plr.UserId,
		Character = ch,
		Team = plr.Team,
		RootPart = root,
		Head = parts.Head,
		LowerTorso = parts.LowerTorso,
		Humanoid = hum,
		Health = hum.Health,
		MaxHealth = hum.MaxHealth,
		RigType = rig,
	}

	pcall(function()
		override_local_data(data)
	end)
end

local function watch_toggle(inst: Instance)
	if not inst then return end
	if inst ~= workspace and not inst.Parent then return end

	local id = get_id(inst)
	local on = WatchEnabled[id] and true or false
	WatchEnabled[id] = not on

	if WatchEnabled[id] then
		Watched[id] = inst
		ScanStacks[id] = { inst }
	else
		Watched[id] = nil
		ScanStacks[id] = nil
	end
end

local function watcher_step(step_budget: number)
	local steps = 0

	for wid, root in pairs(Watched) do
		if steps >= step_budget then
			break
		end

		if not WatchEnabled[wid] then
			Watched[wid] = nil
			ScanStacks[wid] = nil
			continue
		end

		if root ~= workspace and not root.Parent then
			Watched[wid] = nil
			WatchEnabled[wid] = nil
			ScanStacks[wid] = nil
			continue
		end

		local stack = ScanStacks[wid]
		if not stack then
			stack = { root }
			ScanStacks[wid] = stack
		end

		while steps < step_budget and #stack > 0 do
			local inst = stack[#stack]
			stack[#stack] = nil
			steps += 1

			if inst and (inst == workspace or inst.Parent) then
				if inst.ClassName == "Model" then
					try_register_model(inst)
				end

				if is_container_class(inst.ClassName) then
					local children = get_children_safe(inst)
					for i = 1, #children do
						local c = children[i]
						if c and (c == workspace or c.Parent) then
							stack[#stack + 1] = c
						end
					end
				end
			end
		end

		if #stack == 0 then
			stack[#stack + 1] = root
		end
	end

	local pls = Players:GetChildren()
	for i = 1, #pls do
		if steps >= step_budget then
			break
		end
		local p = pls[i]
		if p and p.ClassName == "Player" then
			try_register_player(p)
			steps += 1
		end
	end
end

---- keyboard ----
local function keyname_to_char(name: string): string?
	if typeof(name) ~= "string" then
		return nil
	end
	if #name == 1 then
		local up = string_upper(name)
		return up
	end

	local map = {
		Space = " ",
		Minus = "-",
		Equals = "=",
		Comma = ",",
		Period = ".",
		Slash = "/",
		Semicolon = ";",
		Quote = "'",
		LeftBracket = "[",
		RightBracket = "]",
		BackSlash = "\\",
		BackQuote = "`",
	}
	return map[name]
end

local function apply_keyname_to_focused(name: string)
	if not focused_field then
		return
	end

	local tab = (focused_field.tab == 0) and PARTCFG.R6 or PARTCFG.R15
	local key = focused_field.key
	local cur = tab[key] or ""

	if name == "Escape" or name == "Enter" then
		focused_field = nil
		return
	end

	if name == "Backspace" then
		if #cur > 0 then
			tab[key] = string.sub(cur, 1, #cur - 1)
		end
		return
	end

	local ch = keyname_to_char(name)
	if not ch then
		return
	end

	if #cur < 64 then
		tab[key] = cur .. ch
	end
end

local function read_pressed_set_names(): {[string]: boolean}
	local set: {[string]: boolean} = {}
	local ok, keys = pcall(getpressedkeys_fn)
	if ok and typeof(keys) == "table" then
		for _, k in ipairs(keys) do
			if typeof(k) == "string" and k ~= "None" then
				set[k] = true
			end
		end
		return set
	end

	local ok2, k2 = pcall(getpressedkey_fn)
	if ok2 and typeof(k2) == "string" and k2 ~= "None" then
		set[k2] = true
	end
	return set
end

local function poll_text_input()
	if not focused_field then
		pressed_prev = {}
		hold_next_at = {}
		return
	end

	local now = os.clock()
	local pressed_now = read_pressed_set_names()

	for name, _ in pairs(pressed_now) do
		if not pressed_prev[name] then
			apply_keyname_to_focused(name)
			hold_next_at[name] = now + INITIAL_REPEAT
		end
	end

	local bs = "Backspace"
	if pressed_now[bs] and hold_next_at[bs] and now >= hold_next_at[bs] then
		hold_next_at[bs] = now + REPEAT_RATE
		apply_keyname_to_focused(bs)
	end

	pressed_prev = pressed_now
end

---- selection bounds ----
local function update_selection_bounds()
	sel_visible = false
	local part = selected_part
	if not part or (part ~= workspace and not part.Parent) then
		selected_part = nil
		selected_part_id = nil
		return
	end

	if not is_selectable_part_class(part.ClassName) then
		selected_part = nil
		selected_part_id = nil
		return
	end

	local cam = workspace.CurrentCamera
	if not cam then
		return
	end

	local ok, pos, size, rvec, uvec, lvec = pcall(function()
		return part.Position, part.Size, part.RightVector, part.UpVector, part.LookVector
	end)
	if not ok or not pos or not size or not rvec or not uvec or not lvec then
		return
	end

	local hx = size.X * 0.5
	local hy = size.Y * 0.5
	local hz = size.Z * 0.5
	local minx, miny = math.huge, math.huge
	local maxx, maxy = -math.huge, -math.huge
	local any = false

	for sx = -1, 1, 2 do
		for sy = -1, 1, 2 do
			for sz = -1, 1, 2 do
				local corner = pos + (rvec * (hx * sx)) + (uvec * (hy * sy)) + (lvec * (hz * sz))
				local ok2, screen = pcall(function()
					return cam:WorldToScreenPoint(corner)
				end)
				if ok2 and screen then
					any = true
					local x, y = screen.X, screen.Y
					if x < minx then minx = x end
					if y < miny then miny = y end
					if x > maxx then maxx = x end
					if y > maxy then maxy = y end
				end
			end
		end
	end

	if not any or minx == math.huge then
		return
	end

	sel_min = vector_create(minx, miny, 0)
	sel_max = vector_create(maxx, maxy, 0)
	sel_visible = true
end

---- Add As menu ----
local function open_addas_menu(target: Instance, mouse_x: number, mouse_y: number)
	addas_target = target
	addas_open = true

	addas_items = {}
	local src = (config_tab == 0) and R6_KEYS or R15_KEYS
	for i = 1, #src do
		addas_items[#addas_items + 1] = src[i]
	end

	addas_h = (#addas_items * addas_item_h) + 10

	local x0 = UI.pos.X
	local y0 = UI.pos.Y
	local w = UI.size.X
	local h = UI.size.Y
	local maxx = (x0 + w - 6) - addas_w
	local maxy = (y0 + h - 6) - addas_h
	local px = clamp(mouse_x + 10, x0 + 6, maxx)
	local py = clamp(mouse_y + 10, y0 + 6, maxy)
	addas_pos = vector_create(px, py, 0)
end

local function close_addas_menu()
	addas_open = false
	addas_target = nil
	addas_items = {}
	addas_h = 0
end

local function apply_addas_choice(choice: string)
	local target = addas_target
	if not target or (target ~= workspace and not target.Parent) then
		close_addas_menu()
		return
	end

	local tab = (config_tab == 0) and PARTCFG.R6 or PARTCFG.R15
	tab[choice] = target.Name

	config_open = true
	focused_field = { tab = config_tab, key = choice }
	close_addas_menu()
end

---- async tree rebuild ----
local function request_rebuild()
	rebuild_requested = true
end

local function build_tree_async()
	if rebuild_running then
		return
	end
	rebuild_running = true
	rebuild_requested = false

	task_spawn(function()
		local out: {Node} = {}
		local out_h = 0
		local processed = 0

		local function push(inst: Instance, depth: number)
			if not inst or (inst ~= workspace and not inst.Parent) then
				return
			end

			local class = inst.ClassName
			local show = (inst == workspace) or (inst == Players)
				or (class == "Folder") or (class == "Model") or (class == "Player")
				or is_selectable_part_class(class)

			if not show then
				return
			end

			local id = get_id(inst)
			local expandable = (inst == workspace) or (inst == Players) or (class == "Folder") or (class == "Model")

			table_insert(out, {
				inst = inst,
				id = id,
				name = inst.Name,
				class = class,
				depth = depth,
				expandable = expandable,
			})
			out_h += UI.row_h

			if expandable and expanded[id] then
				local children = get_children_safe(inst)
				for i = 1, #children do
					local c = children[i]
					if c and (c == workspace or c.Parent) then
						push(c, depth + 1)
					end
					processed += 1
					if (processed % 350) == 0 then
						task_wait()
					end
				end
			end
		end

		push(workspace, 0)
		push(Players, 0)

		nodes = out
		content_h = out_h
		last_rebuild = os.clock()
		rebuild_running = false
	end)
end

---- UI update + render ----
local function ui_update_loop()
	if not ui_open then
		return
	end

	if rebuild_requested or (os.clock() - last_rebuild > 1.0) then
		build_tree_async()
	end

	local mouse = getmouseposition_fn()
	local mx, my = mouse.X, mouse.Y
	local left = isleftpressed_fn()
	local just_pressed = left and not last_left
	local just_released = (not left) and last_left
	last_left = left

	local x0, y0 = UI.pos.X, UI.pos.Y
	local w, h = UI.size.X, UI.size.Y

	local btn_w = 18
	local btn_min_x = x0 + w - UI.pad - btn_w
	local btn_cfg_x = btn_min_x - 6 - btn_w
	local btn_y = y0 + 4
	local btn_h = UI.header_h - 8

	if just_pressed and point_in(mx, my, btn_min_x, btn_y, btn_w, btn_h) then
		ui_minimized = not ui_minimized
		focused_field = nil
		close_addas_menu()
		return
	end

	if just_pressed and point_in(mx, my, btn_cfg_x, btn_y, btn_w, btn_h) then
		config_open = not config_open
		focused_field = nil
		close_addas_menu()
		return
	end

	if just_pressed
		and point_in(mx, my, x0, y0, w, UI.header_h)
		and (not point_in(mx, my, btn_cfg_x, btn_y, btn_w, btn_h))
		and (not point_in(mx, my, btn_min_x, btn_y, btn_w, btn_h))
	then
		dragging = true
		drag_dx = mx - x0
		drag_dy = my - y0
	end

	if dragging and left then
		UI.pos = vector_create(mx - drag_dx, my - drag_dy, 0)
		return
	end

	if just_released then
		dragging = false
	end

	if ui_minimized then
		return
	end

	poll_text_input()
	update_selection_bounds()

	local inner_x0 = x0 + UI.pad
	local inner_y0 = y0 + UI.header_h + UI.pad
	local inner_h = h - UI.header_h - UI.pad * 2
	local inner_w = w - UI.pad * 2 - UI.scroll_w - 4

	local max_scroll = math_max(0, content_h - inner_h)
	scroll = clamp(scroll, 0, max_scroll)

	if addas_open and just_pressed then
		local mx0, my0 = addas_pos.X, addas_pos.Y
		if point_in(mx, my, mx0, my0, addas_w, addas_h) then
			local rel_y = my - (my0 + 6)
			if rel_y >= 0 then
				local idx = math_floor(rel_y / addas_item_h) + 1
				local choice = addas_items[idx]
				if choice then
					apply_addas_choice(choice)
					return
				end
			end
			return
		else
			close_addas_menu()
		end
	end

	local panel_w = 270
	local panel_x0 = x0 + w - UI.pad - panel_w
	local panel_y0 = inner_y0

	if config_open and just_pressed then
		if point_in(mx, my, panel_x0, panel_y0, panel_w, inner_h) then
			local rx = mx - panel_x0
			local ry = my - panel_y0

			local tab_y = 28
			local tab_h = 20
			local tab_w = math_floor((panel_w - 24) / 2)
			local tab_x0 = 10
			local tab_x1 = tab_x0 + tab_w + 4

			if point_in(rx, ry, tab_x0, tab_y, tab_w, tab_h) then
				config_tab = 0
				focused_field = nil
				return
			end

			if point_in(rx, ry, tab_x1, tab_y, tab_w, tab_h) then
				config_tab = 1
				focused_field = nil
				return
			end

			local list = (config_tab == 0) and R6_KEYS or R15_KEYS
			local y = tab_y + tab_h + 10
			local row_hh = 20
			local label_w = 120
			local box_x = 10 + label_w + 8
			local box_w = panel_w - box_x - 10

			for i = 1, #list do
				local k = list[i]
				if point_in(rx, ry, box_x, y + 2, box_w, row_hh - 4) then
					focused_field = { tab = config_tab, key = k }
					return
				end
				y += row_hh
			end

			focused_field = nil
			return
		else
			focused_field = nil
		end
	end

	local sb_x = x0 + w - UI.pad - UI.scroll_w
	if just_pressed and point_in(mx, my, sb_x, inner_y0, UI.scroll_w, inner_h) then
		local thumb_h = (content_h > 0) and clamp((inner_h / content_h) * inner_h, 26, inner_h) or inner_h
		local thumb_y = inner_y0 + ((max_scroll > 0) and ((scroll / max_scroll) * (inner_h - thumb_h)) or 0)
		if my < thumb_y then
			scroll = clamp(scroll - inner_h, 0, max_scroll)
		elseif my > thumb_y + thumb_h then
			scroll = clamp(scroll + inner_h, 0, max_scroll)
		end
		return
	end

	local view_w = inner_w
	if config_open then
		view_w = math_max(160, (panel_x0 - inner_x0) - 10)
	end

	if just_pressed and point_in(mx, my, inner_x0, inner_y0, view_w, inner_h) then
		local idx = math_floor(((my - inner_y0) + scroll) / UI.row_h) + 1
		local node = nodes[idx]
		if not node or not node.inst then
			return
		end

		if node.inst ~= workspace and not node.inst.Parent then
			request_rebuild()
			return
		end

		local row_y = inner_y0 + (idx - 1) * UI.row_h - scroll
		local exp_x = inner_x0 + node.depth * UI.indent

		if node.expandable and point_in(mx, my, exp_x, row_y, 12, UI.row_h) then
			expanded[node.id] = not expanded[node.id]
			request_rebuild()
			return
		end

		local watch_x = inner_x0 + view_w - UI.btn_watch_w
		local addas_x = watch_x - UI.btn_gap - UI.btn_addas_w

		if point_in(mx, my, watch_x, row_y + 2, UI.btn_watch_w, UI.row_h - 4) then
			watch_toggle(node.inst)
			return
		end

		if is_selectable_part_class(node.class) then
			if point_in(mx, my, addas_x, row_y + 2, UI.btn_addas_w, UI.row_h - 4) then
				config_open = true
				open_addas_menu(node.inst, mx, my)
				return
			end
		end

		if is_selectable_part_class(node.class) then
			local nid = node.id
			if selected_part_id == nid then
				selected_part = nil
				selected_part_id = nil
				sel_visible = false
			else
				selected_part = node.inst
				selected_part_id = nid
			end
			return
		end
	end
end

local function ui_render_loop()
	if not ui_open then
		return
	end

	local x0, y0 = UI.pos.X, UI.pos.Y
	local w, h = UI.size.X, UI.size.Y

	DrawingImmediate.FilledRectangle(UI.pos, vector_create(w, UI.header_h, 0), UI.col_header, 0.95)
	DrawingImmediate.Rectangle(UI.pos, vector_create(w, UI.header_h, 0), UI.col_border, 1, 1)
	DrawingImmediate.OutlinedText(UI.pos + vector_create(UI.pad, 6, 0), UI.font_size, UI.col_text, 1,
		ui_minimized and "Model Data Explorer (min)" or "Model Data Explorer", false, UI.font)

	local btn_w = 18
	local btn_min_x = x0 + w - UI.pad - btn_w
	local btn_cfg_x = btn_min_x - 6 - btn_w
	local btn_y = y0 + 4
	local btn_h = UI.header_h - 8

	DrawingImmediate.FilledRectangle(vector_create(btn_cfg_x, btn_y, 0), vector_create(btn_w, btn_h, 0), UI.col_border, 0.35)
	DrawingImmediate.OutlinedText(vector_create(btn_cfg_x + 6, btn_y + 2, 0), UI.font_size, UI.col_text, 1, "C", false, UI.font)
	DrawingImmediate.FilledRectangle(vector_create(btn_min_x, btn_y, 0), vector_create(btn_w, btn_h, 0), UI.col_border, 0.35)
	DrawingImmediate.OutlinedText(vector_create(btn_min_x + 6, btn_y + 2, 0), UI.font_size, UI.col_text, 1, ui_minimized and "+" or "-", false, UI.font)

	if ui_minimized then
		if sel_visible then
			local size2 = sel_max - sel_min
			DrawingImmediate.FilledRectangle(sel_min, size2, SEL_FILL, SEL_FILL_ALPHA)
			DrawingImmediate.Rectangle(sel_min, size2, SEL_OUTLINE, SEL_OUTLINE_ALPHA, SEL_THICKNESS)
		end
		return
	end

	DrawingImmediate.FilledRectangle(UI.pos + vector_create(0, UI.header_h, 0), vector_create(w, h - UI.header_h, 0), UI.col_bg, 0.92)
	DrawingImmediate.Rectangle(UI.pos, vector_create(w, h, 0), UI.col_border, 1, 1)

	local inner_x0 = x0 + UI.pad
	local inner_y0 = y0 + UI.header_h + UI.pad
	local inner_h = h - UI.header_h - UI.pad * 2
	local inner_w = w - UI.pad * 2 - UI.scroll_w - 4

	local sb_x = x0 + w - UI.pad - UI.scroll_w
	DrawingImmediate.FilledRectangle(vector_create(sb_x, inner_y0, 0), vector_create(UI.scroll_w, inner_h, 0), UI.col_scroll_track, 0.9)

	local max_scroll = math_max(0, content_h - inner_h)
	scroll = clamp(scroll, 0, max_scroll)
	local thumb_h = (content_h > 0) and clamp((inner_h / content_h) * inner_h, 26, inner_h) or inner_h
	local thumb_y = inner_y0 + ((max_scroll > 0) and ((scroll / max_scroll) * (inner_h - thumb_h)) or 0)
	DrawingImmediate.FilledRectangle(vector_create(sb_x, thumb_y, 0), vector_create(UI.scroll_w, thumb_h, 0), UI.col_scroll_thumb, 0.95)

	local view_w = inner_w
	local panel_w = 270
	local panel_x0 = x0 + w - UI.pad - panel_w
	if config_open then
		view_w = math_max(160, (panel_x0 - inner_x0) - 10)
	end

	-- ✅ FIX: Only render rows that are fully or partially within visible bounds
	local first = math_max(1, math_floor(scroll / UI.row_h) + 1)
	local last = math_min(#nodes, first + math_floor(inner_h / UI.row_h) + 2)

	for i = first, last do
		local n = nodes[i]
		local row_y = inner_y0 + (i - 1) * UI.row_h - scroll

		-- ✅ Skip rows outside visible area
		if row_y + UI.row_h < inner_y0 or row_y > inner_y0 + inner_h then
			continue
		end

		if (i % 2) == 0 then
			DrawingImmediate.FilledRectangle(vector_create(inner_x0, row_y, 0), vector_create(view_w, UI.row_h, 0), Color3.new(0.08, 0.08, 0.11), 0.85)
		end

		local depth_x = inner_x0 + n.depth * UI.indent
		if n.expandable then
			DrawingImmediate.OutlinedText(vector_create(depth_x, row_y + 2, 0), UI.font_size, UI.col_dim, 1,
				expanded[n.id] and "-" or "+", false, UI.font)
		end

		local watch_x = inner_x0 + view_w - UI.btn_watch_w
		local addas_x = watch_x - UI.btn_gap - UI.btn_addas_w

		if is_selectable_part_class(n.class) then
			DrawingImmediate.FilledRectangle(vector_create(addas_x, row_y + 2, 0), vector_create(UI.btn_addas_w, UI.row_h - 4, 0), UI.col_btn_neutral, 0.90)
			DrawingImmediate.OutlinedText(vector_create(addas_x + 8, row_y + 3, 0), UI.font_size, UI.col_text, 1, "Add As", false, UI.font)
		end

		local on = WatchEnabled[n.id] and true or false
		local btn_col = on and UI.col_btn_on or UI.col_btn_off
		DrawingImmediate.FilledRectangle(vector_create(watch_x, row_y + 2, 0), vector_create(UI.btn_watch_w, UI.row_h - 4, 0), btn_col, 0.90)
		DrawingImmediate.OutlinedText(vector_create(watch_x + 8, row_y + 3, 0), UI.font_size, UI.col_text, 1, on and "Watching" or "Watch", false, UI.font)

		local label_x = depth_x + 14
		local label_w = (is_selectable_part_class(n.class) and (addas_x - label_x) or (watch_x - label_x)) - 6

		if label_w > 20 then
			local label = truncate_to_px(n.name .. " (" .. n.class .. ")", label_w, UI.font_size)
			DrawingImmediate.OutlinedText(vector_create(label_x, row_y + 2, 0), UI.font_size, UI.col_text, 1, label, false, UI.font)
		end
	end

	if config_open then
		local panel_y0 = inner_y0
		DrawingImmediate.FilledRectangle(vector_create(panel_x0, panel_y0, 0), vector_create(panel_w, inner_h, 0), UI.col_cfg_bg, 0.96)
		DrawingImmediate.Rectangle(vector_create(panel_x0, panel_y0, 0), vector_create(panel_w, inner_h, 0), UI.col_border, 1, 1)
		DrawingImmediate.OutlinedText(vector_create(panel_x0 + 10, panel_y0 + 6, 0), UI.font_size, UI.col_text, 1, "Rig Parts Config", false, UI.font)

		local tab_y = 28
		local tab_h = 20
		local tab_w = math_floor((panel_w - 24) / 2)
		local tab_x0 = panel_x0 + 10
		local tab_x1 = tab_x0 + tab_w + 4

		local r6_col = (config_tab == 0) and Color3.new(1, 1, 1) or UI.col_border
		local r15_col = (config_tab == 1) and Color3.new(1, 1, 1) or UI.col_border

		DrawingImmediate.Rectangle(vector_create(tab_x0, panel_y0 + tab_y, 0), vector_create(tab_w, tab_h, 0), r6_col, 1, 1)
		DrawingImmediate.Rectangle(vector_create(tab_x1, panel_y0 + tab_y, 0), vector_create(tab_w, tab_h, 0), r15_col, 1, 1)
		DrawingImmediate.OutlinedText(vector_create(tab_x0 + 10, panel_y0 + tab_y + 2, 0), UI.font_size, UI.col_text, 1, "R6", false, UI.font)
		DrawingImmediate.OutlinedText(vector_create(tab_x1 + 10, panel_y0 + tab_y + 2, 0), UI.font_size, UI.col_text, 1, "R15", false, UI.font)

		local list = (config_tab == 0) and R6_KEYS or R15_KEYS
		local tab = (config_tab == 0) and PARTCFG.R6 or PARTCFG.R15
		local y = panel_y0 + tab_y + tab_h + 10
		local row_hh = 20
		local label_w = 120
		local box_x = panel_x0 + 10 + label_w + 8
		local box_w = panel_w - (10 + label_w + 8) - 10

		for i = 1, #list do
			local k = list[i]
			local val = tab[k] or ""

			DrawingImmediate.OutlinedText(vector_create(panel_x0 + 10, y + 2, 0), UI.font_size, UI.col_text, 1, k, false, UI.font)

			local focused = focused_field and (focused_field.tab == config_tab) and (focused_field.key == k)
			local border_col = focused and Color3.new(1, 1, 1) or UI.col_border

			DrawingImmediate.FilledRectangle(vector_create(box_x, y + 2, 0), vector_create(box_w, row_hh - 4, 0), UI.col_cfg_field_bg, 0.85)
			DrawingImmediate.Rectangle(vector_create(box_x, y + 2, 0), vector_create(box_w, row_hh - 4, 0), border_col, 1, 1)

			local shown = truncate_to_px(val, box_w - 10, UI.font_size)
			if focused then
				shown = shown .. "|"
			end
			DrawingImmediate.OutlinedText(vector_create(box_x + 6, y + 2, 0), UI.font_size, UI.col_text, 1, shown, false, UI.font)

			y += row_hh
		end
	end

	if addas_open and addas_h > 0 then
		local mx0, my0 = addas_pos.X, addas_pos.Y
		DrawingImmediate.FilledRectangle(addas_pos, vector_create(addas_w, addas_h, 0), UI.col_menu_bg, 0.97)
		DrawingImmediate.Rectangle(addas_pos, vector_create(addas_w, addas_h, 0), UI.col_border, 1, 1)
		DrawingImmediate.OutlinedText(vector_create(mx0 + 8, my0 + 4, 0), UI.font_size, UI.col_text, 1, "Add As:", false, UI.font)

		local y = my0 + 6
		for i = 1, #addas_items do
			local item = addas_items[i]
			y += addas_item_h
			DrawingImmediate.OutlinedText(vector_create(mx0 + 10, y - 14, 0), UI.font_size, UI.col_text, 1, item, false, UI.font)
		end
	end

	if sel_visible then
		local size2 = sel_max - sel_min
		DrawingImmediate.FilledRectangle(sel_min, size2, SEL_FILL, SEL_FILL_ALPHA)
		DrawingImmediate.Rectangle(sel_min, size2, SEL_OUTLINE, SEL_OUTLINE_ALPHA, SEL_THICKNESS)
	end
end

---- runtime ----
expanded[get_id(workspace)] = true
expanded[get_id(Players)] = true
build_tree_async()

RunService.PostLocal:Connect(function()
	ui_update_loop()
end)

RunService.Render:Connect(function()
	ui_render_loop()
end)

task_spawn(function()
	local tick = 0
	while true do
		watcher_step(520)
		tick += 1
		if (tick % 8) == 0 then
			watcher_cleanup()
			pcall(update_local_override)
		end
		task_wait(0.03)
	end
end)
