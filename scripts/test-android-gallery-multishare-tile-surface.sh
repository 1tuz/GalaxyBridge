#!/bin/sh
# Verify Direct/Internal-only gallery + multi-share, and shared Quick Settings tile.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ANDROID="$ROOT/android"
cd "$ANDROID"

./gradlew --console=plain \
  :app:processInternalDebugManifest \
  :app:processDirectDebugManifest \
  :app:processPlayDebugManifest \
  :app:testDirectDebugUnitTest --tests '*FileSendPolicyTest' \
  :app:testInternalDebugUnitTest --tests '*FileSendPolicyTest' \
  :app:testPlayDebugUnitTest --tests '*FileSendPolicyTest'

python3 - <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET

android = '{http://schemas.android.com/apk/res/android}'

def manifest(flavor: str) -> Path:
    variant = flavor + 'Debug'
    title = variant[0].upper() + variant[1:]
    return (
        Path('app/build/intermediates/merged_manifests')
        / variant
        / ('process' + title + 'Manifest')
        / 'AndroidManifest.xml'
    )

def names(root, tag: str):
    app = root.find('application')
    return [e.get(android + 'name', '') for e in app.findall(tag)]

for flavor in ('internal', 'direct', 'play'):
    root = ET.parse(manifest(flavor)).getroot()
    activities = names(root, 'activity')
    receivers = names(root, 'receiver')
    services = names(root, 'service')
    permissions = {
        e.get(android + 'name')
        for e in root.findall('uses-permission')
    }

    has_gallery_activity = any(n.endswith('.gallery.GalleryPermissionActivity') for n in activities)
    has_gallery_receiver = any(n.endswith('.gallery.GalleryExportReceiver') for n in receivers)
    has_tile = any(n.endswith('.service.GalaxyBridgeTileService') for n in services)
    has_media_perm = 'android.permission.READ_MEDIA_IMAGES' in permissions

    share_actions = []
    app = root.find('application')
    for activity in app.findall('activity'):
        if not activity.get(android + 'name', '').endswith('.FileShareActivity'):
            continue
        for action in activity.findall('intent-filter/action'):
            share_actions.append(action.get(android + 'name'))

    if flavor == 'play':
        assert not has_gallery_activity, flavor
        assert not has_gallery_receiver, flavor
        assert not has_media_perm, flavor
        assert share_actions == [], flavor
    else:
        assert has_gallery_activity, flavor
        assert has_gallery_receiver, flavor
        assert has_media_perm, flavor
        assert share_actions == [
            'android.intent.action.SEND',
            'android.intent.action.SEND_MULTIPLE',
        ], (flavor, share_actions)

    assert has_tile, f'{flavor} must expose GalaxyBridgeTileService'
    print('PASS', flavor, 'gallery/multishare/tile surface')
PY

echo "Android gallery / multishare / tile surface passed"
