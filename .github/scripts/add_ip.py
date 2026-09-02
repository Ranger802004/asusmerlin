#!/usr/bin/env python3
import argparse
import ipaddress
from pathlib import Path


def is_public(addr: ipaddress._BaseAddress) -> bool:
    return bool(addr.is_global)


def parse_entries(raw: str) -> list[str]:
    text = raw.replace(",", "\n").replace(";", "\n")
    out = []
    seen = set()
    for part in text.split():
        item = part.strip()
        if not item or item.startswith("#") or item in seen:
            continue
        seen.add(item)
        out.append(item)
    return out


def classify(item: str) -> tuple[str, ipaddress._BaseNetwork]:
    try:
        net = ipaddress.ip_network(item, strict=False)
    except ValueError as exc:
        raise SystemExit(f"Invalid IP/CIDR: {item}") from exc
    if net.prefixlen == net.max_prefixlen:
        if not is_public(net.network_address):
            raise SystemExit(f"Not a public address: {item}")
        return "host", net
    addr = net.network_address
    if (
        addr.is_private
        or addr.is_loopback
        or addr.is_link_local
        or addr.is_multicast
        or addr.is_unspecified
    ):
        raise SystemExit(f"Not a public network: {item}")
    return "cidr", net


def load_lines(path: Path) -> list[str]:
    if not path.exists():
        return []
    out = []
    seen = set()
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        item = raw.split("#", 1)[0].strip()
        if item and item not in seen:
            seen.add(item)
            out.append(item)
    return out


def sort_key(item: str):
    try:
        net = ipaddress.ip_network(item, strict=False)
        return (net.version, int(net.network_address), net.prefixlen)
    except ValueError:
        return (99, 0, 0)


def write_lines(path: Path, items: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    ordered = sorted(dict.fromkeys(items), key=sort_key)
    path.write_text("\n".join(ordered) + ("\n" if ordered else ""), encoding="utf-8")


def add_line(path: Path, value: str) -> bool:
    items = load_lines(path)
    if value in items:
        return False
    items.append(value)
    write_lines(path, items)
    return True


def stem_paths(iplist_dir: Path, stem: str, version: int) -> dict[str, Path]:
    v = f"ipv{version}"
    return {
        "recent": iplist_dir / f"{stem}_{v}_recent.txt",
        "accum": iplist_dir / f"{stem}_{v}_accumulative.txt",
        "cidr": iplist_dir / f"{stem}_{v}_accumulative_cidr.txt",
    }


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--iplist-dir", required=True)
    p.add_argument("--list", required=True, help="List stem, e.g. fox-one")
    p.add_argument("--entry", required=True, help="IP and/or CIDR values")
    args = p.parse_args()

    stem = Path(args.list).name
    if stem.endswith(".txt"):
        stem = stem[:-4]
    if not stem or stem.startswith(".") or "/" in stem or "\\" in stem:
        raise SystemExit(f"Invalid list name: {args.list}")

    submitted = parse_entries(args.entry)
    if not submitted:
        raise SystemExit("No IP/CIDR values provided")

    iplist_dir = Path(args.iplist_dir)
    iplist_dir.mkdir(parents=True, exist_ok=True)

    added_hosts = []
    added_cidrs = []
    skipped = []

    for raw in submitted:
        kind, net = classify(raw)
        version = net.version
        paths = stem_paths(iplist_dir, stem, version)
        if kind == "host":
            value = str(net.network_address)
            changed_recent = add_line(paths["recent"], value)
            changed_accum = add_line(paths["accum"], value)
            if changed_recent or changed_accum:
                added_hosts.append(f"{value} ({paths['recent'].name if changed_recent else '-'}, {paths['accum'].name})")
            else:
                skipped.append(f"{value} already present")
        else:
            value = str(net)
            changed_cidr = add_line(paths["cidr"], value)
            changed_accum = add_line(paths["accum"], value)
            if changed_cidr or changed_accum:
                added_cidrs.append(f"{value} ({paths['cidr'].name}, {paths['accum'].name})")
            else:
                skipped.append(f"{value} already present")

    print(f"List: {stem}")
    print(f"Submitted: {len(submitted)}")
    print(f"Added hosts: {len(added_hosts)}")
    for item in added_hosts:
        print(f"  + {item}")
    print(f"Added CIDRs: {len(added_cidrs)}")
    for item in added_cidrs:
        print(f"  + {item}")
    print(f"Already present: {len(skipped)}")
    for item in skipped:
        print(f"  = {item}")


if __name__ == "__main__":
    main()
