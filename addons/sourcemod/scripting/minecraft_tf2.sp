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

native any mctf_FuncToVal(Function func);

enum PosOffset
{
	Pos_Unknown = -1,
	Pos_XUp,
	Pos_XDown,
	Pos_YUp,
	Pos_YDown,
	Pos_ZUp,
	Pos_ZDown
}

enum struct Block
{
	char Id[32];
	char Name[64];
	char Model[PLATFORM_MAX_PATH];
	char Skin[4];
	int Health;
	int Rotate;
	bool Grief;
	
	Function OnSpawn;
	Function OnThink;
	Function OnNotice;
	Function OnInteract;
	Function OnDamage;
	
	int Inv[MAXTF2PLAYERS];
}

enum struct WorldBlock
{
	int Id;
	int Team;
	int Owner;
	int Health;
	int Pos[3];
	float Ang[3];
	int Ref;
	int Edicts;
	int Flags;
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
ConVar CvarFadeMinDist;
ConVar CvarFadeMaxDist;
ConVar CvarVote;
ConVar CvarNoCollide;
ConVar CvarNoGrief;
Cookie SaveDelay;

//bool BlockMoney;
bool LimitedMode;
bool IgnoreSpawn;
bool OffsetCached;
Handle RenderTimer;

int FreeingEntities;
int RenderTimers;
int CurrentEntities;

bool Creative[MAXTF2PLAYERS];
bool InMenu[MAXTF2PLAYERS];
int PredictRef[MAXTF2PLAYERS];
int Selected[MAXTF2PLAYERS];
int InPage[MAXTF2PLAYERS];

#include "minecraft/shared.sp"
#include "minecraft/chest.sp"
#include "minecraft/furnace.sp"
#include "minecraft/noteblock.sp"
#include "minecraft/sand.sp"
#include "minecraft/tnt.sp"

public Plugin myinfo =
{
	name		=	"Dynamic Minecraft",
	description	=	"More blocks you say?",
	author		=	"Batfoxkid",
	version		=	"manual"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("mctf_FuncToVal", Native_FuncToVal);
	CreateNative("MC_OpenMenu", Native_OpenMenu);
	CreateNative("MC_CloseMenu", Native_CloseMenu);
	CreateNative("MC_GetBlockInv", Native_GetBlockInv);
	CreateNative("MC_SetBlockInv", Native_SetBlockInv);
	return APLRes_Success;
}

public void OnPluginStart()
{
	CvarLimit = CreateConVar("minecraft_edictlimit", "1900", "At what amount of edicts do we start limiting block rendering", FCVAR_NOTIFY, true, 0.0, true, 2000.0);
	CvarSize = CreateConVar("minecraft_blocksize", "32.0", "Size of blocks in Hammer Units (when modelscale is 1.0)", FCVAR_NOTIFY, true, 0.000001);
	CvarModel = CreateConVar("minecraft_modelscale", "1.0", "Model size of blocks", FCVAR_NOTIFY, true, 0.000001);
	CvarOffset = CreateConVar("minecraft_offset", "0.0 0.0 0.0", "Block offset from world origin", FCVAR_NOTIFY);
	CvarRange = CreateConVar("minecraft_range", "300.0", "Range for placing and removing blocks", _, true, 0.0);
	CvarAll = CreateConVar("minecraft_allplayers", "0", "Allow everyone to press Special Attack to give build tools", _, true, 0.0, true, 1.0);
	CvarVote = CreateConVar("minecraft_allvote", "0", "Allow everyone to with build tools to call a vote on world settings", _, true, 0.0, true, 1.0);
	CvarFadeMinDist = CreateConVar("minecraft_fademindist", "3000.0", "Distance at which blocks starts fading", _, true, 0.0);
	CvarFadeMaxDist = CreateConVar("minecraft_fademaxdist", "4000.0", "Distance at which blocks ends fading", _, true, 0.0);
	CvarNoCollide = CreateConVar("minecraft_nocollide", "0", "Players on the same team except for the placer can walk through blocks", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	CvarNoGrief = CreateConVar("minecraft_nogrief", "0", "Standard players can't place blocks with 'grief' tag", _, true, 0.0, true, 1.0);

	AutoExecConfig();

	SaveDelay = new Cookie("mc_lastsave", "Save Delay", CookieAccess_Private);

	CvarLimit.AddChangeHook(ConVarChanged);
	CvarSize.AddChangeHook(ConVarChanged);
	CvarModel.AddChangeHook(ConVarChanged);
	CvarOffset.AddChangeHook(ConVarChanged);
	CvarFadeMinDist.AddChangeHook(ConVarChanged);
	CvarFadeMaxDist.AddChangeHook(ConVarChanged);
	CvarNoCollide.AddChangeHook(ConVarChanged);

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
	OffsetCached = false;
	StartSpawning();
	
	if(World)
	{
		static WorldBlock wblock;
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
	AddFileToDownloadsTable("sound/minecraft/stone1.mp3");
	AddFileToDownloadsTable("sound/minecraft/stone2.mp3");
	
	MapStart_Furnace();
	MapStart_Noteblock();
	MapStart_Tnt();
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
		static WorldBlock wblock;
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
	if(Blocks)
		delete Blocks;
	
	Blocks = new ArrayList(sizeof(Block));
	
	int table = FindStringTable("downloadables");
	
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof(buffer), CONFIG_BL);
	KeyValues kv = new KeyValues("Blocks");
	kv.ImportFromFile(buffer);
	
	Block block;
	kv.GotoFirstSubKey();
	do
	{
		if(kv.GetSectionName(block.Id, sizeof(block.Id)))
		{
			kv.GetString("name", block.Name, sizeof(block.Name), DefaultBlock.Name);
			kv.GetString("model", block.Model, sizeof(block.Model), DefaultBlock.Model);
			kv.GetString("skin", block.Skin, sizeof(block.Skin), DefaultBlock.Skin);
			block.Health = kv.GetNum("health", DefaultBlock.Health);
			block.Rotate = kv.GetNum("rotate", DefaultBlock.Rotate);
			block.Grief = view_as<bool>(kv.GetNum("grief", DefaultBlock.Grief));
			
			block.OnSpawn = KvGetFunction(kv, "onspawn", DefaultBlock.OnSpawn);
			block.OnThink = KvGetFunction(kv, "onthink", DefaultBlock.OnThink);
			block.OnNotice = KvGetFunction(kv, "onnotice", DefaultBlock.OnNotice);
			block.OnInteract = KvGetFunction(kv, "oninteract", DefaultBlock.OnInteract);
			block.OnDamage = KvGetFunction(kv, "ondamage", DefaultBlock.OnDamage);
			
			if(StrEqual(block.Id, "default"))
			{
				DefaultBlock = block;
			}
			else if(block.Model[0])
			{
				PrecacheModel(block.Model);
				Blocks.PushArray(block);
			}
			
			if(kv.JumpToKey("downloads"))
			{
				if(kv.GotoFirstSubKey(false))
				{
					bool save = LockStringTables(false);
					
					do
					{
						if(kv.GetSectionName(buffer, sizeof(buffer)))
						{
							kv.GetString(NULL_STRING, block.Skin, sizeof(block.Skin));
							if(!StrContains(block.Skin, "mdl"))
							{
								static const char Exts[][] = {"dx80.vtx", "dx90.vtx", "mdl", "phy", "vvd"};
								for(int i; i<sizeof(Exts); i++)
								{
									FormatEx(block.Model, sizeof(block.Model), "%s.%s", buffer, Exts[i]);
									if(FileExists(block.Model, true))
									{
										AddToStringTable(table, block.Model);
									}
									else
									{
										LogError("File '%s' not found", block.Model);
									}
								}
							}
							else if(!StrContains(block.Skin, "mat"))
							{
								static const char Exts[][] = {"vtf", "vmt"};
								for(int i; i<sizeof(Exts); i++)
								{
									FormatEx(block.Model, sizeof(block.Model), "%s.%s", buffer, Exts[i]);
									if(FileExists(block.Model, true))
									{
										AddToStringTable(table, block.Model);
									}
									else
									{
										LogError("File '%s' not found", block.Model);
									}
								}
							}
							else if(FileExists(buffer, true))
							{
								AddToStringTable(table, buffer);
							}
							else
							{
								LogError("File '%s' not found", buffer);
							}
						}
					} while(kv.GotoNextKey(false));
					
					kv.GoBack();
					LockStringTables(save);
				}
				kv.GoBack();
			}
		}
	} while(kv.GotoNextKey());
	delete kv;
	
	PrintToConsoleAll("Reloaded Minecraft with %d blocks", Blocks.Length);
}

public void OnClientDisconnect(int client)
{
	InPage[client] = 0;
	
	if(Blocks)
	{
		static Block block;
		int length = Blocks.Length;
		for(int i; i<length; i++)
		{
			Blocks.GetArray(i, block);
			if(block.Inv[client])
			{
				block.Inv[client] = 0;
				Blocks.SetArray(i, block);
			}
		}
	}
	
}

public void OnMapRefresh(Event event, const char[] name, bool dontBroadcast)
{
	ConVarChanged(null, name, name);
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if(CvarAll.BoolValue)
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		if(client)
			PrintToChat(client, "[SM] Use /mc to build blocks");
	}
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
	return Plugin_Continue;
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
		LimitedMode = false;
		bool empty;
		int limit = CvarLimit.IntValue;
		int blocks;
		
		static WorldBlock wblock;
		int length = World.Length;
		for(int i; i<length; i++)
		{
			World.GetArray(i, wblock);
			if(wblock.Ref == INVALID_ENT_REFERENCE)
			{
				empty = true;
			}
			else if(EntRefToEntIndex(wblock.Ref) <= MaxClients)
			{
				// We are going to assume a kill from another instance
				World.Erase(i);
				i--;
				length--;
			}
			else
			{
				blocks += wblock.Edicts;
			}
			
		}
		
		if(empty || CurrentEntities > limit)
		{
			StartSpawning();
			
			float offset[3];
			GetBlockOffset(offset);
			float spread = CvarModel.FloatValue*CvarSize.FloatValue;
			
			int clients;
			static float pos[MAXTF2PLAYERS][3];
			for(int i=1; i<=MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i))
					GetClientAbsOrigin(i, pos[clients++]);
			}
			
