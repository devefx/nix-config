#!/usr/bin/env python3
"""Turn a Breath of the Wild dump into the folder Savage Wind Recomp sets up from.

    provision.py --base GAME.xci --update UPDATE.nsp --keys prod.keys \
                 --hactool PATH --out DIR --work DIR

Steps, each skipped when its output is already there:

1. ExeFS of the 1.9.0 update (the only version Savage Wind supports).
2. RomFS: hactool merges the base Program NCA with the update's BKTR section.
3. Split that image into the file tree Savage Wind reads.

The recompilation itself is not done here: `swgen` and `zig` come from the
release, and the build is driven by the module's provisioner.
"""
import argparse
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from extract_exefs import (common_tickets, container_entries, load_keys,  # noqa: E402
                           nca_inventory, program_nca, record_offset, require)
from extract_romfs import index_romfs  # noqa: E402
from extract_update_romfs import copy_range, hactool_prod_keys  # noqa: E402


def program_records(source, keys, *, update):
    with source.open('rb') as f:
        kind, entries = container_entries(f, source.stat().st_size)
        require(not update or kind == 'nsp', 'The update must be an NSP')
        tickets = common_tickets(f, entries)
        record, header = program_nca(nca_inventory(f, entries, keys), update=update)
    return record, header, tickets


def extract_exefs(update_nsp, keys_path, out):
    if (out / 'main').is_file():
        print('exefs: already extracted', flush=True)
        return
    print('exefs: extracting the 1.9.0 modules', flush=True)
    script = Path(__file__).with_name('extract_exefs.py')
    subprocess.run(
        [sys.executable, str(script), str(update_nsp), '--keys', str(keys_path),
         '--update', '--output', str(out)],
        check=True,
    )


def merge_romfs(base, update_nsp, keys_path, hactool, out, work):
    image = out.parent / (out.name + '.bin')
    if image.is_file():
        print(f'romfs: {image.name} already merged', flush=True)
        return image
    if out.is_dir() and any(out.iterdir()):
        # The tree survives the image, so a resume finds it without one.
        print('romfs: already split, no image needed', flush=True)
        return None

    print('romfs: reading the two Program NCAs', flush=True)
    keys = load_keys(keys_path)
    base_record, _, _ = program_records(base, keys, update=False)
    upd_record, upd_header, tickets = program_records(update_nsp, keys, update=True)
    sections = [i for i in range(4) if upd_header[0x400 + i * 512 + 4] == 4]
    require(len(sections) == 1, 'Expected exactly one BKTR section')

    work.mkdir(parents=True, exist_ok=True)
    title_keys = work / 'title.keys'
    title_keys.write_text(''.join(f'{r.hex()} = {k.hex()}\n' for r, k in tickets.items()))
    title_keys.chmod(0o600)
    hactool_keys = work / 'hactool.keys'
    if not hactool_keys.exists():
        hactool_prod_keys(keys_path, hactool_keys)

    # hactool's --basenca wants a standalone NCA. The MNG_BASE_RANGE_* hint the
    # TotK toolchain uses assumes the TotK XCI layout, which Breath of the Wild
    # does not share; extracting the NCA avoids that entirely.
    base_nca = work / 'base.nca'
    if not base_nca.exists():
        print(f'romfs: extracting the base Program NCA '
              f'({base_record["size"] / 2**30:.1f} GiB)', flush=True)
        copy_range(base, record_offset(base_record), base_record['size'], base_nca)

    update_nca = work / 'update.nca'
    if not update_nca.exists():
        copy_range(update_nsp, record_offset(upd_record), upd_record['size'], update_nca)

    print(f'romfs: merging (BKTR section {sections[0]})', flush=True)
    image.parent.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, MNG_TITLE_KEYS=str(title_keys))
    log = subprocess.run(
        [str(hactool), '-x', '-y', '--disablekeywarns', '--suppresskeys',
         '-k', str(hactool_keys), f'--basenca={base_nca}',
         f'--section{sections[0]}={image}', str(update_nca)],
        env=env, capture_output=True, text=True,
    )
    (work / 'merge.log').write_text(log.stdout + log.stderr)
    require(log.returncode == 0, f'hactool failed, see {work / "merge.log"}')
    require(all(f'Level {i} (GOOD)' in log.stdout for i in range(6)),
            'hactool did not verify all six IVFC levels')
    print(f'romfs: merged {image.stat().st_size / 2**30:.1f} GiB', flush=True)
    return image


def split_romfs(image, out):
    if out.is_dir() and any(out.iterdir()):
        print('romfs: already split', flush=True)
        return
    print('romfs: splitting into the file tree', flush=True)
    files = index_romfs(image)
    print(f'romfs: {len(files)} files', flush=True)
    out.mkdir(parents=True, exist_ok=True)
    with image.open('rb') as f:
        for i, e in enumerate(files):
            target = out / e['path']
            target.parent.mkdir(parents=True, exist_ok=True)
            f.seek(e['offset'])
            left = e['size']
            with target.open('wb') as o:
                while left:
                    chunk = f.read(min(left, 1 << 22))
                    require(bool(chunk), f'truncated: {e["path"]}')
                    o.write(chunk)
                    left -= len(chunk)
            if (i + 1) % 50000 == 0:
                print(f'  {i + 1}/{len(files)}', flush=True)
    print(f'romfs: {len(files)} files written', flush=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--base', required=True, type=Path, help='base game, XCI or NSP')
    ap.add_argument('--update', required=True, type=Path, help='the 1.9.0 update NSP')
    ap.add_argument('--keys', required=True, type=Path, help='prod.keys')
    ap.add_argument('--hactool', required=True, type=Path, help='hactool with the BKTR patches')
    ap.add_argument('--out', required=True, type=Path, help='folder for exefs/ and romfs/')
    ap.add_argument('--work', required=True, type=Path, help='scratch folder, kept for resumes')
    ap.add_argument('--base-id', default='01007EF00011E000',
                    help='base title id (default: Breath of the Wild)')
    ap.add_argument('--update-id', default='01007EF00011E800',
                    help='update title id (default: Breath of the Wild)')
    ap.add_argument('--keep-image', action='store_true',
                    help='keep romfs.bin next to the tree (debugging; 14 GiB)')
    args = ap.parse_args()
    os.environ['SW_BASE_ID'] = args.base_id
    os.environ['SW_UPDATE_ID'] = args.update_id

    args.out.mkdir(parents=True, exist_ok=True)
    extract_exefs(args.update, args.keys, args.out / 'exefs')
    image = merge_romfs(args.base, args.update, args.keys, args.hactool,
                        args.out / 'romfs', args.work)
    if image is not None:
        split_romfs(image, args.out / 'romfs')
        if not args.keep_image:
            image.unlink()
            print(f'romfs: removed {image.name} (the tree is what the game reads)', flush=True)
    print('provision: game files ready in ' + str(args.out), flush=True)


if __name__ == '__main__':
    main()
