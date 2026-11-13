import importlib.util
import pathlib
import plistlib
import tempfile
import unittest
import zipfile

class IPAPackageTests(unittest.TestCase):
    def test_packaged_app_and_extension_must_match_the_release(self):
        spec = importlib.util.spec_from_file_location('verify_ipa', pathlib.Path(__file__).parents[1] / 'Tools/verify_ipa.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as folder:
            package = pathlib.Path(folder) / 'test.ipa'
            def write(extension_version):
                with zipfile.ZipFile(package, 'w') as archive:
                    for prefix, identifier, version in (
                        ('Payload/BEAT4.app', 'com.example.beat4', '0.5.7'),
                        ('Payload/BEAT4.app/PlugIns/Beat4AU.appex', 'com.example.beat4.au', extension_version)):
                        archive.writestr(prefix+'/Info.plist', plistlib.dumps({'CFBundleShortVersionString':version,'CFBundleVersion':'7','CFBundleIdentifier':identifier,'CFBundleExecutable':'binary'}))
                        archive.writestr(prefix+'/binary', b'\xcf\xfa\xed\xfe'+b'\x0c\x00\x00\x01'+bytes(24))
            write('0.5.7')
            module.verify(package, '0.5.7', '7')
            write('0.5.6')
            with self.assertRaises(ValueError):
                module.verify(package, '0.5.7', '7')

if __name__ == '__main__':
    unittest.main()
