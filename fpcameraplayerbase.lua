local pc_look = FPCameraPlayerBase._pc_look_function
function FPCameraPlayerBase:_pc_look_function(...)
	
	if RadialMenu and RadialMenu.current_menu and not RadialMenu.current_menu.allow_camera_look and RadialMenu.current_menu:active() then
		return 0,0
	end
	return pc_look(self,...)
end

local gamepad_look = FPCameraPlayerBase._gamepad_look_function
function FPCameraPlayerBase:_gamepad_look_function(...)
	if RadialMenu and RadialMenu.current_menu and not RadialMenu.current_menu.allow_camera_look and RadialMenu.current_menu:active() then
		return 0,0
	end
	return gamepad_look(self,...)
end

local gamepad_look_ctl = FPCameraPlayerBase._gamepad_look_function_ctl
function FPCameraPlayerBase:_gamepad_look_function_ctl(...)
	if RadialMenu and RadialMenu.current_menu and not RadialMenu.current_menu.allow_camera_look and RadialMenu.current_menu:active() then
		return 0,0
	end
	return gamepad_look_ctl(self,...)
end

local steampad_look = FPCameraPlayerBase._steampad_look_function
function FPCameraPlayerBase:_steampad_look_function(...)
	if RadialMenu and RadialMenu.current_menu and not RadialMenu.current_menu.allow_camera_look and RadialMenu.current_menu:active() then
		return 0,0
	end
	return steampad_look(self,...)
end
