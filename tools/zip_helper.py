#!/usr/bin/env python3
import sys
import os
import zipfile
import fnmatch

def matches_any(path, patterns):
    path = path.replace('\\', '/')
    for pat in patterns:
        pat = pat.replace('\\', '/')
        # Support simple wildcard matching
        if fnmatch.fnmatch(path, pat) or any(fnmatch.fnmatch(part, pat) for part in path.split('/')):
            return True
        if pat.endswith('/*'):
            prefix = pat[:-2]
            if path.startswith(prefix + '/'):
                return True
    return False

def run_zip(args):
    # Expecting: [-r] <zip_path> <inputs...> [-x <excludes...>]
    if '-r' in args:
        args.remove('-r')
    
    if not args:
        print("Error: No zip file specified", file=sys.stderr)
        sys.exit(1)
        
    zip_path = args[0]
    inputs = []
    excludes = []
    
    i = 1
    in_exclude = False
    while i < len(args):
        arg = args[i]
        if arg == '-x':
            in_exclude = True
        elif in_exclude:
            excludes.append(arg)
        else:
            inputs.append(arg)
        i += 1
        
    # Ensure parent directory of zip file exists
    parent_dir = os.path.dirname(zip_path)
    if parent_dir and not os.path.exists(parent_dir):
        os.makedirs(parent_dir, exist_ok=True)
        
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as z:
        for inp in inputs:
            if not os.path.exists(inp):
                continue
            if os.path.isdir(inp):
                for root, dirs, files in os.walk(inp):
                    for file in files:
                        full_path = os.path.join(root, file)
                        rel_path = os.path.relpath(full_path, start=os.getcwd())
                        rel_path = rel_path.replace('\\', '/')
                        if not matches_any(rel_path, excludes):
                            z.write(full_path, rel_path)
            else:
                rel_path = inp.replace('\\', '/')
                if not matches_any(rel_path, excludes):
                    z.write(inp, rel_path)
    print(f"Built (Python fallback): {zip_path}")

def run_unzip(args):
    # Expecting: [-l] <zip_path>
    if '-l' in args:
        args.remove('-l')
    if not args:
        print("Error: No zip file specified", file=sys.stderr)
        sys.exit(1)
        
    zip_path = args[0]
    if not os.path.exists(zip_path):
        print(f"Error: {zip_path} not found", file=sys.stderr)
        sys.exit(1)
        
    with zipfile.ZipFile(zip_path, 'r') as z:
        print("Archive:  " + zip_path)
        print("  Length      Date    Time    Name")
        print("---------  ---------- -----   ----")
        for info in z.infolist():
            print(f"{info.file_size:9}  2026-06-17 12:00   {info.filename}")
        print("---------                     -------")
        print(f"{0:9}                     {len(z.infolist())} files")

def main():
    if len(sys.argv) < 2:
        print("Usage: zip_helper.py [zip|unzip] [args...]", file=sys.stderr)
        sys.exit(1)
        
    cmd = sys.argv[1]
    args = sys.argv[2:]
    
    if cmd == 'zip':
        run_zip(args)
    elif cmd == 'unzip':
        run_unzip(args)
    else:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
