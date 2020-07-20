# Advanced Auto Retry

Advanced Auto Retry is an auto retry system for custom particles on CS:GO maps that connects with [an API](https://github.com/Vauff/AdvancedAutoRetry-API) to ensure that players are only retried when they actually had to download the map when joining. This plugin also features the ability for players to turn off the plugin by using !autoretry, and automatic detection of maps using custom particles. It should be noted that while this solution is very effective, it comes with a significant amount of setup steps, including having to host your FastDL content under the [Cloudflare CDN](https://www.cloudflare.com/cdn/). If this is a problem for you, you may be better off using [DarkerZ's version](https://github.com/darkerz7/CSGO-Plugins/tree/master/Auto_Retry), which while less accurate, is a more plug and play experience.

## Requirements

- [REST in Pawn Extension](https://github.com/ErikMinekus/sm-ripext/releases)
- [Advanced Auto Retry API](https://github.com/Vauff/AdvancedAutoRetry-API)

## Installation

- Install the plugin as you normally would, whether by compiling the .sp or using the pre-compiled .smx
- Set the **sm_aar_api_url** cvar to the URL you are hosting the API at with the path excluded (e.g. http://api.example.com, not http://api.example.com/clientdownloaded)
- Set the **sm_aar_api_token** cvar to whatever token you setup during the installation of the API