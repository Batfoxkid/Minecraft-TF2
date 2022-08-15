#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

public void OnPluginStart()
{
	File file = OpenFile("addons/sourcemod/configs/mc/plr_hightower/land.txt", "w");
	if(file)
	{
		for(int x=262; x<321; x++)
		{
			for(int y=203; y<278; y++)
			{
				file.WriteLine("stone;75;%d;%d;-8;0;-90;0;2", x, y);
			}
		}
		file.Close();
	}
}