			ArrayList list = new ArrayList(2);
			static any data[2];
			for(int i; i<length; i++)
			{
				World.GetArray(i, wblock);
				for(int a; a<3; a++)
				{
					pos[MAXTF2PLAYERS-1][a] = float(wblock.Pos[a]) * spread + offset[a];
				}
				
				data[0] = i;
				data[1] = Pow(GetVectorDistance(pos[MAXTF2PLAYERS-1], pos[0], true), -1.0);
				for(int a=1; a<clients; a++)
				{
					data[1] += Pow(GetVectorDistance(pos[MAXTF2PLAYERS-1], pos[a], true), -1.0);
				}
				list.PushArray(data);
			}
			
			list.SortCustom(Sort_DataScore);
			// TODO: Make a custom sort algorithm that gets the top X amount then stops sorting
			// Allow the dream for tens of thousands of blocks with little lag
			//
			// X = (limit - CurrentEntities + FreeingEntities + blocks)
			// Probably, 2 am brain speaking at this moment
			
			int i;
			for(; i<length; i++)
			{
				list.GetArray(i, data);
				World.GetArray(data[0], wblock);
				if(wblock.Ref == INVALID_ENT_REFERENCE)
				{
					if(CurrentEntities < limit)
					{
						for(int a; a<3; a++)
						{
							pos[MAXTF2PLAYERS-1][a] = float(wblock.Pos[a]) * spread + offset[a];
						}
						
						// We have room for the block
						CreateBlock(wblock, pos[MAXTF2PLAYERS-1]);
						World.SetArray(data[0], wblock);
					}
					else if((CurrentEntities - FreeingEntities) < limit)
					{
						// We can make this block, just give it some time
						LimitedMode = true;
					}
					else
					{
						// Free some room for this block
						LimitedMode = true;
						blocks--;
					}
				}
				else if((limit - CurrentEntities + FreeingEntities + blocks) > 0)
				{
					// Keep this block please
					blocks -= wblock.Edicts;
				}
				else
				{
					// We reached our limit
					LimitedMode = true;
					break;
				}
			}
			
