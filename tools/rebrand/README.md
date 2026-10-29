# rebrand — "Kdenlive" → "Catavan" in the interface strings

Used for the `branding` patch. To apply it again on a new Kdenlive version (from `src/kdenlive-<version>/`):

```bash
python3 -I ../../tools/rebrand/strings.py .            # lists: CHANGE (becomes Catavan) / KEEP (stays Kdenlive)
python3 -I ../../tools/rebrand/strings.py . --apply    # applies it to the .cpp/.h/.qml/.ui/.kcfg/.rc files
python3 -I ../../tools/rebrand/po.py ../../tools/rebrand/strings.py po/*/kdenlive.po   # same rule in the translations
for f in po/*/kdenlive.po; do msgfmt --check -o /dev/null "$f" || echo "$f"; done
```

The exceptions (format names, online docs, donations, update reminder) are in `KEEP_AFTER`/`KEEP_WHOLE` in
`strings.py`. Strings naming Kdenlive both ways at once are reported as `MIXED` by `po.py` and need a manual fix.
