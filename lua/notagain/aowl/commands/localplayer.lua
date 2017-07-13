AddCSLuaFile()

do -- mute
	aowl.AddCommand("mute|block=player",function(ply,line,target)
		local ent = net.ReadEntity()
		ent:SetMuted(true)
		ent.aowl_muted = true
	end, "localplayer")

	aowl.AddCommand("unmute|unblock=player",function(ply,line,target)
		local ent = net.ReadEntity()
		ent:SetMuted(false)
		ent.aowl_muted = nil
	end, "localplayer")

	hook.Add("OnPlayerChat","aowl_mute",function(ply)
		if ply.aowl_muted then
			return true
		end
	end)
end

aowl.AddCommand("fakedie=string[],string[],boolean", function(ply, line, killer, icon, swap)
	local victim = ply:Name()
	local killer_team = -1
	local victim_team = ply:Team()

	if swap then
		victim, killer = killer, victim
		victim_team, killer_team = killer_team, victim_team
	end

	GAMEMODE:AddDeathNotice(killer, killer_team, icon, victim, victim_team)
end, "clientside")

aowl.AddCommand("volume|vol=number",function(ply, line, vol)
	ply:ConCommand("volume " .. tostring(vol))
end, "localplayer")

aowl.AddCommand("fullupdate|update",function(ply, line)
	ply:ConCommand("record 1;stop")
end, "localplayer")

aowl.AddCommand("ctp|thirdperson|view|3p", function(ply, line)
	if ctp.Enabled then
		ctp.Disable()
	else
		ctp.Enable()
	end
end, "localplayer")

aowl.AddCommand("g|search", function(ply, line)
	local parts = string.Explode(" ", line)
	gui.OpenURL("https://www.google.com/#q="..table.concat( parts, "+", 1, #parts ))
end, "localplayer")

aowl.AddCommand("cmd|console", function(ply, line)
	ply:ConCommand(line)
end, "localplayer")

aowl.AddCommand("decals|cleardecals", function(ply, line)
	ply:ConCommand("r_cleardecals")
end, "localplayer")

do -- ignore players
	local ref = 0

	aowl.AddCommand("ignore|undraw=player",function(ply, line, ent)
		ent.ignore_draw = true

		if pac and pace then
			pac.IgnoreEntity(ent)
		end

		ref = ref + 1

		hook.Add("PrePlayerDraw", "ignore_draw", function(ply)
			if ply.ignore_draw then
				ply:SetNoDraw(true)
				ply:SetNotSolid(true)
				return true
			end
		end)

		hook.Add("pac_OnWoreOutfit", "ignore_draw", function(_, ply)
			if ply.ignore_draw then
				pac.IgnoreEntity(ply)
			end
		end)
	end, "localplayer")

	aowl.AddCommand("unignore|draw=player",function(ply, line, ent)
		if ent.ignore_draw then
			ent.ignore_draw = nil

			ent:SetNoDraw(false)
			ent:SetNotSolid(false)

			if pac and pace then
				pac.UnIgnoreEntity(ent)
			end

			ref = ref - 1
		end

		if ref <= 0 then
			hook.Remove("PrePlayerDraw", "ignore_draw")
			hook.Remove("pac_OnWoreOutfit", "ignore_draw")
		end
	end, "localplayer")
end