			for(int a = length-1; a >= i; a--)
			{
				list.GetArray(a, data);
				World.GetArray(data[0], wblock);
				if(wblock.Ref != INVALID_ENT_REFERENCE)
				{
					// Make some room for new blocks
					int entity = EntRefToEntIndex(wblock.Ref);
					if(entity > MaxClients)
					{
						wblock.Health = GetEntProp(entity, Prop_Data, "m_iHealth");
						AcceptEntityInput(entity, "KillHierarchy");
					}
					
					wblock.Ref = INVALID_ENT_REFERENCE;
					World.SetArray(data[0], wblock);
				}
			}
			
			delete list;
		}
		
		if(LimitedMode)
		{
			if(RenderTimer)
			{
				KillTimer(RenderTimer);
				RenderTimer = null;
			}
			
			if(!RenderTimers)
				RenderTimer = CreateTimer(0.3, Timer_UpdateRendering);
		}
	}
}

public int Sort_DataScore(int index1, int index2, Handle array, Handle hndl)
{
	return GetArrayCell(array, index2, 1) - GetArrayCell(array, index1, 1);
}

public void CreateBlock(WorldBlock wblock, const float pos[3])
{
	if(CurrentEntities > 2046)
	{
		PrintToChatAll("ENTITY LIMIT REACHED");
		return;
	}
	
	static Block block;
	Blocks.GetArray(wblock.Id, block);
	
	int entity = CreateEntityByName("base_boss");
	if(entity != -1)
	{
		TeleportEntity(entity, pos, wblock.Ang, NULL_VECTOR);
		
		DispatchKeyValue(entity, "model", block.Model);
		DispatchKeyValue(entity, "skin", block.Skin);
		DispatchKeyValue(entity, "health", "2000000000");
		
		DispatchSpawn(entity);
		ActivateEntity(entity);
		
		SetEntProp(entity, Prop_Send, "m_iTeamNum", wblock.Team);
		SetEntProp(entity, Prop_Data, "m_iMaxHealth", wblock.Health);
		SetEntProp(entity, Prop_Data, "m_iHealth", wblock.Health);
		SetEntPropFloat(entity, Prop_Send, "m_fadeMinDist", CvarFadeMinDist.FloatValue);
		SetEntPropFloat(entity, Prop_Send, "m_fadeMaxDist", CvarFadeMaxDist.FloatValue);
		SetEntPropFloat(entity, Prop_Send, "m_flModelScale", CvarModel.FloatValue);
		SetEntData(entity, FindSendPropInfo("CTFBaseBoss", "m_lastHealthPercentage") + 28, false, 4);	// m_bResolvePlayerCollisions
		SetEntProp(entity, Prop_Data, "m_bloodColor", -1);
		SetEntityFlags(entity, FL_NPC);
		
		wblock.Edicts = 1;
		wblock.Flags = 0;
		
		if(block.OnSpawn != INVALID_FUNCTION)
		{
			int amount;
			Call_StartFunction(null, block.OnSpawn);
			Call_PushCell(entity);
			Call_PushCellRef(wblock.Flags);
			Call_Finish(amount);
			wblock.Edicts += amount;
		}
		
		SDKHook(entity, SDKHook_OnTakeDamage, OnBlockDamaged);
		SDKHook(entity, SDKHook_SetTransmit, OnBlockTransmit);
		
		if(block.OnThink != INVALID_FUNCTION)
			SDKHook(entity, SDKHook_Think, mctf_FuncToVal(block.OnThink));
		
		if(CvarNoCollide.BoolValue)
		{
			SetEntityCollisionGroup(entity, 27);
			int owner = GetClientOfUserId(wblock.Owner);
			if(owner)
				SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", owner);
			//SDKHook(entity, SDKHook_Touch, OnBlockTouch);
			//SDKHook(entity, SDKHook_EndTouch, OnBlockEndTouch);
		}
		
		wblock.Ref = EntIndexToEntRef(entity);
	}
}

