#define FuseSound	"mcinf/random/fuse.mp3"

static const char ExplosionSound[][] =
{
	"mcinf/random/explode1.mp3",
	"mcinf/random/explode2.mp3",
	"mcinf/random/explode3.mp3",
	"mcinf/random/explode4.mp3"
};

void MapStart_Tnt()
{
	PrecacheSound(FuseSound);
	
	for(int i; i<sizeof(ExplosionSound); i++)
	{
		PrecacheSound(ExplosionSound[i]);
	}
}

public void Interact_Tnt(int index, int entity, int client)
{
	float vel[3];
	vel[0] = GetRandomFloat(-2.0, 2.0);
	vel[1] = GetRandomFloat(-2.0, 2.0);
	vel[2] = 20.0;
	
	EmitSoundToAll(FuseSound, entity);
	PrimeTnt(entity, 4.0, client, vel);
}

public void Damage_Tnt(int index, int entity, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if((damagetype & DMG_CLUB) && CvarMeleeOnly.BoolValue)
		return;
	
	if(GetEntProp(entity, Prop_Data, "m_iHealth") <= RoundToNearest(damage))
	{
		SetEntProp(entity, Prop_Data, "m_takedamage", 0);
		//SetEntProp(entity, Prop_Data, "m_iHealth", 2000000000);
		PrimeTnt(entity, GetRandomFloat(0.5, 1.5), attacker, damageForce);
		damage = 0.0;
	}
}

