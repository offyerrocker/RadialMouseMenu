--[[ TODO

* add keyboard button support
	* item var "key id" for hotkeys

* update add_item and create_item to better definitions	
	* icon definition should be separate
	
--]]

RadialMouseMenu = RadialMouseMenu or class()
function RadialMouseMenu:init(params) --create new instance of a radial selection menu; called from new()
	RadialMouseMenu._WS = RadialMouseMenu._WS or managers.gui_data:create_fullscreen_workspace() --create classwide workspace if it doesn't already exist
	
	local base = RadialMouseMenu._WS:panel()

	self._base = base
	params = params or {}
	local name = params.name --radial name; used for labelling hud elements
	if not name then 
		if Console then 
			Console:Log("ERROR: RadialMouseMenu:init(): You must supply a valid name! Please see documentation at https://github.com/offyerrocker/RadialMouseMenu/wiki",{color = Color.red})
		else
			log("ERROR: RadialMouseMenu:init(): You must supply a valid name! Please see documentation at https://github.com/offyerrocker/RadialMouseMenu/wiki")
		end
		return
	end
	--radial menus are automatically centered, so be advised that x/y values here are counted from the center of the screen
	local x = params.x or 0
	local y = params.y or 0
	
	Hooks:Register("radialmenu_selected_" .. name) --this hook is called when you select a thing
	local radius = params.radius or 300 --size of radial, NOT the size of the parent panel
	self._size = radius
	
	self._name = name
	self._items = params.items or {}
		
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
		texture = "guis/textures/pd2/hud_radialbg",--dark radial background texture (blank circle by default)
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

--[[ key stuff
function RadialMouseMenu:key_press(o,k)
	
end

function RadialMouseMenu:update_key_down(o,k,t)

end
--]]

