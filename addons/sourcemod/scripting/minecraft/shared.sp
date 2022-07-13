public Action Think_None(int entity)
{
	return Plugin_Handled;
}

public int Spawn_NoCollide(int entity, int &flags)
{
	SetEntityCollisionGroup(entity, 27);
	return 0;
}

public int Spawn_Light(int entity, int &flags)
{
	AttachLight(entity);
	return 1;
}

int AttachLight(int entity, float level=15.0)
{
	int light = CreateEntityByName("light_dynamic");
	if(light != -1)
	{
		DispatchKeyValue(light, "_light", "250 250 200");
		DispatchKeyValue(light, "brightness", "5");
		DispatchKeyValueFloat(light, "spotlight_radius", 17.0 * level);
		DispatchKeyValueFloat(light, "distance", 34.0 * level);
		DispatchKeyValue(light, "style", "0");
		DispatchSpawn(light);
		ActivateEntity(light);
		
		static float pos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
		pos[2] += CvarSize.FloatValue * CvarModel.FloatValue / 2.0;
		TeleportEntity(light, pos, NULL_VECTOR, NULL_VECTOR); 
		
		SetEntPropEnt(light, Prop_Data, "m_hOwnerEntity", entity);
		
		SetVariantString("!activator");
		AcceptEntityInput(light, "SetParent", entity, light);
		AcceptEntityInput(light, "TurnOn");
	}
	return light;
}