public Action OnBlockTransmit(int entity, int client)
{
	SetEdictFlags(entity, GetEdictFlags(entity) & ~FL_EDICT_ALWAYS);
	return Plugin_Changed;
}

public Action OnBlockDamaged(int entity, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	static WorldBlock wblock;
	int id = World.FindValue(EntIndexToEntRef(entity), WorldBlock::Ref);
	if(id != -1)
	{
		World.GetArray(id, wblock);
		
		static Block block;
		Blocks.GetArray(wblock.Id, block);
		
		if(block.OnDamage != INVALID_FUNCTION)
		{
			Call_StartFunction(null, block.OnDamage);
			Call_PushCell(id);
			Call_PushCell(entity);
			Call_PushCellRef(attacker);
			Call_PushCellRef(inflictor);
			Call_PushFloatRef(damage);
			Call_PushCellRef(damagetype);
			Call_PushCellRef(weapon);
			Call_PushArrayEx(damageForce, sizeof(damageForce), SP_PARAMFLAG_BYREF);
			Call_PushArrayEx(damagePosition, sizeof(damagePosition), SP_PARAMFLAG_BYREF);
			Call_PushCell(damagecustom);
			Call_Finish();
		}
	}
	
	if(damage == 0.0)
		return Plugin_Handled;
	
	bool client = (attacker > 0 && attacker <= MaxClients);
	if(client && CvarNoCollide.BoolValue && GetEntProp(entity, Prop_Send, "m_iTeamNum") == GetClientTeam(attacker))
	{
		if(id != -1)
		{
			int owner = GetClientOfUserId(wblock.Owner);
			if(!owner || owner != attacker)
				return Plugin_Handled;
		}
	}
	
	int dmg = RoundToNearest(damage);
	int health = GetEntProp(entity, Prop_Data, "m_iHealth") - dmg;
	if(health < 0)
		health = 0;
	
	if(client)
	{
		Event event = CreateEvent("npc_hurt", true);
		event.SetInt("entindex", entity);
		event.SetInt("health", health);
		event.SetInt("damageamount", dmg);
		event.SetBool("crit", view_as<bool>(damagetype & DMG_CRIT));
		event.SetInt("attacker_player", GetClientUserId(attacker));
		event.SetInt("weaponid", weapon);
		event.Fire();
	}
	
	if(health)
	{
		SetEntProp(entity, Prop_Data, "m_iHealth", health);
	}
	else
	{
		if(id != -1)
		{
			CallBlockNotice(wblock.Pos, false);
			World.Erase(id);
		}
		
		RemoveEntity(entity);
	}
	
	/*SetVariantInt(dmg);
	FireEntityOutput(entity, "RemoveHealth", attacker, 0.0);
	
	SDKHooks_TakeDamage(entity, inflictor, attacker, damage, DMG_GENERIC, -1, damageForce, damagePosition);
	return Plugin_Handled;*/
	return Plugin_Handled;
}

/*public bool OnBlockCollide(int entity, int collisiongroup, int contentsmask, bool originalResult)
{
	PrintToChatAll("%d %d", collisiongroup, contentsmask);
	if(collisiongroup == 8)
	{
		float spread = CvarModel.FloatValue*CvarSize.FloatValue;
		float mins[3], maxs[3];
		for(int i; i<3; i++)
		{
			maxs[i] = spread;
			mins[i] = -spread;
		}
		
		float pos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
		
		Handle trace = TR_TraceHullFilterEx(pos, pos, mins, maxs, MASK_PLAYERSOLID, TraceFilterBuilding, entity);
		bool found = (TR_DidHit(trace) && 0 < TR_GetEntityIndex(trace) <= MaxClients);
		delete trace;
		
		if(found)
			return false;
	}
	return originalResult;
}

public Action OnBlockTouch(int entity, int client)
{
	if(client > 0 && client <= MaxClients && GetEntProp(entity, Prop_Send, "m_iTeamNum") == GetClientTeam(client))
	{
		int id = World.FindValue(EntIndexToEntRef(entity), WorldBlock::Ref);
		if(id != -1)
		{
			WorldBlock wblock;
			World.GetArray(id, wblock);
			if(GetClientOfUserId(wblock.Owner) != client)
				SetEntityCollisionGroup(entity, 27);
		}
	}
	return Plugin_Continue;
}

public Action OnBlockEndTouch(int entity, int client)
{
	if(client > 0 && client <= MaxClients && GetEntProp(entity, Prop_Send, "m_iTeamNum") == GetClientTeam(client))
	{
		float spread = CvarModel.FloatValue*CvarSize.FloatValue;
		float mins[3], maxs[3];
		for(int i; i<3; i++)
		{
			maxs[i] = spread;
			mins[i] = -spread;
		}
		
		float pos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
		
		Handle trace = TR_TraceHullFilterEx(pos, pos, mins, maxs, MASK_PLAYERSOLID, TraceFilterBuilding, entity);
		bool found = (TR_DidHit(trace) && 0 < TR_GetEntityIndex(trace) <= MaxClients);
		delete trace;
		
		if(!found)
			SetEntityCollisionGroup(entity, 5);
	}
	return Plugin_Continue;
}

public void OnBlockKilled(const char[] output, int caller, int activator, float delay)
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

	/*if(entity > EntityCount)	// Due to GetEntityCount() not exactly getting everything
	{
		EntityCount = entity;
		if(EntityTimer)
			KillTimer(EntityTimer);

		EntityTimer = CreateTimer(2.0, Timer_CheckEntity);
	}*/

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
	// In Source Engine, edicts won't get reallocated for 1 second after being freed
	FreeingEntities++;
	
	bool render;
	if(LimitedMode)
	{
		float gameTime = GetGameTime();
		static float lastRenderRequest;
		if(lastRenderRequest < gameTime)
		{
			lastRenderRequest = gameTime + 0.1;
			render = true;
			RenderTimers++;
		}
	}
	
	CreateTimer(1.01, Timer_FreeEdict, render);
}

