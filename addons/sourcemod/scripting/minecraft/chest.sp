#define TF_REGENERATE_SOUND		"Regenerate.Touch"
#define TF_REGENERATE_NEXT_USE_TIME	3.0

static bool DenyUse[MAXTF2PLAYERS];

public void Interact_Chest(int index, int entity, int client)
{
	if(!DenyUse[client])
	{
		DenyUse[client] = true;
		TF2_RegeneratePlayer(client);
		ClientCommand(client, "playgamesound %s", TF_REGENERATE_SOUND);
		CreateTimer(TF_REGENERATE_NEXT_USE_TIME, Chest_AllowUsing, client);
	}
}

public Action Chest_AllowUsing(Handle timer, int client)
{
	DenyUse[client] = false;
	return Plugin_Continue;
}