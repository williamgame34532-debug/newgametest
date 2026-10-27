#!/usr/bin/env python3
"""Generate compile-only Java stubs from the javap dump, for type-checking mod code offline.
usage: stubgen.py <javap.txt> <outdir> <seed classes file>
"""
import re, sys, os
from collections import defaultdict

dump, outdir, seedfile = sys.argv[1:4]
lines = open(dump, encoding='utf-8').read().split('\n')

HDR = re.compile(r'^((?:public |protected |private |abstract |final |static |sealed |non-sealed |strictfp )*)(class|interface|enum) ([\w.$]+)(<.*?>)?(?: extends (.*?))?(?: implements (.*?))?(?: permits .*?)? \{$')
classes = {}
i = 0
while i < len(lines):
    l = lines[i]
    m = HDR.match(l)
    if m:
        name = m.group(3)
        body = []
        i += 1
        while i < len(lines) and lines[i] != '}':
            body.append(lines[i])
            i += 1
        if name not in classes:
            classes[name] = dict(mods=m.group(1), kind=m.group(2), tparams=m.group(4) or '', ext=m.group(5) or '', impl=m.group(6) or '', body=body)
    i += 1

QN = re.compile(r'\b((?:[a-z_][\w]*\.)+[A-Z][\w$]*)')

def split_top(s, sep=','):
    out, depth, cur = [], 0, ''
    for ch in s:
        if ch == '<': depth += 1
        elif ch == '>': depth -= 1
        if ch == sep and depth == 0:
            out.append(cur.strip()); cur = ''
        else:
            cur += ch
    if cur.strip(): out.append(cur.strip())
    return out

def strip_generics(t):
    out, depth = '', 0
    for ch in t:
        if ch == '<': depth += 1; continue
        if ch == '>': depth -= 1; continue
        if depth == 0: out += ch
    return out.strip()

def supertypes(name):
    c = classes.get(name)
    if not c: return []
    res = []
    for part in (c['ext'], c['impl']):
        for t in split_top(part):
            if t: res.append(strip_generics(t))
    return res

seeds = [s.strip() for s in open(seedfile) if s.strip() and not s.startswith('#')]
full = set()
stack = list(seeds)
while stack:
    n = stack.pop()
    if n in full or n not in classes: continue
    full.add(n)
    stack.extend(supertypes(n))
    # outer classes of nested
    if '$' in n:
        stack.append(n.rsplit('$', 1)[0])

missing = [s for s in seeds if s not in classes]
if missing:
    print('NOT IN DUMP (need hand stubs):', ' '.join(missing), file=sys.stderr)

# collect referenced types + arity
arity = defaultdict(int)
iface_hint = set()
def scan(text):
    # find qualified names followed by optional generic args
    for m in QN.finditer(text):
        n = m.group(1)
        rest = text[m.end():]
        if rest.startswith('<'):
            depth, j = 0, 0
            for j, ch in enumerate(rest):
                if ch == '<': depth += 1
                elif ch == '>':
                    depth -= 1
                    if depth == 0: break
            args = split_top(rest[1:j])
            arity[n] = max(arity[n], len(args))
        else:
            arity.setdefault(n, 0)

member_ok = []
for n in full:
    c = classes[n]
    scan(c['tparams'] + ' ' + c['ext'] + ' ' + c['impl'])
    for t in split_top(c['impl']):
        iface_hint.add(strip_generics(t))
    if c['kind'] == 'interface':
        for t in split_top(c['ext']):
            iface_hint.add(strip_generics(t))
    for l in c['body']:
        if 'lambda$' in l or '$$' in l: continue
        scan(l)
for n in list(arity):
    if n in classes and classes[n]['tparams']:
        arity[n] = max(arity[n], len(split_top(classes[n]['tparams'][1:-1])))

handled_elsewhere = set(open(os.path.join(os.path.dirname(seedfile), 'handstub_types.txt')).read().split()) if os.path.exists(os.path.join(os.path.dirname(seedfile), 'handstub_types.txt')) else set()

alltypes = set(arity) | full
# ensure outers exist
for n in list(alltypes):
    while '$' in n:
        n = n.rsplit('$', 1)[0]
        alltypes.add(n)
alltypes = {t for t in alltypes if not t.startswith('java.') and not t.startswith('javax.') and t not in handled_elsewhere
            and not any(t.startswith(h + '$') for h in handled_elsewhere)}

def jt(t):
    """type text -> java source"""
    return t.replace('$', '.')

PRIM_DEFAULT = {'int': '0', 'long': '0L', 'short': '(short)0', 'byte': '(byte)0', 'char': "'a'", 'float': '0f', 'double': '0d', 'boolean': 'false'}

def simple(n):
    return n.rsplit('.', 1)[-1].rsplit('$', 1)[-1]

def gen_params(params):
    ps = split_top(params)
    out = []
    for k, p in enumerate(ps):
        out.append(f'{jt(p)} a{k}')
    return ', '.join(out)

MEM = re.compile(r'^  ((?:public |protected |private |static |final |abstract |default |synchronized |native |transient |volatile |strictfp )*)(<.*?> )?(.*?)\s*(\(.*\))?(?: throws (.*))?;$')

