#include <sourcemod>
#include <clientprefs>
#include <ripext>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "Advanced Auto Retry",
	author = "Vauff",
	description = "A toggleable auto retry system for custom particles that only retries players when actually necessary",
	version = "1.3.1",
	url = "https://github.com/Vauff/AdvancedAutoRetry"
};

ConVar g_cvEnabled, g_cvApiUrl, g_cvToken;
Handle g_hAutoRetryDisabled;
StringMap g_smPlayerConnections, g_smPlayerConnectionTime;

bool g_bParticles = false;
bool g_bAutoRetryDisabled[MAXPLAYERS+1];
char g_sMap[128], g_sApiUrl[256], g_sToken[256];

public void OnPluginStart()
{
	g_cvEnabled = CreateConVar("sm_aar_enabled", "1", "Whether the plugin is enabled or not");
	g_cvApiUrl = CreateConVar("sm_aar_api_url", "", "URL that the API worker is running at", FCVAR_PROTECTED);
	g_cvToken = CreateConVar("sm_aar_api_token", "", "Token for the API worker", FCVAR_PROTECTED);
	g_hAutoRetryDisabled = RegClientCookie("aar_disabled_new", "", CookieAccess_Private);

	RegConsoleCmd("sm_autoretry", Command_AutoRetryToggle, "Toggles the auto retry feature for maps with particles on or off");
	SetCookieMenuItem(CookieHandler, 0, "Auto Retry");

	HookConVarChange(g_cvApiUrl, ApiConVarChanged);
	HookConVarChange(g_cvToken, ApiConVarChanged);
	AutoExecConfig(true, "AdvancedAutoRetry");
}

public void OnMapStart()
{
	char map[128];
	char filePath[147];

	GetCurrentMap(map, sizeof(map));
	Format(filePath, sizeof(filePath), "maps/%s_particles.txt", map);

	// Will be case sensitive on Windows servers if use_valve_fs is false!!!
	if (FileExists(filePath, true, NULL_STRING))
		g_bParticles = true;
	else
		g_bParticles = false;

	// Don't reset StringMaps if not changing to a different map, this helps prevent double retries after a map reload
	if (!StrEqual(map, g_sMap, false))
	{
		if (g_smPlayerConnections != null)
			CloseHandle(g_smPlayerConnections);

		if (g_smPlayerConnectionTime != null)
			CloseHandle(g_smPlayerConnectionTime);

		g_smPlayerConnections = CreateTrie();
		g_smPlayerConnectionTime = CreateTrie();
	}

	g_sMap = map;
}

public void OnClientCookiesCached(int client)
{
	char cookieState[2];
	GetClientCookie(client, g_hAutoRetryDisabled, cookieState, sizeof(cookieState));
	g_bAutoRetryDisabled[client] = StrEqual(cookieState, "1");
}

public void OnClientPostAdminCheck(int client)
{
	if (!g_bParticles || !g_cvEnabled.BoolValue)
		return;

	char steamID[32];
	GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID));

	int playerConnections = 0;
	GetTrieValue(g_smPlayerConnections, steamID, playerConnections);
	playerConnections += 1;
	SetTrieValue(g_smPlayerConnections, steamID, playerConnections);

	SetTrieValue(g_smPlayerConnectionTime, steamID, GetTime());

	if (playerConnections >= 2)
		return;

	if (AreClientCookiesCached(client))
	{
		if (!g_bAutoRetryDisabled[client])
			SendApiHttpRequest(client);
	}
	else
	{
		// Late cookie load, keep rechecking until clients cookies are cached
		CreateTimer(0.5, CookieTimer, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void ApiConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_cvApiUrl.GetString(g_sApiUrl, sizeof(g_sApiUrl));
	g_cvToken.GetString(g_sToken, sizeof(g_sToken));
}

public void CookieHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	if (action == CookieMenuAction_DisplayOption)
	{
		FormatEx(buffer, maxlen, "Auto Retry: %s", g_bAutoRetryDisabled[client] ? "Disabled" : "Enabled");
	}
	else if (action == CookieMenuAction_SelectOption)
	{
		AutoRetryToggle(client);
		ShowCookieMenu(client);
	}
}

public Action Command_AutoRetryToggle(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;

	AutoRetryToggle(client);

	return Plugin_Handled;
}

void AutoRetryToggle(int client)
{
	g_bAutoRetryDisabled[client] = !g_bAutoRetryDisabled[client];
	SetClientCookie(client, g_hAutoRetryDisabled, g_bAutoRetryDisabled[client] ? "1" : "");
	PrintToChat(client, " \x0F[AdvancedAutoRetry] \x05Auto retry after downloading maps with particles has been %s", g_bAutoRetryDisabled[client] ? "disabled" : "enabled");
}

void OnApiHttpResponse(HTTPResponse response, any data)
{
	int client = GetClientOfUserId(data);

	if (!IsValidClient(client))
		return;

	if (response.Status != HTTPStatus_OK)
	{
		if (response.Status == HTTPStatus_Invalid)
			LogError("HTTP error: No response received from the API for %L", client);
		else
			LogError("HTTP error: Status code %i on request to the API for %L", response.Status, client);

		return;
	}

	if (response.Data == null)
	{
		LogError("HTTP error: No response received from the API for %L", client);
		return;
	}

	char steamID[32];
	GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID));

	JSONObject json = view_as<JSONObject>(response.Data);

	if (json.GetBool("clientDownloaded"))
	{
		int playerConnectionTime = 0;
		GetTrieValue(g_smPlayerConnectionTime, steamID, playerConnectionTime);

		// Show a warning countdown to the player if we weren't able to get the API data we needed fast enough for a quick retry
		if ((playerConnectionTime + 5) < GetTime())
		{
			DataPack dp;
			CreateDataTimer(1.0, RetryTimer, dp);
			dp.WriteCell(data);
			dp.WriteCell(5);
		}
		else
		{
			ClientCommand(client, "retry");
		}
	}

	CloseHandle(json);
}

public Action CookieTimer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (!IsValidClient(client))
		return Plugin_Stop;

	if (AreClientCookiesCached(client))
	{
		if (!g_bAutoRetryDisabled[client])
			SendApiHttpRequest(client);

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action RetryTimer(Handle timer, DataPack data)
{
	data.Reset();
	int userid = data.ReadCell();
	int client = GetClientOfUserId(userid);
	int seconds = data.ReadCell();

	if (!IsValidClient(client))
		return Plugin_Handled;

	if (seconds > 0)
	{
		PrintToChat(client, " \x0F[AdvancedAutoRetry] \x05Your downloading of the map was detected late, you will be auto retried in %i seconds", seconds);

		DataPack dp;
		CreateDataTimer(1.0, RetryTimer, dp);
		dp.WriteCell(userid);
		dp.WriteCell(seconds - 1);

		return Plugin_Handled;
	}
	else
	{
		ClientCommand(client, "retry");
		return Plugin_Handled;
	}
}

void SendApiHttpRequest(int client)
{
	char ip[32];
	GetClientIP(client, ip, sizeof(ip));

	HTTPRequest httpRequest = new HTTPRequest(g_sApiUrl);
	httpRequest.SetHeader("Token", g_sToken);
	httpRequest.SetHeader("Map", g_sMap);
	httpRequest.SetHeader("ClientIP", ip);
	httpRequest.Get(OnApiHttpResponse, GetClientUserId(client));
}

bool IsValidClient(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
		return false;

	return IsClientInGame(client);
}