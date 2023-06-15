--[[
	TODO
straighten highlight/selected/active item terminology
recreate with items
eliminate radialmenuobject (redundant)
	
--allow repositioning text (currently centered from formula: [0.5*radius  +  constant] )

* add keyboard button support
	* item var "key id" for hotkeys

* update add_item and create_item to better definitions	
	* icon definition should be separate
	
--]]

core:module("SystemMenuManager")
require("lib/managers/dialogs/Dialog")

local RadialMenuDialog = class(Dialog)

local RadialMenuObject = class()

local RadialMenuManager = {
	queued_items = {},
	WIKI_URL = "https://github.com/offyerrocker/RadialMouseMenu/wiki",
	_ws = nil,
	log_to_console = true,
	log_to_blt = true,
	log_to_beardlib = false
	
}
--RadialMenuManager.radial_menu_objects = {}
--RadialMenuManager._core = RadialMenuCore


--====================================
-- RadialMenuManager
--====================================

function RadialMenuManager:Log(s)
	local msg = "[Radial Menu] " .. tostring(s)
	if self.log_to_console and _G.Console then
		_G.Console:Log(msg)
	end
	if self.log_to_blt then
		_G.log(msg)
	end
--	if self.log_to_beardlib and RadialMenuManager._core then
--		RadialMenuObject._core:Log(msg)
--	end
end

function RadialMenuManager.CreateQueuedMenus()
	for i=#RadialMenuManager.queued_items,1,-1 do
		local data = table.remove(RadialMenuManager.queued_items,i)
	end
end

function RadialMenuManager:CheckCreateWorkspace()
	if _G.managers.gui_data and not alive(RadialMenuManager._ws) then 
		--create classwide workspace if it doesn't already exist
		self._ws = _G.managers.gui_data:create_fullscreen_workspace()
	end
end

function RadialMenuManager:NewMenu(params,...)
	self:CheckCreateWorkspace()
	
	local new_radial_menu = RadialMenuObject:new(self,params,...)
	return new_radial_menu
end

--====================================
-- RadialMenuObject class
--====================================

function RadialMenuObject:init(radialmenumanager,params) --constructor
	self._radial_menu_manager = radialmenumanager
	
	params = params or {}
	self.log_to_console = params.log_to_console
	self.log_to_blt = params.log_to_blt
	self.log_to_beardlib = params.log_to_beardlib
	
	if not _G.managers.gui_data then 
		table.insert(RadialMenuObject.queued_items,1,{params = params})
		--if RadialMenuObject:new() is called after RMM loads but before the rest of the game,
		--save the information for later and create it on game load
		return
	end
	
	self:setup(params)
end

function RadialMenuObject:Log(s)
	return self._radial_menu_manager:Log(tostring(self._id) .. tostring(s))
end

function RadialMenuObject:setup(params) --create new instance of a radial selection menu; called from new()
	
	local class_panel = self._class_panel
	if not alive(class_panel) then 
		class_panel = self._radial_menu_manager._ws:panel()
		self._class_panel = class_panel
	end
	
	local id = params.id --radial id; used for labelling hud elements
	if not id then 
		id = "RadialMenuObject_" .. tostring(self)
		self:Log(string.format("ERROR: Missing id parameter! Please refer to the wiki: %s",self._radial_menu_manager.WIKI_URL))
	end
	self._id = id
	
	self:CreateDialog({
		id = id,
		items = params.items,
		parent = self,
		class_panel = class_panel,
		size = params.size or 256, --size of radial, NOT the size of the parent panel
		deadzone = params.deadzone, --minimum distance from center the mouse must be in order to select an item
		item_margin = params.item_margin,
		texture_highlight = params.texture_highlight,
		texture_darklight = params.texture_darklight,
		texture_cursor = params.texture_cursor,
		animate_focus_grow_size = 1.66,
		animate_focus_duration = 0.33,
		animate_unfocus_duration = 0.33,
		focus_alpha = params.focus_alpha,
		unfocus_alpha = params.unfocus_alpha,
		title = "toitle m8",
		text = "placeholder text"
	})
