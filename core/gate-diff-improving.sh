#!/usr/bin/env bash
# Is the gate-file diff of a change purely IMPROVING?  The owner's rule: a PR that touches the gate-defining set may be landed by the caretaker only if
# its gate-file diff is purely improving; otherwise it waits for the owner.
#   gate-diff-improving.sh [--conf FILE] <base-ref> <head-ref>      (run in the repository; the diff is taken from the merge base, like protected-set.sh)
# THE TABLES ARE gates.conf (core/gates-conf.sh; an unknown key fails): GATES_TIER1, GATES_STRICT, GATES_LISTS, GATES_SOURCE, GATES_SOURCE_DIRS, GATES_PROTECTED_LIST, and GATES_RULES_FILE (the numeric baselines' rules, one per line, read as of the base). --conf: another conf (the lander's hooks pass main's copy).
# One line per changed gate-defining file ("PASS|FAIL file: why", FAIL names the exact offending lines), then a final PASS/FAIL. Exit 0 = PASS, 1 = FAIL, 2 = cannot decide.
#   NUMERIC BASELINES: every key moves only in its improving direction (the rules file; an unknown key or field FAILS; a baseline that appears or disappears FAILS).
#   the Tier 1 script (GATES_TIER1): may only GAIN lines: a removed or changed line FAILS, so does an added line that weakens (|| true, exit 0, set +e, if false, ...) or that joins
#                      onto an existing line (a trailing backslash / && / || / |, or an added line that continues the one above).
#   GATES_STRICT files (a toolchain pin, a build configuration): may only GAIN lines (a removed or changed line FAILS); what an added line does is the consumer's own check.
#   GATES_LISTS and GATE SOURCE (GATES_SOURCE, GATES_SOURCE_DIRS): FAIL on ANY change (add, edit, delete): owner only.
#   --suite-judged (what the lander's post-rebase hook runs): a LIST or GATE SOURCE change is not owner-only but judged by the RELABEL-ATTACK SUITE (run by the lander's post-tier1 hook on the
#      proposed tree) instead; here it PASSes except the protected list (GATES_PROTECTED_LIST), which must still protect everything the base list did
#      (protected-set.sh --superset). the Tier 1 script and the numeric baselines are judged the same in both modes.
#   --touched <base> <head>: print the gate-defining files the change touches (one per line; nothing = none): the lander runs the suite exactly when this prints something.
# Files outside this set are not judged here (protected-set.sh judges the wider protected set). Self-test: tests/test_gate_diff_improving.sh.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/gates-conf.sh"
export GDI_HERE=$here GDI_SUITE=0 GDI_TOUCHED=0; conf=
usage="usage: gate-diff-improving.sh [--conf FILE] [--suite-judged|--touched] <base-ref> <head-ref>"
while :; do case ${1:-} in --suite-judged) GDI_SUITE=1; shift;; --touched) GDI_TOUCHED=1; shift;; --conf) conf=${2:?$usage}; shift 2;; *) break;; esac; done
base=${1:?$usage}; head=${2:?$usage}
gates_load ${conf:+"$conf"} || exit 2   # the tables: an unknown key or a malformed value cannot decide
export GDI_TIER1=$GATES_TIER1 GDI_STRICT=$GATES_STRICT GDI_LISTS=$GATES_LISTS GDI_SOURCE=$GATES_SOURCE GDI_SOURCE_DIRS=$GATES_SOURCE_DIRS GDI_RULES_FILE=$GATES_RULES_FILE GDI_PLIST=$GATES_PROTECTED_LIST
mb=$(git merge-base "$base" "$head") || { echo "gate-diff-improving: no merge base for $base $head" >&2; exit 2; }
# The judge is bounded: GDI_TIMEOUT seconds (default 120), then exit 2 "cannot decide" with a clear message (a gate must never hold the land lock unbounded).
rc=0; timeout -k 5 "${GDI_TIMEOUT:-120}" python3 - "$mb" "$head" <<'PY' || rc=$?
import os, re, subprocess, sys, tempfile
SUITE, TOUCHED, HERE = os.environ["GDI_SUITE"] == "1", os.environ["GDI_TOUCHED"] == "1", os.environ["GDI_HERE"]
mb, head = sys.argv[1:3]
def die(msg):  # cannot decide: exit 2 (sys.exit(msg) alone would exit 1, which reads as a FAIL verdict)
    print(f"gate-diff-improving: {msg}", file=sys.stderr); sys.exit(2)
