"""Verify the same unsigned app/extension IPA layout used for V0.5.6 delivery."""
import argparse
import hashlib
import plistlib
import zipfile


def verify(package, version, build):
    with zipfile.ZipFile(package) as archive:
        if archive.testzip() is not None:
            raise ValueError('IPA ZIP integrity failure')
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError('Duplicate entries in IPA')
        for prefix, identifier in (
            ('Payload/BEAT4.app', 'com.example.beat4'),
            ('Payload/BEAT4.app/PlugIns/Beat4AU.appex', 'com.example.beat4.au'),
        ):
            info = plistlib.loads(archive.read(prefix + '/Info.plist'))
            expected = {'CFBundleShortVersionString':version, 'CFBundleVersion':build,
                        'CFBundleIdentifier':identifier}
            for key, value in expected.items():
                if info.get(key) != value:
                    raise ValueError(f'{prefix}: {key} is {info.get(key)!r}, expected {value!r}')
            executable = info.get('CFBundleExecutable', '')
            if not executable or '/' in executable:
                raise ValueError(f'{prefix}: invalid executable name')
            binary = archive.read(prefix + '/' + executable)
            if binary[:8] != b'\xcf\xfa\xed\xfe\x0c\x00\x00\x01':
                raise ValueError(f'{prefix}: expected arm64 Mach-O executable')
    print(f'IPA PASS: application and AUv3 extension {version} build {build}, identifiers and arm64 binaries')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('package')
    parser.add_argument('--version', required=True)
    parser.add_argument('--build', required=True)
    args = parser.parse_args()
    verify(args.package, args.version, args.build)
    with open(args.package, 'rb') as stream:
        print('SHA256', hashlib.sha256(stream.read()).hexdigest())
