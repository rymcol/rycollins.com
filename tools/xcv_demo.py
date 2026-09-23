#!/usr/bin/env python3
"""Seeds an xcv history.json with made-up items for the site screenshot.

    xcv_demo.py <store dir> <image png>

Nothing here comes from a real clipboard. Newest first; the first card is the
one the snapshot shows selected.
"""
import datetime
import json
import shutil
import sys
import uuid
from pathlib import Path

base, image = Path(sys.argv[1]), Path(sys.argv[2])
(base / "images").mkdir(parents=True, exist_ok=True)
(base / "files").mkdir(exist_ok=True)
shutil.copy(image, base / "images" / "demo.png")
dmg = base / "files" / "Percolate-1.0.dmg"
dmg.touch()

now = datetime.datetime.now(datetime.timezone.utc)


def item(kind, text, minutes_ago, bundle_id, app, **extra):
    d = {
        "id": str(uuid.uuid4()).upper(),
        "kind": kind,
        "text": text,
        "hash": str(uuid.uuid4()),
        "fileURLs": [],
        "sourceBundleID": bundle_id,
        "sourceAppName": app,
        "createdAt": (now - datetime.timedelta(minutes=minutes_ago)).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "isPinned": False,
    }
    d.update(extra)
    return d


items = [
    item("image", "", 1, "com.pixelmatorteam.pixelmator.x", "Pixelmator Pro",
         imageFile="demo.png", imageWidth=1024, imageHeight=1024, imageBytes=(base / "images" / "demo.png").stat().st_size),
    item("color", "#687C6C", 3, "com.pixelmatorteam.pixelmator.x", "Pixelmator Pro"),
    item("text", "withAnimation(.spring(response: 0.55, dampingFraction: 0.68)) {\n    model.expanded = true\n}\n"
                 "// let the island grow out of the notch", 6, "dev.zed.Zed", "Zed"),
    item("link", "https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets", 11, "com.apple.Safari", "Safari"),
    item("file", str(dmg), 26, "com.apple.finder", "Finder", fileURLs=[dmg.as_uri()]),
    item("text", "Launch checklist\nNotarize the build\nFresh screenshots for the site\nTell everyone", 48,
         "com.apple.Notes", "Notes", isPinned=True),
    item("text", "Coffee at 3?", 95, "com.apple.MobileSMS", "Messages"),
    item("link", "https://rycollins.com", 140, "com.tinyspeck.slackmacgap", "Slack"),
]
(base / "history.json").write_text(json.dumps(items, indent=1))
