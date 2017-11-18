public OnAdminMenuReady(Handle:topmenu) 
{ 
	if (topmenu == INVALID_HANDLE || topmenu == g_TopMenu) return; 

	g_TopMenu = topmenu; 

	new TopMenuObject:MyCat = FindTopMenuCategory(g_TopMenu, ADMINMENU_PLAYERCOMMANDS);
	
	if (MyCat != INVALID_TOPMENUOBJECT)
	{
		AddToTopMenu(g_TopMenu, "sm_callskype", TopMenuObject_Item, AdminMenu_CallBack, MyCat, "sm_callskype", ADMFLAG_CHAT);
	}
} 

public AdminMenu_CallBack(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength) 
{ 
	if (action == TopMenuAction_DisplayOption) 	Format(buffer, maxlength, "Запросить Skype");

	else if (action == TopMenuAction_SelectOption) 
	{ 
		DisplaySkypeMenu(param);
	} 
} 

DisplaySkypeMenu(client)
{
	new Handle:menu = CreateMenu(MenuHandler_Skype);
	
	decl String:title[100];
	Format(title, sizeof(title), "Запросить Skype игрока:", client);
	SetMenuTitle(menu, title);
	SetMenuExitBackButton(menu, true);
	
	UTIL_AddTargetsToMenu3(menu);
	
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}


public MenuHandler_SkypeList(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && g_TopMenu != INVALID_HANDLE)
		{
			DisplayTopMenu(g_TopMenu, param1, TopMenuPosition_LastCategory);
		}
	}
}

public MenuHandler_Skype(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && g_TopMenu != INVALID_HANDLE)
		{
			DisplayTopMenu(g_TopMenu, param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		new userid, target;
		
		GetMenuItem(menu, param2, info, sizeof(info));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			CPrintToChat(param1, "%t %t", "plugin_tag", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target))
		{
			CPrintToChat(param1, "%t %t", "plugin_tag", "Unable to target");
		}
		else if(g_WriteSkype[target])
		{
			CPrintToChat(param1, "%t %t", "plugin_tag", "skype_already_requested");
			ClientCommand(param1, "play buttons/button11.wav"); 
		}
		else
		{
			g_WriteSkype[target] = true;
			if (GetClientTeam(target) > 1) ChangeClientTeam(target, 1);
			CPrintToChat(param1, "%t %t", "plugin_tag", "skype_requested");
			
			if(logs == 1)
			{
			
				decl String: AdminName[32], String: PlayerName[32];
			
				GetClientName(param1, AdminName, sizeof(AdminName));
				GetClientName(target, PlayerName, sizeof(PlayerName));
			
				LogToFile(LogPath, "Администратор %s запрос скайп игрока %s", AdminName, PlayerName);
			}
			
			SkypeZapros(target);		
			
			SetClientCookie(target, g_CallSkype, "1");
		}
		
		if(target != param1) DisplaySkypeMenu(param1);
	}
}


stock UTIL_AddTargetsToMenu3(Handle:menu)
{	
	decl String:user_id[12];
	decl String:name[MAX_NAME_LENGTH];
	decl String:display[MAX_NAME_LENGTH+12];
	
	new num_clients;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || IsClientInKickQueue(i) || !IsClientInGame(i) || IsFakeClient(i) || GetUserAdmin(i) != INVALID_ADMIN_ID)
		{
			continue;
		}
						
		IntToString(GetClientUserId(i), user_id, sizeof(user_id));
		GetClientName(i, name, sizeof(name));
		Format(display, sizeof(display), "%s (%s)", name, user_id);
		AddMenuItem(menu, user_id, display);
		num_clients++;
	}
	
	if (num_clients == 0)	AddMenuItem(menu, "", "Нет доступных игроков", ITEMDRAW_DISABLED);
	
	return num_clients;
}