static void PrimeTnt(int entity, float time, int owner, const float vel[3])
{
	int tnt = World.FindValue(EntIndexToEntRef(entity), WorldBlock::Ref);
	if(tnt != -1)
	{
		static WorldBlock wblock;
		World.GetArray(tnt, wblock);
		CallBlockNotice(wblock.Pos, false);
		World.Erase(tnt);
	}
	
	float pos[3], ang[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
	GetEntPropVector(entity, Prop_Data, "m_angRotation", ang);
	
	static int table = INVALID_STRING_TABLE;
	if(table == INVALID_STRING_TABLE)
		table = FindStringTable("modelprecache");
	
	char model[PLATFORM_MAX_PATH];
	ReadStringTable(table, GetEntProp(entity, Prop_Send, "m_nModelIndex"), model, sizeof(model));
	
	char skin[4];
	IntToString(GetEntProp(entity, Prop_Send, "m_nSkin"), skin, sizeof(skin));
	
	RemoveEntity(entity);
	
	/*tnt = CreateEntityByName("base_boss");
	if(tnt != -1)
	{
		TeleportEntity(tnt, pos, ang, NULL_VECTOR);
		
		DispatchKeyValue(tnt, "model", model);
		DispatchKeyValue(tnt, "skin", skin);
		DispatchKeyValue(tnt, "health", "2000000000");
		
		DispatchSpawn(tnt);
		ActivateEntity(tnt);
		
		SetEntityRenderFx(tnt, RENDERFX_PULSE_FAST_WIDE);
		
		TeleportEntity(tnt, NULL_VECTOR, NULL_VECTOR, vel);
		
		SetEntPropFloat(tnt, Prop_Send, "m_fadeMinDist", CvarFadeMinDist.FloatValue);
		SetEntPropFloat(tnt, Prop_Send, "m_fadeMaxDist", CvarFadeMaxDist.FloatValue);
		SetEntPropFloat(tnt, Prop_Send, "m_flModelScale", CvarModel.FloatValue);
		SetEntData(tnt, FindSendPropInfo("CTFBaseBoss", "m_lastHealthPercentage") + 28, false, 4);	// m_bResolvePlayerCollisions
		SetEntProp(tnt, Prop_Data, "m_bloodColor", -1);
		
		SDKHook(tnt, SDKHook_SetTransmit, OnBlockTransmit);
		
		SetEntityCollisionGroup(tnt, 27);
		SetEntProp(tnt, Prop_Send, "m_hOwnerEntity", owner);
		
		CreateTimer(time - 0.4, Tnt_ExpandDelay, EntIndexToEntRef(tnt), TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(time, Tnt_Explode, EntIndexToEntRef(tnt), TIMER_FLAG_NO_MAPCHANGE);
		
		SetEntProp(tnt, Prop_Send, "m_iTeamNum", GetEntProp(owner, Prop_Send, "m_iTeamNum"));
	}*/
	
	tnt = CreateEntityByName("prop_physics_multiplayer");
	if(tnt != -1)
	{
		TeleportEntity(tnt, pos, ang, NULL_VECTOR);
		
		DispatchKeyValue(tnt, "model", model);
		DispatchKeyValue(tnt, "skin", skin);
		DispatchKeyValue(tnt, "physicsmode", "2");
		DispatchKeyValueFloat(tnt, "massscale", 3.0);
		
		DispatchSpawn(tnt);
		
		SetEntityRenderFx(tnt, RENDERFX_PULSE_FAST_WIDE);
		
		TeleportEntity(tnt, NULL_VECTOR, NULL_VECTOR, vel);
		
		SetEntPropFloat(tnt, Prop_Send, "m_fadeMinDist", CvarFadeMinDist.FloatValue);
		SetEntPropFloat(tnt, Prop_Send, "m_fadeMaxDist", CvarFadeMaxDist.FloatValue);
		SetEntPropFloat(tnt, Prop_Send, "m_flModelScale", CvarModel.FloatValue);
		
		SetEntProp(tnt, Prop_Send, "m_hOwnerEntity", owner);
		
		int ref = EntIndexToEntRef(tnt);
		
		CreateTimer(time - 0.4, Tnt_ExpandDelay, ref, TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(time, Tnt_Explode, ref, TIMER_FLAG_NO_MAPCHANGE);
		
		SetEntProp(tnt, Prop_Send, "m_iTeamNum", GetEntProp(owner, Prop_Send, "m_iTeamNum"));
	}
}

public Action Tnt_ExpandDelay(Handle timer, int ref)
{
	Tnt_ExpandFrame(ref);
	return Plugin_Continue;
}

public void Tnt_ExpandFrame(int ref)
{
	int entity = EntRefToEntIndex(ref);
	if(entity != -1)
	{
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", GetEntPropFloat(entity, Prop_Send, "m_flModelScale") * 1.01);
		RequestFrame(Tnt_ExpandFrame, ref);
	}
}

public Action Tnt_Explode(Handle timer, int ref)
{
	int entity = EntRefToEntIndex(ref);
	if(entity != -1)
	{
		if(CurrentEntities < CvarLimit.IntValue + 10)
		{
			int explosion = CreateEntityByName("env_explosion");
			if(explosion != -1)
			{
				float pos[3];
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
				
				char radius[12];
				IntToString(RoundToCeil(CvarSize.FloatValue * CvarModel.FloatValue * 6.9), radius, sizeof(radius));
				
				DispatchKeyValue(explosion, "spawnflags", "64");
				DispatchKeyValue(explosion, "iMagnitude", "285");
				DispatchKeyValue(explosion, "iRadiusOverride", radius);
				
				DispatchSpawn(explosion);
				
				SetEntProp(explosion, Prop_Send, "m_hOwnerEntity", GetEntProp(entity, Prop_Send, "m_hOwnerEntity"));
				RemoveEntity(entity);
				
				TeleportEntity(explosion, pos, NULL_VECTOR, NULL_VECTOR);
				
				AcceptEntityInput(explosion, "Explode");
				RemoveEntity(explosion);
				
				EmitSoundToAll(ExplosionSound[GetURandomInt() % sizeof(ExplosionSound)], explosion, SNDLEVEL_GUNFIRE, _, _, _, _, _, pos);
			}
		}
		else
		{
			float pos[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
			RemoveEntity(entity);
			EmitSoundToAll(ExplosionSound[GetURandomInt() % sizeof(ExplosionSound)], entity, SNDLEVEL_GUNFIRE, _, _, _, _, _, pos);
		}
	}
	return Plugin_Continue;
}