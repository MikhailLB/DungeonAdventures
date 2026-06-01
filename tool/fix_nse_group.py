import re, sys
sys.stdout.reconfigure(encoding='utf-8')

PBXPROJ = "ios/Runner.xcodeproj/project.pbxproj"

with open(PBXPROJ, "rb") as f:
    raw = f.read()
had_bom = raw[:3] == b"\xef\xbb\xbf"
if had_bom:
    raw = raw[3:]
txt = raw.decode("utf-8")

# 1. Find the orphaned NSE group text (it was inserted after PBXFileReference section)
nse_uuid = re.search(r'([0-9A-F]{24}) /\* NotificationService \*/ = \{[^}]+path = NotificationService', txt).group(1)
print("NSE_GROUP UUID:", nse_uuid)

# Normalise to LF for easier regex, we'll restore CRLF at write time
txt = txt.replace("\r\n", "\n")

# Extract the full NSE group object (from UUID to closing };)
nse_pat = re.compile(
    r'\t\t' + nse_uuid + r' /\* NotificationService \*/ = \{.*?\n\t\t\};\n',
    re.S
)
m = nse_pat.search(txt)
if not m:
    print("ERROR: could not find NSE group block")
    sys.exit(1)
nse_block = m.group(0)
print("Found NSE block (%d chars)" % len(nse_block))

# 2. Remove it from its current (wrong) location
txt = txt[:m.start()] + txt[m.end():]
print("Removed from wrong location")

# 3. Insert it inside the PBXGroup section (after the opening marker)
group_marker = "/* Begin PBXGroup section */\n"
idx = txt.find(group_marker)
if idx == -1:
    print("ERROR: PBXGroup section not found")
    sys.exit(1)
insert_at = idx + len(group_marker)
txt = txt[:insert_at] + nse_block + txt[insert_at:]
print("Inserted into PBXGroup section")

# 4. Wire NSE group as a child of the main top-level group
# (the group that contains 97C146F01CF9000F007C117D /* Runner */)
main_group_uuid = re.search(
    r'([0-9A-F]{24}) = \{\s*isa = PBXGroup;\s*children = \([^)]*97C146F01CF9000F007C117D', txt, re.S
).group(1)
print("MAIN_GROUP UUID:", main_group_uuid)

# Add NSE_GROUP to main group's children list
# Find the children array of the main group and prepend the NSE uuid
main_group_children_pat = re.compile(
    main_group_uuid + r' = \{[^{]*children = \(', re.S
)
mc = main_group_children_pat.search(txt)
if not mc:
    print("ERROR: main group children not found")
    sys.exit(1)
insert_pos = mc.end()
txt = txt[:insert_pos] + ("\n\t\t\t\t%s /* NotificationService */," % nse_uuid) + txt[insert_pos:]
print("Added NSE_GROUP as child of main group")

# 5. Strip any "/* Begin/End PBXGroup section (NSE) */" comments we may have left
txt = re.sub(r'/\* Begin PBXGroup section \(NSE\) \*/\n', '', txt)
txt = re.sub(r'/\* End PBXGroup section \(NSE\) \*/\n', '', txt)

# 6. Write back (CRLF, no BOM)
txt = txt.replace("\n", "\r\n")
with open(PBXPROJ, "wb") as f:
    f.write(txt.encode("utf-8"))
print("Written OK (no BOM, CRLF)")
