#include <sourcemod>
#include <adminmenu>
#include <clientprefs>
#include <colors>

#undef REQUIRE_PLUGIN
#include <sourcebans>
#define REQUIRE_PLUGIN

#pragma semicolon 1

new Handle:g_TopMenu = INVALID_HANDLE, 
	Handle:g_CallSkype, 
	Handle:Ban_Timer[MAXPLAYERS+1];
	
static const String: LogPath[] = "addons/sourcemod/logs/callplayerskype.log";

new bool:g_WriteSkype[MAXPLAYERS+1], 
	bool:g_IsSb = false;

new ashomode, 
	iBanDuration, 
	zaprosinfo, 
	iTimerDuration, 
	showmode, 
	strlenskype, 
	logs, 
	count[MAXPLAYERS+1];
	

public Plugin:myinfo = 
{
	name = "Call Player Skype",
	author = "Jon4ik (http://steamcommunity.com/id/jon4ik/)",
	version = "BETA 1.4.2"
};

public OnPluginStart() 
{ 
	if (LibraryExists("adminmenu")) OnAdminMenuReady(GetAdminTopMenu()); 
	
	RegAdminCmd("sm_testsb", Command_test, ADMFLAG_ROOT);
	RegConsoleCmd("say", ChatHook);
	RegConsoleCmd("say_team", ChatHook);
	
	AddCommandListener(ChooseTeam, "jointeam");
		
	g_CallSkype = RegClientCookie("call_skype_check", "CallSkype_Cookie", CookieAccess_Protected);
	
	decl Handle:hCvar;
		
	HookConVarChange((hCvar = CreateConVar("sm_callskype_again_showmode", "1", "Где показывать игроку о необходимости предоставления Skype(если игрок согласился на проверку)? \n 1) Чат \n 2) Меню")), OnAShowModeChanged);
	ashomode = GetConVarInt(hCvar);
	
	HookConVarChange((hCvar = CreateConVar("sm_callskype_bantime", "120", "Время на которое банит игрока при отказе предоставить Skype")), OnTimeBanChanged);
	iBanDuration = GetConVarInt(hCvar);
	
	HookConVarChange((hCvar = CreateConVar("sm_callskype_showzapros", "1", "Где показывать запрос предоставить Skype? \n 1) Чат \n 2) Меню")), OnInfoZpropsChanged);
	zaprosinfo = GetConVarInt(hCvar);
	
	HookConVarChange((hCvar = CreateConVar("sm_callskype_timer", "360", "Сколько секунд давать игроку на написание скайпа? \n По окончанию этого времени будет выдан бан \n При значение 0 время не будет ограничено")), OnTimerChanged);
	iTimerDuration = GetConVarInt(hCvar);
	
	HookConVarChange((hCvar = CreateConVar("sm_callskype_showmode", "1", "Где отображать оставшееся время на написание скайпа? \n 0) Отключено \n 1) Чат \n 2) Hint окно \n 3) Чат + hint окно")), OnShowModeChanged);
	showmode = GetConVarInt(hCvar);
	
	HookConVarChange((hCvar = CreateConVar("sm_callskype_strlen", "3", "Минимальное количество символов которое должен содержать skype \n 0 = нет проверки \n Внимание: Русские буквы считаются за 2 символа(b = 1; б = 2)")), OnstrlenskypeChanged);
	strlenskype = GetConVarInt(hCvar);
	
	HookConVarChange((hCvar = CreateConVar("sm_callskype_logs", "1", "Вести лог файл? \n 0) Нет \n 1) Да")), OnLogsChanged);
	logs = GetConVarInt(hCvar);
	
	
	AutoExecConfig(true, "CallPlayerSkype");
	
	LoadTranslations("CallPlayerSkype.phrases");
	LoadTranslations("common.phrases");
} 


public Action: Command_test(client, a)
{
	PrintToChatAll("Sourcebans %i", (g_IsSb) ? 1 : 0);
	
	return Plugin_Continue;
}

public OnLibraryAdded(const String:name[])
{ 
	if (StrEqual(name, "sourcebans")) g_IsSb = true; 
}

