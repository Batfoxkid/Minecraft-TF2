#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

int Value;
int LastEntity;
int Highest;

public void OnEntityCreated(int entity)
{
	if(entity > Value)
		Value = entity;
	
	if(entity > Highest)
		Highest = entity;
	
	LastEntity = entity;
	PrintCenterTextAll("%d %d (+) %d", Value, LastEntity, Highest);
}

public void OnEntityDestroyed()
{
	PrintCenterTextAll("%d %d (-) %d", --Value, LastEntity, Highest);
}