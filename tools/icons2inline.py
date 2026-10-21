import re, os, sys, json, xml.etree.ElementTree as ET
src = sys.argv[1]; out = sys.argv[2]
NUM = re.compile(r'-?\d+\.\d+(?:e-?\d+)?|-?\d+(?:e-?\d+)?')
def rnd(s, nd=3):
    return NUM.sub(lambda m: ('%.*f' % (nd, float(m.group()))).rstrip('0').rstrip('.') if '.' in m.group() or 'e' in m.group() else m.group(), s)
KEEP = ['d','x','y','width','height','rx','ry','cx','cy','r','transform']
MULTI = {'google.svg', 'logoDarkMode.svg', 'logoLightMode.svg'}
LOGO_OP = {'#686868':'.55','#4b4b4b':'.78','#323232':'1','#c0c0c0':'.55','#d9d9d9':'.78','#f1f1f1':'1'}
res = {}
for f in sorted(os.listdir(src)):
    if not f.endswith('.svg'): continue
    r = ET.parse(os.path.join(src, f)).getroot()
    vb = ' '.join(rnd(v, 3) for v in r.get('viewBox').split())
    def emit(el):
        parts = []
        for c in el:
            tag = c.tag.split('}')[1]
            if tag == 'g':
                inner = emit(c)
                if not inner: continue
                tr = c.get('transform')
                parts.append(f"<g transform=\"{tr}\">{inner}</g>" if tr else inner)
            elif tag in ('path','rect','circle','ellipse'):
                st = c.get('style','')
                m = re.search(r'fill:(#[0-9a-fA-F]{6})', st)
                fill = (m.group(1) if m else c.get('fill','#333333')).lower()
                attrs = "".join(f" {k}=\"{c.get(k) if k == 'transform' else rnd(c.get(k))}\"" for k in KEEP if c.get(k) is not None)
                if f == 'google.svg':
                    attrs += f' fill="{fill}"'
                elif f.startswith('logo'):
                    attrs += f' fill="currentColor" fill-opacity="{LOGO_OP.get(fill,"1")}"'
                parts.append(f'<{tag}{attrs}/>')
        return ''.join(parts)
    body = emit(r)
    fill = '' if f == 'google.svg' else ' fill="currentColor"'
    res[f[:-4]] = f'<svg viewBox="{vb}"{fill} aria-hidden="true">{body}</svg>'
json.dump(res, open(out, 'w', encoding='utf-8'), indent=1)
for k, v in res.items(): print(k, len(v))