public OnLibraryRemoved(const String:name[]) 
{ 
	if (StrEqual(name, "adminmenu")) g_TopMenu = INVALID_HANDLE; 
	if (StrEqual(name, "sourcebans")) g_IsSb = false; 
}

public OnAShowModeChanged(Handle:hCvar, const String:sOld[], const String:sNew[])
{
	ashomode = GetConVarInt(hCvar);
}

public OnLogsChanged(Handle:hCvar, const String:sOld[], const String:sNew[])
{		
	logs = GetConVarInt(hCvar);
}

public OnstrlenskypeChanged(Handle:hCvar, const String:sOld[], const String:sNew[])
{
	strlenskype = GetConVarInt(hCvar);
}

public OnShowModeChanged(Handle:hCvar, const String:sOld[], const String:sNew[])
{
	showmode = GetConVarInt(hCvar);
}

public OnTimeBanChanged(Handle:hCvar, const String:sOld[], const String:sNew[])
{
	iBanDuration = GetConVarInt(hCvar);
}

public OnInfoZpropsChanged(Handle:hCvar, const String:sOld[], const String:sNew[])
{
	zaprosinfo = GetConVarInt(hCvar);
}

public OnTimerChanged(Handle:hCvar, const String:sOld[], const String:sNew[])
{
	iTimerDuration = GetConVarInt(hCvar);
}

public OnClientDisconnect(client)
{
	if(client > 0 && !IsFakeClient(client) && g_WriteSkype[client])
	{
		g_WriteSkype[client] = false;
		BanPlayer(client);
	}
}

public Action:ChatHook(client, args)
{
	if (g_WriteSkype[client])
	{
		new String:Text[512];
		GetCmdArgString(Text, sizeof(Text));
		StripQuotes(Text);
				
		if(StrEqual(Text[0], "!no"))
		{
			BanPlayer(client);
			return Plugin_Handled;
		}
		
		if(strlenskype > 0)
		{
			if(strlen(Text) < strlenskype)
			{
				CPrintToChat(client, "%t %t", "plugin_tag", "strlen_skype", strlenskype);
				ClientCommand(client, "play buttons/button11.wav"); 
					
				return Plugin_Handled;
			}
		}
		
		g_WriteSkype[client] = false;
		SetClientCookie(client, g_CallSkype, "0");
		CPrintToChat(client, "%t %t", "plugin_tag", "now_you_play");
		
		if(logs == 1)
		{
			LogToFile(LogPath, "Игрок %L предоставил skype: %s", client, Text);
		}
				
		if (Ban_Timer[client] != INVALID_HANDLE) 
		{ 
			KillTimer(Ban_Timer[client]); 
			Ban_Timer[client] = INVALID_HANDLE; 
		} 
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && (client == i || CheckCommandAccess(i, "sm_chat", ADMFLAG_CHAT)))
			{	
				CPrintToChat(i, "%t %t", "plugin_tag", "player_provided", client, Text);
			}
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:ChooseTeam(client, const String:command[], args)      
{   
	if (g_WriteSkype[client])   
	{   
		CPrintToChat(client, "%t %t", "plugin_tag", "you_need_enter_skype");
		ClientCommand(client, "play buttons/button11.wav"); 
		return Plugin_Handled; 
	}  
	
	return Plugin_Continue;  	
} 

public OnClientPostAdminCheck(client)
{
	if(client && !IsFakeClient(client) && AreClientCookiesCached(client))
	{
		new String: sCookieValue[12];
		
		GetClientCookie(client, g_CallSkype, sCookieValue, sizeof(sCookieValue));
		new cookieValue = StringToInt(sCookieValue);
			
		g_WriteSkype[client] = (cookieValue == 1) ? true : false;
	}
}

public BanPlayer(client)
{
	if(!client || !IsClientInGame(client) || IsFakeClient(client)) return;

	if(g_IsSb)
	{
		SBBanPlayer(0, client, iBanDuration, "Отказ предоставить Skype");
	}
	else 
	{
		BanClient(client, iBanDuration, BANFLAG_AUTO, "Отказ предоставить Skype", "Отказ предоставить Skype");
	}
	
	g_WriteSkype[client] = false;
	SetClientCookie(client, g_CallSkype, "0");
		
	if(logs == 1)
	{			
		LogToFile(LogPath, "Игрок %L отказался предоставить skype и был забанен на %i мин", client, iBanDuration);
	}
}

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
	
	SetMenuTitle(menu, "Запросить Skype игрока:", client);
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
				LogToFile(LogPath, "Администратор %L запросил скайп игрока %L", param1, target);
			}
			
			SkypeZapros(target);		
			
			SetClientCookie(target, g_CallSkype, "1");
		}
		
		if(target != param1) DisplaySkypeMenu(param1);
	}
}

