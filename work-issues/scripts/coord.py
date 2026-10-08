#!/usr/bin/env python3
# Locked JSON update: coord.py <file> <python-expr-using-d>  (d = loaded json; expr mutates d)
import fcntl, json, os, sys, tempfile
W = os.path.dirname(os.path.abspath(__file__))
path, expr = sys.argv[1], sys.argv[2]
with open(os.path.join(W, "coordination.lock"), "w") as lk:
    fcntl.flock(lk, fcntl.LOCK_EX)
    d = json.load(open(path)) if os.path.exists(path) else None
    ns = {"d": d}; exec(expr, ns); d = ns["d"]
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path)); 
    with os.fdopen(fd, "w") as f: json.dump(d, f, indent=1)
    os.replace(tmp, path)