end

function RadialMenuObject:GetId()
	return self._id
end

function RadialMenuObject:CreateDialog(dialog_data)
	self._dialog = RadialMenuDialog:new(_G.managers.system_menu,dialog_data)
end

function RadialMenuObject:Show()
	if self._dialog then
		_G.managers.system_menu:_show_instance(self._dialog,true)
	end
end

function RadialMenuObject:Hide(...)
	if self:IsActive() then
		self._dialog:hide(...)
	end
end

function RadialMenuObject:Toggle(state,...)
	if state == nil then 
		state = not self:IsActive()
	end	
	
	if state then 
		self:Show(...)
	else
		self:Hide(...)
	end
end

function RadialMenuObject:IsActive()
	if self._dialog then 
		return self._dialog.is_active
	end
	return nil
end



--====================================
-- RadialMenuDialog class
--====================================

function RadialMenuDialog:init(manager,data,...)
	RadialMenuDialog.super.init(self,manager,data,...)
	
	self._manager = manager --RadialMenuMananger
	self._ws = manager._ws
	self._data = data

	self._items = {} --populated later
	if data.controller_mode_enabled ~= nil then 
		self._controller_mode_enabled = data.controller_mode_enabled --if true, checks the axis movement and selects the item by that angle
	else
		local wrapper_type = _G.managers.controller:get_default_wrapper_type()
		self._controller_mode_enabled = wrapper_type ~= "pc"
	end
	self._parent = data.parent --parent RadialMenuObject
	self._class_panel = data.class_panel
	self._panel = nil --populated later
	self._mouse_id = nil
	self.is_active = false --determines whether this dialog is active and stops gameplay input
	self._input_enabled = false --determines whether this dialog can take input
	
	self._controller = data.controller or manager:_get_controller()
	self._confirm_func = callback(self, self, "button_pressed_callback") --automatic menu input for this is unreliable
	self._cancel_func = callback(self, self, "dialog_cancel_callback")

	self:recreate_gui()
--	self:populate_items()
	
	self._selected_index = nil
end

function RadialMenuDialog:log(s)
	local msg = string.format("RadialMenuDialog: %s",s)
	return self._parent:Log(s)
end

function RadialMenuDialog:recreate_gui()
	
	local panel = self._panel
	if alive(panel) then 
		local children = panel:children()
		for i=#children,1,-1 do 
			panel:remove(table.remove(children,i))
		end