public Action Timer_FreeEdict(Handle timer, bool render)
{
	FreeingEntities--;
	CurrentEntities--;
	if(render)
	{
		RenderTimers--;
		if(LimitedMode)
			UpdateRendering();
	}
	return Plugin_Continue;
}

public void Frame_AllowSpawn(int entity)
{
	IgnoreSpawn = false;
}

/*public Action Timer_CheckEntity(Handle timer)
{
	EntityTimer = null;
	EntityCount = GetEntitySlots();
	return Plugin_Continue;
}*/

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
	StartSpawning();
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

			Creative[targets[target]] = true;
			InMenu[targets[target]] = true;
			ToolMenu(targets[target]);
			PrintToChatAll("[SM] %N gave %N building tools", client, targets[target]);
		}
	}
	else if(!client)
	{
		ReplyToCommand(client, "[SM] Usage: sm_minecraft <player>");
	}
	else if(CvarAll.BoolValue || CheckCommandAccess(client, "sm_noclip", ADMFLAG_CHEATS))
	{
		Creative[client] = true;
		InMenu[client] = true;
		ToolMenu(client);
	}
	else
	{
		ReplyToCommand(client, "[SM] %t", "No Access");
	}
	return Plugin_Handled;
}

void ToolMenu(int client)
{
	Menu menu = new Menu(ToolMenuH);
	menu.SetTitle("Minecraft: Build\n ");
	
	bool creative = Creative[client];
	bool noGrief = (CvarNoGrief.BoolValue && !CheckCommandAccess(client, "sm_noclip", ADMFLAG_CHEATS));
	
	Block block;
	char num[12], buffer[64];
	int count;
	int length = Blocks.Length;
	for(int i; i<length; i++)
	{
		Blocks.GetArray(i, block);
		if((!noGrief || !block.Grief) && (creative || block.Inv[client] > 0))
		{
			count++;
			IntToString(i, num, sizeof(num));
			if(creative)
			{
				menu.AddItem(num, block.Name, Selected[client]==i ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
			}
			else
			{
				if(Selected[client] == -1)
					Selected[client] = i;
				
				FormatEx(buffer, sizeof(buffer), "%s (x%d)", block.Name, block.Inv[client]);
				menu.AddItem(num, buffer, Selected[client]==i ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
			}
		}
	}
	
	if(!count)
		menu.AddItem("-1", "None", ITEMDRAW_DISABLED);
	
	if(InPage[client] > count)
		InPage[client] = count;
	
	menu.DisplayAt(client, (InPage[client]/7)*7, MENU_TIME_FOREVER);
	
	InMenu[client] = true;
	Creative[client] = creative;
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
			Creative[client] = false;
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
			char buffer[12];
			menu.GetItem(choice, buffer, sizeof(buffer));
			Selected[client] = StringToInt(buffer);
			InPage[client] = choice;
			ToolMenu(client);
		}
	}
	return 0;
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
				save.Stamp = GetFileTime(file, FileTime_LastChange);
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
				return 0;
			}

			if(!World || World.Length<11)
			{
				SaveMenu(client, choice);
				return 0;
			}

			int time = GetTime();
			if(!CheckCommandAccess(client, "sm_rcon", ADMFLAG_RCON))
			{
				if(AreClientCookiesCached(client))
				{
					int last = SaveDelay.GetClientTime(client);
					if(last > time + SAVE_DELAY)
					{
						PrintToChat(client, "[SM] You can not save for %d minutes", (last-time)/60);
						SaveMenu(client, choice);
						return 0;
					}
				}
				else
				{
					PrintToChat(client, "[SM] %t", "No Access");
					SaveMenu(client, choice);
					return 0;
				}
			}

			menu.GetItem(choice, file, sizeof(file));
			SaveWorld(client, file, time);
			SaveMenu(client, choice);
		}
	}
	return 0;
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
	return 0;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	static int holding[MAXTF2PLAYERS];
	if(holding[client])
	{
		if(!(buttons & holding[client]))
			holding[client] = 0;
	}
	else if(buttons & IN_ATTACK)
	{
		holding[client] = IN_ATTACK;
		if(InMenu[client])
			BreakBlock(client);
	}
	else if(buttons & IN_ATTACK2)
	{
		holding[client] = IN_ATTACK2;
		if(InMenu[client])
			PlaceBlock(client);
	}
	else if(buttons & IN_ATTACK3)
	{
		if(InMenu[client])
		{
			PlaceBlock(client);
		}
		else if(CvarAll.BoolValue)
		{
			Creative[client] = true;
			InMenu[client] = true;
			ToolMenu(client);
			holding[client] = IN_ATTACK3;
			buttons &= ~IN_ATTACK3;
			return Plugin_Changed;
		}
	}
	else if(buttons & IN_USE)
	{
		holding[client] = IN_USE;
		InteractBlock(client);
	}
	else if(buttons & IN_RELOAD)
	{
		holding[client] = IN_RELOAD;
		InteractBlock(client);
	}

	if(InMenu[client])
	{
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
	return Plugin_Continue;
}

