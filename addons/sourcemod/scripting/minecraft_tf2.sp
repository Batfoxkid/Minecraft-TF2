#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>
#include <sdkhooks>
#include <tf2_stocks>

#pragma newdecls required

#define	CONFIG_DL	"configs/mc/download.txt"
#define	CONFIG_BL	"configs/mc/blocks.cfg"
#define	CONFIG_SV	"configs/mc"
#define	CONFIG_SVFULL	"configs/mc/%s"

#define MAXTF2PLAYERS	36
#define SAVE_DELAY	86400	// 24 hours

enum struct Block
{
	char Name[64];
	char Model[64];
	char Skin[6];
	int Health;
	bool Light;
}

enum struct WorldBlock
{
	int Id;
	int Health;
	int Pos[3];
	float Ang[3];
	int Ref;
	bool Light;
}

enum struct BlockData
{
	int Id;
	float Score;
	float Pos[3];
}

Block DefaultBlock;
ArrayList Blocks;
ArrayList World;
ConVar CvarLimit;
ConVar CvarSize;
ConVar CvarModel;
ConVar CvarOffset;
ConVar CvarRange;
ConVar CvarAll;
ConVar CvarVote;
Cookie SaveDelay;

//bool BlockMoney;
bool LimitedMode;
bool IgnoreSpawn;
Handle RenderTimer;

int EntityCount;
int CurrentEntities;
Handle EntityTimer;

bool InMenu[MAXTF2PLAYERS];
int PredictRef[MAXTF2PLAYERS];
int Selected[MAXTF2PLAYERS];

public Plugin myinfo =
{
	name		=	"Dynamic Minecraft",
	description	=	"More blocks you say?",
	author		=	"Batfoxkid",
	version		=	"manual"
};

public void OnPluginStart()
{
	CvarLimit = CreateConVar("minecraft_edictlimit", "1900", "At what amount of edicts do we start limiting block rendering", FCVAR_NOTIFY, true, 0.0, true, 2000.0);
	CvarSize = CreateConVar("minecraft_blocksize", "50.0", "Size of blocks in Hammer Units (when modelscale is 1.0)", FCVAR_NOTIFY, true, 0.000001);
	CvarModel = CreateConVar("minecraft_modelscale", "1.0", "Model size of blocks", FCVAR_NOTIFY, true, 0.000001);
	CvarOffset = CreateConVar("minecraft_offset", "0.0 0.0 0.0", "Block offset from world origin", FCVAR_NOTIFY);
	CvarRange = CreateConVar("minecraft_range", "300.0", "Range for placing and removing blocks", _, true, 0.0);
	CvarAll = CreateConVar("minecraft_allplayers", "0", "Allow everyone to press Special Attack to give build tools", _, true, 0.0, true, 1.0);
	CvarVote = CreateConVar("minecraft_allvote", "0", "Allow everyone to with build tools to call a vote on world settings", _, true, 0.0, true, 1.0);

	AutoExecConfig();

	SaveDelay = new Cookie("mc_lastsave", "Save Delay", CookieAccess_Private);

	CvarLimit.AddChangeHook(ConVarChanged);
	CvarSize.AddChangeHook(ConVarChanged);
	CvarModel.AddChangeHook(ConVarChanged);
	CvarOffset.AddChangeHook(ConVarChanged);

	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);
	HookEvent("teamplay_round_start", OnMapRefresh, EventHookMode_PostNoCopy);
	HookEvent("tf_game_over", OnGameOver, EventHookMode_PostNoCopy);

	RegConsoleCmd("sm_build", Command_Tool, "Begin building", FCVAR_HIDDEN);
	RegConsoleCmd("sm_block", Command_Tool, "Begin building", FCVAR_HIDDEN);
	RegConsoleCmd("sm_mc", Command_Tool, "Begin building", FCVAR_HIDDEN);
	RegConsoleCmd("sm_minecraft", Command_Tool, "Begin building");
	RegConsoleCmd("sm_save", Command_Save, "Save building", FCVAR_HIDDEN);
	RegConsoleCmd("sm_load", Command_Save, "Save building", FCVAR_HIDDEN);
	RegConsoleCmd("sm_mcsave", Command_Save, "Save building");
	RegConsoleCmd("sm_mcload", Command_Save, "Save building", FCVAR_HIDDEN);
	RegAdminCmd("sm_clearblocks", Command_Clear, ADMFLAG_KICK, "Clears all Minecraft Blocks");

	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(!IgnoreSpawn)
	{
		IgnoreSpawn = true;
		RequestFrame(Frame_AllowSpawn);
	}

	if(World)
	{
		WorldBlock wblock;
		int length = World.Length;
		for(int i; i<length; i++)
		{
			World.GetArray(i, wblock);
			if(wblock.Ref != INVALID_ENT_REFERENCE)
			{
				int entity = EntRefToEntIndex(wblock.Ref);
				if(entity > MaxClients)
				{
					wblock.Health = GetEntProp(entity, Prop_Data, "m_iHealth");
					RemoveEntity(entity);
				}

				wblock.Ref = INVALID_ENT_REFERENCE;
				World.SetArray(i, wblock);
			}
		}
	}

	UpdateRendering();
}

public void OnMapStart()
{
	OnMapEnd();
	World = new ArrayList(sizeof(WorldBlock));
}

public void OnMapEnd()
{
	if(RenderTimer)
	{
		KillTimer(RenderTimer);
		RenderTimer = null;
	}

	if(World)
	{
		delete World;
		World = null;
	}
}

