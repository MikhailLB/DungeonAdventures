import re, sys
sys.stdout.reconfigure(encoding='utf-8')

PBXPROJ = "ios/Runner.xcodeproj/project.pbxproj"
raw = open(PBXPROJ, "rb").read()
assert raw[:3] != b"\xef\xbb\xbf", "unexpected BOM"
txt = raw.decode("utf-8").replace("\r\n", "\n")

ENT = "Runner/Runner.entitlements"
LINE = "\t\t\t\tCODE_SIGN_ENTITLEMENTS = %s;\n" % ENT

# 1. Remove ALL existing CODE_SIGN_ENTITLEMENTS lines (it was wrongly on the NSE config).
before = txt.count("CODE_SIGN_ENTITLEMENTS")
txt = re.sub(r"\t*CODE_SIGN_ENTITLEMENTS = [^;]+;\n", "", txt)
print("Removed %d stray CODE_SIGN_ENTITLEMENTS line(s)" % before)

# 2. Add it to the three RUNNER build configs only.
runner_cfgs = {
    "97C147061CF9000F007C117D": "Runner Debug",
    "97C147071CF9000F007C117D": "Runner Release",
    "7AFA3C8E1D35360C0083082E": "Runner Profile",
}
for uid, label in runner_cfgs.items():
    # Insert right after this config's `buildSettings = {` opening.
    pat = re.compile(re.escape(uid) + r"[^\n]*= \{\n\t\t\tisa = XCBuildConfiguration;\n(?:[^\n]*\n)?\t\t\tbuildSettings = \{\n")
    m = pat.search(txt)
    if not m:
        print("  WARN: %s (%s) buildSettings not found" % (label, uid))
        continue
    txt = txt[:m.end()] + LINE + txt[m.end():]
    print("  OK added entitlements to %s" % label)

count = txt.count("CODE_SIGN_ENTITLEMENTS")
print("Final CODE_SIGN_ENTITLEMENTS count: %d (expect 3)" % count)

txt = txt.replace("\n", "\r\n")
open(PBXPROJ, "wb").write(txt.encode("utf-8"))
print("Written (CRLF, no BOM)")
