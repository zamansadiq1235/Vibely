import re

files = {
    'lib/features/upload/domain/entities/upload_draft.dart': [],
    'lib/features/feed/domain/entities/video_post.dart': [],
    'lib/features/feed/presentation/widgets/video_feed_item.dart': [],
    'lib/features/feed/presentation/screens/home_feed_screen.dart': [],
}

for f, _ in files.items():
    p = '/Users/zamansadiq/Desktop/clipzo/clipzo/' + f
    with open(p) as fh:
        lines = fh.readlines()
    for i, line in enumerate(lines, 1):
        # Look for word followed by ?; (stray nullable mark)
        matches = re.findall(r'\w\?;', line)
        if matches and '??' not in line.split('?;')[0]:
            print(f'{f}:{i}: STRAY_Q_SEMI: {line.rstrip()[:120]}')
        if 'feedProvider]' in line:
            print(f'{f}:{i}: BRACKET: {line.rstrip()[:120]}')

    'lib/features/upload/domain/entities/video_animation_preset.dart',
    'lib/features/upload/domain/entities/music_api_song.dart',
    'lib/features/upload/data/datasources/music_api_data_source.dart',
    'lib/features/upload/presentation/providers/music_search_provider.dart',
    'lib/features/upload/domain/entities/upload_draft.dart',
    'lib/features/feed/presentation/providers/feed_video_controller_cache.dart',
    'lib/features/feed/presentation/widgets/video_feed_item.dart',
    'lib/features/feed/domain/entities/video_post.dart',
    'lib/features/upload/presentation/widgets/music_step.dart',
    'lib/features/upload/presentation/widgets/filter_step.dart',
    'lib/features/feed/presentation/screens/home_feed_screen.dart',
]

for f in files:
    p = os.path.join(base, f)
    with open(p, 'rb') as fh:
        raw = fh.read()
    text = raw.decode('utf-8', errors='replace')
    
    # Show file size and first 5 lines with repr
    print(f'\n=== {f} ({len(text)} chars, {text.count(chr(10))} lines) ===')
    
    # Check for the specific corruption: ';;' or ');;' or missing ')' 
    lines = text.split('\n')
    for i, line in enumerate(lines, 1):
        # Check for ;; at end
        if ';;' in line:
            print(f'  LINE {i}: DOUBLE_SEMI: {repr(line[:80])}')
        # Check for ;) patterns that are wrong (should be );)
        if re.search(r'"\s*; ', line):  # unlikely
            pass
    
    # Check specific corruption: missing close paren before semicolon
    import re
    for i, line in enumerate(lines, 1):
        stripped = line.rstrip()
        opens = stripped.count('(')
        closes = stripped.count(')')
        if ';' in stripped and opens > closes and not stripped.strip().startswith('//'):
            if re.search(r'\w+\(', stripped):
                print(f'  LINE {i}: MISSING_PAREN: {stripped[:100]}')
    
    # Check for double commas
    for i, line in enumerate(lines, 1):
        if ',,' in line:
            print(f'  LINE {i}: DOUBLE_COMMA: {stripped[:100]}')
    
    # Check for control chars
    for i, line in enumerate(lines, 1):
        for ch in line:
            if ord(ch) < 32 and ch not in ('\t',):
                print(f'  LINE {i}: CONTROL_CHAR: {repr(line[:100])}')
                break
