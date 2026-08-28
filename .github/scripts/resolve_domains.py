#!/usr/bin/env python3
import argparse
import concurrent.futures
import ipaddress
import socket
from pathlib import Path

SKIP_NAMES = {".gitkeep", "readme.txt", "README.txt"}

def load_lines(path: Path) -> set[str]:
    if not path.exists():
        return set()
    out = set()
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.split("#", 1)[0].strip()
        if line:
            out.add(line)
    return out

def load_ips(path: Path, version: int) -> set[str]:
    ips = set()
    for item in load_lines(path):
        try:
            addr = ipaddress.ip_address(item)
            if addr.version == version and not (
                addr.is_private
                or addr.is_loopback
                or addr.is_link_local
                or addr.is_multicast
            ):
                ips.add(str(addr))
        except ValueError:
            continue
    return ips

def is_domain(name: str) -> bool:
    name = name.strip().lower().rstrip(".")
    if "." not in name or " " in name:
        return False
    try:
        ipaddress.ip_address(name)
        return False
    except ValueError:
        return True

def resolve_one(name: str) -> tuple[set[str], set[str]]:
    v4, v6 = set(), set()
    for family, bucket in ((socket.AF_INET, v4), (socket.AF_INET6, v6)):
        try:
            for info in socket.getaddrinfo(name, None, family, socket.SOCK_STREAM):
                addr = ipaddress.ip_address(info[4][0])
                if addr.is_private or addr.is_loopback or addr.is_link_local or addr.is_multicast:
                    continue
                bucket.add(str(addr))
        except socket.gaierror:
            pass
    return v4, v6

def write_ips(path: Path, ips: set[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    ordered = sorted(ips, key=lambda x: ipaddress.ip_address(x))
    path.write_text("\n".join(ordered) + ("\n" if ordered else ""), encoding="utf-8")

def domain_files(domain_dir: Path) -> list[Path]:
    files = []
    for path in sorted(domain_dir.glob("*.txt")):
        if path.name in SKIP_NAMES or path.name.startswith("."):
            continue
        files.append(path)
    return files

def resolve_file(in_path: Path, iplist_dir: Path, accumulate: bool, workers: int) -> None:
    stem = in_path.stem
    v4_path = iplist_dir / f"{stem}_ipv4.txt"
    v6_path = iplist_dir / f"{stem}_ipv6.txt"

    domains = sorted(
        {n.rstrip(".").lower() for n in load_lines(in_path) if is_domain(n)}
    )
    v4 = load_ips(v4_path, 4) if accumulate else set()
    v6 = load_ips(v6_path, 6) if accumulate else set()

    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        for new_v4, new_v6 in pool.map(resolve_one, domains):
            v4.update(new_v4)
            v6.update(new_v6)

    write_ips(v4_path, v4)
    write_ips(v6_path, v6)
    print(f"{in_path.name}: domains={len(domains)} ipv4={len(v4)} ipv6={len(v6)}")

def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--domain-dir", required=True)
    p.add_argument("--iplist-dir", required=True)
    p.add_argument("--accumulate", action="store_true")
    p.add_argument("--workers", type=int, default=50)
    args = p.parse_args()

    domain_dir = Path(args.domain_dir)
    iplist_dir = Path(args.iplist_dir)
    iplist_dir.mkdir(parents=True, exist_ok=True)

    files = domain_files(domain_dir)
    if not files:
        print(f"No domain lists found in {domain_dir}")
        return

    for path in files:
        resolve_file(path, iplist_dir, args.accumulate, args.workers)

if __name__ == "__main__":
    main()