--[[ TODO

* angle offset

* clean up mouse_moved()

* background for items5

* add keyboard button support
	* item var "key id" for hotkeys

* add non-exclusive selection (toggle modes)
	* item flag "closes menu"
	
* write documentation

--]]


local function is_even (n)
	return math.floor(n/2) == n/2
end

RadialMouseMenu = RadialMouseMenu or class()
function RadialMouseMenu:init(base,params) --create new instance of a radial selection menu; called from new()
	RadialMouseMenu._WS = RadialMouseMenu._WS or managers.gui_data:create_fullscreen_workspace()
	
	base = base or RadialMouseMenu._WS:panel()
	
--[[
	base = base or managers.hud:script(PlayerBase.PLAYER_INFO_HUD_PD2)._panel
	--if using a custom hud, default hud may not be available; 
	--in this case, it is strongly advised that you create your radial mouse menu in a hud panel of your choosing, 
	--or create a new one to use
	
	if not base then 
		if Console then 
			Console:Log("ERROR: RadialMouseMenu:init(): You must supply a valid HUD Panel base! Please see documentation.",{color = Color.red})
		else
			log("ERROR: RadialMouseMenu:init(): You must supply a valid HUD Panel base! Please see documentation.")
		end
		return
	end	
	
	--]]
	self._base = base
	params = params or {}

	local name = params.name or tostring(math.ceil(math.random(1000000))) --radial name; used for labelling hud elements
	Hooks:Register("radialmenu_selected_" .. name) --this hook is called when you select a thing
	local radius = params.radius or 300 --size of radial, NOT the size of the parent panel
	self._size = radius
	
	local texture = params.texture or "guis/dlcs/coco/textures/pd2/hud_absorb_stack_fg" --selection foreground texture 
	local texture_alpha = params.texture_alpha or 1
	local bg_alpha = params.bg_alpha or 1
	local bg_texture = params.bg_texture or "guis/textures/pd2/hud_radialbg"
	
	self._name = name
	self._items = params.items or {} 
	self._texture = texture
	self._bg_texture = bg_texture --dark radial background texture (blank circle by default)
		
	self._hud = base:panel({ --master panel for this instance of RadialMouseMenu
		name = self._name,
		layer = 1,
		visible = false,
		x = x,
		y = y,
		w = base:w(),
		h = base:h()
	})
	
	local bg = params.bg or {
		name = name .. "_BG",
		texture = "guis/textures/pd2/hud_radialbg",
		blend_mode = "multiply",
		layer = 1,
		alpha = 0.8,
		w = radius,
		h = radius
	}
	local center_text = params.center_text or {
		name = name .. "_CENTER_TEXT",
		text = "",
		layer = 1,
		font_size = 16,
		align = "center",
		vertical = "center",
		font = tweak_data.hud.medium_font,
		color = Color.white
	}
	local selector = params.selector or {
		name = name .. "_SELECTOR",
		texture = "guis/textures/pd2/hud_shield",
		render_template = "VertexColorTexturedRadial",
		layer = 1,
		color = Color(1 / #self._items,1,1),
		w = radius,
		h = radius
	}
	local arrow = params.arrow or {
		name = name .. "_ARROW",
		w = 16,
		h = 16,
		texture = tweak_data.hud_icons.wp_arrow.texture,
		texture_rect = tweak_data.hud_icons.wp_arrow.texture_rect,
		layer = 1
	}
--	local arrow_texture = params.arrow_texture or "guis/textures/pd2/equip_count"
	
	x = params.x or 1
	y = params.y or 1
	self._callback = params.callback
	
	self._selected = false
	self._init_items_done = false
	self._active = false

	
	self._bg = self._hud:bitmap(bg)
	self._bg:set_center(self._hud:w() / 2,self._hud:h() / 2)
	
	
	self._center_text = self._hud:text(center_text)
	
	self._selector = self._hud:bitmap(selector)
	self._selector:set_center(self._hud:w() / 2,self._hud:h() / 2)
	self._arrow = self._hud:bitmap(arrow)
	--[[
	local debug_area = self._hud:rect{
		color = Color.red,
		alpha = 0.1,
		name = "debug_area",
		layer = 1
	}--]]
	return self
end


function RadialMouseMenu:mouse_moved(o,mouse_x,mouse_y)
	local offset_x = self._hud:w() / 2
	local offset_y = self._hud:h() / 2
	Console:SetTrackerValue("trackera",mouse_x)
	Console:SetTrackerValue("trackerb",mouse_y)
	mouse_x = (mouse_x - (self._hud:x() + offset_x))
	mouse_y = (mouse_y - (self._hud:y() + offset_y))
	local mouse_angle
	local clean_angle
	local length = 0.5 * (self._size + 10)
	if mouse_x ~= 0 then 
		mouse_angle = math.atan(mouse_y/mouse_x) % 180
	--	mouse_angle = (math.atan(mouse_y/mouse_x) * (180 / math.pi)) % 360
		if mouse_y == 0 then 
--			mouse_angle = ((1 + math.sign(mouse_x)) * 180) - 90

			if mouse_x > 0 then 
				mouse_angle = 90 + 90
			else
				mouse_angle = 270 + 90
			end

		elseif mouse_y > 0 then 
			mouse_angle = mouse_angle - 180
		end
	
		
	else
--		mouse_angle = ((mouse_y < 0 and 180) or 0) + 90
		if mouse_y > 0 then 
			mouse_angle = 180 + 90
		else
			mouse_angle = 0 + 90
		end
--		mouse_angle = ((1 + math.sign(mouse_y)) * 180) - 90
	end	
	clean_angle = (mouse_angle - 90) % 360
	
	local num_items = math.max(#self._items,1)
	local angle_interval = 360 / num_items
	
	local mouseover_selected = 1 + math.floor(clean_angle / angle_interval) --number index of selected object of self._items 
	local mouseover_angle = (mouseover_selected - 1) * angle_interval --angle of selected object of self._items
	self._selected = mouseover_selected
	self._selector:set_rotation(mouseover_angle)
--	self._selector:set_color(Color(1 / num_items,1,1))

	local item = self._items[mouseover_selected]
	if item then 
--		item._bitmap:set_color(Color(math.random(),math.random(),math.random()))
		self._center_text:set_text(item.name)
		self._arrow:set_color(item._icon:color() or Color.white)
	end
	
	local opposite = math.cos((mouse_angle - 180))
	
	local adjacent = math.sin((mouse_angle - 180))
	
	self._arrow:set_x((opposite * length) + offset_x + - (self._arrow:w() / 2))
	self._arrow:set_y((adjacent * length) + offset_y + - (self._arrow:h() / 2))
	self._arrow:set_rotation(mouse_angle)
end

function RadialMouseMenu:mouse_clicked(o,button,x,y)
	if button ~= Idstring("0") then 
		return
	end
	local item = self._selected and self._items[self._selected]
	if item then 
--		Console:cmd_say("Clicked " .. tostring(item.name))
		local success,result
		if item.callback then 
			success,result = pcall(item.callback)
		end
		Hooks:Call("radialmenu_selected_" .. self._name,self._selected,success)
		if not item.stays_open then 
			self:Hide()
		end
	end
end

function RadialMouseMenu:Toggle(state)
	if state == nil then 
		state = not self:active()
	end	
	
	if state then 
		self:Show()
	else
		self:Hide()
	end
end

function RadialMouseMenu:Show()
	if not self._init_items_done then 
		self:populate_items()	
		self._init_items_done = true
	end

	self._hud:show()
	local data = {
		mouse_move = callback(self, self, "mouse_moved"),
		mouse_click = callback(self, self, "mouse_clicked"),
		id = "radial_menu_mouse"
	}
	if not self._active then 
		managers.mouse_pointer:use_mouse(data)
		game_state_machine:_set_controller_enabled(false)
	end
	self._active = true
end

function RadialMouseMenu:active() --whether or not this menu instance is visible and interactable
	return self._active
end

function RadialMouseMenu:Hide()
	self._selected = false
	self._hud:hide()
--	RadialMouseMenu._WS:disconnect_keyboard()
	if self._active then 
		managers.mouse_pointer:remove_mouse("radial_menu_mouse")
		game_state_machine:_set_controller_enabled(true)
	end
	self._active = false
end

--[[
		to destroy a radial menu object:
1. Call pre_destroy() from your object 
	- eg. my_radial_menu:pre_destroy()
2. Set your object to nil
	- Lua's garbage collection should clear the object from memory automatically
--]]
function RadialMouseMenu:pre_destroy()
	self._base:remove(self._hud)
	--self = nil
end

function RadialMouseMenu:create_item(data) --the slightly easier way to auto-generate an item
--creates item data if you want to customize an item,
--but want to only change some things,
--and want to use auto-created default values for everything else
	if not data then 
		return 
	end
	
	local item = {
		name = data.name or tostring(math.random(1000000)),
		texture = data.texture, --icon will be invisible if you don't specify one
		texture_rect = data.texture_rect,
		w = data.w or 16,
		h = data.h or 16,
		alpha = data.alpha or 0.7,
		color = data.color or Color.white
	}
--	return item
	
	self:add_item(item)
end

function RadialMouseMenu:add_item(item)
	table.insert(self._items,item)
end

function RadialMouseMenu:get_item(index)
	return self._items[index]
end

function RadialMouseMenu:get_all_items()
	return self._items
end

function RadialMouseMenu:reset_items() --removes panels from items, but keeps original data
	for k,data in pairs(self._items) do 
		if data._panel and alive(data._panel) then 
			self._hud:remove(data._panel)
			data._icon = nil
			data._panel = nil
		end
	end
end

function RadialMouseMenu:clear_items() --removes ALL ITEM DATA
	self:reset_items()
	self._items = {}
end

function RadialMouseMenu:populate_items()
	local num_items = #self._items
	for k,data in pairs(self._items) do 
		local name = data.name or "RADIAL_ITEM_" .. math.ceil(math.random(1000000))

		local ho = self._hud:h() / 2
		local wo = self._hud:w() / 2
		local new_segment = self._hud:panel({
			name = name,
			layer = 2,
			w = self._size, --same effective panel size and position as radial bg
			h = self._size
		})
		new_segment:set_center(wo,ho)
		data._panel = new_segment --master panel for this item
		
		
		--[[
		local debug_area = new_segment:rect{
			color = tweak_data.chat_colors[k] or Color.red,
			alpha = 0.1,
			name = name .. "_DEBUG_AREA",
			layer = 1
		}--]]
		
		local segment_texture = new_segment:bitmap({ --arc texture for this item
			name = name .. "_TEXTURE",
			layer = 2,
			alpha = 0.5,
			texture = self._texture,
			render_template = "VertexColorTexturedRadial",
			w = self._size,
			h = self._size,
			rotation = (k/num_items) * 360,
			color = Color(1/num_items,1,1) --arc length
		})
		segment_texture:set_center(self._size / 2,self._size / 2)
		
		local angle = (360 * ((1 + k) / num_items) + 180) --todo fix misalignment
		--[[
		angle = angle + (360 * 
			(   
				0.25 / num_items
--				(is_even(num_items) and 0.5 or 0.25) / (num_items)
			)
		)
		--]]
		local icon = data.icon or { --invisible icon if not specified
			layer = 3,
			alpha = 0.7,
			color = tweak_data.chat_colors[1 + (k % #tweak_data.chat_colors)] or Color.white
		}
		icon.name = name .. "_ICON"
		icon.w = icon.w or 24
		icon.h = icon.h or 24
		
		local x = (math.cos(angle) * (self._size * 0.314)) + - (icon.w / 2)
		local y = (math.sin(angle) * (self._size * 0.314)) + - (icon.h / 2)
		icon.x = x + (self._size / 2)
		icon.y = y + (self._size / 2)
		
		local segment_icon = new_segment:bitmap(icon)
		
		data._icon = segment_icon
		
		data._bitmap = segment_texture
	end	
end
--return foo._items[1]._icon:x()