from io import BytesIO
from pathlib import Path
import struct
import sys
from zipfile import ZipFile

archive = ZipFile(sys.argv[1])
if 'CodisVP.zip' in archive.namelist():
    archive = ZipFile(BytesIO(archive.read('CodisVP.zip')))
expected = {
    'codisvp.windows.x86_64.dll': ('pe', 0x8664),
    'codisvp.linux.x86_64.so': ('elf', 62),
    'codisvp.linux.arm64.so': ('elf', 183),
    'codisvp.android.x86_64.so': ('elf', 62),
    'codisvp.android.arm64.so': ('elf', 183),
    'codisvp.macos.x86_64.dylib': ('mach', 0x01000007),
    'codisvp.macos.arm64.dylib': ('mach', 0x0100000c),
    'codisvp.ios.arm64.framework/codisvp.ios.arm64': ('mach', 0x0100000c),
}
for name, (kind, machine) in expected.items():
    data = archive.read('addons/codisvp/bin/' + name)
    if kind == 'pe':
        assert data[:2] == b'MZ', name
        offset = struct.unpack_from('<I', data, 0x3c)[0]
        assert data[offset:offset+4] == b'PE\0\0', name
        actual = struct.unpack_from('<H', data, offset+4)[0]
    elif kind == 'elf':
        assert data[:4] == b'\x7fELF' and data[4:6] == b'\x02\x01', name
        actual = struct.unpack_from('<H', data, 18)[0]
    else:
        assert data[:4] == b'\xcf\xfa\xed\xfe', name
        actual = struct.unpack_from('<I', data, 4)[0]
    assert actual == machine, (name, hex(actual), hex(machine))
    print('Architecture verified:', name)
for name in ['LICENSE', 'README.md', 'codisvp.gdextension',
             'demo/assets/streamflow_astria.png', 'licenses/FFmpeg-LGPL-2.1.txt',
             'licenses/FFmpeg-LGPL-3.0.txt', 'licenses/godot-cpp-MIT.txt']:
    assert 'addons/codisvp/' + name in archive.namelist(), name
assert archive.testzip() is None
print('Archive integrity, all eight binary architectures, artwork and licenses verified.')
