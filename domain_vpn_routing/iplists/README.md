# IP lists

This folder holds public addresses produced from the hostname files in [`../domainlists`](../domainlists).

The routing script itself is documented in [`../readme.txt`](../readme.txt). Beta script notes are in [`../readme-beta.txt`](../readme-beta.txt).

Do not edit these files by hand unless you intend to bypass the resolve workflow. They are generated automatically.

---

## What a file in this folder is

For each domain list stem (`youtube`, `discord`, `netflix`, and so on) six files are written.

Private, loopback, link-local, multicast, reserved, and unspecified addresses are not stored.

---

## `{stem}_ipv4_recent.txt`

IPv4 addresses returned by the latest resolve of `domainlists/{stem}.txt`.

This file is replaced on every successful run. It shows what IPv4 DNS returned this time. It is not a historical list.

---

## `{stem}_ipv6_recent.txt`

IPv6 addresses returned by the latest resolve of `domainlists/{stem}.txt`.

This file is replaced on every successful run. It shows what IPv6 DNS returned this time. It is not a historical list.

---

## `{stem}_ipv4_accumulative.txt`

Every public IPv4 address that has been returned for that stem across all successful resolves.

New addresses are added. Existing addresses stay even if a later lookup no longer returns them. Use this file when you want long-term IPv4 coverage as CDN and anycast answers change.

---

## `{stem}_ipv6_accumulative.txt`

Every public IPv6 address that has been returned for that stem across all successful resolves.

New addresses are added. Existing addresses stay even if a later lookup no longer returns them. Use this file when you want long-term IPv6 coverage as CDN and anycast answers change.

---

## `{stem}_ipv4_accumulative_cidr.txt`

The IPv4 accumulative list collapsed into the largest CIDR blocks that still cover the same addresses.

This file is rebuilt from `{stem}_ipv4_accumulative.txt` after each resolve. It is the compact form of the IPv4 accumulative list.

---

## `{stem}_ipv6_accumulative_cidr.txt`

The IPv6 accumulative list collapsed into the largest CIDR blocks that still cover the same addresses.

This file is rebuilt from `{stem}_ipv6_accumulative.txt` after each resolve. It is the compact form of the IPv6 accumulative list.

---

## How these files are produced

```text
domainlists/{stem}.txt
        │
        │  resolve
        ▼
{stem}_ipv4_recent.txt
{stem}_ipv6_recent.txt
        │
        │  merge into
        ▼
{stem}_ipv4_accumulative.txt
{stem}_ipv6_accumulative.txt
        │
        │  collapse
        ▼
{stem}_ipv4_accumulative_cidr.txt
{stem}_ipv6_accumulative_cidr.txt
```

The **Resolve domainlists to iplists** workflow runs about every four hours and when domain list files change. It also runs when **Add domain**, **Create list**, or **Update list** finishes updating a stem.

**Remove domain** stops future lookups for the removed names. Addresses already stored in the accumulative files are not automatically deleted.

**Test domain DNS** prints lookup results only. It does not write files here.

---

## Other files in this folder

`.gitkeep` keeps the directory in git when it would otherwise be empty.

`.hashes/` stores a checksum of each domain list so a changed-only resolve can skip stems that did not change.

This `README.md` is not an address list and is ignored by the resolve job.

---

## Raw URL

```text
https://raw.githubusercontent.com/Ranger802004/asusmerlin/refs/heads/main/domain_vpn_routing/iplists/{filename}
```

Example:

```text
https://raw.githubusercontent.com/Ranger802004/asusmerlin/refs/heads/main/domain_vpn_routing/iplists/netflix_ipv4_accumulative_cidr.txt
```