void PredictBlock(int client)
{
	if(!DefaultBlock.Model[0])
		return;

	static float eye[3], ang[3], pos[3];
	GetClientEyePosition(client, eye);
	GetClientEyeAngles(client, ang);

	Handle trace = TR_TraceRayFilterEx(eye, ang, MASK_SOLID, RayType_Infinite, TraceFilterEntity, client); 
	TR_GetEndPosition(pos, trace);
	delete trace;
	
	float scale = CvarModel.FloatValue;
	float spread = scale*CvarSize.FloatValue;
	if(!Creative[client])
	{
		float mins[3], maxs[3];
		for(int i; i<3; i++)
		{
			maxs[i] = spread;
			mins[i] = -spread;
		}
		
		trace = TR_TraceHullFilterEx(eye, pos, mins, maxs, MASK_PLAYERSOLID, TraceFilterWorld);
		if(TR_DidHit(trace))
			TR_GetEndPosition(pos, trace);
		
		delete trace;
	}

	float offset[3];
	GetBlockOffset(offset);

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
		pos[i] = /*i==2 ? (RoundToFloor((pos[i] - offset[i]) / spread) * spread + offset[i]) : */(RoundToNearest((pos[i] - offset[i]) / spread) * spread + offset[i]);
		ang[i] = (RoundToNearest(ang[i] / 90.0) * 90.0)/* + 90.0*/;
	}

	if(pos[0] > 32768.0 || pos[1] > 32768.0 || pos[2] > 32768.0 || pos[0] < -32768.0 || pos[1] < -32768.0 || pos[2] < -32768.0)
		return;

	int entity = EntRefToEntIndex(PredictRef[client]);
	if(entity > MaxClients)
	{
		TeleportEntity(entity, pos, ang, NULL_VECTOR);
	}
	else
	{
		entity = CreateEntityByName("tf_taunt_prop");
		if(entity != -1)
		{
			TeleportEntity(entity, pos, ang, NULL_VECTOR);

			SetEntityModel(entity, DefaultBlock.Model);
			SetEntProp(entity, Prop_Send, "m_nSkin", StringToInt(DefaultBlock.Skin));
			SetEntPropFloat(entity, Prop_Send, "m_flModelScale", scale);
			SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);

			DispatchSpawn(entity);
			ActivateEntity(entity);

			SetEntityRenderMode(entity, RENDER_TRANSALPHA);
			SetEntityRenderColor(entity, 100, 10, 10, 100);
			SetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity", client);
			SDKHook(entity, SDKHook_SetTransmit, Transmit_Predict);
			SDKHook(entity, SDKHook_ShouldCollide, ShouldCollide_None);

			PredictRef[client] = EntIndexToEntRef(entity);
		}
	}
}

public Action Transmit_Predict(int entity, int client)
{
	return GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity") == client ? Plugin_Continue : Plugin_Stop;
}

public bool ShouldCollide_None(int entity, int collisiongroup, int contentsmask, bool originalResult)
{
	return false;
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
				static WorldBlock wblock;
				World.GetArray(id, wblock);
				if(Creative[client] || GetClientOfUserId(wblock.Owner) == client)
				{
					static float pos1[3], pos2[3];
					GetClientEyePosition(client, pos1);
					GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos2);
					if(GetVectorDistance(pos1, pos2) < CvarRange.FloatValue + (CvarModel.FloatValue*CvarSize.FloatValue/2.0))
					{
						if(!Creative[client])
						{
							static Block block;
							Blocks.GetArray(wblock.Id, block);
							if(CvarNoCollide.BoolValue && GetEntProp(entity, Prop_Data, "m_iHealth") < block.Health)
							{
								PrintHintText(client, "Block is damaged");
								return;
							}
							
							block.Inv[client]++;
							Blocks.SetArray(wblock.Id, block);
							if(InMenu[client])
								ToolMenu(client);
						}
						
						CallBlockNotice(wblock.Pos, false);
						World.Erase(id);
						RemoveEntity(entity);
						ClientCommand(client, "playgamesound minecraft/stone2.mp3");
					}
				}
			}
		}
	}
}

