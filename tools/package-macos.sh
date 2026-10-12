#!/bin/sh
# Publish a self-contained Apple Silicon app and a drag-to-Applications DMG.
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${1:-"$repo_dir/publish/macos"}
mkdir -p "$output_dir"
output_dir=$(CDPATH= cd -- "$output_dir" && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/HoianViewer-package.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

dotnet publish "$repo_dir/PlayerViewer/PlayerViewer.csproj" \
    -c Release -r osx-arm64 --self-contained true -p:PublishSingleFile=true \
    -p:IncludeNativeLibrariesForSelfExtract=false \
    -o "$work_dir/publish"

app="$work_dir/image/HoianViewer.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
# Resources stay beside the managed host, outside the bundle's executable directory.
ditto "$work_dir/publish" "$app/Contents/Resources/runtime"
chmod +x "$app/Contents/Resources/runtime/PlayerViewer" "$app/Contents/Resources/runtime/uberslicer"
clang -arch arm64 -mmacosx-version-min=12.0 -O2 "$repo_dir/tools/macos-launcher.c" \
    -o "$app/Contents/MacOS/HoianViewer"

# Check every native binary, deriving the true minimum OS from the build inputs.
python3 - "$app" <<'PY'
import pathlib, plistlib, re, shutil, subprocess, sys
app = pathlib.Path(sys.argv[1])
native_dir = app / 'Contents/Resources/runtime'
minimum = (12, 0)
pending = list(sorted(native_dir.rglob('*'))) + [app / 'Contents/MacOS/HoianViewer']
origins = {}
visited = set()
while pending:
    path = pending.pop(0)
    if path in visited:
        continue
    visited.add(path)
    if not path.is_file():
        continue
    description = subprocess.check_output(['file', '-b', str(path)], text=True)
    if 'Mach-O' not in description:
        continue
    if 'arm64' not in description:
        raise SystemExit(f'Not an Apple Silicon binary: {path}')
    build = subprocess.check_output(['vtool', '-show-build', str(path)], text=True)
    for version in re.findall(r'\bminos\s+([\d.]+)', build):
        minimum = max(minimum, tuple(map(int, version.split('.'))))
    identity = subprocess.check_output(['otool', '-D', str(path)], text=True).splitlines()[1:]
    dependencies = subprocess.check_output(['otool', '-L', str(path)], text=True)
    for line in dependencies.splitlines()[1:]:
        dependency = line.strip().split(' (')[0]
        if dependency in identity:
            continue
        if dependency.startswith(('/opt/homebrew/', '@rpath/', '@loader_path/', '@executable_path/')):
            target = native_dir / pathlib.Path(dependency).name
            source = (pathlib.Path(dependency) if dependency.startswith('/opt/homebrew/') else
                      origins.get(path, path).parent / pathlib.Path(dependency).name)
            if not target.exists():
                if not source.is_file():
                    raise SystemExit(f'Cannot resolve {dependency} used by {path.name}')
                shutil.copy2(source, target)
                origins[target] = source
                pending.append(target)
                license_path = source.parent.parent / 'LICENSE'
                if license_path.is_file():
                    license_dir = native_dir / 'Licenses'
                    license_dir.mkdir(exist_ok=True)
                    shutil.copy2(license_path, license_dir / ('LICENSE.' + source.parent.parent.name))
            elif source != target and source.is_file() and target.read_bytes() != source.read_bytes() and target not in visited:
                raise SystemExit(f'Conflicting native library: {target.name}')
            subprocess.run(['install_name_tool', '-change', dependency,
                            '@loader_path/' + target.name, str(path)], check=True)
        elif not dependency.startswith(('/System/', '/usr/lib/', '@')):
            raise SystemExit(f'External dependency in {path.name}: {dependency}')
    # IDs are not dependency edges, but should not retain build-machine paths.
    if path.suffix == '.dylib' or path.name == 'SDL2.dll':
        subprocess.run(['install_name_tool', '-id', '@loader_path/' + path.name, str(path)], check=True)
    subprocess.run(['codesign', '--force', '--sign', '-', str(path)], check=True)
info = dict(CFBundleName='HoianViewer', CFBundleDisplayName='HoianViewer',
            CFBundleIdentifier='org.space4yyy.hoianviewer', CFBundleExecutable='HoianViewer',
            CFBundlePackageType='APPL', CFBundleShortVersionString='1.0.0', CFBundleVersion='1',
            LSMinimumSystemVersion='.'.join(map(str, minimum)), NSHighResolutionCapable=True)
with (app / 'Contents/Info.plist').open('wb') as stream:
    plistlib.dump(info, stream)
print('Minimum macOS version:', info['LSMinimumSystemVersion'])
PY
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
plutil -lint "$app/Contents/Info.plist"
ln -s /Applications "$work_dir/image/Applications"
hdiutil create -volname HoianViewer -srcfolder "$work_dir/image" \
    -format UDZO -ov "$work_dir/HoianViewer-macos-arm64.dmg"
hdiutil verify "$work_dir/HoianViewer-macos-arm64.dmg"
# Only replace the generated output after publishing and verification succeed.
if [ -e "$output_dir/HoianViewer.app" ]; then
    rm -rf "$output_dir/HoianViewer.app"
fi
ditto "$app" "$output_dir/HoianViewer.app"
cp "$work_dir/HoianViewer-macos-arm64.dmg" "$output_dir/HoianViewer-macos-arm64.dmg"
printf 'App: %s\nDMG: %s\n' "$output_dir/HoianViewer.app" "$output_dir/HoianViewer-macos-arm64.dmg"
