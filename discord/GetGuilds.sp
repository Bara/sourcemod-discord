public int Native_DiscordBot_GetGuilds(Handle plugin, int numParams) {
	DiscordBot bot = GetNativeCell(1);
	Function fCallback = GetNativeCell(2);
	Function fCallbackAll = GetNativeCell(3);
	any data = GetNativeCell(4);
	
	char url[64];
	FormatEx(url, sizeof(url), "users/@me/guilds");
	
	Handle request = PrepareRequest(bot, url, k_EHTTPMethodGET, null, GetGuildsData);
	
	DataPack dp = CreateDataPack();
	WritePackCell(dp, bot);
	WritePackCell(dp, plugin);
	WritePackFunction(dp, fCallback);
	WritePackFunction(dp, fCallbackAll);
	WritePackCell(dp, data);
	
	SteamWorks_SetHTTPRequestContextValue(request, dp);
	
	SteamWorks_SendHTTPRequest(request);
}

public int GetGuildsData(Handle request, bool failure, int offset, int statuscode, any dp) {
	if(failure || statuscode != 200) {
		LogError("[DISCORD] Couldn't Retrieve Guilds - Fail %i %i", failure, statuscode);
		delete request;
		delete view_as<Handle>(dp);
		return;
	}
	SteamWorks_GetHTTPResponseBodyCallback(request, GetGuildsData_Data, dp);
	delete request;
}

public int GetGuildsData_Data(const char[] data, any datapack) {
	Handle hJson = json_load(data);
	
	//Read from datapack to get info
	Handle dp = view_as<Handle>(datapack);
	ResetPack(dp);
	int bot = ReadPackCell(dp);
	Handle plugin = view_as<Handle>(ReadPackCell(dp));
	Function func = ReadPackFunction(dp);
	Function funcAll = ReadPackFunction(dp);
	any pluginData = ReadPackCell(dp);
	delete dp;
	
	//Create forwards
	Handle fForward = INVALID_HANDLE;
	Handle fForwardAll = INVALID_HANDLE;
	if(func != INVALID_FUNCTION) {
		fForward = CreateForward(ET_Ignore, Param_Cell, Param_String, Param_String, Param_String, Param_Cell, Param_Cell, Param_Cell);
		AddToForward(fForward, plugin, func);
	}
	
	if(funcAll != INVALID_FUNCTION) {
		fForwardAll = CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
		AddToForward(fForwardAll, plugin, funcAll);
	}
	
	ArrayList alId = null;
	ArrayList alName = null;
	ArrayList alIcon = null;
	ArrayList alOwner = null;
	ArrayList alPermissions = null;
	
	if(funcAll != INVALID_FUNCTION) {
		alId = CreateArray(32);
		alName = CreateArray(64);
		alIcon = CreateArray(128);
		alOwner = CreateArray();
		alPermissions = CreateArray();
	}
	
	//Loop through json
	for(int i = 0; i < json_array_size(hJson); i++) {
		Handle hObject = json_array_get(hJson, i);
		
		static char id[32];
		static char name[64];
		static char icon[128];
		bool owner = false;
		int permissions;
		
		JsonObjectGetString(hObject, "id", id, sizeof(id));
		JsonObjectGetString(hObject, "name", name, sizeof(name));
		JsonObjectGetString(hObject, "icon", icon, sizeof(icon));
		
		owner = JsonObjectGetBool(hObject, "owner");
		permissions = JsonObjectGetBool(hObject, "permissions");
		
		if(fForward != INVALID_HANDLE) {
			Call_StartForward(fForward);
			Call_PushCell(bot);
			Call_PushString(id);
			Call_PushString(name);
			Call_PushString(icon);
			Call_PushCell(owner);
			Call_PushCell(permissions);
			Call_PushCell(pluginData);
			Call_Finish();
		}
		
		if(fForwardAll != INVALID_HANDLE) {
			alId.PushString(id);
			alName.PushString(name);
			alIcon.PushString(icon);
			alOwner.Push(owner);
			alPermissions.Push(permissions);
		}
		
		delete hObject;
	}
	
	if(fForwardAll != INVALID_HANDLE) {
		Call_StartForward(fForwardAll);
		Call_PushCell(bot);
		Call_PushCell(alId);
		Call_PushCell(alName);
		Call_PushCell(alIcon);
		Call_PushCell(alOwner);
		Call_PushCell(alPermissions);
		Call_PushCell(pluginData);
		Call_Finish();
		
		delete alId;
		delete alName;
		delete alIcon;
		delete alOwner;
		delete alPermissions;
	}
	
	delete hJson;
}