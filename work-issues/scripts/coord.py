#!/usr/bin/env python3
"""Atomic JSON update under a shared lock: coord.py FILE EXPR --lock LOCK."""
import argparse
import fcntl
import json
import os
import tempfile
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('file', type=Path)
    parser.add_argument('expression', help='Trusted local Python mutating d; never use issue text')
    parser.add_argument('--lock', required=True, type=Path)
    args = parser.parse_args()
    with args.lock.open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        data = json.loads(args.file.read_text()) if args.file.exists() else None
        namespace = {'d': data}
        exec(args.expression, namespace)
        fd, temporary = tempfile.mkstemp(dir=args.file.parent)
        try:
            with os.fdopen(fd, 'w') as output:
                json.dump(namespace['d'], output, indent=2)
                output.write('\n')
            os.replace(temporary, args.file)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)


if __name__ == '__main__':
    main()
