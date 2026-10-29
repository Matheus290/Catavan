# Lists (or rewrites with --apply) the translatable strings that name "Kdenlive" in C++/QML/.ui/.kcfg/.rc sources.
import re, sys, os
ROOT = sys.argv[1]
APPLY = '--apply' in sys.argv
WORD = re.compile(r'\bKdenlive\b')
# occurrences that name the project format, the upstream project or its people/sites stay
KEEP_AFTER = re.compile(r'^Kdenlive(\s+(project|Project|projects|Projects|document|Document|documents|file|File|files|authors|team|Team|community|Community|website|Website|forum|Forum|Store|store|developers|bug|Bug|handbook|Handbook|manual|Manual|documentation|Documentation)\b|\.org|\s*\(\*\.kdenlive)')
changes = []
# strings about Kdenlive itself (its funding, docs, update page) or about its file formats
KEEP_WHOLE = re.compile(r"was upgraded\. If you like it|Help us make Kdenlive|^Kdenlive (Effect definitions|Layout|JSON|title)|Your Kdenlive version is older|Kdenlive's online documentation")

def fix_text(s, where):
    out = []; last = 0
    for m in WORD.finditer(s):
        tail = s[m.start():]
        keep = bool(KEEP_AFTER.match(tail)) or re.search(r'(fork of|based on|Catavan is based on)\s*$', s[:m.start()]) \
            or KEEP_WHOLE.search(s) or (s == 'Kdenlive' and where.endswith('main.cpp'))
        changes.append((where, 'KEEP' if keep else 'CHANGE', s))
        out.append(s[last:m.start()]); out.append(m.group(0) if keep else 'Catavan'); last = m.end()
    out.append(s[last:])
    return ''.join(out)

def tokens(text):
    # yields ('str', a, b) for string literal contents and ('(' | ')', i) outside literals/comments
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if text.startswith('//', i):
            j = text.find('\n', i); i = n if j < 0 else j
        elif text.startswith('/*', i):
            j = text.find('*/', i + 2); i = n if j < 0 else j + 2
        elif c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == '\\' else 1
            yield ('str', i + 1, j); i = j + 1
        elif c == "'" and not (i > 0 and (text[i-1].isalnum())):
            j = i + 1
            while j < n and text[j] != "'" and text[j] != '\n':
                j += 2 if text[j] == '\\' else 1
            i = j + 1
        else:
            if c in '()':
                yield (c, i, i)
            elif text[i:i+1].isalpha() or c == '_':
                j = i
                while j < n and (text[j].isalnum() or text[j] == '_'):
                    j += 1
                yield ('id', i, j); i = j; continue
            i += 1

def do_code(path):
    text = open(path, encoding='utf-8').read()
    if 'Kdenlive' not in text: return
    toks = list(tokens(text))
    spans = []
    k = 0
    while k < len(toks):
        t = toks[k]
        if t[0] == 'id' and re.fullmatch(r'k?x?i18n[a-z]*|tr', text[t[1]:t[2]]) and k + 1 < len(toks) and toks[k+1][0] == '(':
            depth = 0; m = k + 1
            while m < len(toks):
                if toks[m][0] == '(': depth += 1
                elif toks[m][0] == ')':
                    depth -= 1
                    if depth == 0: break
                elif toks[m][0] == 'str': spans.append((toks[m][1], toks[m][2]))
                m += 1
            k = m
        k += 1
    if not spans: return
    new = []; last = 0
    for a, b in sorted(set(spans)):
        if a < last: continue
        new.append(text[last:a]); new.append(fix_text(text[a:b], path)); last = b
    new.append(text[last:])
    new = ''.join(new)
    if APPLY and new != text: open(path, 'w', encoding='utf-8').write(new)

XMLTAGS = re.compile(r'(<(string|label|whatsthis|tooltip|text|title)(\s[^>]*)?>)(.*?)(</\2>)', re.S)
def do_xml(path):
    text = open(path, encoding='utf-8').read()
    if 'Kdenlive' not in text: return
    def rep(m):
        if 'notr="true"' in (m.group(3) or ''): return m.group(0)
        return m.group(1) + fix_text(m.group(4), path) + m.group(5)
    new = XMLTAGS.sub(rep, text)
    if APPLY and new != text: open(path, 'w', encoding='utf-8').write(new)

for d, _, fs in os.walk(ROOT):
    if os.path.relpath(d, ROOT).split(os.sep)[0] in ('po', 'doc', 'tests', 'fuzzer'): continue
    for f in fs:
        p = os.path.join(d, f)
        if f.endswith(('.cpp', '.h', '.hpp', '.qml', '.js')): do_code(p)
        elif f.endswith(('.ui', '.kcfg', '.rc')): do_xml(p)
for w, k, s in changes:
    print(k, os.path.relpath(w, ROOT), '|', s.replace('\n', ' ')[:200])