void PlaceBlock(int client)
{
	if(!World || Selected[client] < 0 || Selected[client] >= Blocks.Length)
		return;
	
	Block block;
	Blocks.GetArray(Selected[client], block);
	if(!Creative[client] && block.Inv[client] < 1)
	{
		PrintHintText(client, "Out of blocks");
		Selected[client] = -1;
		if(InMenu[client])
			ToolMenu(client);
		
		return;
	}
	
	static float eye[3], ang[3], pos[3];
	GetClientEyePosition(client, eye);
	GetClientEyeAngles(client, ang);
	
	Handle trace = TR_TraceRayFilterEx(eye, ang, MASK_SOLID, RayType_Infinite, TraceFilterEntity, client); 
	TR_GetEndPosition(pos, trace);
	delete trace;
	
	float spread = CvarModel.FloatValue*CvarSize.FloatValue;
	if(!Creative[client])
	{
		float mins[3], maxs[3];
		for(int i; i<3; i++)
		{
			maxs[i] = spread;
			mins[i] = -spread;
		}
		
		trace = TR_TraceHullFilterEx(eye, pos, mins, maxs, MASK_PLAYERSOLID, TraceFilterWorld);
		if(TR_DidHit(trace))
			TR_GetEndPosition(pos, trace);
		
		delete trace;
	}
	
	float offset[3];
	GetBlockOffset(offset);
	
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
		cords[i] = /*i==2 ? RoundToFloor((pos[i] - offset[i]) / spread) :*/ RoundToNearest((pos[i] - offset[i]) / spread);
		pos[i] = cords[i] * spread + offset[i];
	}
	
	static WorldBlock wblock;
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
	
	if(!Creative[client])
	{
		block.Inv[client]--;
		Blocks.SetArray(Selected[client], block);
		
		if(!block.Inv[client])
			Selected[client] = -1;
		
		if(InMenu[client])
			ToolMenu(client);
	}
	
	for(int i; i<3; i++)
	{
		wblock.Pos[i] = cords[i];
		if(i == 1)
		{
			if(block.Rotate)
			{
				wblock.Ang[i] = (RoundToNearest(ang[i] / 90.0) * 90.0);
			}
			else
			{
				wblock.Ang[i] = -90.0;
			}
		}
		else if(block.Rotate > 1)
		{
			wblock.Ang[i] = (RoundToNearest(ang[i] / 90.0) * 90.0) + 180.0;
		}
	}
	
	wblock.Owner = GetClientUserId(client);
	wblock.Team = GetClientTeam(client);
	wblock.Health = block.Health;
	if(CurrentEntities < 2030)
	{
		// Yes were creating pass our limit but for good reason
		CreateBlock(wblock, pos);
	}
	else
	{
		wblock.Ref = INVALID_ENT_REFERENCE;
	}
	
	World.PushArray(wblock);
	CallBlockNotice(wblock.Pos, true);
	
	ClientCommand(client, "playgamesound minecraft/stone1.mp3");
}

void InteractBlock(int client)
{
	if(World)
	{
		int entity = GetClientAimTarget(client, false);
		if(IsValidEntity(entity))
		{
			int id = World.FindValue(EntIndexToEntRef(entity), WorldBlock::Ref);
			if(id != -1)
			{
				static WorldBlock wblock;
				World.GetArray(id, wblock);
				
				static float pos1[3], pos2[3];
				GetClientEyePosition(client, pos1);
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos2);
				if(GetVectorDistance(pos1, pos2) < CvarRange.FloatValue + (CvarModel.FloatValue*CvarSize.FloatValue/2.0))
				{
					static Block block;
					Blocks.GetArray(wblock.Id, block);
					if(block.OnInteract != INVALID_FUNCTION)
					{
						Call_StartFunction(null, block.OnInteract);
						Call_PushCell(id);
						Call_PushCell(entity);
						Call_PushCell(client);
						Call_Finish();
					}
				}
			}
		}
	}
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

	Block block;
	static WorldBlock wblock;
	int length = World.Length;
	for(int i; i<length; i++)
	{
		World.GetArray(i, wblock);
		Blocks.GetArray(wblock.Id, block);
		file.WriteLine("%s;%d;%d;%d;%d;%.0f;%.0f;%.0f;%d;%d", block.Id, wblock.Health, wblock.Pos[0], wblock.Pos[1], wblock.Pos[2], wblock.Ang[0], wblock.Ang[1], wblock.Ang[2], wblock.Team, wblock.Flags);
	}
	file.Close();
}

bool LoadWorld(const char[] filepath)
{
	File file = OpenFile(filepath, "r");
	if(!file)
		return false;

	StartSpawning();
	OnPluginEnd();
	OnMapStart();

	Block block;
	WorldBlock wblock;
	wblock.Ref = INVALID_ENT_REFERENCE;
	while(!file.EndOfFile())
	{
		static char buffer[256], buffers[10][32];
		if(file.ReadLine(buffer, sizeof(buffer)) && ExplodeString(buffer, ";", buffers, sizeof(buffers), sizeof(buffers[])))
		{
			if((wblock.Id = GetBlockOfId(buffers[0], block)) != -1)
			{
				wblock.Health = StringToInt(buffers[1]);
				wblock.Pos[0] = StringToInt(buffers[2]);
				wblock.Pos[1] = StringToInt(buffers[3]);
				wblock.Pos[2] = StringToInt(buffers[4]);
				wblock.Ang[0] = StringToFloat(buffers[5]);
				wblock.Ang[1] = StringToFloat(buffers[6]);
				wblock.Ang[2] = StringToFloat(buffers[7]);
				wblock.Team = StringToInt(buffers[8]);
				wblock.Flags = StringToInt(buffers[9]);
				World.PushArray(wblock);
			}
		}
	}
	file.Close();

	UpdateRendering();
	return true;
}

