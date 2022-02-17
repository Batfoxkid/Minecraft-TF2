#define SAND_FALLING_SPEED	5.0

public int Spawn_Sand(int entity, int &flags)
{
	if(flags < 2)
		RequestFrame(Sand_FrameCheck, EntIndexToEntRef(entity));
	
	return 0;
}

public void Notice_Sand(int index, int entity, PosOffset offset, bool created)
{
	if(offset == Pos_ZDown && !created)
	{
		if(entity > MaxClients)
		{
			SDKHook(entity, SDKHook_StartTouch, Sand_Touch);
			RequestFrame(Sand_FrameMove, EntIndexToEntRef(entity));
		}
		
		WorldBlock wblock;
		World.GetArray(index, wblock);
		wblock.Flags = 0;
		World.SetArray(index, wblock);
		
		CallBlockNotice(wblock.Pos, false);
	}
}

public void Sand_FrameCheck(int ref)
{
	int entity = EntRefToEntIndex(ref);
	if(entity > MaxClients)
	{
		int id = World.FindValue(ref, WorldBlock::Ref);
		if(id != -1)
		{
			WorldBlock wblock;
			World.GetArray(id, wblock);
			
			WorldBlock wblock2;
			int length = World.Length;
			for(int i; i<length; i++)
			{
				if(i != id)
				{
					// TODO: Get a better method on when a block is falling
					World.GetArray(i, wblock2);
					if((wblock2.Flags > 1 || wblock2.Id != wblock.Id) && wblock2.Pos[0] == wblock.Pos[0] && wblock2.Pos[1] == wblock.Pos[1] && wblock2.Pos[2]+1 == wblock.Pos[2])
					{
						wblock.Flags = 2;
						World.SetArray(id, wblock);
						return;
					}
				}
			}
			
			SDKHook(entity, SDKHook_StartTouch, Sand_Touch);
			RequestFrame(Sand_FrameMove, ref);
		}
	}
}

public void Sand_FrameMove(int ref)
{
	int entity = EntRefToEntIndex(ref);
	if(entity > MaxClients)
	{
		int id = World.FindValue(ref, WorldBlock::Ref);
		if(id != -1)
		{
			WorldBlock wblock;
			World.GetArray(id, wblock);
			
			float pos[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
			if(!wblock.Flags)
				pos[2] -= SAND_FALLING_SPEED;
			
			float offset[3];
			GetBlockOffset(offset);
			float spread = CvarModel.FloatValue*CvarSize.FloatValue;
			
			int z = wblock.Flags ? (RoundToNearest((pos[2] - offset[2]) / spread)) : (RoundToCeil((pos[2] - offset[2]) / spread));
			
			if(wblock.Pos[2] != z || wblock.Flags)
			{
				bool found, changed;
				WorldBlock wblock2;
				int length = World.Length;
				for(int i; i != length && !found; )
				{
					for(i=0; i<length; i++)
					{
						if(i != id)
						{
							World.GetArray(i, wblock2);
							if((wblock2.Flags > 1 || wblock2.Id != wblock.Id) && wblock2.Pos[0] == wblock.Pos[0] && wblock2.Pos[1] == wblock.Pos[1])
							{
								if(wblock2.Pos[2] == z)
								{
									z++;
									changed = true;
									found = false;
									break;
								}
								else if(wblock2.Pos[2] == z-1)
								{
									found = true;
								}
							}
						}
					}
				}
				
				if(found || wblock.Flags)
				{
					wblock.Pos[2] = z;
					wblock.Flags = 2;
					World.SetArray(id, wblock);
					
					for(int i; i<3; i++)
					{
						pos[i] = float(wblock.Pos[i]) * spread + offset[i];
					}
					
					TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
					SDKUnhook(entity, SDKHook_StartTouch, Sand_Touch);
					return;
				}
				else
				{
					wblock.Pos[2] = z;
					World.SetArray(id, wblock);
					
					if(changed)
					{
						for(int i; i<3; i++)
						{
							pos[i] = float(wblock.Pos[i]) * spread + offset[i];
						}
					}
				}
			}
			
			TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
			RequestFrame(Sand_FrameMove, ref);
		}
	}
}

public Action Sand_Touch(int entity, int other)
{
	if(other == 0)
	{
		int id = World.FindValue(EntIndexToEntRef(entity), WorldBlock::Ref);
		if(id != -1)
		{
			WorldBlock wblock;
			World.GetArray(id, wblock);
			wblock.Flags = 1;
			World.SetArray(id, wblock);
		}
	}
	return Plugin_Continue;
}