public void OnPluginEnd()
{
	if(World)
	{
		IgnoreSpawn = true;
		WorldBlock wblock;
		int length = World.Length;
		for(int i; i<length; i++)
		{
			World.GetArray(i, wblock);
			if(wblock.Ref != INVALID_ENT_REFERENCE)
			{
				wblock.Ref = EntRefToEntIndex(wblock.Ref);
				if(wblock.Ref > MaxClients)
					RemoveEntity(wblock.Ref);
			}
		}
	}
}

public void OnConfigsExecuted()
{
	int table = FindStringTable("downloadables");
	bool save = LockStringTables(false);

	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof(buffer), CONFIG_DL);
	File file = OpenFile(buffer, "r");
	while(!file.EndOfFile())
	{
		file.ReadLine(buffer, sizeof(buffer));
		ReplaceString(buffer, sizeof(buffer), "\n", "");
		AddToStringTable(table, buffer);
	}
	file.Close();

	LockStringTables(save);


	if(Blocks)
		delete Blocks;

	Blocks = new ArrayList(sizeof(Block));

	BuildPath(Path_SM, buffer, sizeof(buffer), CONFIG_BL);
	KeyValues kv = new KeyValues("Blocks");
	kv.ImportFromFile(buffer);

	Block block;
	kv.GotoFirstSubKey();
	do
	{
		if(kv.GetSectionName(block.Name, sizeof(block.Name)))
		{
			kv.GetString("model", block.Model, sizeof(block.Model), DefaultBlock.Model);
			kv.GetString("skin", block.Skin, sizeof(block.Skin), DefaultBlock.Skin);
			block.Health = kv.GetNum("health", DefaultBlock.Health);
			block.Light = view_as<bool>(kv.GetNum("light", DefaultBlock.Light));

			if(StrEqual(block.Name, "default"))
			{
				DefaultBlock = block;
			}
			else if(block.Model[0])
			{
				PrecacheModel(block.Model);
				Blocks.PushArray(block);
			}
		}
	} while(kv.GotoNextKey());
	delete kv;

	PrintToConsoleAll("Reloaded Minecraft with %d blocks", Blocks.Length);
}

public void OnMapRefresh(Event event, const char[] name, bool dontBroadcast)
{
	ConVarChanged(null, name, name);
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client && CvarAll.BoolValue)
		PrintToChat(client, "[SM] Use /mc to build blocks");
}

public void OnGameOver(Event event, const char[] name, bool dontBroadcast)
{
	if(World && World.Length>50)
	{
		char filepath[PLATFORM_MAX_PATH];
		GetCurrentMap(filepath, sizeof(filepath));
		BuildPath(Path_SM, filepath, sizeof(filepath), CONFIG_SVFULL, filepath);
		SaveWorld(0, filepath, GetTime());
	}
}

public Action Timer_UpdateRendering(Handle timer)
{
	RenderTimer = null;
	UpdateRendering();
}

/*
	blocks - Current Blocks
	limit - CvarLimit.IntValue;

	CvarLimit.IntValue > GetEntityCount()
	
	blocks - 900
	entities - 1900
	CvarLimit.IntValue - 1900

	remaining = Total Blocks + Entities - Alive Blocks;
	remaining = Entities + Non-Alive Blocks
	
	over = remaining - limit

	Note: If major lag, move scoring stuff to a different timer
*/

