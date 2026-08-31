#!/usr/bin/env python3
import argparse
import concurrent.futures
import hashlib
import ipaddress
import re
import socket
from pathlib import Path

SKIP_NAMES = {".gitkeep", "readme.txt", "README.txt"}
CNAME_TRIPLE = re.compile(
    r"^((?:rr?)\d+)---(sn-[a-z0-9-]+\.googlevideo\.com)$",
    re.I,
)

socket.setdefaulttimeout(2)


def is_public(addr: ipaddress._BaseAddress) -> bool:
    return bool(addr.is_global)


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
        except ValueError:
            continue
        if addr.version == version and is_public(addr):
            ips.add(str(addr))
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


def resolve_targets(domains: list[str]) -> list[str]:
    present = set(domains)
    out = []
    skipped = 0
    for name in domains:
        m = CNAME_TRIPLE.match(name)
        if m:
            target = f"{m.group(1).lower()}.{m.group(2).lower()}"
            if target in present:
                skipped += 1
                continue
        out.append(name)
    print(f"  resolve {len(out)} of {len(domains)} (skipped {skipped} googlevideo CNAME aliases)")
    return out


def resolve_one(name: str) -> tuple[set[str], set[str]]:
    v4, v6 = set(), set()
    try:
        for info in socket.getaddrinfo(name, None, socket.AF_UNSPEC, socket.SOCK_STREAM):
            addr = ipaddress.ip_address(info[4][0])
            if not is_public(addr):
                continue
            if addr.version == 4:
                v4.add(str(addr))
            else:
                v6.add(str(addr))
    except (socket.gaierror, socket.timeout, OSError):
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

    prev_v4 = load_ips(accum_v4, 4)
    prev_v6 = load_ips(accum_v6, 6)

    domains = sorted(
        {n.rstrip(".").lower() for n in load_lines(in_path) if is_domain(n)}
    )
    targets = resolve_targets(domains)

    now_v4, now_v6 = set(), set()
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        for new_v4, new_v6 in pool.map(resolve_one, targets, chunksize=32):
            now_v4.update(new_v4)
            now_v6.update(new_v6)

    all_v4 = prev_v4 | now_v4
    all_v6 = prev_v6 | now_v6

    write_ips(recent_v4, now_v4)
    write_ips(recent_v6, now_v6)
    write_ips(accum_v4, all_v4)
    write_ips(accum_v6, all_v6)
    save_hash(in_path, iplist_dir)

    print(
        f"{in_path.name}: domains={len(domains)} queried={len(targets)} "
        f"recent_v4={len(now_v4)} recent_v6={len(now_v6)} "
        f"accum_v4={len(prev_v4)}->{len(all_v4)} "
        f"accum_v6={len(prev_v6)}->{len(all_v6)}"
    )


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--domain-dir", required=True)
    p.add_argument("--iplist-dir", required=True)
    p.add_argument("--workers", type=int, default=150)
    p.add_argument("--mode", choices=("all", "changed"), default="all")
    p.add_argument("--files", nargs="*", default=None)
    args = p.parse_args()

    domain_dir = Path(args.domain_dir)
    iplist_dir = Path(args.iplist_dir)
    iplist_dir.mkdir(parents=True, exist_ok=True)

    if args.files:
        files = []
        for item in args.files:
            path = Path(item)
            if not path.is_absolute():
                path = Path.cwd() / path
            if path.suffix.lower() == ".txt" and path.name not in SKIP_NAMES and path.exists():
                files.append(path)
        files = sorted(set(files))
    else:
        files = domain_files(domain_dir)
        if args.mode == "changed":
            files = [path for path in files if domain_changed(path, iplist_dir)]

    if not files:
        print("No domain lists to resolve")
        return

    for path in files:
        print(f"Resolving {path}")
        resolve_file(path, iplist_dir, args.workers)


if __name__ == "__main__":
    main()