def git(*a, check=True):
    r = subprocess.run(["git", *a], capture_output=True, text=True)
    if check and r.returncode: die(f"git {' '.join(a)}: {r.stderr.strip()}")
    return r.stdout if r.returncode == 0 else None
changed = set(git("diff", "--name-only", "--no-renames", mb, head).split("\n")) - {""}
def show(ref, p): return git("show", f"{ref}:{p}", check=False)

# RULES: baseline file -> [(key regex, {field: rule}, removable)], from the rules file (GATES_RULES_FILE, as of the base), one rule per line: `FILE | KEY-REGEX | FIELDS | removable|fixed`, FIELDS = `f0=down,f1=ratio` or `*=down`.
# Fields are `name=int` or positional (f0, f1, ...). Rules: down (may only fall), up (may only rise), free (not a ratchet), ratio (f0 f1: the fraction f0/f1 may only rise, compared exactly). A key absent on one side counts as 0 on it
# (a new unverified module or a new allocation is a raise); a key that is `fixed` may not disappear (a target, or coverage of a function/module). A baseline file without a rule FAILS as unknown.
def conf_list(n): return os.environ.get(n, "").split()
def load_rules():
    rules, rf = {}, os.environ.get("GDI_RULES_FILE", "")
    if not rf: return rules
    text = show(mb, rf)
    if text is None: die(f"GATES_RULES_FILE {rf} does not exist on the base: cannot decide")
    for n, l in enumerate(text.splitlines(), 1):
        if not l.split("#")[0].strip(): continue
        c = [x.strip() for x in l.split("#")[0].split("|")]
        try:
            f, rx, fl, rm = c; re.compile(rx); assert rm in ("removable", "fixed")
            fields = dict(x.split("=") for x in fl.split(","))
            assert fields and all(v in ("down", "up", "free", "ratio") for v in fields.values()) and all(re.fullmatch(r"\*|f\d+|[A-Za-z_][A-Za-z0-9_]*", k) for k in fields)
        except Exception:
            die(f"{rf}:{n}: not `FILE | KEY-REGEX | FIELDS | removable|fixed`: {l}")
        rules.setdefault(f, []).append((rx, fields, rm == "removable"))
    return rules
RULES = load_rules()
LISTS, SOURCE, STRICT, SOURCE_DIRS = conf_list("GDI_LISTS"), conf_list("GDI_SOURCE"), conf_list("GDI_STRICT"), conf_list("GDI_SOURCE_DIRS")
TIER1, PLIST = os.environ["GDI_TIER1"], os.environ["GDI_PLIST"]
out, bad = [], 0
def say(ok, f, why):
    global bad; bad += (not ok); out.append(f"{'PASS' if ok else 'FAIL'} {f}: {why}")

def parse(text):
    d = {}
    for l in (text or "").splitlines():
        if l.startswith("#") or not l.strip(): continue
        k, *f = l.split(); v = {}
        for i, x in enumerate(f):
            n, _, val = x.partition("=") if "=" in x else (f"f{i}", "", x)
            try: v[n] = int(val)
            except ValueError: v[n] = val
        d[k] = (l, v)
    return d

