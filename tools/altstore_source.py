#!/usr/bin/env python3
"""Write and validate the AltStore / SideStore source for Ashen Oath.

CI runs this after every IPA build:
  python3 tools/altstore_source.py --ipa build/ios/AshenOath.ipa \
      --version 2.0.1 --build-version 2.0.1 --sha <git sha> --run 1 \
      --out dist/altstore.json
  python3 tools/altstore_source.py --validate dist/altstore.json

The source is hosted as an asset on the 'ota' release:
  https://github.com/Rico-Rodriguez/ashen-oath/releases/download/ota/altstore.json
"""
import argparse
import datetime as dt
import json
import os
import re
import sys

REPO = "Rico-Rodriguez/ashen-oath"
SOURCE_URL = f"https://github.com/{REPO}/releases/download/ota/altstore.json"
IPA_URL = f"https://github.com/{REPO}/releases/download/ios-v1/AshenOath.ipa"
ICON_URL = f"https://raw.githubusercontent.com/{REPO}/main/icon.png"
TINT = "D4A853"


def bundle_id(presets="export_presets.cfg"):
    text = open(presets, encoding="utf-8").read()
    m = re.search(r'^application/bundle_identifier="([^"]+)"', text, re.M)
    if not m:
        raise SystemExit("bundle_identifier not found in export_presets.cfg")
    return m.group(1)


def build(args):
    size = os.path.getsize(args.ipa) if args.ipa else int(args.size)
    date = args.date or dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    notes = (
        f"Build {args.run} from {args.sha[:7]}. "
        "Content-only updates arrive in-game as OTA packs; reinstall this IPA when a new native shell is published."
    )
    desc = (
        "Dark-medieval pocket ARPG through the Barrow Lands. Choose Oathbreaker, Battlemage, or Revenant, "
        "carve through four blighted zones, forge and temper relics that visibly transform your knight, "
        "and break the guardian bosses of each realm.\n\n"
        "Most updates arrive automatically inside the game via over-the-air (OTA) content packs. "
        "Update here when a new native app build is published."
    )
    version = {
        "version": args.version,
        "buildVersion": args.build_version,
        "date": date,
        "localizedDescription": notes,
        "downloadURL": IPA_URL,
        "size": size,
        "minOSVersion": "15.0",
    }
    app = {
        "name": "Ashen Oath",
        "bundleIdentifier": bundle_id(),
        "developerName": "Rico Rodriguez",
        "subtitle": "Dark-medieval pocket ARPG through the Barrow Lands.",
        "localizedDescription": desc,
        "iconURL": ICON_URL,
        "tintColor": TINT,
        "category": "games",
        "screenshots": [],
        "versions": [version],
        "appPermissions": {"entitlements": [], "privacy": {}},
        # Legacy fields required by AltStore 1.x.
        "version": args.version,
        "versionDate": date,
        "versionDescription": notes,
        "downloadURL": IPA_URL,
        "size": size,
    }
    return {
        "name": "Ashen Oath",
        "identifier": "com.rico.ashenoath.source",
        "subtitle": "Dark-medieval pocket ARPG through the Barrow Lands.",
        "description": "Unsigned Ashen Oath iOS builds from CI, for AltStore and SideStore.",
        "iconURL": ICON_URL,
        "website": f"https://github.com/{REPO}",
        "tintColor": TINT,
        "sourceURL": SOURCE_URL,
        "featuredApps": [app["bundleIdentifier"]],
        "apps": [app],
        "news": [],
    }


def _need(obj, key, kind, where):
    if key not in obj:
        raise ValueError(f"{where}: missing '{key}'")
    if not isinstance(obj[key], kind) or (kind is str and not obj[key]):
        raise ValueError(f"{where}: '{key}' should be a non-empty {kind}")


def validate(src):
    _need(src, "name", str, "source")
    _need(src, "identifier", str, "source")
    _need(src, "apps", list, "source")
    if not src["apps"]:
        raise ValueError("source: apps is empty")
    for app in src["apps"]:
        w = "app " + str(app.get("name"))
        for key in ["name", "bundleIdentifier", "developerName", "localizedDescription", "iconURL"]:
            _need(app, key, str, w)
        _need(app, "versions", list, w)
        _need(app, "appPermissions", dict, w)
        if not app["versions"]:
            raise ValueError(w + ": versions is empty")
        for v in app["versions"]:
            for key in ["version", "date", "downloadURL"]:
                _need(v, key, str, w + " version")
            _need(v, "size", int, w + " version")
            if v["size"] <= 0:
                raise ValueError(w + ": version size must be positive")
            dt.datetime.fromisoformat(v["date"].replace("Z", "+00:00"))
            if not v["downloadURL"].startswith("https://"):
                raise ValueError(w + ": downloadURL must be https")
        for key in ["version", "versionDate", "downloadURL"]:
            _need(app, key, str, w + " (legacy)")
        _need(app, "size", int, w + " (legacy)")
        if app["version"] != app["versions"][0]["version"]:
            raise ValueError(w + ": legacy version does not match versions[0]")
    return True


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--validate")
    p.add_argument("--ipa")
    p.add_argument("--size", default="0")
    p.add_argument("--version")
    p.add_argument("--build-version")
    p.add_argument("--sha", default="")
    p.add_argument("--run", default="0")
    p.add_argument("--date")
    p.add_argument("--out")
    args = p.parse_args()
    if args.validate:
        with open(args.validate, encoding="utf-8") as f:
            validate(json.load(f))
        print(f"{args.validate}: valid AltStore source")
        return
    src = build(args)
    validate(src)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(src, f, indent=2)
        f.write("\n")
    print(f"wrote {args.out}")


if __name__ == "__main__":
    sys.exit(main())
