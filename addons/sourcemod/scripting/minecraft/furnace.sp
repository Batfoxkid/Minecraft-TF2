static const char FurnaceSound[][] =
{
	"mcinf/block/furnace/fire_crackle1.mp3",
	"mcinf/block/furnace/fire_crackle2.mp3",
	"mcinf/block/furnace/fire_crackle3.mp3",
	"mcinf/block/furnace/fire_crackle4.mp3",
	"mcinf/block/furnace/fire_crackle5.mp3"
};

void MapStart_Furnace()
{
	for(int i; i<sizeof(FurnaceSound); i++)
	{
		PrecacheSound(FurnaceSound[i]);
	}
}

public int Spawn_Furance(int entity, int &flags)
{
	if(!flags)
		return 0;
	
	CreateTimer(0.1, Furnace_Timer, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	AttachLight(entity, 13.0);
	SetEntProp(entity, Prop_Send, "m_nSkin", GetEntProp(entity, Prop_Send, "m_nSkin") + 1);
	return 1;
}

public void Damage_Furance(int index, int entity, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(IsValidEntity(weapon))
	{
		char classname[36];
		if(GetEntityClassname(weapon, classname, sizeof(classname)))
		{
			if(!StrContains(classname, "tf_weapon_flamethrower") ||
			   !StrContains(classname, "tf_weapon_rocketlauncher_fireball") ||
			   !StrContains(classname, "tf_weapon_flaregun") ||
			   damagecustom == TF_CUSTOM_TAUNT_HADOUKEN ||
			   damagecustom == TF_CUSTOM_BURNING_ARROW ||
			   damagecustom == TF_CUSTOM_SPELL_FIREBALL ||
			   damagecustom == TF_CUSTOM_TAUNTATK_GASBLAST)
			{
				static WorldBlock wblock;
				World.GetArray(index, wblock);
				
				bool newLight = wblock.Flags < 1;
				
				wblock.Flags += RoundToNearest(damage);
				if(wblock.Flags > 999)
				{
					damage = float(wblock.Flags - 999);
					wblock.Flags = 999;
				}
				else
				{
					damage = 0.0;
				}
				
				if(newLight && wblock.Flags > 0)
					wblock.Edicts += Spawn_Furance(entity, wblock.Flags);
				
				World.SetArray(index, wblock);
			}
		}
	}
}

public Action Furnace_Timer(Handle timer, int ref)
{
	int entity = EntRefToEntIndex(ref);
	if(entity != -1)
	{
		int id = World.FindValue(ref, WorldBlock::Ref);
		if(id != -1)
		{
			static WorldBlock wblock;
			World.GetArray(id, wblock);
			
			if(wblock.Flags > 1)
			{
				wblock.Flags--;
				if(!(wblock.Flags % 31))
					EmitSoundToAll(FurnaceSound[GetURandomInt() % sizeof(FurnaceSound)], entity, _, SNDLEVEL_HOME);
			}
			else
			{
				wblock.Flags = 0;
				SetEntProp(entity, Prop_Send, "m_nSkin", GetEntProp(entity, Prop_Send, "m_nSkin") - 1);
				
				int light = -1;
				while((light=FindEntityByClassname(light, "light_dynamic")) != -1)
				{
					if(GetEntPropEnt(light, Prop_Data, "m_hOwnerEntity") == entity)
					{
						RemoveEntity(light);
						wblock.Edicts--;
						break;
					}
				}
			}
			
			World.SetArray(id, wblock);
			
			if(wblock.Flags)
				return Plugin_Continue;
		}
	}
	return Plugin_Stop;
}