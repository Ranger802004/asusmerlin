#!/usr/bin/env python3
import argparse
import concurrent.futures
import ipaddress
import socket
from pathlib import Path

def normalize(name: str) -> str:
    return name.strip().lower().rstrip(".")

def is_domain(name: str) -> bool:
    name = normalize(name)
    if "." not in name or " " in name or "/" in name or "\\" in name:
        return False
    try:
        ipaddress.ip_address(name)
        return False
    except ValueError:
        return True

def parse_domains(raw: str) -> list[str]:
    text = raw.replace(",", "\n").replace(";", "\n")
    out = []
    seen = set()
    for part in text.split():
        name = normalize(part)
        if not name or name in seen:
            continue
        seen.add(name)
        out.append(name)
    return out

def load_domains(path: Path) -> list[str]:
    existing = []
    seen = set()
    if path.exists():
        for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            item = normalize(raw.split("#", 1)[0])
            if item and item not in seen:
                seen.add(item)
                existing.append(item)
    return existing

def usable_ip(addr: ipaddress._BaseAddress) -> bool:
    return not (
        addr.is_private
        or addr.is_loopback
        or addr.is_link_local
        or addr.is_multicast
        or addr.is_unspecified
        or addr.is_reserved
    )

def load_ips(path: Path, version: int) -> set[str]:
    ips = set()
    if not path.exists():
        return ips
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        item = raw.split("#", 1)[0].strip()
        if not item:
            continue
        try:
            addr = ipaddress.ip_address(item)
            if addr.version == version and usable_ip(addr):
                ips.add(str(addr))
        except ValueError:
            continue
    return ips

def write_ips(path: Path, ips: set[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    ordered = sorted(ips, key=lambda x: ipaddress.ip_address(x))
    path.write_text("\n".join(ordered) + ("\n" if ordered else ""), encoding="utf-8")

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

def resolve_many(names: list[str], workers: int) -> tuple[set[str], set[str]]:
    v4, v6 = set(), set()
    if not names:
        return v4, v6
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        for new_v4, new_v6 in pool.map(resolve_one, names):
            v4.update(new_v4)
            v6.update(new_v6)
    return v4, v6

def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--domain-dir", required=True)
    p.add_argument("--iplist-dir", required=True)
    p.add_argument("--list", required=True)
    p.add_argument("--domain", required=True)
    p.add_argument("--workers", type=int, default=50)
    args = p.parse_args()

    stem = Path(args.list).name
    if stem.endswith(".txt"):
        stem = stem[:-4]
    if not stem or stem.startswith(".") or "/" in stem or "\\" in stem:
        raise SystemExit(f"Invalid list name: {args.list}")

    submitted = parse_domains(args.domain)
    if not submitted:
        raise SystemExit("No domains provided")

    invalid = [name for name in submitted if not is_domain(name)]
    if invalid:
        raise SystemExit("Invalid domain(s): " + ", ".join(invalid))

    domain_path = Path(args.domain_dir) / f"{stem}.txt"
    if not domain_path.exists():
        raise SystemExit(f"List not found: {domain_path}")

    existing = load_domains(domain_path)
    present = set(existing)
    removed = [name for name in submitted if name in present]
    missing = [name for name in submitted if name not in present]

    if not removed:
        print(f"None of the submitted domains are in {domain_path.name}")
        for name in missing:
            print(f"  ? {name}")
        return

    drop_v4, drop_v6 = resolve_many(removed, args.workers)

    kept = [name for name in existing if name not in set(removed)]
    domain_path.write_text("\n".join(kept) + "\n", encoding="utf-8")

    iplist_dir = Path(args.iplist_dir)
    recent_v4 = iplist_dir / f"{stem}_ipv4_recent.txt"
    recent_v6 = iplist_dir / f"{stem}_ipv6_recent.txt"
    accum_v4 = iplist_dir / f"{stem}_ipv4_accumulative.txt"
    accum_v6 = iplist_dir / f"{stem}_ipv6_accumulative.txt"

    now_v4, now_v6 = resolve_many(kept, args.workers)
    old_accum_v4 = load_ips(accum_v4, 4)
    old_accum_v6 = load_ips(accum_v6, 6)

    # Drop IPs from the removed names unless another remaining domain still has them.
    all_v4 = (old_accum_v4 - drop_v4) | now_v4
    all_v6 = (old_accum_v6 - drop_v6) | now_v6

    write_ips(recent_v4, now_v4)
    write_ips(recent_v6, now_v6)
    write_ips(accum_v4, all_v4)
    write_ips(accum_v6, all_v6)

    print(f"List: {domain_path.name}")
    print(f"Removed domains: {len(removed)}")
    for name in removed:
        print(f"  - {name}")
    print(f"Not in list: {len(missing)}")
    for name in missing:
        print(f"  ? {name}")
    print(f"IPs from removed domains: v4={len(drop_v4)} v6={len(drop_v6)}")
    print(
        f"After rebuild: remaining_domains={len(kept)} "
        f"recent_v4={len(now_v4)} recent_v6={len(now_v6)} "
        f"accum_v4={len(all_v4)} accum_v6={len(all_v6)}"
    )

if __name__ == "__main__":
    main()