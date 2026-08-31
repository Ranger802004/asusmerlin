#!/usr/bin/env python3
import argparse
import concurrent.futures
import hashlib
import ipaddress
import random
import re
import socket
import struct
from pathlib import Path

SKIP_NAMES = {".gitkeep", "readme.txt", "README.txt"}
CNAME_TRIPLE = re.compile(
    r"^((?:rr?)\d+)---(sn-[a-z0-9-]+\.googlevideo\.com)$",
    re.I,
)

# Anycast (US PoP from GitHub Actions) plus unicast/regional resolvers.
DNS_SERVERS = (
    "8.8.8.8",
    "1.1.1.1",
    "9.9.9.9",
    "208.67.222.222",
    "84.200.69.80",       # DNS.WATCH DE
    "84.200.70.40",       # DNS.WATCH DE
    "51.75.96.82",        # le_dns FR
    "151.115.80.165",     # le_dns PL
    "89.233.43.71",       # UncensoredDNS DK unicast
    "185.95.218.42",      # Digitale Gesellschaft CH
)

# Google honors ECS. Query these as if the client were in that prefix.
ECS_SERVERS = ("8.8.8.8", "8.8.4.4")
ECS_PREFIXES = (
    "80.0.0.0/8",      # DE/EU
    "2.16.0.0/13",     # FR/EU
    "126.0.0.0/8",     # JP
    "211.104.0.0/13",  # KR
    "203.0.0.0/8",     # APAC
)

# googlevideo.com is large; skip regional/ECS fan-out on those names.
FAST_SERVERS = ("8.8.8.8", "1.1.1.1")
DNS_TIMEOUT = 2.0

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


def _encode_name(name: str) -> bytes:
    out = b""
    for label in name.rstrip(".").split("."):
        raw = label.encode("idna")
        out += bytes([len(raw)]) + raw
    return out + b"\x00"


def _skip_name(buf: bytes, pos: int) -> int:
    while pos < len(buf):
        length = buf[pos]
        if length == 0:
            return pos + 1
        if length & 0xC0 == 0xC0:
            return pos + 2
        pos += 1 + length
    return pos


def _parse_answers(buf: bytes, qtype: int) -> list[str]:
    if len(buf) < 12:
        return []
    _, flags, qd, an, _, _ = struct.unpack("!HHHHHH", buf[:12])
    if not (flags & 0x8000):
        return []
    pos = 12
    for _ in range(qd):
        pos = _skip_name(buf, pos) + 4
    found = []
    for _ in range(an):
        pos = _skip_name(buf, pos)
        if pos + 10 > len(buf):
            break
        rtype, _, _, rdlen = struct.unpack("!HHIH", buf[pos:pos + 10])
        pos += 10
        rdata = buf[pos:pos + rdlen]
        pos += rdlen
        if rtype != qtype:
            continue
        try:
            if qtype == 1 and rdlen == 4:
                found.append(str(ipaddress.IPv4Address(rdata)))
            elif qtype == 28 and rdlen == 16:
                found.append(str(ipaddress.IPv6Address(rdata)))
        except ValueError:
            continue
    return found


def _ecs_option(prefix: str) -> bytes:
    net = ipaddress.ip_network(prefix, strict=False)
    if net.version != 4:
        return b""
    addr = net.network_address.packed
    src_len = net.prefixlen
    keep = (src_len + 7) // 8
    addr = addr[:keep]
    payload = struct.pack("!HBB", 1, src_len, 0) + addr
    return struct.pack("!HH", 8, len(payload)) + payload


def _opt_record(ecs_prefix: str | None) -> bytes:
    rdata = _ecs_option(ecs_prefix) if ecs_prefix else b""
    return b"\x00" + struct.pack("!HHIH", 41, 4096, 0, len(rdata)) + rdata


def dns_query(name: str, qtype: int, server: str, ecs_prefix: str | None = None) -> list[str]:
    txn = random.randint(0, 65535)
    extra = _opt_record(ecs_prefix)
    header = struct.pack("!HHHHHH", txn, 0x0100, 1, 0, 0, 1)
    question = _encode_name(name) + struct.pack("!HH", qtype, 1)
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.settimeout(DNS_TIMEOUT)
        sock.sendto(header + question + extra, (server, 53))
        data, _ = sock.recvfrom(4096)
    except OSError:
        return []
    finally:
        sock.close()
    return _parse_answers(data, qtype)


def _collect(name: str, server: str, ecs_prefix: str | None, v4: set[str], v6: set[str]) -> None:
    for ip in dns_query(name, 1, server, ecs_prefix) + dns_query(name, 28, server, ecs_prefix):
        try:
            addr = ipaddress.ip_address(ip)
        except ValueError:
            continue
        if is_public(addr):
            (v4 if addr.version == 4 else v6).add(str(addr))


def resolve_one(name: str) -> tuple[set[str], set[str]]:
    v4, v6 = set(), set()

    try:
        for info in socket.getaddrinfo(name, None, socket.AF_UNSPEC, socket.SOCK_STREAM):
            addr = ipaddress.ip_address(info[4][0])
            if is_public(addr):
                (v4 if addr.version == 4 else v6).add(str(addr))
    except (socket.gaierror, socket.timeout, OSError):
        pass

    extra = not name.endswith(".googlevideo.com")
    servers = DNS_SERVERS if extra else FAST_SERVERS
    for server in servers:
        _collect(name, server, None, v4, v6)

    if extra:
        for server in ECS_SERVERS:
            for prefix in ECS_PREFIXES:
                _collect(name, server, prefix, v4, v6)

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
