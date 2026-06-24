#!/usr/bin/env python3
"""
fix-tables.sh — Hugo 빌드 전 깨진 테이블 구분자 자동 수정

배포 스크립트에서 Hugo 실행 직전에 호출:
    cd rap-hugo && ./fix-tables.sh

content/posts/*/index.md 의 깨진 표 구분자(|--||----| 등)를
헤더 열 개수에 맞춰 |---|---|---| 형태로 교정합니다.
"""
import glob
import os
import sys


def fix_file(filepath: str) -> bool:
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    modified = False
    new_lines = []

    for i, line in enumerate(lines):
        stripped = line.strip()
        # Must be a table-like line
        if not stripped.startswith('|') or not stripped.endswith('|'):
            new_lines.append(line)
            continue

        inner = stripped[1:-1]
        # Check if it looks like a (possibly broken) separator
        chars = set(inner.replace(' ', ''))
        if not chars.issubset({'|', '-'}):
            new_lines.append(line)
            continue
        if '||' not in inner and inner.count('|') < 2:
            new_lines.append(line)
            continue

        # Look back for header row
        prev_idx = i - 1
        while prev_idx >= 0:
            ps = lines[prev_idx].strip()
            if ps:
                break
            prev_idx -= 1

        if prev_idx < 0:
            new_lines.append(line)
            continue

        # Verify it's a header (has text content, not separators)
        ps_stripped = lines[prev_idx].strip()
        if not ps_stripped.startswith('|') or not ps_stripped.endswith('|'):
            new_lines.append(line)
            continue

        pchars = set(ps_stripped[1:-1].replace(' ', ''))
        if pchars.issubset({'|', '-'}):
            new_lines.append(line)
            continue

        # Count columns from header
        header_parts = [p.strip() for p in ps_stripped.split('|')]
        n_cols = len([p for p in header_parts if p])
        if n_cols <= 0:
            new_lines.append(line)
            continue

        # Generate correct separator
        correct = '|' + '|'.join(['---'] * n_cols) + '|'
        if line.endswith('\r\n'):
            new_lines.append(correct + '\r\n')
        elif line.endswith('\n'):
            new_lines.append(correct + '\n')
        else:
            new_lines.append(correct)

        modified = True
        slug = os.path.basename(os.path.dirname(filepath))
        print(f'  🔧 {slug}: {stripped} -> {correct}')

    if modified:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        return True
    return False


def main():
    posts_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'content', 'posts')
    if not os.path.isdir(posts_dir):
        print(f'❌ content/posts/ 디렉토리를 찾을 수 없습니다: {posts_dir}')
        sys.exit(1)

    pattern = os.path.join(posts_dir, '**', 'index.md')
    files = glob.glob(pattern, recursive=True)

    fixed = 0
    for fpath in sorted(files):
        with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        if '||' not in content:
            continue

        # Only scan files where || appears in a table context
        has_broken = False
        for line in content.split('\n'):
            s = line.strip()
            if s.startswith('|') and '||' in s:
                has_broken = True
                break
        if not has_broken:
            continue

        if fix_file(fpath):
            fixed += 1

    if fixed > 0:
        print(f'  ✅ {fixed}개 파일의 깨진 표 수정 완료')
    else:
        print(f'  ℹ️  깨진 표 없음 (정상)')

    return 0


if __name__ == '__main__':
    sys.exit(main())
