try:
    import radiusd
except Exception:
    class _D:  # let the file lint outside FR
        L_INFO = 2
        RLM_MODULE_OK = 0
        def radlog(self, *_a, **_k): pass
    radiusd = _D()

CANDIDATES = [
    "TLS-Client-Version", "TLS-Version", "TLS-Protocol",
    "EAP-Session-SSL-Protocol", "EAP-TLS-SSL-Version"
]

def _find_tls_version(p):
    for name in CANDIDATES:
        v = p.get(name)
        if v: return str(v)
        try:
            v = p.reply.get(name)
            if v: return str(v)
        except Exception:
            pass
        try:
            v = p.control.get(name)
            if v: return str(v)
        except Exception:
            pass
    return None

def post_auth(p):
    ver = _find_tls_version(p)
    if ver:
        p.control["Tmp-String-0"] = ver
        radiusd.radlog(radiusd.L_INFO, f"tls_version: user={p.get('User-Name','')} ver={ver}")
    else:
        radiusd.radlog(radiusd.L_INFO, "tls_version: not found")
    return radiusd.RLM_MODULE_OK