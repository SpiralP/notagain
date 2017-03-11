AddCSLuaFile()

if SERVER then
	
	EMF = EMF or {}
	EMF.Ents = EMF.Ents or {}
	EMF.Topology = EMF.Topology or {}
	
	EMF.InitTopology = EMF.InitTopology or {}
	EMF.ActiveEnts   = EMF.ActiveEnts or {}
	EMF.MaxDistToRef = 1000 
	EMF.MinDistToRef = 100

	local BigValue = 100000	
	
	function EMF.GenerateTopology()

		local ToIgnore = {

			sky_camera               = true,
			env_fog_controller       = true,
			worldspawn               = true,
			func_physbox_multiplayer = true,
			info_particle_system     = true,
			game_text                = true,
			soundent                 = true,
			scene_manager            = true,
			env_skypaint             = true,

		}

		for _ , ent in pairs( ents.GetAll() ) do

			if !EMF.IsStuck( ent ) and ent:IsInWorld() and !ToIgnore[ent:GetClass()] then

				local tr = util.TraceLine({
					start  = ent:GetPos(),
					endpos = ent:GetPos() - ent:GetAngles():Up() * BigValue,
					mask   = MASK_PLAYERSOLID,
				})

				if tr.HitPos and !tr.HitNoDraw and !tr.HitSky and tr.HitWorld then
					
					EMF.Topology[#EMF.Topology + 1] = tr.HitPos
					EMF.InitTopology[#EMF.InitTopology + 1] = true
				
				end
			
			end

		end
	
	end

	function EMF.AddTopology( pos )
		
		local add = true
		
		for index , topo in pairs( EMF.Topology ) do
			
			if !EMF.InitTopology[index] and topo:Distance( pos ) < EMF.MaxDistToRef / 2 then
				
				add = false
				break
			
			end
		
		end

		if add then
			
			EMF.Topology[#EMF.Topology + 1] = pos 
			EMF.InitTopology[#EMF.InitTopology + 1] = false

		end
		
		return add
	
	end

	function EMF.TrackPlayersPos()

		local count = 0

		for _ , ply in pairs( player.GetAll() ) do
			
			if ply:IsInWorld() then
				
				if ply:OnGround() then
					
					if EMF.AddTopology( ply:GetPos() ) then
						count = count + 1
					end
				
				else

					local tr = util.TraceLine({
						start  = ply:GetPos(),
						endpos = ply:GetPos() - ply:GetAngles():Up() * BigValue,
						mask   = MASK_PLAYERSOLID,
					})

					if !tr.HitNoDraw and !tr.HitSky and tr.HitWorld and !tr.AllSolid then
						
						if EMF.AddTopology( tr.HitPos ) then
							count = count + 1
						end
					
					end

				end
			
			end
		
		end
		
		for _ = 1 , count do
			
			table.remove( EMF.Topology , 1 )
			table.remove( EMF.InitTopology , 1 )
		
		end
	
	end

	function EMF.GetRenewedTopology()

		local count = 0

		for _ , bool in pairs( EMF.InitTopology ) do

			if !bool then 

				count = count + 1 

			end

		end

		return math.Round( count / #EMF.InitTopology )

	end

	local function RandPosToRef( pos , min , max )
		
		local randpos     = Vector( math.random( -max , max ) , math.random( -max , max ) , 5 )
		local arearandpos = pos + randpos
		local finalpos    = ( pos:Distance( arearandpos ) < min and ( pos + ( pos - arearandpos ) ) or arearandpos )

		return finalpos
	
	end

	function EMF.IsStuck( ent )

		local refpos  = ent:WorldSpaceCenter() - Vector( 0 , 0 , ( ent:WorldSpaceCenter() - ent:NearestPoint( ent:GetPos() - Vector( 0 , 0 , BigValue ) ) ) )
		local refmins = ent:OBBMins()
		local refmaxs = ent:OBBMaxs()
		local refdist = 128

		for j = 1 , refmaxs.z do
			
			local currentpos = refpos + Vector( 0 , 0 , j )

			for i = 1 , 10 do 
				
				local tr = util.TraceHull({
					
					start  = currentpos,
					endpos = currentpos + Angle( 0 , i*36 - 180 , 0 ):Forward() * refdist,
					maxs   = refmaxs,
					mins   = refmins,
					filter = ent 
				
				})

				if tr.StartSolid then

					return true 

				end
			
			end
		
		end

		return false 
	
	end

	function EMF.SetValidPos( ent , ref ) 

		if !EMF.Topology[ref] or !ent or !IsValid( ent ) then return end 

		local refmins = ent:OBBMins()
		local refmaxs = ent:OBBMaxs()
		local refpos  = EMF.Topology[ref]
		local randpos = RandPosToRef( refpos , EMF.MinDistToRef , EMF.MaxDistToRef )

		local tr = util.TraceHull({
			start  = randpos,
			endpos = randpos.z >= 0 and randpos - Vector( 0 , 0 , refpos.z )  * BigValue or randpos + Vector( 0 , 0 , refpos.z )  * BigValue,
			maxs   = refmaxs,
			mins   = refmins,
			filter = ent,
			mask   = MASK_PLAYERSOLID,
		})

		if !EMF.IsStuck( ent ) and ent:IsInWorld() and !tr.HitNoDraw and !tr.HitSky and tr.HitWorld and !tr.StartSolid then

			ent:SetPos( tr.HitPos )
			ent:SetPos( ent:NearestPoint( ent:GetPos() - Vector( 0 , 0 , BigValue ) ) )  
			ent:DropToFloor() 

		else
			
			ent.EMFTryPos = ent.EMFTryPos and ent.EMFTryPos + 1 or 1
			
			if ent.EMFTryPos <= 30 then
				
				EMF.SetValidPos( ent , ref )
			
			else
				
				ent:SetPos( tr.HitPos )
			
			end
		
		end

		if EMF.IsStuck( ent ) or !ent:IsInWorld() then
			
			SafeRemoveEntity( ent ) 
			table.remove(EMF.ActiveEnts,ent.EMFID)
		
		end

	end

	function EMF.SetValidAngle( ent )
		
		if !ent or !IsValid( ent ) then return end
		
		local refpos     = ent:WorldSpaceCenter()
		local refmins    = ent:OBBMins()
		local refmaxs    = ent:OBBMaxs()
		local refdist    = refmaxs.x < refmaxs.y and ( refmaxs.x * 2 ) or ( refmaxs.y * 2 )
		
		local closest    = BigValue
		local finalang   = Angle()
		local angled     = false

		local function SetBestAngle( ang )

			finalang = ang 
			angled   = true

		end

		for i = 1 , 10 do -- Walls
			
			local currentang = Angle( 0 , i*36 - 180 , 0 )
			
			local tr = util.TraceHull({
				
				start  = refpos,
				endpos = refpos + currentang:Forward() * refdist,
				maxs   = refmaxs,
				mins   = refmins,
				filter = ent,
				mask   = MASK_PLAYERSOLID,
			
			})

			if closest > refpos:Distance( tr.HitPos ) then
				
				closest = refpos:Distance( tr.HitPos )
				SetBestAngle( currentang )
			
			end

			if tr.StartSolid then

				closest = 0
				SetBestAngle( currentang )
				break

			end
		
		end

		if !angled then -- Holes

			local ztr = util.TraceLine({

				start  = refpos,
				endpos = refpos - Vector( 0 , 0 , BigValue ),
				filter = ent,
				mask   = MASK_PLAYERSOLID,

			})

			local zrefpos = ztr.HitPos 
			local deepest = zrefpos.z

			for i = 1 , 10 do
				
				local currentang = Angle( 0 , i*36 - 180 , 0 )
				local currentpos = zrefpos + currentang:Forward() * refdist
				
				local tr = util.TraceLine({
					
					start  = currentpos,
					endpos = currentpos - Vector( 0 , 0 , BigValue ),
					filter = ent,
					mask   = MASK_PLAYERSOLID,
				
				})

				if tr.HitPos.z < deepest and !tr.StartSolid then

					deepest = tr.HitPos.z
					SetBestAngle( currentang )

				end

			end

		end

		if !angled then -- Random
			
			finalang = Angle( 0 , math.random( -180 , 180 ) , 0 )
		
		end
		
		ent:SetAngles( finalang )
		
	end

	function EMF.GenerateEnts()
		
		local MaxEntries = #EMF.Topology
		local AmScale    = math.Round( MaxEntries / 25 * ( 1 + EMF.GetRenewedTopology() ) )

		for i = 1 , AmScale do
			
			local random = math.random( 1 , #EMF.Ents )

			local function Unique()
				
				if EMF.Ents[random][2] then
					
					for _ , preent in pairs( EMF.ActiveEnts ) do
						
						if preent:GetClass() == EMF.Ents[random][1] then
							
							random = math.random( 1 , #EMF.Ents )
							break
						
						end
					
					end
				
				end

				Unique() 

			end
			
			local ent = ents.Create( EMF.Ents[random][1] )
			ent:Spawn()
			ent.EMFSpawned = true
			ent.EMFID = #EMF.ActiveEnts + 1

			EMF.SetValidPos( ent , math.random( 1 , #EMF.Topology ) )
			EMF.SetValidAngle( ent )
			EMF.ActiveEnts[ent.EMFID] = ent
		
		end
	
	end

	function EMF.RegenEnts()
		
		for _ , ent in pairs( EMF.ActiveEnts ) do
			
			SafeRemoveEntity( ent )
		
		end

		table.Empty( EMF.ActiveEnts )

		EMF.GenerateEnts()
	
	end

	function EMF.AddEnt( class , unique )

		unique = unique or false
		
		local add = true

		for _ , tbl in pairs( EMF.Ents ) do
			
			if tbl[1] == class then
				
				add = false
				break
			
			end
		
		end
		
		if add then
			
			EMF.Ents[#EMF.Ents + 1] = { class , unique }
		
		end

		return add
	
	end

	function EMF.Initialize()
		
		EMF.GenerateTopology()
		EMF.GenerateEnts()

		timer.Create( "EMFEntsRegen" , 600 , 0 , function()
			
			EMF.RegenEnts()
		
		end )

		timer.Create( "EMFPlayerTracking" , 20 , 0 , function()

			EMF.TrackPlayersPos()

		end)
	
	end

	hook.Add("InitPostEntity" , "EMFInit" , function()
		
		EMF.Initialize()
	
	end)

end

for _ , fl in ipairs( ( file.Find( "notagain/jrpg/entities/*" , "LUA" ) ) ) do
	
	include( "notagain/jrpg/entities/" .. fl )

end