public SkypeZapros(client)
{
	switch(zaprosinfo)
	{
		case 1:
		{
			CreateTimerBan(client);
			PrintToChat(client, "Админ просит предоставить Ваш Skype");
		}
				
		case 2:
		{
			DisplayZaprosSkypeMenu(client);
		}
	}
}

DisplayZaprosSkypeMenu(client)
{
	decl String: Title[100], String: Text[100], String: Yes[10], String: No[10];
	FormatEx(Title, sizeof(Title), "%t", "menu_title");
	FormatEx(Text, sizeof(Text), "%t", "menu_text");
	FormatEx(Yes, sizeof(Yes), "%t", "menu_yes");
	FormatEx(No, sizeof(No), "%t", "menu_no");
	
	new Handle:panel = CreatePanel();
	SetPanelTitle(panel, Title);
	DrawPanelText(panel, Text);
	DrawPanelItem(panel, Yes);
	DrawPanelItem(panel, No);
	SendPanelToClient(panel, client, Select_Menu, 0);
	CloseHandle(panel);
}


public CreateTimerBan(client)
{
	if(iTimerDuration > 0)
	{
		count[client] = iTimerDuration;
		Ban_Timer[client] = CreateTimer(1.0, Timer_Ban, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);	
		//LogToFile(LogPath, "[DEBUG] Создание таймера для игрока %N (%i|%i)",client, client, GetClientUserId(client));
	}
}

public Action:Timer_Ban(Handle:timer, any:userid)
{  
	new client = GetClientOfUserId(userid);
	
	if(count[client] == 0)
	return Plugin_Stop;  
		 
	count[client]--;
	
	if(count[client] == 0)
	{
		BanPlayer(client);
	}
	
	if (IsClientInGame(client) && !IsFakeClient(client))
	{
		switch(showmode)
		{
			case 1:
			{
				CPrintToChat(client, "%t %t", "plugin_tag", "time_enter_skype_chat", count[client]);
			}
			
			case 2:
			{
				PrintHintText(client, "%t", "time_enter_skype", count[client]);
			}
			
			case 3:
			{
				CPrintToChat(client, "%t %t", "plugin_tag", "time_enter_skype_chat", count[client]);
				PrintHintText(client, "%t", "time_enter_skype", count[client]);
			}
		}
	}
      	 
	return Plugin_Continue; 
} 

public Select_Menu(Handle:menu, MenuAction:action, client, option) 
{ 	
	if(action == MenuAction_Select)
	{
		switch(option)
		{
			case 1:
			{
				if (ashomode == 1)
				{
					CPrintToChat(client, "%t %t", "plugin_tag", "ok_enter_skype_chat");
				}
				else
				{
					CreateAgainZaprops(client);
				}
				
				
				CreateTimerBan(client);
			}
				
			case 2:
			{
				BanPlayer(client);
			}
		}
	}
}

CreateAgainZaprops(client)
{
	decl String: Title[100], String: Enter[100];
	FormatEx(Title, sizeof(Title), "%t", "again_menu_title");
	FormatEx(Enter, sizeof(Enter), "%t", "ok_enter_skype_menu");
	
	new Handle:hMBC = CreatePanel();
	SetPanelTitle(hMBC, Title);
	DrawPanelText(hMBC, Enter);
	SendPanelToClient(hMBC, client, Select_Menu, iBanDuration);
	CloseHandle(hMBC);
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
