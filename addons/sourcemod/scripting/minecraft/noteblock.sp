static const char NoteSound[][2][] =
{
	{ "",			"mcinf/note/harp.mp3" },
	{ "soul_sand",		"mcinf/note/cow_bell.mp3" },
	{ "sand",		"mcinf/note/snare.mp3" },
	{ "gravel",		"mcinf/note/snare.mp3" },
	{ "powder",		"mcinf/note/snare.mp3" },
	{ "soil",		"mcinf/note/snare.mp3" },
	{ "planks",		"mcinf/note/bass.mp3" },
	{ "log",		"mcinf/note/bass.mp3" },
	{ "glass",		"mcinf/note/hat.mp3" },
	{ "lantern",		"mcinf/note/hat.mp3" },
	{ "beacon",		"mcinf/note/hat.mp3" },
	{ "gold_block",		"mcinf/note/bell.mp3" },
	{ "clay",		"mcinf/note/flute.mp3" },
	{ "honeycomb",		"mcinf/note/flute.mp3" },
	{ "infested",		"mcinf/note/flute.mp3" },
	{ "packed_ice",		"mcinf/note/icechime.mp3" },
	{ "wool",		"mcinf/note/guitar.mp3" },
	{ "bone",		"mcinf/note/xylobone.mp3" },
	{ "iron_block",		"mcinf/note/iron_xylophone.mp3" },
	{ "pumpkin",		"mcinf/note/didgeridoo.mp3" },
	{ "emerald_block",	"mcinf/note/bit.mp3" },
	{ "hay_block",		"mcinf/note/banjo.mp3" },
	{ "glowstone",		"mcinf/note/pling.mp3" },
	{ "stone",		"mcinf/note/bd.mp3" },
	{ "netherrack",		"mcinf/note/bd.mp3" },
	{ "nylium",		"mcinf/note/bd.mp3" },
	{ "obsidian",		"mcinf/note/bd.mp3" },
	{ "quartz",		"mcinf/note/bd.mp3" },
	{ "sandstone",		"mcinf/note/bd.mp3" },
	{ "brick",		"mcinf/note/bd.mp3" },
	{ "coral",		"mcinf/note/bd.mp3" },
	{ "anchor",		"mcinf/note/bd.mp3" },
	{ "bedrock",		"mcinf/note/bd.mp3" },
	{ "concrete",		"mcinf/note/bd.mp3" }
};

void MapStart_Noteblock()
{
	for(int i; i<sizeof(NoteSound); i++)
	{
		PrecacheSound(NoteSound[i][1]);
	}
}

public void Interact_Noteblock(int index, int entity, int client)
{
	WorldBlock wblock;
	World.GetArray(index, wblock);
	int pitch = wblock.Flags;
	if(++wblock.Flags > 24)
		wblock.Flags = 0;
	
	World.SetArray(index, wblock);
	
	char below[32];
	WorldBlock wblock2;
	int length = World.Length;
	for(int i; i<length; i++)
	{
		if(i != index)
		{
			World.GetArray(i, wblock2);
			if(wblock2.Pos[0] == wblock.Pos[0] && wblock2.Pos[1] == wblock.Pos[1])
			{
				// Block is muffled
				if(wblock2.Pos[2]-1 == wblock.Pos[2])
					return;
				
				if(!below[0] && wblock2.Pos[2]+1 == wblock.Pos[2])
				{
					Block block;
					Blocks.GetArray(wblock2.Id, block);
					strcopy(below, sizeof(below), block.Id);
				}
			}
		}
	}
	
	pitch = RoundToNearest(float(SNDPITCH_NORMAL) * Pow(2.0, float(pitch - 12) / 12.0));
	
	int type;
	if(below[0])
	{
		for(int i=1; i<sizeof(NoteSound); i++)
		{
			if(StrContains(below, NoteSound[i][0]) != -1)
			{
				type = i;
				break;
			}
		}
	}
	
	EmitSoundToAll(NoteSound[type][1], entity, _, _, _, _, pitch);
}