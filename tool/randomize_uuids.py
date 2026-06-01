import re, secrets

PBXPROJ = "ios/Runner.xcodeproj/project.pbxproj"

with open(PBXPROJ, "rb") as f:
    raw = f.read()
had_bom = raw[:3] == b"\xef\xbb\xbf"
if had_bom:
    raw = raw[3:]
txt = raw.decode("utf-8")

# Find every distinct synthetic UUID we previously inserted (BB2026... pattern).
tokens = sorted(set(re.findall(r"BB2026[0-9A-Fa-f]{18}", txt)))
print("Found %d synthetic UUIDs" % len(tokens))

def new_uuid():
    # 24 uppercase hex chars, Xcode style.
    return secrets.token_hex(12).upper()

mapping = {}
used = set(re.findall(r"\b[0-9A-F]{24}\b", txt))
for t in tokens:
    u = new_uuid()
    while u in used or u in mapping.values():
        u = new_uuid()
    mapping[t] = u

for old, new in mapping.items():
    txt = txt.replace(old, new)
    print("  %s -> %s" % (old, new))

txt = txt.replace("\r\n", "\n").replace("\n", "\r\n")
with open(PBXPROJ, "wb") as f:
    f.write(txt.encode("utf-8"))
print("done (BOM was %s, written without BOM)" % had_bom)
