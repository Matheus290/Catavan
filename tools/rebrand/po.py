# Applies the Kdenlive -> Catavan rule of strings.py to the msgids of a .po file and to their translations.
import re, sys, importlib.util
spec = importlib.util.spec_from_file_location('s', sys.argv[1])
sys.argv_saved = sys.argv; sys.argv = ['x', '/nonexistent']
S = importlib.util.module_from_spec(spec); spec.loader.exec_module(S)
WORD = re.compile(r'\bKdenlive\b')
mixed = []
for path in sys.argv_saved[2:]:
    blocks = open(path, encoding='utf-8').read().split('\n\n')
    out = []
    for b in blocks:
        lines = b.split('\n')
        # joined msgid
        mid = []; cur = None
        for l in lines:
            if l.startswith('msgid '): cur = 'id'; mid.append(l[6:].strip('"'))
            elif l.startswith(('msgid_plural', 'msgstr', 'msgctxt')): cur = None
            elif l.startswith('"') and cur == 'id': mid.append(l.strip('"'))
        msgid = ''.join(mid)
        if not WORD.search(msgid) or msgid == 'Kdenlive':
            out.append(b); continue
        S.changes.clear()
        S.fix_text(msgid, path)
        kinds = {k for _, k, _ in S.changes}
        if kinds == {'KEEP'}:
            out.append(b); continue
        if kinds != {'CHANGE'}:
            mixed.append((path, msgid)); out.append(b); continue
        new = []
        for l in lines:
            if l.startswith('#'): new.append(l)
            else: new.append(WORD.sub('Catavan', l))
        out.append('\n'.join(new))
    open(path, 'w', encoding='utf-8').write('\n\n'.join(out))
for p, m in mixed: print('MIXED', p, m)
