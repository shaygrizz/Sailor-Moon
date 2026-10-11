"""Fetch only the two Web entries from the official Godot template ZIP via HTTP Range."""
import io
import os
import time
import urllib.request
import zipfile
import argparse
from pathlib import Path

URL = 'https://github.com/godotengine/godot-builds/releases/download/4.5.2-stable/Godot_v4.5.2-stable_export_templates.tpz'

class RemoteZip(io.RawIOBase):
    def __init__(self):
        request = urllib.request.Request(URL, headers={'Range': 'bytes=0-0'})
        with urllib.request.urlopen(request, timeout=60) as response:
            if response.status != 206:
                raise RuntimeError('Server does not support partial download')
            self.url = response.url
            self.length = int(response.headers['Content-Range'].split('/')[-1])
        self.pos = 0

    def seekable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, offset, whence=0):
        self.pos = offset if whence == 0 else self.pos + offset if whence == 1 else self.length + offset
        return self.pos

    def read(self, length=-1):
        length = min(length if length >= 0 else self.length, self.length-self.pos)
        if length <= 0:
            return b''
        parts = []
        end = self.pos + length
        while self.pos < end:
            stop = min(end, self.pos + 4*1024*1024)
            for attempt in range(4):
                try:
                    request = urllib.request.Request(self.url, headers={'Range': f'bytes={self.pos}-{stop-1}'})
                    with urllib.request.urlopen(request, timeout=60) as response:
                        if response.status != 206:
                            raise RuntimeError('Range not honored')
                        block = response.read()
                    if len(block) != stop-self.pos:
                        raise IOError('Incomplete range')
                    parts.append(block)
                    self.pos = stop
                    break
                except Exception:
                    if attempt == 3:
                        raise
                    time.sleep(1)
        return b''.join(parts)

destination = Path(os.environ['APPDATA']) / 'Godot/export_templates/4.5.2.stable'
destination.mkdir(parents=True, exist_ok=True)
parser = argparse.ArgumentParser()
parser.add_argument('--target', choices=['web', 'windows'], default='web')
args = parser.parse_args()
suffixes = ('windows_release_x86_64.exe', 'windows_debug_x86_64.exe') if args.target == 'windows' else ('web_nothreads_release.zip', 'web_nothreads_debug.zip')
with zipfile.ZipFile(RemoteZip()) as archive:
    names = [n for n in archive.namelist() if n.endswith(suffixes)]
    if len(names) != 2:
        raise RuntimeError(f'Unexpected template entries: {names}')
    for name in names:
        print('Downloading', name, flush=True)
        (destination / Path(name).name).write_bytes(archive.read(name))
        print('Installed', Path(name).name, flush=True)
