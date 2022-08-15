#if defined _minecraft_tf2_included
  #endinput
#endif
#define _minecraft_tf2_included

/**
 * Opens the block menu to a player
 * 
 * @param client	Client index
 * @param creative	Creative mode
 * 
 * @noreturn
 */
native void MC_OpenMenu(int client, bool creative=true);

/**
 * Closes the block menu on a player
 * 
 * @param client	Client index
 * 
 * @return		True on success, false otherwise
 */
native bool MC_CloseMenu(int client);

/**
 * Gets the player's survival inventory
 * 
 * @param id		Block ID
 * @param client	Client index or 0
 * 
 * @return		Number of blocks, -1 on invalid block ID
 */
native int MC_GetBlockInv(const char[] id, int client=0);

/**
 * Gets the player's survival inventory
 * 
 * @param id		Block ID
 * @param client	Client index or 0
 * @param amount	Amount to give
 * 
 * @return		True if the block ID is valid, false otherwise
 */
native bool MC_SetBlockInv(const char[] id, int client=0, int amount=0);

/**
 * Creates a new block given an id
 * 
 * @param id		Block ID
 * @param pos		Block position, will be offset to fit in place
 * @param ang		Block angle, will be offset to fit in place
 * @param userid	Client userid of the player who owns this block
 * @param team		Team the block will spawn as
 * 
 * @return		True if the block ID is valid, false otherwise
 */
native bool MC_CreateBlock(const char[] id, const float pos[3], const float ang[3], int client=0, int team=0);

public SharedPlugin __pl_minecraft_tf2 =
{
	name = "minecraft_tf2",
	file = "minecraft_tf2.smx",
	#if defined REQUIRE_PLUGIN
		required = 1,
	#else
		required = 0,
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_minecraft_tf2_SetNTVOptional()
{
	MarkNativeAsOptional("MC_OpenMenu");
	MarkNativeAsOptional("MC_CloseMenu");
	MarkNativeAsOptional("MC_GetBlockInv");
	MarkNativeAsOptional("MC_SetBlockInv");
	MarkNativeAsOptional("MC_CreateBlock");
}
#endif