#!/usr/bin/env python3
# Self time per function for each thread of a macOS `sample` report (its "Call graph" section).
# usage: sampletree.py file.sample [min_thread_samples] [top_n]
import re, sys, collections
f, minth, top = sys.argv[1], int(sys.argv[2]) if len(sys.argv) > 2 else 2000, int(sys.argv[3]) if len(sys.argv) > 3 else 25
lines = open(f, errors='replace').read().split('\n')
start = next(i for i, l in enumerate(lines) if l.startswith('Call graph:'))
end = next(i for i in range(start + 1, len(lines)) if lines[i].strip() == '' )
rx = re.compile(r'^(?P<ind>[\s+!:|]*)(?P<n>\d+)\s+(?P<name>.*)$')
WAIT = ('__psynch_cvwait', 'semaphore_wait', 'mach_msg', '__workq_kernreturn', '__semwait', '__ulock_wait', 'kevent', '__select', 'nanosleep', '__kill')
threads = []   # (name, total, selfcounts)
stack = []     # (depth, count, name)
cur = None
def flush(entry):
    pass
for l in lines[start + 1:end]:
    m = rx.match(l)
    if not m: continue
    depth, n, name = len(m.group('ind')), int(m.group('n')), m.group('name')
    name = re.sub(r'\s+\(in [^)]*\).*$', '', name).strip()
    name = re.sub(r'\s+\+\s+\d+.*$', '', name)
    if depth <= 4 and ('Thread_' in name or 'DispatchQueue' in name):
        cur = [name[:70], n, collections.Counter(), collections.Counter()]
        threads.append(cur); stack = [(depth, n, name)]; continue
    if cur is None: continue
    while stack and stack[-1][0] >= depth: stack.pop()
    if stack:
        pd, pn, pname = stack[-1]
        cur[2][pname] -= n          # child time comes off the parent's self time
    cur[2][name] += n
    cur[3][name] += n               # inclusive (approximate: recursion counted twice)
    stack.append((depth, n, name))
for name, total, selfc, incl in threads:
    if total < minth: continue
    busy = total - sum(v for k, v in selfc.items() if k.startswith(WAIT))
    print(f'\n== {name}  total {total}  busy {busy} ({100*busy/total:.0f}%)')
    for k, v in selfc.most_common(top):
        if k.startswith(WAIT) or v <= 0: continue
        print(f'  {100*v/total:5.1f}%  self  {k[:110]}')