--		self._class_panel:remove(self._panel)
	else
		panel = self._class_panel:panel({
			name = self._parent:GetId() .. "_dialog_panel",
			visible = false
		})
		self._panel = panel
	end
	
	--clear existing data
	self._selected_item = nil
	for k,v in pairs(self._items) do 
		self._items[k] = nil
	end
	
	local data = self._data
	--dialog_panel:
		--radial_cursor --free rotating segment. arc segment 
		--background --darklight for category slots
		--item:
			--active_highlight --toggle-visible for active items. arc segment
			--icon --the image primarily representing this button
			
	local HIGHLIGHT_TEXTURE = data.texture_highlight
	local DARKLIGHT_TEXTURE = data.texture_darklight
	local CURSOR_TEXTURE = data.texture_cursor
	local radius = data.size
	local icon_distance = radius / 3
	local label_distance = radius / 4
	
	local num_items = #data.items
	local cursor = panel:bitmap({
		name = "cursor",
		texture = CURSOR_TEXTURE,
		rotation = 0,
		w = radius,
		h = radius,
		color = Color.white,
		halign = "grow",
		valign = "grow",
		layer = 5
	})
	local c_x,c_y = panel:center()
	cursor:set_center(c_x,c_y)
	
	local background = panel:bitmap({
		name = "background",
		texture = DARKLIGHT_TEXTURE,
		w = radius,
		h = radius,
		alpha = 1,
		halign = "grow",
		valign = "grow",
		layer = 1
	})
	background:set_center(c_x,c_y)
	
	
	local MARGIN_PERCENT = data.item_margin --10% of a slice's theta angle is cut off to create a margin
	for i,item in ipairs(data.items) do 
		local icon_w = item.w
		local icon_h = item.h
		local i_prog = (i - 1) / num_items
		local arc_length = (1 / num_items) * (1 - MARGIN_PERCENT)
		local arc_offset = MARGIN_PERCENT / (num_items * 2)
		local arc_length_col = Color(arc_length,1,0)
		local arc_position = 360 * (i_prog + arc_offset - (0.5 / num_items)) --highlight/darklight position
		local icon_position = (i_prog * 360) - 90 --icon position; centered so it doesn't need the -0.5rad offset
		local x = math.cos(icon_position)
		local y = math.sin(icon_position)
		local icon_x = c_x + (x * icon_distance)
		local icon_y = c_y + (y * icon_distance)
		local label_x = x * label_distance
		local label_y = y * label_distance
		local icon = panel:bitmap({
			name = "icon_" .. i,
			texture = item.texture,
			texture_rect = item.texture_rect,
			w = icon_w,
			h = icon_h,
			layer = 4,
			alpha = 1,
			color = item.color,
			halign = "grow",
			valign = "grow"
--,			visible = i == 1
		})
		icon:set_center(icon_x,icon_y)
		local highlight = panel:bitmap({
			name = "highlight_" .. i,
			texture = HIGHLIGHT_TEXTURE,
			render_template = "VertexColorTexturedRadial",
			w = radius,
			h = radius,
			color = arc_length_col,
			rotation = arc_position,
			layer = 3,
			alpha = 1,
			halign = "grow",
			valign = "grow",
			visible = false --disable unless it's visible
		})
		highlight:set_center(c_x,c_y)
		
		local label = panel:text({
			name = "label_" .. i,
			text = item.text or "",
			font = item.font or "fonts/font_medium_shadow_mf",
			font_size = item.font_size or 24,
			x = label_x,
			y = label_y,
			align = "center",
			vertical = "center",
			alpha = 1,
			--halign/valign don't apply to text object font size, only clipping box
			layer = 5
		})
		
		local darklight = panel:bitmap({
			name = "darklight_" .. i,
			texture = DARKLIGHT_TEXTURE,
			render_template = "VertexColorTexturedRadial",
			w = radius,
			h = radius,
			color = arc_length_col,
			rotation = arc_position,
			layer = 2,
			alpha = 1,
			halign = "grow",
			valign = "grow"
--,			visible = i == 1
		})
		darklight:set_center(c_x,c_y)
		
		self._items[i] = {
			icon = icon,
			w = icon_w or icon:w(),
			h = icon_h or icon:h(),
			icon_x = icon_x,
			icon_y = icon_y,
			highlight = highlight,
			darklight = darklight,
			label = label,
			focus_alpha = data.focus_alpha,
			unfocus_alpha = data.unfocus_alpha,
--			active_color = active_color,
--			inactive_color = inactive_color,
			callback = item.callback
		}
	end
	
end

function RadialMenuDialog:update(t,dt)
	self:update_input(t,dt)
end

function RadialMenuDialog:update_input(t,dt)
	if self.is_active then 
		if self._input_enabled then 
			local dir --"absolute" control- direction as determined by (analog stick direction if using controller mode) or (else mouse position relative to center)
			
--			local move = self._controller:get_input_axis("menu_move")
			local move = self._controller:get_input_axis("look")
			
			if self._controller_mode_enabled then 
				local panel = self._panel
				if alive(panel) then
					
					local cursor = panel:child("cursor")
					local x = move.x
					local y = move.y
