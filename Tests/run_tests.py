"""Run all mocked suites and validate release contents. Requires Python + lupa.
Usage: python Tests/run_tests.py [--package output.zip]
Lua-only users can run each listed Tests/*.lua suite directly from the root.
"""
import argparse
import os
from pathlib import Path
import zipfile
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
SUITES = ('AutoShow', 'LootProvider', 'WindowLoot', 'WindowPresentation',
          'SharedLoot', 'LootSpecialization', 'Options', 'Integration')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', type=Path)
    args = parser.parse_args()
    os.chdir(ROOT)
    manifest = ROOT / 'Spekifier.toc'
    runtime = [line.strip().replace('\\', '/') for line in manifest.read_text().splitlines()
               if line.strip().endswith('.lua')]
    expected = ['Core/Init.lua', 'Core/Database.lua', 'Core/Debug.lua', 'Core/Events.lua',
                'Modules/EncounterResolver.lua', 'Modules/LootProvider.lua',
                'Modules/LootSpecialization.lua', 'UI/Options.lua', 'UI/Minimap.lua',
                'UI/MainWindow.lua', 'UI/SpecColumns.lua', 'Modules/Commands.lua',
                'Modules/AutoShow.lua', 'Spekifier.lua']
    assert runtime == expected, 'Unexpected final manifest load order'
    actual = {p.relative_to(ROOT).as_posix() for folder in ('Core', 'Modules', 'UI')
              for p in (ROOT / folder).rglob('*.lua')} | {'Spekifier.lua'}
    assert set(runtime) == actual, 'Missing or unregistered runtime file'
    compile_lua = LuaRuntime().eval('function(s,n) local f,e=loadstring(s,n); assert(f,e) end')
    for path in ROOT.rglob('*.lua'):
        compile_lua(path.read_text(encoding='utf-8-sig'), str(path))
    for name in SUITES:
        print('Running ' + name, flush=True)
        LuaRuntime().execute("dofile('Tests/" + name + ".lua')")
    print('All suites, Lua 5.1 syntax and final manifest checks passed.', flush=True)
    if args.package:
        contents = ['Spekifier.toc', *runtime, 'README.md',
                    *sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / 'Tests').glob('*.md'))]
        with zipfile.ZipFile(args.package, 'w', zipfile.ZIP_DEFLATED) as archive:
            for name in contents:
                archive.write(ROOT / name, 'Spekifier/' + name)
        with zipfile.ZipFile(args.package) as archive:
            assert archive.testzip() is None
            assert set(archive.namelist()) == {'Spekifier/' + name for name in contents}
            for name in contents:
                assert archive.read('Spekifier/' + name) == (ROOT / name).read_bytes()
        print('Verified clean-install candidate: ' + str(args.package.resolve()))


if __name__ == '__main__':
    main()