void UpdateRendering()
{
	if(World)
	{
		CurrentEntities = GetEntityCount();
		int limit = CvarLimit.IntValue;
		int blocks;
		LimitedMode = false;

		static WorldBlock wblock;
		int length = World.Length;
		for(int i; i<length; i++)
		{
			World.GetArray(i, wblock);
			if(wblock.Ref != INVALID_ENT_REFERENCE)
			{
				if(EntRefToEntIndex(wblock.Ref) <= MaxClients)
				{
					// We are going to assume a kill from another instance
					World.Erase(i);
					i--;
					length--;
				}
				continue;
			}

			blocks += wblock.Light ? 2 : 1;
		}

		LimitedMode = CurrentEntities + blocks >= limit;
		if(blocks || CurrentEntities >= limit)
		{
			if(!IgnoreSpawn)
			{
				IgnoreSpawn = true;
				RequestFrame(Frame_AllowSpawn);
			}

			static char buffer[48];
			CvarOffset.GetString(buffer, sizeof(buffer));

			float offset[3];
			ExplodeStringFloat(buffer, " ", offset, sizeof(offset));

			float spread = CvarModel.FloatValue*CvarSize.FloatValue;

			IntToString(length, buffer, sizeof(buffer));
			KeyValues kv = new KeyValues("Stuff", "title", buffer);
			kv.SetColor("color", 0, 255, 0, 255);
			kv.SetNum("level", 1);
			kv.SetNum("time", 1);
	
			int clients;
			static float pos[MAXTF2PLAYERS][3];
			for(int i=1; i<=MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i))
				{
					GetClientAbsOrigin(i, pos[clients++]);
					if(InMenu[i])
						CreateDialog(i, kv, DialogType_Msg);
				}
			}
			delete kv;

			ArrayList list = new ArrayList(sizeof(BlockData));
			static BlockData data;
			for(int i; i<length; i++)
			{
				World.GetArray(i, wblock);
				for(int a; a<3; a++)
				{
					data.Pos[a] = float(wblock.Pos[a]) * spread + offset[a];
				}

				data.Id = i;
				data.Score = Pow(GetVectorDistance(data.Pos, pos[0], true), -1.0);
				for(int a=1; a<clients; a++)
				{
					data.Score += Pow(GetVectorDistance(data.Pos, pos[a], true), -1.0);
				}
				list.PushArray(data);
			}

			list.SortCustom(Sort_DataScore);

			ArrayStack normal = new ArrayStack();
			ArrayStack glowing = new ArrayStack();
			for(int i; i<length; i++)
			{
				list.GetArray(i, data);
				World.GetArray(data.Id, wblock);
				if(wblock.Ref == INVALID_ENT_REFERENCE)
				{
					if(CurrentEntities + blocks < limit)
					{
						static Block block;
						Blocks.GetArray(wblock.Id, block);
						if(block.Light)
						{
							if(!glowing.Empty)
							{
								wblock.Ref = SwapBlock(glowing.Pop(), block.Model, block.Skin, wblock.Health, block.Light, data.Pos, wblock.Ang);
							}
							else if(EntityCount < limit)
							{
								if(!normal.Empty)
								{
									wblock.Ref = SwapBlock(normal.Pop(), block.Model, block.Skin, wblock.Health, block.Light, data.Pos, wblock.Ang);
								}
								else if(EntityCount+1 < limit)	// RemoveEntity isn't really instant...
								{
									wblock.Ref = CreateBlock(block.Model, block.Skin, wblock.Health, block.Light, data.Pos, wblock.Ang);
								}
							}
						}
						else if(!normal.Empty)
						{
							wblock.Ref = SwapBlock(normal.Pop(), block.Model, block.Skin, wblock.Health, block.Light, data.Pos, wblock.Ang);
						}
						else if(EntityCount < limit)	// RemoveEntity isn't really instant...
						{
							if(!glowing.Empty)
							{
								wblock.Ref = SwapBlock(glowing.Pop(), block.Model, block.Skin, wblock.Health, block.Light, data.Pos, wblock.Ang);
							}
							else
							{
								wblock.Ref = CreateBlock(block.Model, block.Skin, wblock.Health, block.Light, data.Pos, wblock.Ang);
							}
						}
						World.SetArray(data.Id, wblock);
						if(wblock.Light)
							blocks--;
					}
				}
				else if(CurrentEntities + blocks >= limit)
				{
					int entity = EntRefToEntIndex(wblock.Ref);
					if(entity > MaxClients)
					{
						wblock.Health = GetEntProp(entity, Prop_Data, "m_iHealth");
						if(wblock.Light)
						{
							glowing.Push(entity);
						}
						else
						{
							normal.Push(entity);
						}
					}

					wblock.Ref = INVALID_ENT_REFERENCE;
					World.SetArray(data.Id, wblock);
				}

				blocks--;
			}

			while(!normal.Empty)
			{
				RemoveEntity(normal.Pop());
			}
			while(!glowing.Empty)
			{
				RemoveEntity(glowing.Pop());
			}
			delete normal;
			delete glowing;
			delete list;
		}

		if(LimitedMode)
		{
			if(RenderTimer)
				KillTimer(RenderTimer);

			RenderTimer = CreateTimer(0.3, Timer_UpdateRendering);
		}
	}
}

public int Sort_DataScore(int index1, int index2, Handle array, Handle hndl)
{
	static BlockData data1, data2;
	GetArrayArray(array, index1, data1);
	GetArrayArray(array, index2, data2);
	if(data1.Score > data2.Score)
	{
		return 1;
	}
	else if(data1.Score < data2.Score || data1.Pos[0] > data2.Pos[0])
	{
		return -1;
	}
	return 1;
}

public int CreateBlock(const char[] model, const char[] skin, int health, bool hasLight, const float pos[3], const float ang[3])
{
	if(EntityCount > 2046)
	{
		PrintToChatAll("ENTITY LIMIT REACHED");
		return INVALID_ENT_REFERENCE;
	}

	int entity = CreateEntityByName("prop_dynamic_override");
	if(IsValidEntity(entity))
	{
		// TODO: Get better models made so angles are possible and maybe base_boss
		TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);

		float scale = CvarModel.FloatValue;

		DispatchKeyValue(entity, "model", model);
		DispatchKeyValue(entity, "skin", skin);
		DispatchKeyValue(entity, "solid", "6");
		DispatchKeyValue(entity, "health", "1");
		DispatchKeyValueFloat(entity, "modelscale", scale);

		DispatchSpawn(entity);
		ActivateEntity(entity);

		SetEntProp(entity, Prop_Data, "m_iMaxHealth", health);
		SetEntProp(entity, Prop_Data, "m_iHealth", health);

		if(hasLight)
		{
			int light = CreateEntityByName("light_dynamic");
			if(IsValidEntity(light))
			{
				DispatchKeyValue(light, "_light", "250 250 200");
				DispatchKeyValue(light, "brightness", "5");
				DispatchKeyValueFloat(light, "spotlight_radius", 280.0);
				DispatchKeyValueFloat(light, "distance", 180.0);
				DispatchKeyValue(light, "style", "0");
				DispatchSpawn(light);
				ActivateEntity(light);

				static float pos2[3];
				pos2[0] = pos[0];
				pos2[1] = pos[1];
				pos2[2] = pos[2] + CvarSize.FloatValue*scale/2.0;
				TeleportEntity(light, pos2, NULL_VECTOR, NULL_VECTOR); 

				SetEntPropEnt(light, Prop_Data, "m_hOwnerEntity", entity);

				SetVariantString("!activator");
				AcceptEntityInput(light, "SetParent", entity, light);
				AcceptEntityInput(light, "TurnOn");
			}
		}

		SDKHook(entity, SDKHook_OnTakeDamage, OnBlockDamaged);
		//HookSingleEntityOutput(entity, "OnBreak", OnBlockKilled, true);
	}

	return EntIndexToEntRef(entity);
}