--					_G.Console:SetTracker(string.format("%0.2f, %0.2f | %0.1fs",move.x,move.y,t),1)
					
					local new_selected_index
					
					if x ~= 0 or y ~= 0 then
						local c_x,c_y = panel:center()
						local m_x,m_y = x - c_x,y - c_y
						local angle = 90 - math.atan(y/x) --0/0 returns nan, but 1/0 works as intended
						if x < 0 then
							angle = angle + 180
						end
						angle = angle % 360
						
						cursor:set_rotation(angle)
						cursor:set_center(c_x,c_y)
						
						local num_items = #self._items
						
						local angle_interval = 360 / num_items
						new_selected_index = 1 + ((math.round((angle - angle_interval) / angle_interval) + 1) % num_items)
	--					_G.Console:SetTracker(string.format("selected: %i",new_selected_index),2)
	--					_G.Console:SetTracker(string.format("angle: %i",angle),3)
						
					end
					
					local selected_index = self:get_selected_index()
					if selected_index ~= new_selected_index then
						self:set_selected_index(new_selected_index)
						
						self:animate_mouseover_item_focus(new_selected_index)
						self:animate_mouseover_item_unfocus(selected_index)
					end
					
				end
				
				
				
				
				--[[
				local move_time = nil
				
				if self._controller:get_input_bool("menu_down") or move.y < -self.MOVE_AXIS_LIMIT then
					dir = 1
				elseif self._controller:get_input_bool("menu_up") or self.MOVE_AXIS_LIMIT < move.y then
					dir = -1
				end
				
				if dir then
					if self._move_button_dir == dir and self._move_button_time and t < self._move_button_time + self.MOVE_AXIS_DELAY then
						move_time = self._move_button_time or t
					else
						
						--self._panel_script:change_focus_button(dir)

						move_time = t
					end
				end
				--]]
			else
				
			end
		else
			--skip the first frame of input
			self:set_input_enabled(true)
		end
	end
	
end