def baseline(p):
    o, n = show(mb, p), show(head, p)
    if o is None or n is None: return say(False, p, "the baseline " + ("appears" if o is None else "disappears") + " (owner only)")
    old, new, why = parse(o), parse(n), []
    for k in sorted(set(old) | set(new)):
        line = (new.get(k) or old[k])[0]
        rule = next(((fl, rm) for rx, fl, rm in RULES[p] if re.fullmatch(rx, k)), None)
        if rule is None: why.append(f"unknown key '{k}': +{line}"); continue
        fl, removable = rule
        if k not in new and not removable: why.append(f"key '{k}' removed: -{old[k][0]}"); continue
        ov, nv = (old.get(k) or ("", {}))[1], (new.get(k) or ("", {}))[1]
        if ov == nv: continue
        if "*" in fl: fl = {f: "down" for f in set(ov) | set(nv)}
        for f in sorted(set(ov) | set(nv)):
            if f not in fl: why.append(f"unknown field '{f}' of '{k}': +{line}"); continue
            a, b = ov.get(f, 0), nv.get(f, 0)
            if not isinstance(a, int) or not isinstance(b, int): why.append(f"non-numeric field '{f}' of '{k}': +{line}"); continue
            r = fl[f]
            if r == "ratio":
                if f == "f0":  # judged once, on the pair
                    (s0, t0), (s1, t1) = (ov.get("f0", 0), ov.get("f1", 1)), (nv.get("f0", 0), nv.get("f1", 1))
                    if s1 * t0 < s0 * t1: why.append(f"'{k}' fell {s0}/{t0} -> {s1}/{t1}: -{old[k][0]} +{line}")
            elif (r == "down" and b > a) or (r == "up" and b < a):
                why.append(f"'{k}' {f} moved the wrong way {a} -> {b} (may only {'fall' if r == 'down' else 'rise'}): " + (f"-{old[k][0]} " if k in old else "") + (f"+{line}" if k in new else ""))
    say(not why, p, "improving only" if not why else "; ".join(why))
    return not why

# An ADDED tier1.sh line must be a plain step or a guard: a denylist of masks (`|| true`) is a list the next mask is not on (`! cmd`, `cmd && :`, `: $(cmd)`, `trap 'exit 0' EXIT`, `cmd &`).
Q = r'(?:"(?:[^"\\]|\\.)*"|\'[^\']*\')'
# W is one alternation under ONE quantifier, every alternative starting on a distinct character (a nested `(?:x+|y)+` backtracks exponentially on a long line that fails to match: it ran 47 min on one).
W = rf'(?:[A-Za-z0-9_./=:,+@%-]|\$(?:\{{[A-Za-z_][A-Za-z0-9_]*\}}|[A-Za-z_][A-Za-z0-9_]*(?![A-Za-z0-9_]))|{Q})+'
R = rf'(?:>>? ?{W}|2>&1|>&2|2>>? ?{W}|< ?{W})'
CMD = rf'{W}(?: (?:{W}|{R}))*'
PLAIN = re.compile(rf'^{CMD}(?: \| {CMD})*$')
GUARD = re.compile(rf'^\[ [^\]]* \](?: && \[ [^\]]* \])* \|\| \{{ (?:echo|printf) {Q}(?: >&2)?; exit 1; \}}$')
BAD_FIRST = {":", "true", "false", "set", "trap", "exit", "return", "eval", "export", "local", "source", ".", "unset", "shopt", "exec", "test", "[", "if", "then", "fi", "for", "do", "done", "while",
             "until", "case", "esac", "function", "else", "elif", "alias", "builtin", "command", "wait", "kill", "disown", "read", "cd"}
def plain_step(a):
    s = re.sub(r"\s+#.*$", "", a.strip())
    if not s or s.startswith("#"): return True
    if GUARD.match(s): return True
    if "$(" in s or "`" in s: return False
    first = re.sub(Q, "Q", s).split()[0]
    return bool(PLAIN.match(s)) and first not in BAD_FIRST