public int SwapBlock(int entity, const char[] model, const char[] skin, int health, bool hasLight, const float pos[3], const float ang[3])
{
	TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);

	float scale = CvarModel.FloatValue;

	SetEntityModel(entity, model);
	SetEntProp(entity, Prop_Send, "m_nSkin", StringToInt(skin));

	SetEntProp(entity, Prop_Data, "m_iMaxHealth", health);
	SetEntProp(entity, Prop_Data, "m_iHealth", health);
	SetEntPropFloat(entity, Prop_Send, "m_flModelScale", scale);

	int light = -1;
	while((light=FindEntityByClassname(light, "light_dynamic")) != -1)
	{
		if(GetEntPropEnt(light, Prop_Data, "m_hOwnerEntity") == entity)
			break;
	}

	if(hasLight)
	{
		light = CreateEntityByName("light_dynamic");  
		if(IsValidEntity(light))    
		{
			DispatchKeyValue(light, "_light", "250 250 200");  
			DispatchKeyValue(light, "brightness", "5");  
			DispatchKeyValueFloat(light, "spotlight_radius", 280.0);  
			DispatchKeyValueFloat(light, "distance", 180.0);
			DispatchKeyValue(light, "style", "0");   
			DispatchSpawn(light);
			ActivateEntity(light);

			static float pos2[3];
			pos2[0] = pos[0];
			pos2[1] = pos[1];
			pos2[2] = pos[2] + CvarSize.FloatValue*scale/2.0;
			TeleportEntity(light, pos2, NULL_VECTOR, NULL_VECTOR); 

			SetEntPropEnt(light, Prop_Data, "m_hOwnerEntity", entity);

			SetVariantString("!activator");
			AcceptEntityInput(light, "SetParent", entity, light);
			AcceptEntityInput(light, "TurnOn");
		}
	}
	else if(light != -1)
	{
		AcceptEntityInput(light, "TurnOff");
		RemoveEntity(light);
	}

	return EntIndexToEntRef(entity);
}

public Action OnBlockDamaged(int entity, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(attacker < 1 || attacker > MaxClients)
		return Plugin_Continue;

	int dmg = RoundToNearest(damage);
	int health = GetEntProp(entity, Prop_Data, "m_iHealth") - dmg;
	if(health < 0)
		health = 0;

	Event event = CreateEvent("npc_hurt", true);
	event.SetInt("entindex", entity);
	event.SetInt("health", health);
	event.SetInt("damageamount", dmg);
	event.SetBool("crit", view_as<bool>(damagetype & DMG_CRIT));
	event.SetInt("attacker_player", GetClientUserId(attacker));
	event.SetInt("weaponid", weapon);
	event.Fire();

	if(health)
	{
		SetEntProp(entity, Prop_Data, "m_iHealth", health);
	}
	else
	{
		int ref = EntIndexToEntRef(entity);
		int id = World.FindValue(ref, WorldBlock::Ref);
		if(id != -1)
			World.Erase(id);

		RemoveEntity(entity);
	}

	/*SetVariantInt(dmg);
	FireEntityOutput(entity, "RemoveHealth", attacker, 0.0);

	SDKHooks_TakeDamage(entity, inflictor, attacker, damage, DMG_GENERIC, -1, damageForce, damagePosition);
	return Plugin_Handled;*/
	return Plugin_Handled;
}

/*public void OnBlockKilled(const char[] output, int caller, int activator, float delay)
{
	int ref = EntIndexToEntRef(caller);
	int id = World.FindValue(ref, WorldBlock::Ref);
	if(id != -1)
		World.Erase(id);

	if(!BlockMoney)
	{
		BlockMoney = true;
		RequestFrame(OnBlockKilledPost);
	}
}

public void OnBlockKilledPost()
{
	BlockMoney = false;
}*/

public void OnEntityCreated(int entity, const char[] classname)
{
	if(entity > CurrentEntities)
		CurrentEntities = entity;

	if(entity > EntityCount)	// Due to GetEntityCount() not exactly getting everything
	{
		EntityCount = entity;
		if(EntityTimer)
			KillTimer(EntityTimer);

		EntityTimer = CreateTimer(2.0, Timer_CheckEntity);
	}

	/*if(BlockMoney && StrEqual(classname, "item_currencypack_custom"))
	{
		SDKHook(entity, SDKHook_Spawn, OnCashSpawn);
		SDKHook(entity, SDKHook_SpawnPost, OnCashSpawnPost);
	}
	else */if(!IgnoreSpawn && entity > CvarLimit.IntValue)
	{
		UpdateRendering();
	}
}

public void OnEntityDestroyed(int entity)
{
	if(!IgnoreSpawn && LimitedMode)
		UpdateRendering();

	if(!EntityTimer)
		EntityTimer = CreateTimer(2.0, Timer_CheckEntity);
}

public void Frame_AllowSpawn(int entity)
{
	IgnoreSpawn = false;
}

public Action Timer_CheckEntity(Handle timer)
{
	EntityTimer = null;
	EntityCount = GetEntityCount();
	return Plugin_Continue;
}

/*public Action OnCashSpawn(int entity)
{
	return Plugin_Handled;
}

public void OnCashSpawnPost(int entity)
{
	RemoveEntity(entity);
}*/

public Action Command_Clear(int client, int args)
{
	if(!IgnoreSpawn)
		RequestFrame(Frame_AllowSpawn);

	OnPluginEnd();
	OnMapStart();
	return Plugin_Handled;
}