function RadialMenuDialog:move_selection(dir) --unused; intended for scrolling behavior
	local selection_index = self._selection_index
	local prev_selection_index = selection_index
	selection_index = ((selection_index + dir) % #self._items) + 1
	self._selection_index = selection_index
	self:callback_set_selection(prev_selection_index,selection_index)
end

function RadialMenuDialog:get_selected_index()
	return self._selected_index
end

function RadialMenuDialog:set_selected_index(index)
	self._selected_index = index
end

function RadialMenuDialog:clear_selected_index()
	self._selected_index = nil
end

function RadialMenuDialog:callback_item_confirmed(index)
	local item_data = index and self._items[index]
	if item_data then
		if not item_data.keep_open then
			self:hide()
		else
			self:clear_selected_index()
		end
		self:_callback_item_confirmed(index,item_data)
	end
end

function RadialMenuDialog:_callback_item_confirmed(index,item_data)
	if item_data and item_data.callback then
		item_data.callback(index,item_data)
	end
	self:animate_mouseover_item_unfocus(index)
end

function RadialMenuDialog:button_pressed_callback()
--	self:log("Button pressed callback")
	--queue hide
end

function RadialMenuDialog:dialog_cancel_callback()
--	self:log("Dialog cancel callback")
end

function RadialMenuDialog:callback_mouse_moved(o,x,y)
	if not self._controller_mode_enabled and alive(self._panel) then
		local cursor = self._panel:child("cursor")
		local c_x,c_y = self._panel:center()
		local m_x,m_y = x - c_x,y - c_y
		local angle = math.atan(m_y/m_x) + 90
		if m_x < 0 then
			angle = angle + 180
		end
		angle = angle % 360
		
		cursor:set_rotation(angle)
		cursor:set_center(c_x,c_y)
		local num_items = #self._items
		
		local angle_interval = 360 / num_items
		local new_selected_index = 1 + ((math.round((angle - angle_interval) / angle_interval) + 1) % num_items)
--		_G.Console:SetTracker(string.format("angle: %i",angle),3)
--		_G.Console:SetTracker(string.format("selected: %i",new_selected_index),2)
		local selected_index = self:get_selected_index()
		if selected_index ~= new_selected_index then
			self:animate_mouseover_item_focus(new_selected_index)
			self:animate_mouseover_item_unfocus(selected_index)
			
			self:set_selected_index(new_selected_index)
		end
--		_G.managers.mouse_pointer:set_pointer_image("arrow")
	end
--	log("moved " .. tostring(x) .. " " .. tostring(y))
end

function RadialMenuDialog:callback_mouse_pressed(o,button,x,y) --unused
--	self:log("pressed  " .. tostring(x) .. " " .. tostring(y))
end

function RadialMenuDialog:callback_mouse_released(o,button,x,y)
--	self:log("released  " .. tostring(x) .. " " .. tostring(y))
	if button == Idstring("0") then
		self:callback_item_confirmed(self:get_selected_index())
	elseif button == Idstring("1") then 
		self:hide()
	end
end

function RadialMenuDialog:callback_mouse_clicked(o,button,x,y) --don't use this
--	self:log("Mouse clicked")
	--[[
		--this callback is called whenever the mouse is released after clicking.
		--but it isn't capable of checking whether the mouseover object is the same one from when the mouse was pressed.
		--and by definition a mouse must always first press before releasing. that is how clicks work.
		--also it's executed after release instead of before.
		--so it's completely worthless to me.
	--]]
end

function RadialMenuDialog:set_input_enabled(enabled)
	local controller = self._controller
	if not self._input_enabled ~= not enabled then
		if enabled then
			controller:add_trigger("confirm", self._confirm_func)

			if _G.managers.controller:get_default_wrapper_type() == "pc" or _G.managers.controller:get_default_wrapper_type() == "steam" or _G.managers.controller:get_default_wrapper_type() == "vr" then
				controller:add_trigger("toggle_menu", self._cancel_func)

				self._mouse_id = _G.managers.mouse_pointer:get_id()
				self._removed_mouse = nil
				local data = {
					mouse_move = callback(self, self, "callback_mouse_moved"),
					mouse_press = callback(self, self, "callback_mouse_pressed"),
					mouse_release = callback(self, self, "callback_mouse_released"),
					mouse_click = callback(self, self, "callback_mouse_clicked"), --don't use this
					id = self._mouse_id
				}
--				self._ws:connect_keyboard(Input:keyboard())
--				self._input_text:key_press(callback(self, self, "callback_key_press"))
--				self._input_text:key_release(callback(self, self, "callback_key_release"))

				
				_G.managers.mouse_pointer:use_mouse(data)
			else
				self._removed_mouse = nil

				controller:add_trigger("cancel", self._cancel_func)
				_G.managers.mouse_pointer:disable()
			end
		else
--			self._ws:disconnect_keyboard()
--			self._panel:key_release(nil)
			controller:remove_trigger("confirm", self._confirm_func)

			if _G.managers.controller:get_default_wrapper_type() == "pc" or _G.managers.controller:get_default_wrapper_type() == "steam" or _G.managers.controller:get_default_wrapper_type() == "vr" then
				controller:remove_trigger("toggle_menu", self._cancel_func)
			else
				controller:remove_trigger("cancel", self._cancel_func)
			end

			self:remove_mouse()
		end

		self._input_enabled = enabled

		_G.managers.controller:set_menu_mode_enabled(enabled)
	end
end

function RadialMenuDialog:remove_mouse()
	if not self._removed_mouse then
		self._removed_mouse = true

		if _G.managers.controller:get_default_wrapper_type() == "pc" or _G.managers.controller:get_default_wrapper_type() == "steam" or _G.managers.controller:get_default_wrapper_type() == "vr" then
			_G.managers.mouse_pointer:remove_mouse(self._mouse_id)
		else
			_G.managers.mouse_pointer:enable()
		end

		self._mouse_id = nil
	end
end

function RadialMenuDialog:show()
	self._manager:event_dialog_shown(self)
	self._panel:show()
	self.is_active = true
	return true
end	

function RadialMenuDialog:hide(select_current)
	if select_current then
		local index = self:get_selected_index()
		if index then
			self:_callback_item_confirmed(index,self._items[index])
		end
	end
	self:set_input_enabled(false)
	self._panel:hide()
	self.is_active = false
	self._manager:event_dialog_hidden(self)
end

function RadialMenuDialog:animate_mouseover_item_focus(index)
	local items = self._items
	local panel = self._panel
	if index and alive(panel) then
		local icon = panel:child("icon_" .. index)
		if alive(icon) then
			icon:stop()
			local item_data = self._items[index]
			local grow_size = self._data.animate_focus_grow_size or 1.66
			local duration = self._data.animate_focus_duration or 0.33
			icon:animate(self._animate_grow_center,duration,icon:w(),icon:h(),item_data.w * grow_size,item_data.h * grow_size,item_data.icon_x,item_data.icon_y,icon:alpha(),item_data.focus_alpha)
		end
	end
end

function RadialMenuDialog._animate_grow_center(o,duration,w1,h1,w2,h2,c_x,c_y,a1,a2)
	local dw,dh,da
	if w1 and w2 then
		dw = w2 - w1
	end
	if h1 and h2 then
		dh = h2 - h1
	end
	if a1 and a2 then
		da = a2 - a1
	end
	_G.over(duration,function(lerp)
		if dw then
			o:set_w(w1 + (dw * lerp))
		end
		if dh then
			o:set_h(h1 + (dh * lerp))
		end
		if da then
			o:set_alpha(a1 + (da * lerp))
		end
		o:set_center(c_x,c_y)
	end)
	if a2 then
		o:set_alpha(a2)
	end
	o:set_size(w2,h2)
	o:set_center(c_x,c_y)
end

function RadialMenuDialog:animate_mouseover_item_unfocus(index)
	local items = self._items
	local panel = self._panel
	if index and alive(panel) then
		local icon = panel:child("icon_" .. index)
		if alive(icon) then
			icon:stop()
			local duration = self._data.animate_unfocus_duration or 0.33
			local item_data = self._items[index]
			icon:animate(self._animate_grow_center,duration,icon:w(),icon:h(),item_data.w,item_data.h,item_data.icon_x,item_data.icon_y,icon:alpha(),item_data.unfocus_alpha)
		end
	end
end



Hooks:Add("BaseNetworkSessionOnLoadComplete","RadialMenu_OnLoaded",RadialMenuManager.CreateQueuedMenus)

do return RadialMenuManager end













-------------------------------------------------------------------------------------------------------------------------------

do return end


--====================================
-- RadialMenuDialog class
--====================================
--core:module("SystemMenuManager")
require("lib/managers/dialogs/Dialog")


local RadialMenuDialog = class(Dialog)
RadialMenuDialog.TEXTURE_HIGHLIGHT = ""
RadialMenuDialog.TEXTURE_DARKLIGHT = ""
RadialMenuDialog.TEXTURE_CURSOR = ""
RadialMenuDialog.ITEM_ROTATION_OFFSET_PERCENT = 0.1

RadialMenuDialog.INPUT_IGNORE_DELAY_INTERVAL = 0.05
RadialMenuDialog.INPUT_REPEAT_INTERVAL_INITIAL = 0.4
RadialMenuDialog.INPUT_REPEAT_INTERVAL_CONTINUE = 0.066
RadialMenuDialog.MOVE_AXIS_LIMIT = 0.4
RadialMenuDialog.MOVE_AXIS_DELAY = 0.4
--[[

RadialMenuDialog.DEFAULT_FONT_NAME = tweak_data.hud.medium_font
--]]






Hooks:Add("BaseNetworkSessionOnLoadComplete","RadialMenu_OnLoaded",RadialMenu.CreateQueuedMenus)



do return end


function RadialMenu:mouse_moved(o,mouse_x,mouse_y)

	local offset_x = self._hud:w() / 2
	local offset_y = self._hud:h() / 2
	mouse_x = (mouse_x - (self._hud:x() + offset_x))
	mouse_y = (mouse_y - (self._hud:y() + offset_y))
	
	local num_items = math.max(#self._items,1)
	local length = 0.5 * (self._size + 10)
	
	local mouse_angle,clean_angle
	
	-- [ [
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
	local angle_interval = 360 / num_items
	-- ] ]
	
--	clean_angle = ( -angle_interval + ((mouse_angle - 90) - (180/num_items))) % 360
	clean_angle = ((mouse_angle - 90) + (180/num_items)) % 360
	
	
	local mouseover_selected = 1 + math.floor(clean_angle / angle_interval)  --number index of selected object of self._items 
	local mouseover_angle = (mouseover_selected - 0.5) * angle_interval --angle of selected object of self._items
	self._selector:set_rotation(mouseover_angle - angle_interval)
	
	local function outside_deadzone(x1,y1,d)
		if not d then return true end
		return ((x1 * x1) + (y1 * y1)) >= (d * d)
	end
	
	local item = self._items[mouseover_selected]
	if outside_deadzone(mouse_x,mouse_y,self._deadzone) then 
		self:on_mouseover_item(mouseover_selected)
	else
		self._selector:set_visible(false)
		self._selected = false
		self._center_text:set_visible(false)
	end
	
	local opposite = math.cos((mouse_angle - 180))
	
	local adjacent = math.sin((mouse_angle - 180))
	
	--rotate arrow around the radial to match mouse angle
	self._arrow:set_x((opposite * length) + offset_x + - (self._arrow:w() / 2))
	self._arrow:set_y((adjacent * length) + offset_y + - (self._arrow:h() / 2))
	self._arrow:set_rotation(mouse_angle)
end

function RadialMenu:mouse_clicked(o,button,x,y)
	if button ~= Idstring("0") then 
		return
	end
	local item = self._selected and self._items[self._selected]
	if item then 
		self:on_item_clicked(item)
	end
end

function RadialMenu:on_item_clicked(item,skip_hide)
--	item._body:set_visible(not item._body:visible())
	local success,result
	if not (item.stay_open or skip_hide) then 
		self:Hide(nil,false)
	end
	if item.callback then 
		success,result = pcall(item.callback)
	end
	Hooks:Call("radialmenu_selected_" .. self._name,self._selected,result)
end


function RadialMenu:on_mouseover_item(index) --you can choose to clone the class and change the mousover event animation if you want
	local item = self:get_item(index)
	if not item then 
		self._selected = false
		return 
	end
	self._selected = index
	self._selector:set_visible(true)
	local old_item = self:get_item(self._selected)
	local function animate_flare(o,down)
		local text_panel = o._text_panel
		local font_size = o.text_panel.font_size
		local final_size = font_size * (down and 1 or 1.25)

		local rate = down and 0.95 or 1.05
		
		repeat
			local s = math[down and "max" or "min"](text_panel:font_size() * rate,final_size)
			
			text_panel:set_font_size(s)
			
			coroutine.yield()
		until math.abs(text_panel:font_size() - final_size) <= 0.01
	end
	
	self._center_text:set_visible(true)
	self._center_text:set_text(item.text) --set text in radial center to name of selected item
	self._arrow:set_color(item._icon and item._icon:color() or Color.white) --set arrow color to match color of item icon
	
--	item:animate(animate_flare,false) --must be called from a hud panel
--	old_item:animate(animate_flare,true)

end

function RadialMenu:Toggle(state,...)
	if state == nil then 
		state = not self:active()
	end	
	
	if state then 
		self:Show(...)
	else
		self:Hide(...)
	end
end

function RadialMenu:Show()
	if not self._init_items_done then 
		self:populate_items()
		self._init_items_done = true
	end
	
	if RadialMenu.current_menu and RadialMenu._name ~= self:get_name() then 
		RadialMenu.current_menu:Hide(true) --hide any other active radial menus, since only one can take input at a time
	end
	RadialMenu.current_menu = self

	self._hud:show()
	local data = {
		mouse_move = callback(self, self, "mouse_moved"),
		mouse_click = callback(self, self, "mouse_clicked"),
		id =  RadialMenu.MOUSE_ID
	}
	if not self._active then 
		managers.mouse_pointer:use_mouse(data)
		if self.block_all_input then 
			game_state_machine:_set_controller_enabled(false)
		end
	end
	if not self.keep_mouse_position then 
		managers.mouse_pointer:set_mouse_world_position(self._hud:w()/2,self._hud:h()/2) --todo use center() instead
	end
	self._active = true
end

function RadialMenu:get_name()
	return self._name
end

function RadialMenu:active() --whether or not this menu instance is visible and interactable
	return self._active
end

function RadialMenu:Hide(skip_reset,do_success_cb)
	if not skip_reset then 
		RadialMenu.current_menu = nil
	end
	self._hud:hide()
--	RadialMenu._class_ws:disconnect_keyboard()
	if self.block_all_input then 
		game_state_machine:_set_controller_enabled(true)
	end
	local item = self._selected and self._items[self._selected]
	self._selected = false
	if self._active then 
		self._active = false
		self._selector:set_visible(false)
		local player = managers.player and managers.player:local_player()
		if alive(player) then 
			player:movement():current_state()._menu_closed_fire_cooldown = player:movement():current_state()._menu_closed_fire_cooldown + 0.01
		end
		self:on_closed()
		managers.mouse_pointer:remove_mouse(RadialMenu.MOUSE_ID)
		if do_success_cb then 
			if item then 
				self:on_item_clicked(item,true) --already hiding here so skip_hide 
			end
		end
	end
end

--[[ to destroy a radial menu object:
1. Call pre_destroy() from your object 
	- eg. my_radial_menu:pre_destroy()
2. Set your object to nil
	- Lua's garbage collection should clear the object from memory automatically
--]]

function RadialMenu:pre_destroy()
	self._base:remove(self._hud)
	--self = nil
end

function RadialMenu:create_item(data,skip_refresh) --the slightly easier way to auto-generate an item
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

function RadialMenu:add_item(item,skip_refresh)
	table.insert(self._items,item)
	if not skip_refresh then 
		--skip_refresh should be used if you are adding multiple items at a time 
		--	and don't want to waste computing power running populate_items() every time
		self:populate_items()
	end
end

function RadialMenu:get_item(index)
	return self._items[index]
end

function RadialMenu:get_all_items()
	return self._items
end

function RadialMenu:reset_items(skip_refresh) --removes panels from items, but keeps original data
	for k,data in ipairs(self._items) do 
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

function RadialMenu:on_closed()
	Hooks:Call("radialmenu_released_" .. self:get_name(),self._selected)
end

function RadialMenu:clear_items() --removes ALL ITEM DATA
	self:reset_items(true)
	self._items = {}
end

function RadialMenu:remove_item(index,skip_refresh) --removes a particular item entry
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

function RadialMenu:populate_items()
	self:reset_items(true) --tell reset_items() not to call populate_items()
	--stacks are not chief among the things i like to overflow
	
	local num_items = math.max(#self._items,1)
	for k,data in ipairs(self._items) do --order is important here
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
		
		local angle = (360 * ((k - 1) / num_items) - 90) % 360

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
		data._body = segment_texture

		local icon = data.icon or { --invisible icon if not specified
			layer = 3,
			visible = false,
			color = tweak_data.chat_colors[1 + (k % #tweak_data.chat_colors)] or Color.white
		}
		icon.name = name .. "_ICON"
		icon.w = icon.w or 24
		icon.h = icon.h or 24
		
		local x = (math.cos(angle) * (self._size * 0.314))
		local y = ((math.sin(angle) * (self._size * 0.314)) + - (icon.h / 2)) + (self._size / 2)
		icon.x = x + (self._size / 2) -- -(icon.w / 2)
		icon.y = y
		icon.halign = "center"
		icon.valign = "center"
		
		
		local segment_icon = new_segment:bitmap(icon)
		segment_icon:set_center(icon.x,icon.y)
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
	self._init_items_done = true
end

