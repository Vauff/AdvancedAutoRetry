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
	version = "1.0",
	url = "https://github.com/Vauff/AdvancedAutoRetry"
};

ConVar g_cvEnabled, g_cvApiUrl, g_cvToken;
Handle g_hAutoRetryDisabled;
StringMap g_smPlayerRetried;
HTTPClient g_hHTTPClient;

bool g_bParticles = false;

public void OnPluginStart()
{
	g_cvEnabled = CreateConVar("sm_aar_enabled", "1", "Whether the plugin is enabled or not");
	g_cvApiUrl = CreateConVar("sm_aar_api_url", "", "URL that the Advanced Auto Retry API is running at", FCVAR_PROTECTED);
	g_cvToken = CreateConVar("sm_aar_api_token", "", "Token for the Advanced Auto Retry API", FCVAR_PROTECTED);
	g_hAutoRetryDisabled = RegClientCookie("aar_disabled", "", CookieAccess_Protected);

	RegConsoleCmd("sm_autoretry", Command_AutoRetryToggle, "Toggles the auto retry feature for maps with particles on or off");

	UpdateHttpClient();

	HookConVarChange(g_cvApiUrl, ApiConVarChanged);
	HookConVarChange(g_cvToken, ApiConVarChanged);
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

	if (g_smPlayerRetried != null)
		CloseHandle(g_smPlayerRetried);

	g_smPlayerRetried = CreateTrie();
}

public void OnClientPostAdminCheck(int client)
{
	char cookieState[2];
	GetClientCookie(client, g_hAutoRetryDisabled, cookieState, sizeof(cookieState));

	char steamID[32];
	bool playerRetried;
	GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID));

	if (!GetTrieValue(g_smPlayerRetried, steamID, playerRetried))
		playerRetried = false;

	if (g_bParticles && g_cvEnabled.BoolValue && !StrEqual(cookieState, "1") && !playerRetried)
	{
		char url[PLATFORM_MAX_PATH];
		char ip[32];
		char map[128];

		GetClientIP(client, ip, sizeof(ip));
		GetCurrentMap(map, sizeof(map));
		Format(url, sizeof(url), "clientdownloaded/%s/%s", ip, map);

		g_hHTTPClient.Get(url, OnApiHttpResponse, GetClientUserId(client));
	}
}

public void ApiConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	UpdateHttpClient();
}

public Action Command_AutoRetryToggle(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;

	char cookieState[2];
	GetClientCookie(client, g_hAutoRetryDisabled, cookieState, sizeof(cookieState));

	SetClientCookie(client, g_hAutoRetryDisabled, StrEqual(cookieState, "1") ? "" : "1");
	PrintToChat(client, " \x0F[AdvancedAutoRetry] \x05Auto retry after downloading maps with particles has been %s", StrEqual(cookieState, "1") ? "enabled" : "disabled");

	return Plugin_Handled;
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

	JSONObject json = view_as<JSONObject>(response.Data);

	char jsonString[128];
	json.ToString(jsonString, sizeof(jsonString));

	char steamID[32];
	GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID));

	if (json.GetBool("clientDownloaded"))
	{
		SetTrieValue(g_smPlayerRetried, steamID, true);
		ClientCommand(client, "retry");
	}

	CloseHandle(json);
}

void UpdateHttpClient()
{
	if (g_hHTTPClient != null)
		CloseHandle(g_hHTTPClient);
	
	char apiUrl[256];
	g_cvApiUrl.GetString(apiUrl, sizeof(apiUrl));

	char token[128];
	g_cvToken.GetString(token, sizeof(token));
	
	g_hHTTPClient = new HTTPClient(apiUrl);
	g_hHTTPClient.SetHeader("Token", token);
	g_hHTTPClient.ConnectTimeout = 30;
}

bool IsValidClient(int client, bool nobots = false)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
		return false;

	return IsClientInGame(client);
}