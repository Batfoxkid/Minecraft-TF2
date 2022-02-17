public Action Think_None(int entity)
{
	return Plugin_Handled;
}

public int Spawn_Light(int entity, int &flags)
{
	int light = CreateEntityByName("light_dynamic");
	if(IsValidEntity(light))
	{
		DispatchKeyValue(light, "_light", "250 250 200");
		DispatchKeyValue(light, "brightness", "5");
		DispatchKeyValueFloat(light, "spotlight_radius", 256.0);
		DispatchKeyValueFloat(light, "distance", 512.0);
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
	return 1;
}