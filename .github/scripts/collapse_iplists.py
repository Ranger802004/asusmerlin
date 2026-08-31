#!/usr/bin/env python3
import argparse
import ipaddress
from pathlib import Path

SKIP = {".gitkeep", "readme.txt", "README.txt"}


def is_public(addr: ipaddress._BaseAddress) -> bool:
    return bool(addr.is_global)


def load_networks(path: Path, version: int) -> list[ipaddress._BaseNetwork]:
    nets = []
    if not path.exists():
        return nets
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        try:
            net = ipaddress.ip_network(line, strict=False)
        except ValueError:
            try:
                addr = ipaddress.ip_address(line)
                net = ipaddress.ip_network(addr)
            except ValueError:
                continue
        if net.version != version:
            continue
        if net.prefixlen == net.max_prefixlen and not is_public(net.network_address):
            continue
        if net.prefixlen < net.max_prefixlen:
            # keep existing public CIDRs; skip obviously private blocks
            if (
                net.network_address.is_private
                or net.network_address.is_loopback
                or net.network_address.is_link_local
                or net.network_address.is_multicast
                or net.network_address.is_unspecified
            ):
                continue
        nets.append(net)
    return nets


def write_cidrs(path: Path, nets: list[ipaddress._BaseNetwork]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    collapsed = list(ipaddress.collapse_addresses(nets))
    lines = [str(n) for n in collapsed]
    path.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
    return len(nets), len(lines)


def collapse_one(src: Path) -> None:
    name = src.name.lower()
    if "cidr" in name or src.name in SKIP:
        return
    if name.endswith("_ipv4_accumulative.txt"):
        version = 4
        dest = src.with_name(src.name.replace("_ipv4_accumulative.txt", "_ipv4_accumulative_cidr.txt"))
    elif name.endswith("_ipv6_accumulative.txt"):
        version = 6
        dest = src.with_name(src.name.replace("_ipv6_accumulative.txt", "_ipv6_accumulative_cidr.txt"))
    else:
        return

    nets = load_networks(src, version)
    before = len(nets)
    collapsed = list(ipaddress.collapse_addresses(nets))
    dest.write_text(
        "\n".join(str(n) for n in collapsed) + ("\n" if collapsed else ""),
        encoding="utf-8",
    )
    print(f"{src.name}: {before} -> {len(collapsed)} CIDRs ({dest.name})")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--iplist-dir", required=True)
    args = p.parse_args()
    folder = Path(args.iplist_dir)
    files = sorted(folder.glob("*_ipv4_accumulative.txt")) + sorted(
        folder.glob("*_ipv6_accumulative.txt")
    )
    if not files:
        print("No accumulative IP lists found")
        return
    for path in files:
        collapse_one(path)


if __name__ == "__main__":
    main()