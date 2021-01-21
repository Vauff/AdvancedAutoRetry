# Advanced Auto Retry

Advanced Auto Retry is an auto retry system for custom particles on CS:GO maps that connects with [Cloudflare workers](https://github.com/Vauff/AdvancedAutoRetry-Workers) to ensure that players are only retried when they actually had to download the map when joining. This plugin also features the ability for players to turn off the plugin by using !autoretry, and automatic detection of maps using custom particles. It should be noted that while this solution is very effective, it comes with a significant amount of setup steps, including having to host your FastDL content under the [Cloudflare CDN](https://www.cloudflare.com/cdn/). If this is a problem for you, you may be better off using [DarkerZ's version](https://github.com/darkerz7/CSGO-Plugins/tree/master/Auto_Retry), which while less accurate, is a more plug and play experience.

## Requirements

- [REST in Pawn Extension](https://github.com/ErikMinekus/sm-ripext/releases)
- [Advanced Auto Retry Workers](https://github.com/Vauff/AdvancedAutoRetry-Workers)

## Installation

Installation is too complex to maintain a proper tutorial for. Feel free to contact Vauff for some assistance if you're interested in using this on your server, or try it on your own if you're well versed in SourceMod and Cloudflare setup.

Some key points if you're doing the latter:
- IPv6 needs to be disabled on the Cloudflare domain so the IPs match what clients are using to connect to the gameserver
- Due to the 1000 KV write limit on the free workers plan, you need to subscribe to Workers Bundled if you intend to use this on a server where more than 1000 map download requests can happen per day