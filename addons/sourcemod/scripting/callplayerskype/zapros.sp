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
	decl String:Title[100], String: Text[100], String: Yes[10], String: No[10];
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
		Ban_Timer[client] = CreateTimer(1.0, Timer_Ban, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);	
	}
}

public Action:Timer_Ban(Handle:timer, any:client)
{  
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
	new Handle:hMBC = CreateMenu(MC);
	decl String:Title[100], String: Enter[255];
	FormatEx(Title, sizeof(Title), "%t", "again_menu_title");
	FormatEx(Enter, sizeof(Enter), "%t", "ok_enter_skype_menu");

	SetMenuTitle(hMBC, Title);
	
	AddMenuItem(hMBC, "1", Enter, ITEMDRAW_DISABLED);

	SetMenuExitButton(hMBC, false);
	SetMenuExitBackButton(hMBC, false);
	DisplayMenu(hMBC,client,iBanDuration);
}

public MC(Handle:M, MenuAction:A, client, item)
{
	switch(A)
	{	
		case MenuAction_End:
		{
			CloseHandle(M);
		}
	}
}