function RadialMouseMenu:mouse_moved(o,mouse_x,mouse_y)
	local offset_x = self._hud:w() / 2
	local offset_y = self._hud:h() / 2
	mouse_x = (mouse_x - (self._hud:x() + offset_x))
	mouse_y = (mouse_y - (self._hud:y() + offset_y))
	
	local num_items = math.max(#self._items,1)
	local length = 0.5 * (self._size + 10)
	
	local mouse_angle,clean_angle
	if mouse_x ~= 0 then 
		mouse_angle = math.atan(mouse_y/mouse_x) % 180
		if mouse_y == 0 then --edge cases for if mouse_y is exactly in the center
			if mouse_x > 0 then 
				mouse_angle = 90 + 90  --right
			else
				mouse_angle = 270 + 90 --left
			end

		elseif mouse_y > 0 then 
			mouse_angle = mouse_angle - 180
		end
	else --edge cases for if mouse_x is exactly in the center
		if mouse_y > 0 then 
			mouse_angle = 180 + 90 --up
		else
			mouse_angle = 0 + 90 --down
		end
	end	
	clean_angle = ((mouse_angle - 90) - (180/num_items)) % 360
	
	local angle_interval = 360 / num_items
	
	local mouseover_selected = 1 + math.floor(clean_angle / angle_interval) --number index of selected object of self._items 
	local mouseover_angle = (mouseover_selected - 0.5) * angle_interval --angle of selected object of self._items
	self._selected = mouseover_selected
	self._selector:set_rotation(mouseover_angle)

	local item = self._items[mouseover_selected]
	if item then 
		self._center_text:set_text(item.text) --set text in radial center to name of selected item
		self._arrow:set_color(item._icon and item._icon:color() or Color.white) --set arrow color to match color of item icon
	end
	
	local opposite = math.cos((mouse_angle - 180))
	
	local adjacent = math.sin((mouse_angle - 180))
	
	--rotate arrow around the radial to match mouse angle
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
		local success,result
		if item.callback then 
			success,result = pcall(item.callback)
		end
		Hooks:Call("radialmenu_selected_" .. self._name,self._selected,result)
		if not item.stay_open then 
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

--[[ to destroy a radial menu object:
1. Call pre_destroy() from your object 
	- eg. my_radial_menu:pre_destroy()
2. Set your object to nil
	- Lua's garbage collection should clear the object from memory automatically
--]]

function RadialMouseMenu:pre_destroy()
	self._base:remove(self._hud)
	--self = nil
end

function RadialMouseMenu:create_item(data,skip_refresh) --the slightly easier way to auto-generate an item
--creates item data if you want to customize an item,
--but want to only change some things,
--and want to use auto-created default values for everything else
	if not data then 
		return 
	end
	local item = {}
	local index = #self._items
	local name = "item_" .. index
	local _body = data.body or {}
	local _icon = data.icon or {}
	local _text = data.text_panel or {}
	item.body = {
		name = name .. "_BODY",
		texture = _body.texture or "guis/dlcs/coco/textures/pd2/hud_absorb_stack_fg", --body will be boring white radial slice if not specified
		texture_rect = _body.texture_rect,
		w = _body.w or 16,
		h = _body.h or 16,
		alpha = _body.alpha or 0.7,
		color = _body.color or Color.white
	}
	item.icon = {
		name = name .. "_ICON",
		texture = _icon.texture, --icon will be invisible if not specified
		texture_rect = _icon.texture_rect,
		w = _icon.w or 16,
		h = _icon.h or 16,
		alpha = _icon.alpha or 0.7,
		color = _icon.color or Color.white
	}
	
	
	item.text_panel = { 
		name = name .. "_TEXT_PANEL",
		text = data.text or _text.text,
		font = _text.font or tweak_data.hud.medium_font,
		font_size = _text.font_size or 16,
		alpha = _text.alpha or 1,
		layer = _text.layer or 1,
		color = _text.color or Color.white
	}
	
	item.stay_open = data.stay_open or false
	item.callback = data.callback
	
	self:add_item(item,skip_refresh)
	return item
end

function RadialMouseMenu:add_item(item,skip_refresh)
	table.insert(self._items,item)
	if not skip_refresh then 
		--skip_refresh should be used if you are adding multiple items at a time 
		--	and don't want to waste computing power running populate_items() every time
		self:populate_items()
	end
end

function RadialMouseMenu:get_item(index)
	return self._items[index]
end

function RadialMouseMenu:get_all_items()
	return self._items
end

function RadialMouseMenu:reset_items(skip_refresh) --removes panels from items, but keeps original data
	for k,data in pairs(self._items) do 
		if data._panel and alive(data._panel) then 
			self._hud:remove(data._panel)
			data._icon = nil
			data._body = nil
			data._panel = nil
		end
	end
	if not skip_refresh then 
		self:populate_items()
	end
end

function RadialMouseMenu:clear_items() --removes ALL ITEM DATA
	self:reset_items()
	self._items = {}
end

function RadialMouseMenu:remove_item(index,skip_refresh) --removes a particular item entry
	local item = self._items[index]
	if item then 
		if item._panel and alive(item._panel) then 
			self._hud:remove(item._panel)
			item._icon = nil
			item._body = nil
			item._panel = nil
			item._text_panel = nil
		end
	end
	table.remove(self._items,index)
	if not skip_refresh then 
		self:populate_items()
	end
end

function RadialMouseMenu:populate_items()
	self:reset_items(true) --tell reset_items() not to call populate_items()
	--stacks are not chief among the things i like to overflow
	
	local num_items = math.max(#self._items,1)
	for k,data in pairs(self._items) do 
		local text = data.text or ""
		local name = "item_" .. k
		local ho = self._hud:h() / 2 --position offsets to place the given hud element in the center of the radial
		local wo = self._hud:w() / 2
		local new_segment = self._hud:panel({ --master panel for this item
			name = name .. "_PANEL",
			layer = 2,
			w = self._size, --same effective panel size and position as radial bg
			h = self._size
		})
		new_segment:set_center(wo,ho)
		data._panel = new_segment --save master panel reference to this item's data
		
		local angle = (360 * (k / num_items) - 90) % 360

		local body = data.bitmap or { --arc texture for this item
			layer = 1,
			alpha = 0.3,
			texture = "guis/dlcs/coco/textures/pd2/hud_absorb_stack_fg", --selection foreground texture
			w = self._size,
			h = self._size
		}
		body.name = name .. "_TEXTURE"
		
		body.render_template = "VertexColorTexturedRadial"
		body.color = Color(1/num_items,1,1) --this changes arc length, not actually color
		body.rotation = angle + 90 - (180/num_items)
		local segment_texture = new_segment:bitmap(body)
		segment_texture:set_center(self._size / 2,self._size / 2)
		data._bitmap = segment_texture

		local icon = data.icon or { --invisible icon if not specified
			layer = 3,
			alpha = 0.7,
			color = tweak_data.chat_colors[1 + (k % #tweak_data.chat_colors)] or Color.white
		}
--		Log(angle,{color = icon.color})
		icon.name = name .. "_ICON"
		icon.w = icon.w or 24
		icon.h = icon.h or 24
		
		local x = (math.cos(angle) * (self._size * 0.314))
		local y = ((math.sin(angle) * (self._size * 0.314)) + - (icon.h / 2)) + (self._size / 2)
		icon.x = x + (self._size / 2) - (icon.w / 2)
		icon.y = y
		
		
		local segment_icon = new_segment:bitmap(icon)
		data._icon = segment_icon		
		
		local text_panel = data.text_panel or { 
			name = name .. "_TEXT_PANEL",
			text = text,
			x = x,
			y = y + 12,
			align = "center",
			font = tweak_data.hud.medium_font,
			font_size = 12,
			alpha = 1,
			layer = 1,
			color = Color.white
		}
		text_panel.visible = data.show_text or false
		local segment_text_panel = new_segment:text(text_panel)
		data._text_panel = segment_text_panel

		
		
		self._selector:set_color(Color(1/num_items,1,1))
	end	
end