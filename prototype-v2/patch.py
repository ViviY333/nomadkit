import sys

p = "prototype-v2/index.html"
s = open(p, encoding="utf-8").read()
css = open("prototype-v2/frag_css.txt", encoding="utf-8").read()
html = open("prototype-v2/frag_html.txt", encoding="utf-8").read()

style_anchor = "  </style>"
hero_anchor = '            <article class="city-hero">'

print("STYLE_COUNT", s.count(style_anchor))
print("HERO_COUNT", s.count(hero_anchor))
print("ALREADY", s.count("now-card"))

if s.count("now-card") > 0:
    print("SKIP_ALREADY_PATCHED")
    sys.exit(0)

assert s.count(style_anchor) == 1, "style anchor not unique"
assert s.count(hero_anchor) == 1, "hero anchor not unique"

s = s.replace(style_anchor, css + style_anchor, 1)
s = s.replace(hero_anchor, html + hero_anchor, 1)

open(p, "w", encoding="utf-8").write(s)

print("DONE")
print("LINES", s.count(chr(10)) + 1)
print("NOWCARD", s.count("now-card"))
print("NOWGRID", s.count("now-grid"))
