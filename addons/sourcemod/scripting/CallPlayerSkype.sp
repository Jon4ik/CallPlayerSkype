#pragma semicolon 1

#include <sourcemod>
#include <adminmenu>

#undef REQUIRE_PLUGIN
#include <sourcebans>
#define REQUIRE_PLUGIN

#include <clientprefs>
#include <colors>

new Handle:g_TopMenu = INVALID_HANDLE, Handle: g_CallSkype, Handle: Ban_Timer[MAXPLAYERS+1];

new ashomode, iBanDuration, zaprosinfo, iTimerDuration, showmode, strlenskype, logs, count[MAXPLAYERS+1];

new String: LogPath[PLATFORM_MAX_PATH];

new bool: g_WriteSkype[MAXPLAYERS+1], bool: g_IsSb = false;

#include "callplayerskype/adminmenu.sp"
#include "callplayerskype/zapros.sp"

public Plugin:myinfo = 
{
	name = "Call Player Skype",
	author = "Jon4ik (http://steamcommunity.com/id/jon4ik/)",
	version = "BETA 1.4.1"
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
	
	BuildPath(Path_SM, LogPath, sizeof(LogPath), "logs/callplayerskype.log");
		
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
	//LogMessage("Add lib: %s", name);
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
					
				return Plugin_Continue;
			}
		}
		
		g_WriteSkype[client] = false;
		SetClientCookie(client, g_CallSkype, "0");
		CPrintToChat(client, "%t %t", "plugin_tag", "now_you_play");
		
		if(logs == 1)
		{
			decl String: PlayerName[32];
			GetClientName(client, PlayerName, sizeof(PlayerName));
			
			LogToFile(LogPath, "Игрок %s (%i|%i) предоставил skype: %s",PlayerName, client, GetClientUserId(client), Text);
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
	if(client && !IsFakeClient(client))
	{
		if (AreClientCookiesCached(client))
		{
			new String: sCookieValue[12];
		
			GetClientCookie(client, g_CallSkype, sCookieValue, sizeof(sCookieValue));
			new cookieValue = StringToInt(sCookieValue);
			
			g_WriteSkype[client] = (cookieValue == 1) ? true : false;
		}	
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
		decl String: PlayerName[32];
		GetClientName(client, PlayerName, sizeof(PlayerName));
			
		LogToFile(LogPath, "Игрок %s (%i|%i) отказался предоставить skype и был забанен на %i мин",PlayerName, client, GetClientUserId(client), iBanDuration);
	}
}
