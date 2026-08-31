# Domain lists

This folder is the source of hostnames used for Domain VPN Routing.

The routing script itself is documented in [`../readme.txt`](../readme.txt). Beta script notes are in [`../readme-beta.txt`](../readme-beta.txt).

Resolved addresses for these names are written to [`../iplists`](../iplists).

---

## What a file in this folder is

Each `{stem}.txt` file is the hostname list for one service.

Examples:

- `youtube.txt` — YouTube hostnames
- `discord.txt` — Discord hostnames
- `netflix.txt` — Netflix hostnames

The stem is the file name without `.txt`. That same stem is used for the matching files under `iplists/`.

---

## File format

- One hostname per line
- Lowercase
- No trailing dot
- Hostnames only — no URLs, paths, or IP addresses
- A `#` starts a comment for the rest of that line
- Empty lines are ignored
- The add-domain workflow writes the file sorted A–Z

Example:

```text
cdn.discordapp.com
gateway.discord.gg
latency.discord.media
```

---

## What these files are used for

The resolve workflow reads every `*.txt` file in this folder (except skip names such as this README).

For each hostname it performs DNS lookups and writes public IPv4 and IPv6 addresses into `iplists/`.

Edit the domain list when a service needs more names, fewer names, or a new service list. Do not put addresses in these files.

---

## Current lists

`apple-tv.txt`, `discord.txt`, `disney-plus.txt`, `espn.txt`, `fox-one.txt`, `hbo-max.txt`, `hulu.txt`, `netflix.txt`, `paramount-plus.txt`, `peacock.txt`, `prime-video.txt`, `spotify.txt`, `tiktok.txt`, `twitch.txt`, `xfinity-stream.txt`, `youtube.txt`

---

## Workflows that change files here

Run these from the repository Actions tab.

**Add domain**  
Adds one or more hostnames to an existing `{stem}.txt`, sorts the file, then resolves that stem.

**Remove domain**  
Removes one or more hostnames from an existing `{stem}.txt`. Those names are not resolved on later runs.

**Create list**  
Creates a new `{stem}.txt` in this folder and runs the first resolve.

**Update list**  
Leaves this folder unchanged and re-resolves one existing stem.

**Resolve domainlists to iplists**  
Reads the lists in this folder on a schedule (about every four hours) or when started by hand.

**Test domain DNS**  
Looks up one hostname. It does not change files in this folder.

---

## Raw URL

```text
https://raw.githubusercontent.com/Ranger802004/asusmerlin/refs/heads/main/domain_vpn_routing/domainlists/{stem}.txt
```
