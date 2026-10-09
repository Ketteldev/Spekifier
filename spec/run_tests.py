"""Run all mocked suites and validate release contents. Requires Python + lupa.
Usage: python spec/run_tests.py [--package output.zip]
Lua-only users can run each listed spec/**/*.lua suite directly from the root.
"""
import argparse
import os
from pathlib import Path
import zipfile
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src"
SUITES = (
    'Modules/Context/AutoShow.lua',
    'Modules/Loot/Provider.lua',
    'UI/Window/LootBinding.lua',
    'UI/Loot/Renderer.lua',
    'UI/Loot/SharedRow.lua',
    'Modules/Loot/Selection.lua',
    'UI/Options/Panel.lua',
    'Integration.lua',
    'Modules/Context/AutoShowPreferences.lua',
    'UI/Skins/Presentation.lua',
    'Manifest.lua',
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', type=Path)
    args = parser.parse_args()
    if args.package:
        args.package = args.package.resolve()
    os.chdir(ROOT)
    manifest = SOURCE / 'Spekifier.toc'
    runtime = [line.strip().replace('\\', '/') for line in manifest.read_text().splitlines()
               if line.strip().endswith('.lua')]
    expected = [
        'Core/Init.lua',
        'Core/Database.lua',
        'Core/Debug.lua',
        'Core/Events.lua',
        'Modules/Context/RaidCatalog.lua',
        'Modules/Context/Resolver.lua',
        'Modules/Loot/Model.lua',
        'Modules/Loot/Provider.lua',
        'Modules/Loot/Journal.lua',
        'Modules/Loot/Events.lua',
        'Modules/Loot/Selection.lua',
        'Modules/Loot/RequestIdentity.lua',
        'Modules/Loot/Diagnostics.lua',
        'UI/Skins/Registry.lua',
        'UI/Skins/Palettes.lua',
        'UI/Skins/Presentation.lua',
        'UI/Options/SkinDropdown.lua',
        'UI/Options/Panel.lua',
        'UI/Minimap.lua',
        'UI/Window/Lifecycle.lua',
        'UI/Window/LootBinding.lua',
        'UI/Window/Fit.lua',
        'UI/Window/Layout.lua',
        'UI/Loot/Tooltips.lua',
        'UI/Loot/DisplayLists.lua',
        'UI/Loot/SharedRow.lua',
        'UI/Loot/ItemRows.lua',
        'UI/Loot/Columns.lua',
        'UI/Loot/Renderer.lua',
        'Modules/Commands.lua',
        'Modules/Context/AutoShow.lua',
    ]
    assert runtime == expected, 'Unexpected final manifest load order'
    actual = {p.relative_to(SOURCE).as_posix() for folder in ('Core', 'Modules', 'UI')
              for p in (SOURCE / folder).rglob('*.lua')}
    assert set(runtime) == actual, 'Missing or unregistered runtime file'
    compile_lua = LuaRuntime().eval('function(s,n) local f,e=loadstring(s,n); assert(f,e) end')
    for path in [*SOURCE.rglob('*.lua'), *(ROOT / 'spec').rglob('*.lua')]:
        compile_lua(path.read_text(encoding='utf-8-sig'), str(path))
    for name in SUITES:
        print('Running ' + name, flush=True)
        LuaRuntime().execute("dofile('spec/" + name + "')")
    print('All suites, Lua 5.1 syntax and final manifest checks passed.', flush=True)
    if args.package:
        output = args.package.resolve()
        if output == SOURCE or SOURCE in output.parents:
            parser.error('Package output must be outside src/')
        output.parent.mkdir(parents=True, exist_ok=True)
        contents = sorted(p.relative_to(SOURCE).as_posix()
                          for p in SOURCE.rglob('*') if p.is_file())
        with zipfile.ZipFile(args.package, 'w', zipfile.ZIP_DEFLATED) as archive:
            for name in contents:
                archive.write(SOURCE / name, 'Spekifier/' + name)
        with zipfile.ZipFile(args.package) as archive:
            assert archive.testzip() is None
            assert set(archive.namelist()) == {'Spekifier/' + name for name in contents}
            for name in contents:
                assert archive.read('Spekifier/' + name) == (SOURCE / name).read_bytes()
        print('Verified clean-install candidate: ' + str(args.package.resolve()))


if __name__ == '__main__':
    main()
