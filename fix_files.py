#!/usr/bin/env python3
"""Fix corrupted Dart files using targeted string replacements."""
import os, re

BASE = '/Users/zamansadiq/Desktop/clipzo/clipzo'

def fix_file(relpath, fixes):
    """Apply a list of (old, new) string replacements to a file."""
    path = os.path.join(BASE, relpath)
    with open(path, 'r', encoding='utf-8') as f:
        text = f.read()
    count = 0
    for old, new in fixes:
        n = text.count(old)
        if n > 0:
            text = text.replace(old, new)
            count += n
        else:
            print(f'  WARN not found in {relpath}: {repr(old[:60])}')
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(text)
    print(f'Fixed {relpath} ({count} replacements)')

def write_file(relpath, content):
    """Overwrite a file with clean content."""
    path = os.path.join(BASE, relpath)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(content)
    print(f'Written {relpath} ({len(content)} chars)')

# === music_api_song.dart: fix double commas, ?? -> ?, stray semicolons ===
fix_file('lib/features/upload/domain/entities/music_api_song.dart', [
    (',,', ','),           # double commas everywhere
    ('String??', 'String?'),
    ('Duration??', 'Duration?'),
    (');\n     return MusicApiSong(', ')\n     return MusicApiSong('),  # stray semi
])

print("=== Done part A ===")

