"""Build the distributable source archive without runtime state or credentials."""
import hashlib
import json
import os
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'artifacts' / 'linan-source.zip'
EXCLUDED_PARTS = {
    '.git', '.venv', 'node_modules', '__pycache__', '.pytest_cache',
    'runtime', 'raw', 'recordings', 'artifacts', '.cache', '.pnpm-store',
    '.dart_tool', '.gradle', 'ephemeral', '.idea',
}

# Keep only runnable Flutter artifacts; skip Gradle/CMake intermediates.
BUILD_ALLOWLIST = (
    ('windows', 'x64', 'runner', 'Release'),
    ('app', 'outputs', 'flutter-apk', 'app-release.apk'),
)
SENSITIVE_NAMES = {'credentials', 'credentials.json', 'token.json', 'tokens.json', 'secrets.json', 'server.json', 'local.properties'}
SENSITIVE_SUFFIXES = {'.db', '.sqlite', '.sqlite3', '.pem', '.key', '.pfx', '.p12', '.pyc', '.log', '.symbols'}


def distributable(path):
    relative = path.relative_to(ROOT)
    name = path.name.lower()
    if not (
        path.is_file() and not path.is_symlink()
        and not EXCLUDED_PARTS.intersection(relative.parts)
        and name not in SENSITIVE_NAMES
        and path.suffix.lower() not in SENSITIVE_SUFFIXES
        and not name.endswith(('-wal', '-shm', '-journal', '.iml'))
        and not (name.startswith('.env') and not name.endswith(('.example', '.sample')))
    ):
        return False
    parts = relative.parts
    if parts[:2] == ('app', 'build'):
        tail = parts[2:]
        return any(tail[:len(prefix)] == prefix for prefix in BUILD_ALLOWLIST)
    return 'build' not in parts


def main():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    files = []
    for folder, directories, names in os.walk(ROOT, followlinks=False):
        directories[:] = sorted(d for d in directories if d not in EXCLUDED_PARTS
                                and not (Path(folder) / d).is_symlink()
                                and not (Path(folder) / d).is_junction())
        files.extend(p for p in (Path(folder) / name for name in sorted(names)) if distributable(p))
    entries = []
    with zipfile.ZipFile(OUTPUT, 'w', zipfile.ZIP_DEFLATED, compresslevel=7) as archive:
        for path in files:
            relative = path.relative_to(ROOT).as_posix()
            content = path.read_bytes()
            archive.writestr('linan/' + relative, content)
            entries.append({'path': relative, 'bytes': len(content), 'sha256': hashlib.sha256(content).hexdigest()})
    manifest = {'archive': OUTPUT.name, 'sha256': hashlib.sha256(OUTPUT.read_bytes()).hexdigest(), 'files': entries}
    OUTPUT.with_suffix('.manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'{OUTPUT}\n{len(entries)} files; SHA256 {manifest["sha256"]}')


if __name__ == '__main__':
    main()
