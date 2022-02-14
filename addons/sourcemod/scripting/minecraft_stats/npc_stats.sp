Handle g_hMyNextBotPointer;
Handle g_hGetLocomotionInterface;
Handle g_hGetVelocity;
Handle g_hSetVelocity;
Handle g_hGetIntentionInterface;
Handle g_hGetBodyInterface;
Handle g_hRun;
Handle g_hLookupPoseParameter;
Handle g_hSetPoseParameter;
Handle g_hGetVectors;
Handle g_hGetGroundMotionVector;
Handle g_hGetGroundSpeed;
Handle g_hStudioFrameAdvance;
Handle g_hDispatchAnimEvents;
Handle g_hLookupActivity;
Handle g_hAddGesture;
Handle g_hSelectWeightedSequence;
Handle g_hResetSequenceInfo;
Handle g_hGetGravity;
Handle g_hGetStepHeight;

void OnPluginStart_npcstats()
{
	GameData hConf = LoadGameConfigFile("tf2.pets");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseEntity::MyNextBotPointer");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hMyNextBotPointer = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseEntity::MyNextBotPointer offset!"); 
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "INextBot::GetLocomotionInterface");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hGetLocomotionInterface = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for INextBot::GetLocomotionInterface!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::GetVelocity");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByRef);
	if((g_hGetVelocity = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::GetVelocity!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::SetVelocity");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	if((g_hSetVelocity = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::SetVelocity!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "INextBot::GetIntentionInterface");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hGetIntentionInterface = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for INextBot::GetIntentionInterface!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "INextBot::GetBodyInterface");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hGetBodyInterface = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for INextBot::GetBodyInterface!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::Run");
	if((g_hRun = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::Run!");
	
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::LookupPoseParameter");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hLookupPoseParameter = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimating::LookupPoseParameter");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::SetPoseParameter");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	if((g_hSetPoseParameter = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimating::SetPoseParameter");
		
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseEntity::GetVectors");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef, _, VENCODE_FLAG_COPYBACK);
	if((g_hGetVectors = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for CBaseEntity::GetVectors!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::GetGroundMotionVector");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByRef);
	if((g_hGetGroundMotionVector = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::GetGroundMotionVector!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "ILocomotion::GetGroundSpeed");
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	if((g_hGetGroundSpeed = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Virtual Call for ILocomotion::GetGroundSpeed!");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseAnimating::StudioFrameAdvance");
	if ((g_hStudioFrameAdvance = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::StudioFrameAdvance offset!"); 	
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "CBaseAnimating::DispatchAnimEvents");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((g_hDispatchAnimEvents = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::DispatchAnimEvents offset!"); 
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimatingOverlay::AddGesture");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain); 
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if((g_hAddGesture = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimatingOverlay::AddGesture");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "SelectWeightedSequence");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//pstudiohdr
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//activity
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//curSequence
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//return sequence
	if((g_hSelectWeightedSequence = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for SelectWeightedSequence");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::ResetSequenceInfo");
	if ((g_hResetSequenceInfo = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::ResetSequenceInfo signature!");
	
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "LookupActivity");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//pStudioHdr
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		//label
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//return index
	if((g_hLookupActivity = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for LookupActivity");
	
	g_hGetGravity          = DHookCreateEx(hConf, "ILocomotion::GetGravity",         HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetGravity);	
	g_hGetStepHeight       = DHookCreateEx(hConf, "ILocomotion::GetStepHeight",      HookType_Raw, ReturnType_Float,     ThisPointer_Address, ILocomotion_GetStepHeight);	
	
	delete hConf;
}





methodmap CBaseZombieRiotNpc
{
	property int index 
	{ 
		public get() { return view_as<int>(this); } 
	}

	public int ExtractStringValueAsInt(const char[] key)
	{
		char buffer[64]; 
		bool bExists = GetCustomKeyValue(this.index, key, buffer, sizeof(buffer)); 
		return bExists ? StringToInt(buffer) : -1;
	}
	
	public float ExtractStringValueAsFloat(const char[] key)
	{
		char buffer[64]; 
		bool bExists = GetCustomKeyValue(this.index, key, buffer, sizeof(buffer)); 
		return bExists ? StringToFloat(buffer) : -1.0;
	}
	/*
	This will allow this plugin to talk with npc's! i wish i knew before.
	just use the same "" for everything.
	please reminder that this is being set, so if you alter any thats non permanently, please make a timer or something like that.
	do not worry about cleaning up any of these, if an npc uses these on spawn, they will set them themselves.
	
	
	Usage follows THIS:
	
	
	CBaseZombieRiotNpc npc = view_as<CBaseZombieRiotNpc>(YOURINDEX);
	
	npc.m_flAlterSpeedMultipliative = 5.0; //Become speed!
	
	*/
	property int m_iActivity
	{
		public get()              { return this.ExtractStringValueAsInt("m_iActivity"); }
		public set(int iActivity) { char buff[8]; IntToString(iActivity, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iActivity", buff, true); }
	}
	property float m_flAlterSpeedMultipliative
	{
		public get()                 { return this.ExtractStringValueAsFloat("m_flAlterSpeedMultipliative"); }
		public set(float flNextTime) { char buff[8]; FloatToString(flNextTime, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_flAlterSpeedMultipliative", buff, true); }
	}
	property bool bCantCollidie
	{
		public get()            { return !!this.ExtractStringValueAsInt("bCantCollidie"); }
		public set(bool bOnOff) { char buff[8]; IntToString(bOnOff, buff, sizeof(buff)); SetCustomKeyValue(this.index, "bCantCollidie", buff, true); }
	}
	property bool bCantCollidieAlly
	{
		public get()            { return !!this.ExtractStringValueAsInt("bCantCollidieAlly"); }
		public set(bool bOnOff) { char buff[8]; IntToString(bOnOff, buff, sizeof(buff)); SetCustomKeyValue(this.index, "bCantCollidieAlly", buff, true); }
	}
	property bool bBuildingIsStacked
	{
		public get()            { return !!this.ExtractStringValueAsInt("bBuildingIsStacked"); }
		public set(bool bOnOff) { char buff[8]; IntToString(bOnOff, buff, sizeof(buff)); SetCustomKeyValue(this.index, "bBuildingIsStacked", buff, true); }
	}
	property bool bBuildingIsPlaced
	{
		public get()            { return !!this.ExtractStringValueAsInt("bBuildingIsPlaced"); }
		public set(bool bOnOff) { char buff[8]; IntToString(bOnOff, buff, sizeof(buff)); SetCustomKeyValue(this.index, "bBuildingIsPlaced", buff, true); }
	}
	
	
	public Address GetLocomotionInterface() { return SDKCall(g_hGetLocomotionInterface, SDKCall(g_hMyNextBotPointer, this.index)); }
	public Address GetIntentionInterface()  { return SDKCall(g_hGetIntentionInterface,  SDKCall(g_hMyNextBotPointer, this.index)); }
	public Address GetBodyInterface()       { return SDKCall(g_hGetBodyInterface,       SDKCall(g_hMyNextBotPointer, this.index)); }
	public void GetVelocity(float vecOut[3])                                               { SDKCall(g_hGetVelocity, this.GetLocomotionInterface(), vecOut);                           }	
	public void SetVelocity(const float vec[3])                                            { SDKCall(g_hSetVelocity, this.GetLocomotionInterface(), vec);                              }      
	public void GetVectors(float pForward[3], float pRight[3], float pUp[3]) { SDKCall(g_hGetVectors, this.index, pForward, pRight, pUp); }
	public float GetGroundSpeed()                                    { return SDKCall(g_hGetGroundSpeed, this.GetLocomotionInterface()); }
	public void GetGroundMotionVector(float vecMotion[3])                    { SDKCall(g_hGetGroundMotionVector, this.GetLocomotionInterface(), vecMotion); }
	
	public void SetSequence(int iSequence)    { SetEntProp(this.index, Prop_Send, "m_nSequence", iSequence); }
	public void SetPlaybackRate(float flRate) { SetEntPropFloat(this.index, Prop_Send, "m_flPlaybackRate", flRate); }
	public void SetCycle(float flCycle)       { SetEntPropFloat(this.index, Prop_Send, "m_flCycle", flCycle); }
	
	public void DispatchAnimEvents() { SDKCall(g_hDispatchAnimEvents, this.index, this.index); }
	
	public void ResetSequenceInfo()  { SDKCall(g_hResetSequenceInfo,  this.index); }
	public void StudioFrameAdvance() { SDKCall(g_hStudioFrameAdvance, this.index); }
	
	public Address GetModelPtr()
	{
		//const int offset = FindSendPropInfo("CBaseAnimating", "m_flFadeScale ") + 28;
		
		if(IsValidEntity(this.index)) {
			return view_as<Address>(GetEntData(this.index, 283 * 4));
		}
		
		return Address_Null;
	}	
	public int LookupPoseParameter(const char[] szName)
	{
		Address pStudioHdr = this.GetModelPtr();
		if(pStudioHdr == Address_Null)
			return -1;
			
		return SDKCall(g_hLookupPoseParameter, this.index, pStudioHdr, szName);
	}	
	public void SetPoseParameter(int iParameter, float value)
	{
		Address pStudioHdr = this.GetModelPtr();
		if(pStudioHdr == Address_Null)
			return;
			
		SDKCall(g_hSetPoseParameter, this.index, pStudioHdr, iParameter, value);
	}	
	property int m_iPoseMoveX 
	{
		public get()              { return this.ExtractStringValueAsInt("m_iPoseMoveX"); }
		public set(int iActivity) { char buff[8]; IntToString(iActivity, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iPoseMoveX", buff, true); }
	}
	
	property int m_iPoseMoveY
	{
		public get()              { return this.ExtractStringValueAsInt("m_iPoseMoveY"); }
		public set(int iActivity) { char buff[8]; IntToString(iActivity, buff, sizeof(buff)); SetCustomKeyValue(this.index, "m_iPoseMoveY", buff, true); }
	}
	
	public void UpdateRun()
	{
		/*
			#if defined DEBUG_UPDATE
			PrintToServer("CBaseActor::Update()");
			#endif
		*/
		SDKCall(g_hRun,          this.GetLocomotionInterface());	
	}
		
	public int LookupActivity(const char[] activity)
	{
		Address pStudioHdr = this.GetModelPtr();
		if(pStudioHdr == Address_Null)
			return -1;
			
		return SDKCall(g_hLookupActivity, pStudioHdr, activity);
	}
	public void AddGesture(const char[] anim)
	{
		int iSequence = this.LookupActivity(anim);
		if(iSequence < 0)
			return;
		
		SDKCall(g_hAddGesture, this.index, iSequence, true);
	}
	public int SelectWeightedSequence(int activity, int curSequence) { return SDKCall(g_hSelectWeightedSequence, this.index, this.GetModelPtr(), activity, curSequence); }
	
	public bool StartActivity(int iActivity, int flags = 0)
	{
		#if defined DEBUG_ANIMATION
		PrintToServer("CClotBody::StartActivity(%i, %i)", iActivity, flags);
		#endif
		
		//Translate jump anim
		if(iActivity == 29)
			iActivity = this.LookupActivity("ACT_MP_JUMP_START_MELEE");
		
		int nSequence = this.SelectWeightedSequence(iActivity, GetEntProp(this.index, Prop_Send, "m_nSequence"));
		if (nSequence == 0) 
			return false;
		
		this.m_iActivity = iActivity;
		
		this.SetSequence(nSequence);
		this.SetPlaybackRate(1.0);
		this.SetCycle(0.0);
		
		this.ResetSequenceInfo();
		
		return true;
	}
	
	public void Update()
	{
		/*
		if (this.m_iPoseMoveX < 0) {
			this.m_iPoseMoveX = this.LookupPoseParameter("move_x");
		}
		if (this.m_iPoseMoveY < 0) {
			this.m_iPoseMoveY = this.LookupPoseParameter("move_y");
		}
		
		float flNextBotGroundSpeed = this.GetGroundSpeed();
		
		if (flNextBotGroundSpeed < 0.01) {
			if (this.m_iPoseMoveX >= 0) {
				this.SetPoseParameter(this.m_iPoseMoveX, 0.0);
			}
			if (this.m_iPoseMoveY >= 0) {
				this.SetPoseParameter(this.m_iPoseMoveY, 0.0);
			}
		} else {
			float vecFwd[3], vecRight[3], vecUp[3];
			this.GetVectors(vecFwd, vecRight, vecUp);
			
			float vecMotion[3]; this.GetGroundMotionVector(vecMotion);
			
			if (this.m_iPoseMoveX >= 0) {
				this.SetPoseParameter(this.m_iPoseMoveX, GetVectorDotProduct(vecMotion, vecFwd));
			}
			if (this.m_iPoseMoveY >= 0) {
				this.SetPoseParameter(this.m_iPoseMoveY, GetVectorDotProduct(vecMotion, vecRight));
			}
		}
		
		float m_flGroundSpeed = GetEntPropFloat(this.index, Prop_Data, "m_flGroundSpeed");
		if (m_flGroundSpeed != 0.0) {
			this.SetPlaybackRate(clamp((flNextBotGroundSpeed / m_flGroundSpeed), -4.0, 12.0));
		}
		*/
		this.StudioFrameAdvance();
		this.DispatchAnimEvents();
		
		//Run and StuckMonitor
	//	this.UpdateRun();
		
	}

}

Handle DHookCreateEx(Handle gc, const char[] key, HookType hooktype, ReturnType returntype, ThisPointerType thistype, DHookCallback callback)
{
	int iOffset = GameConfGetOffset(gc, key);
	if(iOffset == -1)
	{
		SetFailState("Failed to get offset of %s", key);
		return null;
	}
	
	return DHookCreate(iOffset, hooktype, returntype, thistype, callback);
}

public MRESReturn ILocomotion_GetGravity(Address pThis, Handle hReturn, Handle hParams)          { DHookSetReturn(hReturn, 0.0); return MRES_Supercede; }
public MRESReturn ILocomotion_GetStepHeight(Address pThis, Handle hReturn, Handle hParams)       { DHookSetReturn(hReturn, 0.0);	return MRES_Supercede; }