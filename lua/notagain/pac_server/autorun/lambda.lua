if engine.ActiveGamemode() ~= "lambda" then return end

hook.Add("PlayerSpawn", "pac_server_lambda", function(ply)
	if SERVER then
		jrpg.SetRPG(ply, true)
	end

	timer.Simple(0, function()
		if ply:IsValid() then
			SafeRemoveEntity(ply.TrackerEntity)
		end
	end)
end)

if CLIENT then
	GAMEMODE.OldShouldDrawCrosshair = GAMEMODE.OldShouldDrawCrosshair or GAMEMODE.ShouldDrawCrosshair
	function GAMEMODE:ShouldDrawCrosshair()
		if battlecam.IsEnabled() then
			return false
		end
		return self:OldShouldDrawCrosshair()
	end
end