public Action Command_Tool(int client, int args)
{
	if(args && (!client || CheckCommandAccess(client, "sm_noclip", ADMFLAG_CHEATS)))
	{
		char pattern[PLATFORM_MAX_PATH];
		GetCmdArg(1, pattern, sizeof(pattern));

		char targetName[MAX_TARGET_LENGTH];
		int targets[MAXPLAYERS], matches;
		bool targetNounIsMultiLanguage;

		if((matches=ProcessTargetString(pattern, client, targets, sizeof(targets), COMMAND_FILTER_NO_BOTS, targetName, sizeof(targetName), targetNounIsMultiLanguage)) < 1)
		{
			ReplyToTargetError(client, matches);
			return Plugin_Handled;
		}

		for(int target; target<matches; target++)
		{
			if(IsClientSourceTV(targets[target]) || IsClientReplay(targets[target]))
				continue;

			InMenu[targets[target]] = true;
			ToolMenu(targets[target], 0);
			PrintToChatAll("[SM] %N gave %N building tools", client, targets[target]);
		}
	}
	else if(!client)
	{
		ReplyToCommand(client, "[SM] Usage: sm_minecraft <player>");
	}
	else if(CvarAll.BoolValue || CheckCommandAccess(client, "sm_noclip", ADMFLAG_CHEATS))
	{
		InMenu[client] = true;
		ToolMenu(client, 0);
	}
	else
	{
		ReplyToCommand(client, "[SM] %t", "No Access");
	}
	return Plugin_Handled;
}

void ToolMenu(int client, int page)
{
	Menu menu = new Menu(ToolMenuH);
	menu.SetTitle("Minecraft: Build\n ");

	Block block;
	int length = Blocks.Length;
	for(int i; i<length; i++)
	{
		Blocks.GetArray(i, block);
		menu.AddItem(block.Name, block.Name, Selected[client]==i ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}

	menu.DisplayAt(client, (page/7)*7, MENU_TIME_FOREVER);
}

public int ToolMenuH(Menu menu, MenuAction action, int client, int choice)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Cancel:
		{
			InMenu[client] = false;
			if(PredictRef[client] != INVALID_ENT_REFERENCE)
			{
				int entity = EntRefToEntIndex(PredictRef[client]);
				if(entity > MaxClients)
					RemoveEntity(entity);

				PredictRef[client] = INVALID_ENT_REFERENCE;
			}
		}
		case MenuAction_Select:
		{
			Selected[client] = choice;
			ToolMenu(client, choice);
		}
	}
}

public Action Command_Save(int client, int args)
{
	if(!client)
	{
		if(args > 0)
		{
			char file[PLATFORM_MAX_PATH], filepath[PLATFORM_MAX_PATH];
			GetCurrentMap(filepath, sizeof(filepath));
			GetCmdArgString(file, sizeof(file));
			BuildPath(Path_SM, filepath, sizeof(filepath), "%s/%s/%s.txt", CONFIG_SV, filepath, file);
			if(!LoadWorld(filepath))
				PrintToServer("[SM] Could not find save with this name");
		}
		else
		{
			if(!World || World.Length<2)
				return Plugin_Continue;

			char filepath[PLATFORM_MAX_PATH];
			GetCurrentMap(filepath, sizeof(filepath));
			BuildPath(Path_SM, filepath, sizeof(filepath), CONFIG_SVFULL, filepath);
			SaveWorld(client, filepath, GetTime());
		}
	}
	else if((CvarAll.BoolValue || CheckCommandAccess(client, "sm_noclip", ADMFLAG_CHEATS)) && (CvarVote.BoolValue || CheckCommandAccess(client, "sm_vote", ADMFLAG_VOTE)))
	{
		SaveMenu(client, 0);
	}
	else
	{
		ReplyToCommand(client, "[SM] %t", "No Access");
	}
	return Plugin_Handled;
}

enum struct SaveEnum
{
	int Stamp;
	char Display[64];
	char Filepath[64];
}

