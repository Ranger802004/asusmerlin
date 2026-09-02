#!/usr/bin/env python3
import argparse
import ipaddress
from pathlib import Path


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
        return "host", net
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


def parse_net(item: str):
    try:
        return ipaddress.ip_network(item, strict=False)
    except ValueError:
        return None


def stem_paths(iplist_dir: Path, stem: str, version: int) -> dict[str, Path]:
    v = f"ipv{version}"
    return {
        "recent": iplist_dir / f"{stem}_{v}_recent.txt",
        "accum": iplist_dir / f"{stem}_{v}_accumulative.txt",
        "cidr": iplist_dir / f"{stem}_{v}_accumulative_cidr.txt",
    }


def remove_host(paths: dict[str, Path], host: ipaddress._BaseNetwork) -> list[str]:
    value = str(host.network_address)
    removed = []
    for label, path in paths.items():
        items = load_lines(path)
        kept = []
        hit = False
        for item in items:
            net = parse_net(item)
            if net is None:
                kept.append(item)
                continue
            if net.version != host.version:
                kept.append(item)
                continue
            # exact host, or /32-/128 written as a network
            if net == host or (net.prefixlen == net.max_prefixlen and net.network_address == host.network_address):
                hit = True
                continue
            kept.append(item)
        if hit:
            write_lines(path, kept)
            removed.append(f"{value} from {path.name}")
    return removed


def remove_cidr(paths: dict[str, Path], target: ipaddress._BaseNetwork) -> list[str]:
    removed = []
    value = str(target)
    for label, path in paths.items():
        items = load_lines(path)
        kept = []
        hits = []
        for item in items:
            net = parse_net(item)
            if net is None:
                kept.append(item)
                continue
            if net.version != target.version:
                kept.append(item)
                continue
            # drop exact CIDR, any contained host/network, and identical supernet match
            if net == target or net.subnet_of(target):
                hits.append(item)
                continue
            kept.append(item)
        if hits:
            write_lines(path, kept)
            for item in hits:
                removed.append(f"{item} from {path.name}")
        elif label == "cidr" and value not in items:
            continue
    return removed


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
    removed = []
    missing = []

    for raw in submitted:
        kind, net = classify(raw)
        paths = stem_paths(iplist_dir, stem, net.version)
        if kind == "host":
            hits = remove_host(paths, net)
        else:
            hits = remove_cidr(paths, net)
        if hits:
            removed.extend(hits)
        else:
            missing.append(str(net.network_address if kind == "host" else net))

    print(f"List: {stem}")
    print(f"Submitted: {len(submitted)}")
    print(f"Removed: {len(removed)}")
    for item in removed:
        print(f"  - {item}")
    print(f"Not found: {len(missing)}")
    for item in missing:
        print(f"  ? {item}")


if __name__ == "__main__":
    main()
