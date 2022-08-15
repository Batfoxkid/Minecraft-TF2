#pragma semicolon 1

#include <sourcemod>

#pragma newdecls required

// bytes[20] 0 --> 1

public void OnPluginStart()
{
	DirectoryListing dir = OpenDirectory("materials/mc_inf");
	if(dir)
	{
		FileType type;
		char buffer[256], filename[64];
		while(dir.GetNext(filename, sizeof(filename), type))
		{
			if(type == FileType_File && StrContains(filename, ".vtf") != -1)
			{
				FormatEx(buffer, sizeof(buffer), "materials/mc_inf/%s", filename);
				File file = OpenFile(buffer, "rb");
				if(file)
				{
					any bytes[2048];
					int size = file.Read(bytes, sizeof(bytes), 1);
					
					delete file;
					
					if(size < sizeof(bytes))
					{
						bytes[20] = 1;
						
						file = OpenFile(buffer, "wb");
						if(file)
						{
							file.Write(bytes, size, 1);
							delete file;
							
							PrintToServer(filename);
						}
						else
						{
							PrintToServer("ERROR: Could not write to %s", filename);
						}
					}
					else
					{
						PrintToServer("ERROR: Filesize bigger then buffer for %s", filename);
					}
				}
				else
				{
					PrintToServer("ERROR: Could not read to %s", filename);
				}
			}
		}
	}
	else
	{
		PrintToServer("Could not find directory");
	}
	
}