WEAK = re.compile(r"\|\|\s*(true|:|echo|printf|continue|break|return|exit\s+0)\b|\|\|\s*:|set\s+\+e|\bexit(\s+0)?\s*($|;|&)|\breturn\s+0\b|\bif\s+(false|true)\b|\bwhile\s+false\b")
def tier1(p):
    d = git("diff", "-U0", "--no-renames", mb, head, "--", p); why = []; hl = (show(head, p) or "").splitlines()
    lines = d.splitlines(); i = 0
    while i < len(lines):
        m = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", lines[i])
        if not m: i += 1; continue
        start = int(m.group(1)); i += 1; added = []
        while i < len(lines) and not lines[i].startswith("@@"):
            l = lines[i]
            if l.startswith("-"): why.append(f"removed/changed: {l}")
            elif l.startswith("+"): added.append(l[1:])
            i += 1
        for a in added:
            if WEAK.search(re.sub(r"\s#.*$", "", a)): why.append(f"weakening: +{a}")
            elif not plain_step(a): why.append(f"not a plain step (an added line is one command, or a `[ test ] || {{ echo ...; exit 1; }}` guard; a loop, `if`, `!`, `&&`, `;`, `&`, `trap`, `set`, `:` or a `$(...)` argument can mask a failure: put it in a test script, which Tier 1 picks up by name): +{a}")
        if added:
            prev = hl[start - 2] if start >= 2 else ""
            cont = re.compile(r"(\\|&&|\|\||\|)\s*$")
            if cont.search(prev) and not prev.lstrip().startswith("#"): why.append(f"joins onto the line above ({prev.strip()[-40:]!r}): +{added[0]}")
            if cont.search(added[-1]) or re.match(r"\s*(&&|\|\||\|)", added[0]): why.append(f"joins onto an existing line: +{added[-1] if cont.search(added[-1]) else added[0]}")
    say(not why, p, "only added lines" if not why else "; ".join(why))

def strict(p):
    d = git("diff", "-U0", "--no-renames", mb, head, "--", p)
    why = [f"removed/changed: {l}" for l in d.splitlines() if l.startswith("-") and not l.startswith("---")]
    say(not why, p, "only added lines (their effect is the consumer's own check)" if not why else "; ".join(why))

def is_source(p): return p in SOURCE or any(p.startswith(d) for d in SOURCE_DIRS)
if TOUCHED:
    print("\n".join(sorted(p for p in changed if p in RULES or p in LISTS or p in STRICT or is_source(p) or p == TIER1))); sys.exit(0)

def protected_superset(p):
    """The protected list may only grow: every entry of the base list is still covered (protected-set.sh --superset, this copy's own)."""
    with tempfile.TemporaryDirectory() as d:
        for n, ref in (("old", mb), ("new", head)):
            open(f"{d}/{n}", "w").write(show(ref, p) or "")
        r = subprocess.run([f"{HERE}/protected-set.sh", "--superset", f"{d}/old", f"{d}/new"], capture_output=True, text=True)
    say(r.returncode == 0, p, "every entry of the base list is still protected (judged by the relabel-attack suite for the rest)" if r.returncode == 0 else "drops protection of: " + " ".join(r.stdout.split() or [r.stderr.strip()]))

for p in sorted(changed):
    if p in RULES: baseline(p)
    elif p == TIER1: tier1(p)
    elif p in STRICT: strict(p)
    elif SUITE and p == PLIST: protected_superset(p)
    elif (p in LISTS or is_source(p)) and SUITE: say(True, p, "a list/gate source: judged by the relabel-attack suite, not by the owner")
    elif p in LISTS or is_source(p): say(False, p, "a list/gate source: any change waits for the owner")
if not out: out.append("PASS (no gate-defining file changed)")
print("\n".join(out)); print("FAIL" if bad else "PASS"); sys.exit(1 if bad else 0)
PY
case $rc in 124|137) echo "gate-diff-improving: FAIL: the judge ran past GDI_TIMEOUT=${GDI_TIMEOUT:-120}s and was killed (rc=$rc): cannot decide" >&2; exit 2;; *) exit "$rc";; esac
