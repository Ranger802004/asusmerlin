#!/usr/bin/env python3
import argparse
import concurrent.futures
import hashlib
import ipaddress
import socket
from pathlib import Path

SKIP_NAMES = {".gitkeep", "readme.txt", "README.txt"}

def usable_ip(addr: ipaddress._BaseAddress) -> bool:
    return not (
        addr.is_private
        or addr.is_loopback
        or addr.is_link_local
        or addr.is_multicast
        or addr.is_unspecified
        or addr.is_reserved
    )

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
            if addr.version == version and usable_ip(addr):
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
                if usable_ip(addr):
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

def file_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def hash_path(iplist_dir: Path, stem: str) -> Path:
    return iplist_dir / ".hashes" / f"{stem}.sha256"

def domain_changed(in_path: Path, iplist_dir: Path) -> bool:
    stored = hash_path(iplist_dir, in_path.stem)
    if not stored.exists():
        return True
    return stored.read_text(encoding="utf-8").strip() != file_hash(in_path)

def save_hash(in_path: Path, iplist_dir: Path) -> None:
    path = hash_path(iplist_dir, in_path.stem)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(file_hash(in_path) + "\n", encoding="utf-8")

def resolve_file(in_path: Path, iplist_dir: Path, workers: int) -> None:
    stem = in_path.stem
    recent_v4 = iplist_dir / f"{stem}_ipv4_recent.txt"
    recent_v6 = iplist_dir / f"{stem}_ipv6_recent.txt"
    accum_v4 = iplist_dir / f"{stem}_ipv4_accumulative.txt"
    accum_v6 = iplist_dir / f"{stem}_ipv6_accumulative.txt"

    domains = sorted(
        {n.rstrip(".").lower() for n in load_lines(in_path) if is_domain(n)}
    )

    now_v4, now_v6 = set(), set()
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        for new_v4, new_v6 in pool.map(resolve_one, domains):
            now_v4.update(new_v4)
            now_v6.update(new_v6)

    all_v4 = load_ips(accum_v4, 4) | now_v4
    all_v6 = load_ips(accum_v6, 6) | now_v6

    write_ips(recent_v4, now_v4