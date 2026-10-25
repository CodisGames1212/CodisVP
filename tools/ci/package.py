"""Validate the merged native matrix and create an installable Godot add-on ZIP."""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[2]
ADDON = ROOT / "addons/codisvp"
EXPECTED = [
    "codisvp.windows.x86_64.dll",
    "codisvp.linux.x86_64.so", "codisvp.linux.arm64.so",
    "codisvp.macos.x86_64.dylib", "codisvp.macos.arm64.dylib",
    "codisvp.android.arm64.so", "codisvp.android.x86_64.so",
    "codisvp.ios.arm64.framework/codisvp.ios.arm64",
    "avcodec-62.dll", "avformat-62.dll", "avutil-60.dll",
    "swresample-6.dll", "swscale-9.dll",
]


def main():
    missing = [name for name in EXPECTED if not (ADDON / "bin" / name).is_file()]
    if missing:
        raise SystemExit("Missing build outputs: " + ", ".join(missing))
    destination = ROOT / "dist/CodisVP.zip"
    destination.parent.mkdir(exist_ok=True)
    with ZipFile(destination, "w", ZIP_DEFLATED) as archive:
        for path in sorted(ADDON.rglob("*")):
            if path.is_file() and path.suffix not in {".lib", ".exp", ".pdb", ".import", ".uid"} and path.name != ".gitkeep":
                archive.write(path, path.relative_to(ROOT))
    print(destination)


if __name__ == "__main__":
    main()