void SaveMenu(int client, int page)
{
	Menu menu = new Menu(SaveMenuH);
	menu.SetTitle("Minecraft: Saves\n ");

	static char filepath[PLATFORM_MAX_PATH];
	GetCurrentMap(filepath, sizeof(filepath));
	BuildPath(Path_SM, filepath, sizeof(filepath), CONFIG_SVFULL, filepath);

	menu.AddItem(filepath, "Save World\n ", (World && World.Length>10 && AreClientCookiesCached(client)) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	DirectoryListing dir = OpenDirectory(filepath);
	if(dir)
	{
		SaveEnum save;
		ArrayList list = new ArrayList(sizeof(SaveEnum));
		FileType type;
		static char file[PLATFORM_MAX_PATH];
		while(dir.GetNext(save.Filepath, sizeof(save.Filepath), type))
		{
			if(type == FileType_File && ReplaceString(save.Filepath, sizeof(save.Filepath), ".txt", "", false) == 1)
			{
				Format(file, sizeof(file), "%s/%s.txt", filepath, save.Filepath);
				save.Stamp = GetFileTime(save.Filepath, FileTime_LastChange);
				if(save.Stamp == -1)
				{
					Format(save.Display, sizeof(save.Display), "Unknown - %s", save.Filepath);
				}
				else
				{
					FormatTime(save.Display, sizeof(save.Display), "%b %d %R", save.Stamp);
					Format(save.Display, sizeof(save.Display), "%s - %s", save.Display, save.Filepath);
				}

				list.PushArray(save);
			}
		}
		delete dir;

		list.SortCustom(Sort_StampScore);

		int length = list.Length;
		for(int i; i<length; i++)
		{
			list.GetArray(i, save);
			menu.AddItem(save.Filepath, save.Display);
		}
		delete list;
	}

	menu.DisplayAt(client, (page/7)*7, MENU_TIME_FOREVER);
}

public int Sort_StampScore(int index1, int index2, Handle array, Handle hndl)
{
	static SaveEnum data1, data2;
	GetArrayArray(array, index1, data1);
	GetArrayArray(array, index2, data2);
	if(data1.Stamp > data2.Stamp)
	{
		return -1;
	}
	else if(data1.Stamp < data2.Stamp)
	{
		return 1;
	}
	return 0;
}

public int SaveMenuH(Menu menu, MenuAction action, int client, int choice)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			static char file[PLATFORM_MAX_PATH];
			if(choice)
			{
				if(CheckCommandAccess(client, "sm_map", ADMFLAG_CHANGEMAP))
				{
					static char filepath[PLATFORM_MAX_PATH];
					GetCurrentMap(filepath, sizeof(filepath));
					menu.GetItem(choice, file, sizeof(file));
					BuildPath(Path_SM, filepath, sizeof(filepath), "%s/%s/%s.txt", CONFIG_SV, filepath, file);
					if(!LoadWorld(filepath))
					{
						if(CheckCommandAccess(client, "sm_rcon", ADMFLAG_RCON))
						{
							PrintToChat(client, "[SM] Failed to load save '%s'", filepath);
						}
						else
						{
							PrintToChat(client, "[SM] Failed to load save");
						}
					}

					SaveMenu(client, choice);
				}
				else if(IsVoteInProgress())
				{
					PrintToChat(client, "[SM] %t", "Vote in Progress");
					SaveMenu(client, choice);
				}
				else
				{
					int delay = CheckVoteDelay();
					if(delay)
					{
						PrintToChat(client, "[SM] %t", "Vote Delay Seconds", delay);
						SaveMenu(client, choice);
					}
					else
					{
						static char display[64];
						menu.GetItem(choice, display, sizeof(display), _, file, sizeof(file));

						Menu vote = new Menu(VoteMenuH, MENU_ACTIONS_ALL);
						vote.SetTitle("%N wants to set Minecraft save to %s\nReset world and change to this save?\n ", client, file);

						menu.GetItem(choice, file, sizeof(file));

						vote.AddItem(file, "Yes");
						vote.AddItem(file, "No");

						vote.DisplayVoteToAll(20);
					}
				}
				return;
			}

			if(!World || World.Length<11)
			{
				SaveMenu(client, choice);
				return;
			}

			int time = GetTime();
			if(CheckCommandAccess(client, "sm_rcon", ADMFLAG_RCON))
			{
				if(AreClientCookiesCached(client))
				{
					int last = SaveDelay.GetClientTime(client);
					if(last > time + SAVE_DELAY)
					{
						PrintToChat(client, "[SM] You can not save for %d minutes", (last-time)/60);
						SaveMenu(client, choice);
						return;
					}
				}
				else
				{
					PrintToChat(client, "[SM] %t", "No Access");
					SaveMenu(client, choice);
					return;
				}
			}

			menu.GetItem(choice, file, sizeof(file));
			SaveWorld(client, file, time);
			SaveMenu(client, choice);
		}
	}
}

public int VoteMenuH(Menu menu, MenuAction action, int client, int choice)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_VoteEnd:
		{
			if(!choice)
			{
				static char file[PLATFORM_MAX_PATH], filepath[PLATFORM_MAX_PATH];
				GetCurrentMap(filepath, sizeof(filepath));
				menu.GetItem(choice, file, sizeof(file));
				BuildPath(Path_SM, filepath, sizeof(filepath), "%s/%s/%s.txt", CONFIG_SV, filepath, file);
				if(!LoadWorld(filepath))
					PrintToChatAll("[SM] Failed to load save");
			}
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	static int holding[MAXTF2PLAYERS];
	if(!InMenu[client])
	{
		if((buttons & IN_ATTACK3) && CvarAll.BoolValue)
		{
			InMenu[client] = true;
			ToolMenu(client, 0);
			holding[client] = IN_ATTACK3;
			buttons &= ~IN_ATTACK3;
			return Plugin_Changed;
		}
		return Plugin_Continue;
	}

	if(holding[client])
	{
		if(!(buttons & holding[client]))
			holding[client] = 0;
	}
	else if(buttons & IN_ATTACK)
	{
		BreakBlock(client);
		holding[client] = IN_ATTACK;
	}
	else if(buttons & IN_ATTACK2)
	{
		PlaceBlock(client);
		holding[client] = IN_ATTACK2;
	}
	else if(buttons & IN_ATTACK3)
	{
		PlaceBlock(client);
	}

	if(!holding[client])
	{
		PredictBlock(client);
	}
	else if(PredictRef[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(PredictRef[client]);
		if(entity > MaxClients)
			RemoveEntity(entity);

		PredictRef[client] = INVALID_ENT_REFERENCE;
	}

	buttons &= ~(IN_ATTACK|IN_ATTACK2|IN_RELOAD|IN_ATTACK3);
	SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime()+1.0);
	return Plugin_Changed;
}

