"""Inspect actual compiled iOS app/extension resources, not just source membership."""
import argparse
import plistlib
import zipfile
from verify_ipa import verify


def verify_icons(package):
    with zipfile.ZipFile(package) as archive:
        for prefix in ('Payload/BEAT4.app', 'Payload/BEAT4.app/PlugIns/Beat4AU.appex'):
            info = plistlib.loads(archive.read(prefix + '/Info.plist'))
            if info['CFBundleShortVersionString'] == '0.5.27':
                fallback = 'BEAT4PrimaryIcon.png'
                if info.get('CFBundleIconFile') != fallback or fallback not in info.get('CFBundleIconFiles', []):
                    raise ValueError(f'{prefix}: missing standalone icon declarations')
                if not archive.read(prefix + '/' + fallback).startswith(b'\x89PNG\r\n\x1a\n'):
                    raise ValueError(f'{prefix}: missing or invalid standalone icon')
            for key in ('CFBundleIcons', 'CFBundleIcons~ipad'):
                primary = info.get(key, {}).get('CFBundlePrimaryIcon', {})
                if primary.get('CFBundleIconName') != 'AppIcon':
                    raise ValueError(f'{prefix}: missing compiled {key}/AppIcon declaration')
                files = primary.get('CFBundleIconFiles', [])
                if not files:
                    raise ValueError(f'{prefix}: missing compiled icon file names')
                for filename in files:
                    matches = [n for n in archive.namelist()
                               if n.startswith(prefix + '/' + filename)
                               and n.endswith('.png') and '/' not in n[len(prefix) + 1:]]
                    if not matches:
                        raise ValueError(f'{prefix}: declared icon {filename} absent')
                    if not all(archive.read(n).startswith(b'\x89PNG\r\n\x1a\n') for n in matches):
                        raise ValueError(f'{prefix}: invalid PNG icon')
            if len(archive.read(prefix + '/Assets.car')) < 100:
                raise ValueError(f'{prefix}: empty compiled asset catalog')
        ext = plistlib.loads(archive.read('Payload/BEAT4.app/PlugIns/Beat4AU.appex/Info.plist'))
        extension = ext['NSExtension']
        assert extension['NSExtensionPointIdentifier'] == 'com.apple.AudioUnit-UI'
        assert extension['NSExtensionPrincipalClass'] == 'Beat4ViewController'
        component, = extension['NSExtensionAttributes']['AudioComponents']
        for key, expected in {'manufacturer': 'B4MT', 'type': 'aumu', 'subtype': 'bt04', 'version': 1}.items():
            if component[key] != expected:
                raise ValueError(f'AUv3 identity changed: {key}')
    print('ICON PASS: both compiled targets contain iPhone/iPad icons and Assets.car; AUv3 identity preserved')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('package')
    parser.add_argument('--version', required=True)
    parser.add_argument('--build', required=True)
    args = parser.parse_args()
    verify(args.package, args.version, args.build)
    verify_icons(args.package)