int GetBlockOfId(const char[] id, Block block)
{
	int length = Blocks.Length;
	for(int i; i<length; i++)
	{
		Blocks.GetArray(i, block);
		if(StrEqual(id, block.Id))
			return i;
	}
	return -1;
}

public bool TraceFilterEntity(int entity, int contentsMask, any data)
{
	return entity != data && IsValidEntity(entity);
}

public bool TraceFilterBuilding(int entity, int contentsMask, any data)
{
	return entity != data && entity > 0 && entity <= MaxClients && GetClientTeam(entity) == GetEntProp(data, Prop_Send, "m_iTeamNum");
}

public bool TraceFilterPlayer(int entity, int contentsMask, any data)
{
	return entity != data && entity > 0 && entity <= MaxClients;
}

public bool TraceFilterWorld(int entity, int contentsMask, any data)
{
	return entity == 0;
}

stock int ExplodeStringInt(const char[] text, const char[] split, int[] buffers, int max)
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

void StartSpawning()
{
	if(!IgnoreSpawn)
	{
		IgnoreSpawn = true;
		RequestFrame(Frame_AllowSpawn);
	}
}

void GetBlockOffset(float offset[3])
{
	static float cache[3];
	if(!OffsetCached)
	{
		char buffer[48];
		CvarOffset.GetString(buffer, sizeof(buffer));
		ExplodeStringFloat(buffer, " ", cache, sizeof(cache));
		OffsetCached = true;
	}
	
	for(int i; i<3; i++)
	{
		offset[i] = cache[i];
	}
}

Function KvGetFunction(Handle kv, const char[] key, Function defvalue=INVALID_FUNCTION)
{
	static char buffer[48];
	KvGetString(kv, key, buffer, sizeof(buffer), "1");
	if(buffer[0] == '1' && defvalue)
		return defvalue;
	
	return GetFunctionByName(null, buffer);
}

void CallBlockNotice(int pos[3], bool create)
{
	static WorldBlock wblock;
	int length = World.Length;
	for(int i; i<length; i++)
	{
		World.GetArray(i, wblock);
		static Block block;
		Blocks.GetArray(wblock.Id, block);
		if(block.OnNotice != INVALID_FUNCTION)
		{
			bool equalX = pos[0] == wblock.Pos[0];
			bool equalY = pos[1] == wblock.Pos[1];
			bool equalZ = pos[2] == wblock.Pos[2];
			
			PosOffset offset = Pos_Unknown;
			if(equalY && equalZ)
			{
				int result = pos[0] - wblock.Pos[0];
				if(result == 1)
				{
					offset = Pos_XUp;
				}
				else if(result == -1)
				{
					offset = Pos_XDown;
				}
			}
			else if(equalX && equalZ)
			{
				int result = pos[1] - wblock.Pos[1];
				if(result == 1)
				{
					offset = Pos_YUp;
				}
				else if(result == -1)
				{
					offset = Pos_YDown;
				}
			}
			else if(equalX && equalY)
			{
				int result = pos[2] - wblock.Pos[2];
				if(result == 1)
				{
					offset = Pos_ZUp;
				}
				else if(result == -1)
				{
					offset = Pos_ZDown;
				}
			}
			
			if(offset != Pos_Unknown)
			{
				Call_StartFunction(null, block.OnNotice);
				Call_PushCell(i);
				Call_PushCell(EntRefToEntIndex(wblock.Ref));
				Call_PushCell(offset);
				Call_PushCell(create);
				Call_Finish();
			}
		}
	}
}

public any Native_FuncToVal(Handle plugin, int params)
{
	return GetNativeCell(1);
}

public any Native_OpenMenu(Handle plugin, int params)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
		return ThrowNativeError(SP_ERROR_INDEX, "Client %d is not in-game", client);
	
	InMenu[client] = true;
	Creative[client] = GetNativeCell(2);
	ToolMenu(client);
	return 0;
}

public any Native_CloseMenu(Handle plugin, int params)
{
	int client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
		return ThrowNativeError(SP_ERROR_INDEX, "Client %d is not in-game", client);
	
	if(!InMenu[client])
		return false;
	
	return CancelClientMenu(client);
}

public any Native_GetBlockInv(Handle plugin, int params)
{
	Block block;
	int length = sizeof(block.Id);
	GetNativeStringLength(1, length);
	
	char[] id = new char[++length];
	GetNativeString(1, id, length);
	
	int client = GetNativeCell(2);
	if(GetBlockOfId(id, block) == -1)
		return -1;
	
	if(!client)
		return true;
	
	if(client < 0 || client > MaxClients || !IsClientInGame(client))
		return ThrowNativeError(SP_ERROR_INDEX, "Client %d is not in-game", client);
	
	return block.Inv[client] < 1 ? 0 : block.Inv[client];
}

public any Native_SetBlockInv(Handle plugin, int params)
{
	Block block;
	int length = sizeof(block.Id);
	GetNativeStringLength(1, length);
	
	char[] id = new char[++length];
	GetNativeString(1, id, length);
	
	int client = GetNativeCell(2);
	int index = GetBlockOfId(id, block);
	if(index == -1)
		return false;
	
	if(!client)
		return true;
	
	if(client < 0 || client > MaxClients || !IsClientInGame(client))
		return ThrowNativeError(SP_ERROR_INDEX, "Client %d is not in-game", client);
	
	block.Inv[client] = GetNativeCell(3);
	Blocks.SetArray(index, block);
	return true;
}