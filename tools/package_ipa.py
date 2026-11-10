"""Package an actual arm64 iPhone app, never fabricate an IPA from source."""
from pathlib import Path
import plistlib
import struct
import sys
import zipfile

app, output = map(Path, sys.argv[1:])
with (app / 'Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
assert info['CFBundlePackageType'] == 'APPL'
assert info.get('CFBundleSupportedPlatforms') == ['iPhoneOS'], 'Device build required'
executable = app / info['CFBundleExecutable']
header = executable.read_bytes()[:12]
assert len(header) == 12 and struct.unpack('<I', header[:4])[0] == 0xFEEDFACF, 'Mach-O required'
assert struct.unpack('<I', header[4:8])[0] == 0x0100000C, 'arm64 required'
assert not (app / '_CodeSignature').exists(), 'App must be unsigned'
output.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(app.rglob('*')):
        if path.is_file():
            archive.write(path, Path('Payload') / app.name / path.relative_to(app))
print(output)
