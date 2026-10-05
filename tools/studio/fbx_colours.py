import struct, sys, zlib, json
def parse(path):
    d = open(path, 'rb').read()
    ver = struct.unpack_from('<I', d, 23)[0]
    big = ver >= 7500
    def node(o):
        if big:
            end, nprops, plen = struct.unpack_from('<QQQ', d, o); o += 24
        else:
            end, nprops, plen = struct.unpack_from('<III', d, o); o += 12
        nl = d[o]; o += 1
        name = d[o:o+nl].decode('latin1'); o += nl
        if end == 0:
            return None, o
        props = []; p = o
        for _ in range(nprops):
            t = chr(d[p]); p += 1
            if t in 'YCIFDL':
                fmt = {'Y':'<h','C':'<b','I':'<i','F':'<f','D':'<d','L':'<q'}[t]
                props.append(struct.unpack_from(fmt, d, p)[0]); p += struct.calcsize(fmt)
            elif t in 'SR':
                n = struct.unpack_from('<I', d, p)[0]; p += 4
                props.append(d[p:p+n] if t == 'R' else d[p:p+n].decode('latin1')); p += n
            else:
                n, enc, clen = struct.unpack_from('<III', d, p); p += 12
                props.append(None); p += clen
        o += plen
        kids = []
        while o < end:
            k, o = node(o)
            if k is None: break
            kids.append(k)
        return (name, props, kids), end
    o = 27; top = []
    while o < len(d) - 200:
        n, o = node(o)
        if n is None: break
        top.append(n)
    return top
def colours(path):
    top = dict((n[0], n) for n in parse(path))
    models, mats = {}, {}
    for name, props, kids in top['Objects'][2]:
        if name == 'Model': models[props[0]] = props[1].split('\x00')[0]
        if name == 'Material':
            col = None
            for k in kids:
                if k[0] == 'Properties70':
                    for p in k[2]:
                        if p[1] and p[1][0] == 'DiffuseColor': col = p[1][4:7]
            mats[props[0]] = (props[1].split('\x00')[0], col)
    out = {}
    for name, props, kids in top['Connections'][2]:
        if props[0] == 'OO' and props[1] in mats and props[2] in models:
            out.setdefault(models[props[2]], []).append(mats[props[1]])
    return out
if __name__ == '__main__':
    res = colours(sys.argv[1])
    multi = {k: v for k, v in res.items() if len(v) > 1}
    print(len(res), 'meshes;', len(multi), 'with more than one material')
    for k in list(res)[:8]: print(k, res[k])
    for k in list(multi)[:5]: print('MULTI', k, multi[k])
