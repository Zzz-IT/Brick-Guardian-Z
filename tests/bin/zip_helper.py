import sys
import os
import zipfile
import fnmatch

def main():
    args = sys.argv[1:]
    outfile = None
    files_to_zip = []
    excludes = []
    
    i = 0
    while i < len(args):
        arg = args[i]
        if arg == '-r':
            i += 1
            if i < len(args):
                outfile = args[i]
        elif arg == '-x':
            i += 1
            while i < len(args) and not args[i].startswith('-'):
                excludes.append(args[i])
                i += 1
            continue
        elif arg.startswith('-'):
            pass
        else:
            files_to_zip.append(arg)
        i += 1

    if not outfile and files_to_zip:
        outfile = files_to_zip[0]
        files_to_zip = files_to_zip[1:]

    # Remove duplicates
    files_to_zip = list(dict.fromkeys(files_to_zip))

    def is_excluded(path):
        # Normalize path separators to forward slashes for pattern matching
        normalized_path = path.replace('\\', '/')
        for pattern in excludes:
            pat = pattern.strip('"').strip("'")
            if fnmatch.fnmatch(normalized_path, pat) or fnmatch.fnmatch(os.path.basename(normalized_path), pat):
                return True
            parts = normalized_path.split('/')
            for part in parts:
                if fnmatch.fnmatch(part, pat):
                    return True
        return False

    with zipfile.ZipFile(outfile, 'w', zipfile.ZIP_DEFLATED) as z:
        for item in files_to_zip:
            if os.path.isdir(item):
                for root, dirs, files in os.walk(item):
                    for file in files:
                        full_path = os.path.join(root, file)
                        rel_path = os.path.relpath(full_path, '.')
                        if not is_excluded(rel_path):
                            z.write(full_path, rel_path)
            elif os.path.isfile(item):
                if not is_excluded(item):
                    z.write(item, item)

if __name__ == '__main__':
    main()
