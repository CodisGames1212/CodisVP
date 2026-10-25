"""Prepare source, relinking ZIPs, checksums and notes for a validated CI build."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

tag = os.environ['RELEASE_TAG']
commit = os.environ['SOURCE_COMMIT']
run = json.loads(Path('build-run.json').read_text())
dist = Path('dist')
expected = {
    'linux-arm64', 'linux-x86_64', 'macos-arm64', 'macos-x86_64',
    'android-arm64', 'android-x86_64', 'ios-arm64',
}
kits = Path('build-release/relink')
assert {p.name.removeprefix('relink-') for p in kits.iterdir() if p.is_dir()} == expected
for platform in sorted(expected):
    kit = kits / ('relink-' + platform)
    assert (kit / 'README.md').is_file() and (kit / 'source/ffmpeg.tar.xz').is_file()
    assert list((kit / 'ffmpeg').glob('*.a')) and list((kit / 'native').glob('*.a'))
    shutil.make_archive(str(dist / ('CodisVP-relink-' + platform)), 'zip', kit)
subprocess.run([
    'git', 'archive', '--format=zip', '--prefix=CodisVP-' + tag + '/',
    '--output=' + str(dist / ('CodisVP-' + tag + '-source.zip')), commit,
], check=True)
(dist / 'BUILD_INFO.json').write_text(json.dumps({
    'tag': tag, 'source_commit': commit, 'build_run': run['html_url'],
    'godot_api': '4.3', 'windows_ffmpeg': '8.1 shared SDK',
    'other_platforms_ffmpeg': '8.0.1 static',
}, indent=2) + '\n')
checksums = []
for path in sorted(dist.iterdir()):
    if path.is_file() and path.name != 'SHA256SUMS.txt':
        with path.open('rb') as source:
            digest = hashlib.file_digest(source, 'sha256').hexdigest()
        checksums.append(digest + '  ' + path.name)
(dist / 'SHA256SUMS.txt').write_text('\n'.join(checksums) + '\n')
Path('build-release/release-notes.md').write_text(f'''Initial CodisVP release for Godot 4.3+.

Download **CodisVP.zip** and extract its `addons/codisvp` folder into your project.

Included native builds:
- Windows x86_64
- Linux x86_64 and arm64
- macOS x86_64 and arm64
- Android arm64 and x86_64 (API 24+)
- iOS arm64 framework (iOS 13+, unsigned)

All eight build jobs and packaging passed in [the build run]({run['html_url']}).
The release step also checks the actual PE, ELF and Mach-O architecture headers.
Source commit: `{commit}`.

Windows playback has been tested; other platforms have compilation validation.
Apple distribution requires your own signing and export/device testing.
Web and 32-bit builds are not included.

The source ZIP matches these binaries. Matching `CodisVP-relink-*.zip` assets
contain FFmpeg source, static archives, extension objects and relinking instructions.
Preserve these materials when redistributing static builds. Windows FFmpeg SDK
metadata and third-party notices are included in the add-on. SHA-256 checksums
and build provenance are attached separately.
''')
print('Prepared', len(list(dist.iterdir())), 'release assets')