void PredictBlock(int client)
{
	if(!DefaultBlock.Model[0])
		return;

	static float eye[3], ang[3], pos[3];
	GetClientEyePosition(client, eye);
	GetClientEyeAngles(client, ang);

	TR_TraceRayFilter(eye, ang, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer, client); 
	TR_GetEndPosition(pos);

	static char buffer[48];
	CvarOffset.GetString(buffer, sizeof(buffer));

	float offset[3];
	ExplodeStringFloat(buffer, " ", offset, sizeof(offset));

	float scale = CvarModel.FloatValue;
	float spread = scale*CvarSize.FloatValue;

	float range = CvarRange.FloatValue;
	float distance = GetVectorDistance(eye, pos);
	if(distance > range)
	{
		ConstrainDistance(eye, pos, distance, range);
	}
	else
	{
		ConstrainDistance(eye, pos, distance, distance-1.0);
	}

	for(int i; i<3; i++)
	{
		pos[i] = i==2 ? (RoundToFloor((pos[i] - offset[i]) / spread) * spread + offset[i]) : (RoundToNearest((pos[i] - offset[i]) / spread) * spread + offset[i]);
		ang[i] = (RoundToNearest(ang[i] / 90.0) * 90.0) + 90.0;
	}

	if(pos[0] > 32768.0 || pos[1] > 32768.0 || pos[2] > 32768.0 || pos[0] < -32768.0 || pos[1] < -32768.0 || pos[2] < -32768.0)
		return;

	int entity = EntRefToEntIndex(PredictRef[client]);
	if(entity > MaxClients)
	{
		TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
	}
	else
	{
		entity = CreateEntityByName("tf_taunt_prop");
		if(IsValidEntity(entity))
		{
			// TODO: Get better models made so angles are possible
			TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);

			SetEntityModel(entity, DefaultBlock.Model);
			SetEntProp(entity, Prop_Send, "m_nSkin", StringToInt(DefaultBlock.Skin));
			SetEntPropFloat(entity, Prop_Send, "m_flModelScale", scale);

			DispatchSpawn(entity);
			ActivateEntity(entity);

			SetEntityRenderMode(entity, RENDER_TRANSALPHA);
			SetEntityRenderColor(entity, 100, 10, 10, 100);
			SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", client);
			SDKHook(entity, SDKHook_SetTransmit, Transmit_Predict);

			PredictRef[client] = EntIndexToEntRef(entity);
		}
	}
}

public Action Transmit_Predict(int entity, int client)
{
	return GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity") == client ? Plugin_Continue : Plugin_Stop;
}

void BreakBlock(int client)
{
	if(World)
	{
		int entity = GetClientAimTarget(client, false);
		if(IsValidEntity(entity))
		{
			int id = World.FindValue(EntIndexToEntRef(entity), WorldBlock::Ref);
			if(id != -1)
			{
				static float pos1[3], pos2[3];
				GetClientEyePosition(client, pos1);
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos2);
				if(GetVectorDistance(pos1, pos2) < CvarRange.FloatValue + (CvarModel.FloatValue*CvarSize.FloatValue/2.0))
				{
					World.Erase(id);
					RemoveEntity(entity);
					ClientCommand(client, "playgamesound minecraft/stone2.mp3");
				}
			}
		}
	}
}

void PlaceBlock(int client)
{
	if(!World && Selected[client] < 0 || Selected[client] >= Blocks.Length)
		return;

	static float eye[3], ang[3], pos[3];
	GetClientEyePosition(client, eye);
	GetClientEyeAngles(client, ang);

	TR_TraceRayFilter(eye, ang, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer, client); 
	TR_GetEndPosition(pos);

	static char buffer[48];
	CvarOffset.GetString(buffer, sizeof(buffer));

	float offset[3];
	ExplodeStringFloat(buffer, " ", offset, sizeof(offset));

	float spread = CvarModel.FloatValue*CvarSize.FloatValue;

	float range = CvarRange.FloatValue;
	float distance = GetVectorDistance(eye, pos);
	if(distance > range)
	{
		ConstrainDistance(eye, pos, distance, range);
	}
	else
	{
		ConstrainDistance(eye, pos, distance, distance-1.0);
	}

	// data.Pos[a] = wblock.Pos[a] * spread + offset[a];
	int cords[3];
	for(int i; i<3; i++)
	{
		cords[i] = i==2 ? RoundToFloor((pos[i] - offset[i]) / spread) : RoundToNearest((pos[i] - offset[i]) / spread);
		pos[i] = cords[i] * spread + offset[i];
	}

	WorldBlock wblock;
	int length = World.Length;
	for(int i; i<length; i++)
	{
		World.GetArray(i, wblock);
		if(wblock.Pos[0] == cords[0] && wblock.Pos[1] == cords[1] && wblock.Pos[2] == cords[2])
		{
			PrintHintText(client, "Block inside another block");
			return;
		}
	}

	if(pos[0] > 32768.0 || pos[1] > 32768.0 || pos[2] > 32768.0 || pos[0] < -32768.0 || pos[1] < -32768.0 || pos[2] < -32768.0)
	{
		PrintHintText(client, "Block out of bounds");
		return;
	}

	static float pos2[3];
	pos2[0] = pos[0];
	pos2[1] = pos[1];
	pos2[2] = pos[2] + spread/2.0;
	spread *= 2.5;
	for(int i=1; i<=MaxClients; i++)
	{
		if(i != client && IsClientInGame(i) && IsPlayerAlive(i) && !TF2_IsPlayerInCondition(i, TFCond_HalloweenGhostMode))
		{
			GetClientAbsOrigin(i, offset);
			if(GetVectorDistance(offset, pos2) < spread)
			{
				PrintHintText(client, "Player in the way");
				return;
			}
		}
	}

	wblock.Id = Selected[client];
	for(int i; i<3; i++)
	{
		wblock.Pos[i] = cords[i];
		wblock.Ang[i] = (RoundToNearest(ang[i] / 90.0) * 90.0) + 90.0;
	}

	Block block;
	Blocks.GetArray(Selected[client], block);
	wblock.Health = block.Health;
	wblock.Light = block.Light;
	wblock.Ref = INVALID_ENT_REFERENCE;//CreateBlock(block.Model, block.Skin, wblock.Health, block.Light, pos, wblock.Ang);

	World.PushArray(wblock);
	UpdateRendering();

	ClientCommand(client, "playgamesound minecraft/stone1.mp3");
}