def gen_class(n, indent, children):
    c = classes.get(n)
    is_full = n in full
    sname = simple(n)
    ind = '    ' * indent
    out = []
    if c:
        kind = c['kind']
        tparams = c['tparams']
        ext, impl = c['ext'], c['impl']
        is_enum = 'java.lang.Enum<' in ext
        is_record = ext.strip() == 'java.lang.Record'
    else:
        kind = 'interface' if n in iface_hint else 'class'
        tparams = ''
        is_enum = is_record = False
        ext = impl = ''
        if arity.get(n, 0):
            tparams = '<' + ', '.join(f'T{k}' for k in range(arity[n])) + '>'
    if not is_full:
        # shell: keep kind + type param names (no bounds)
        if tparams:
            names = [strip_generics(p).split(' ')[0] for p in split_top(tparams[1:-1])]
            tparams = '<' + ', '.join(names) + '>'
        ext = impl = ''
    mods = 'public ' + ('static ' if indent > 0 else '')
    if is_enum:
        decl = f'{ind}{mods}enum {sname}'
        if impl and is_full: decl += ' implements ' + jt(impl)
    elif kind == 'interface':
        decl = f'{ind}{mods}interface {sname}{jt(tparams)}'
        if ext and is_full: decl += ' extends ' + jt(ext)
    else:
        abstract = 'abstract ' if (c and 'abstract' in c['mods']) else ''
        decl = f'{ind}{mods}{abstract}class {sname}{jt(tparams)}'
        if ext and not is_record and is_full: decl += ' extends ' + jt(ext)
        if impl and is_full: decl += ' implements ' + jt(impl)
    out.append(decl + ' {')
    body_ind = ind + '    '
    if is_enum:
        consts = []
        if c:
            for l in c['body']:
                m = re.match(r'^  public static final ([\w.$]+) (\w+);$', l)
                if m and m.group(1) == n:
                    consts.append(m.group(2))
        out.append(body_ind + ', '.join(consts) + ';')
    has_noarg = False
    seen_sigs = set()
    if is_full and c:
        for l in c['body']:
            if 'lambda$' in l or 'static {}' in l or l.startswith('Compiled'):
                continue
            m = MEM.match(l)
            if not m:
                continue
            mods_, tp, rest, params, throws = m.groups()
            if 'private' in mods_: continue
            tp = tp or ''
            if params is None:
                # field
                parts = rest.rsplit(' ', 1)
                if len(parts) != 2: continue
                ftype, fname = parts
                if is_enum and ftype == n: continue
                if fname == '$VALUES' or '$' in fname: continue
                fm = mods_.replace('transient ', '').replace('volatile ', '')
                if kind == 'interface':
                    out.append(f'{body_ind}{jt(ftype)} {fname} = {PRIM_DEFAULT.get(ftype, "null")};')
                elif 'final' in fm:
                    out.append(f'{body_ind}{fm}{jt(ftype)} {fname} = {PRIM_DEFAULT.get(ftype, "null")};')
                else:
                    out.append(f'{body_ind}{fm}{jt(ftype)} {fname};')
                continue
            params = params[1:-1]
            # constructor?
            if rest == n:
                if is_enum: continue
                ps = gen_params(params)
                if not params.strip(): has_noarg = True
                key = ('<init>', len(split_top(params)), strip_generics(params))
                if key in seen_sigs: continue
                seen_sigs.add(key)
                cm = mods_.replace('final ', '')
                th = f' throws {jt(throws)}' if throws else ''
                out.append(f'{body_ind}{cm}{jt(tp)}{sname}({ps}){th} {{ }}')
                continue
            parts = rest.rsplit(' ', 1)
            if len(parts) != 2: continue
            rtype, mname = parts
            if '$' in mname: continue
            if is_enum and mname in ('values', 'valueOf'): continue
            key = (mname, strip_generics(params))
            if key in seen_sigs: continue
            seen_sigs.add(key)
            ps = gen_params(params)
            th = f' throws {jt(throws)}' if throws else ''
            mm = mods_.replace('native ', '').replace('transient ', '').replace('volatile ', '').replace('synchronized ', '')
            is_abstract = 'abstract' in mm
            if is_enum and is_abstract:
                mm = mm.replace('abstract ', ''); is_abstract = False
            if kind == 'interface':
                if is_abstract:
                    out.append(f'{body_ind}{mm}{jt(tp)}{jt(rtype)} {mname}({ps}){th};')
                else:
                    out.append(f'{body_ind}{mm}{jt(tp)}{jt(rtype)} {mname}({ps}){th} {{ throw new RuntimeException(); }}')
            else:
                if is_abstract:
                    out.append(f'{body_ind}{mm}{jt(tp)}{jt(rtype)} {mname}({ps}){th};')
                else:
                    out.append(f'{body_ind}{mm}{jt(tp)}{jt(rtype)} {mname}({ps}){th} {{ throw new RuntimeException(); }}')
    if kind != 'interface' and not is_enum and not has_noarg:
        out.append(f'{body_ind}protected {sname}() {{ }}')
    for ch in sorted(children.get(n, [])):
        out.extend(gen_class(ch, indent + 1, children))
    out.append(ind + '}')
    return out

children = defaultdict(list)
tops = []
for t in alltypes:
    if '$' in t:
        outer = t.rsplit('$', 1)[0]
        if re.match(r'^\d', t.rsplit('$', 1)[1]):
            continue
        children[outer].append(t)
    else:
        tops.append(t)

for t in tops:
    if t in handled_elsewhere: continue
    pkg, sname = t.rsplit('.', 1)
    d = os.path.join(outdir, *pkg.split('.'))
    os.makedirs(d, exist_ok=True)
    src = [f'package {pkg};', ''] + gen_class(t, 0, children)
    open(os.path.join(d, sname + '.java'), 'w').write('\n'.join(src) + '\n')
print('full', len(full), 'total', len(tops), file=sys.stderr)
