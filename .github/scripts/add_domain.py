#!/usr/bin/env python3
import argparse
import ipaddress
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

def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--domain-dir", required=True)
    p.add_argument("--list", required=True, help="List stem, e.g. youtube")
    p.add_argument("--domain", required=True, help="One domain, or several separated by newline/comma/space")
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

    path = Path(args.domain_dir) / f"{stem}.txt"
    path.parent.mkdir(parents=True, exist_ok=True)

    existing = []
    seen = set()
    if path.exists():
        for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            item = normalize(raw.split("#", 1)[0])
            if item and item not in seen:
                seen.add(item)
                existing.append(item)

    added = []
    skipped = []
    for domain in submitted:
        if domain in seen:
            skipped.append(domain)
            continue
        existing.append(domain)
        seen.add(domain)
        added.append(domain)

    if added:
        path.write_text("\n".join(existing) + "\n", encoding="utf-8")

    print(f"List: {path.name}")
    print(f"Submitted: {len(submitted)}")
    print(f"Added: {len(added)}")
    print(f"Already present: {len(skipped)}")
    for name in added:
        print(f"  + {name}")
    for name in skipped:
        print(f"  = {name}")

if __name__ == "__main__":
    main()