void SaveWorld(int client, char filepath[PLATFORM_MAX_PATH], int time)
{
	if(!DirExists(filepath))
	{
		if(!CreateDirectory(filepath, FPERM_O_EXEC|FPERM_O_READ|FPERM_G_EXEC|FPERM_G_READ|FPERM_U_EXEC|FPERM_U_WRITE|FPERM_U_READ))
		{
			if(!client)
			{
				LogError("Failed to create save folder '%s' for current map.", filepath);
			}
			else if(CheckCommandAccess(client, "sm_rcon", ADMFLAG_RCON))
			{
				PrintToChat(client, "[SM] Failed to create save folder '%s' for current map.", filepath);
			}
			else
			{
				PrintToChat(client, "[SM] Failed to create save block for current map.");
			}
			return;
		}
	}

	static char buffer[64];
	if(client)
	{
		if(GetClientName(client, buffer, sizeof(buffer)))
		{
			int length = strlen(buffer);
			for(int i; i<length; i++)
			{
				if(!IsValidConVarChar(buffer[i]))
				{
					if(i)
					{
						buffer[i] = '\0';
					}
					else
					{
						Format(buffer, sizeof(buffer), "unknown%d", time/60);
					}
					break;
				}

				buffer[i] = CharToLower(buffer[i]);
			}

			Format(buffer, sizeof(buffer), "%s%d", buffer, time/60);
		}
		else
		{
			Format(buffer, sizeof(buffer), "unknown%d", time/60);
		}
	}
	else
	{
		Format(buffer, sizeof(buffer), "autosave%d", time/60);
	}

	Format(filepath, sizeof(filepath), "%s/%s.txt", filepath, buffer);
	File file = OpenFile(filepath, "w");
	if(!file)
	{
		if(client)
		{
			PrintToChat(client, "[SM] Failed to create save.");
		}
		else
		{
			LogError("Failed to create '%s'", filepath);
		}
		return;
	}

	if(client)
	{
		SaveDelay.Set(client, buffer);
		if(GetClientAuthId(client, AuthId_SteamID64, buffer, sizeof(buffer)))
			file.WriteLine("Steam Account ID: %d", buffer);
	}

	WorldBlock wblock;
	int length = World.Length;
	for(int i; i<length; i++)
	{
		World.GetArray(i, wblock);
		file.WriteLine("%d;%d;%d;%d;%d;%.0f;%.0f;%.0f;%d", wblock.Id, wblock.Health, wblock.Pos[0], wblock.Pos[1], wblock.Pos[2], wblock.Ang[0], wblock.Ang[1], wblock.Ang[2], wblock.Light);
	}
	file.Close();
}

bool LoadWorld(const char[] filepath)
{
	File file = OpenFile(filepath, "r");
	if(!file)
		return false;

	if(!IgnoreSpawn)
		RequestFrame(Frame_AllowSpawn);

	OnPluginEnd();
	OnMapStart();

	WorldBlock wblock;
	wblock.Ref = INVALID_ENT_REFERENCE;
	while(!file.EndOfFile())
	{
		static char buffer[128];
		if(file.ReadLine(buffer, sizeof(buffer)))
		{
			int values[9];
			if(ExplodeStringInt(buffer, ";", values, sizeof(values)) > 7)
			{
				wblock.Id = values[0];
				wblock.Health = values[1];
				wblock.Pos[0] = values[2];
				wblock.Pos[1] = values[3];
				wblock.Pos[2] = values[4];
				wblock.Ang[0] = float(values[5]);
				wblock.Ang[1] = float(values[6]);
				wblock.Ang[2] = float(values[7]);
				wblock.Light = view_as<bool>(values[8]);
				World.PushArray(wblock);
			}
		}
	}
	file.Close();

	UpdateRendering();
	return true;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask, any data)
{
	return entity != data && IsValidEntity(entity);
}

int ExplodeStringInt(const char[] text, const char[] split, int[] buffers, int max)
{
	int reloc_idx, idx, total;

	if (max < 1 || !split[0])
	{
		return 0;
	}

	char buffer[12];
	while ((idx = SplitString(text[reloc_idx], split, buffer, sizeof(buffer))) != -1)
	{
		reloc_idx += idx;
		buffers[total] = StringToInt(buffer);
		if (++total == max)
			return total;
	}

	buffers[total++] = StringToInt(text[reloc_idx]);
	return total;
}

int ExplodeStringFloat(const char[] text, const char[] split, float[] buffers, int max)
{
	int reloc_idx, idx, total;

	if (max < 1 || !split[0])
	{
		return 0;
	}

	char buffer[16];
	while ((idx = SplitString(text[reloc_idx], split, buffer, sizeof(buffer))) != -1)
	{
		reloc_idx += idx;
		buffers[total] = StringToFloat(buffer);
		if (++total == max)
			return total;
	}

	buffers[total++] = StringToFloat(text[reloc_idx]);
	return total;
}

void ConstrainDistance(const float start[3], float end[3], float distance, float maximum)
{
	float factor = maximum / distance;
	for(int i; i<3; i++)
	{
		end[i] = ((end[i] - start[i]) * factor) + start[i];
	}
}