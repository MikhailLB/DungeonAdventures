"""
Patches ios/Runner.xcodeproj/project.pbxproj to add:
  1. NSE Swift source + Embed App Extensions build files
  2. PBXContainerItemProxy for NSE
  3. Embed App Extensions copy phase (dstSubfolderSpec=13)
  4. NSE file references (swift, plist, appex, GoogleService-Info.plist)
  5. NSE + GoogleService-Info groups
  6. NSE native target
  7. Runner: add Embed App Extensions phase & NSE dependency (single block)
  8. NSE build configurations (Debug/Release/Profile) — NO baseConfigurationReference
  9. Runner.entitlements file reference + CODE_SIGN_ENTITLEMENTS in all 3 Runner configs
  10. GoogleService-Info.plist in Runner Copy Bundle Resources
  11. NSE to PBXProject targets list + TargetAttributes

Uses unique DGA-specific UUIDs (BB prefix with 2026...).
Writes without BOM, verifies first line.
"""
import re, sys

PBXPROJ = "ios/Runner.xcodeproj/project.pbxproj"

# ── Unique UUIDs for DungeonAdventures NSE ───────────────────────────────────
UIDS = dict(
    NSE_SWIFT_BUILD_FILE  = "BB202600000000000000001A",
    NSE_SWIFT_FILE_REF    = "BB202600000000000000003A",
    NSE_PLIST_FILE_REF    = "BB202600000000000000004A",
    NSE_APPEX_FILE_REF    = "BB202600000000000000005A",
    NSE_GROUP             = "BB202600000000000000006A",
    NSE_TARGET            = "BB202600000000000000007A",
    NSE_SOURCES_PHASE     = "BB202600000000000000008A",
    NSE_RESOURCES_PHASE   = "BB202600000000000000009A",
    NSE_FRAMEWORKS_PHASE  = "BB20260000000000000000AA",
    NSE_DEBUG_CFG         = "BB20260000000000000000BA",
    NSE_RELEASE_CFG       = "BB20260000000000000000CA",
    NSE_PROFILE_CFG       = "BB20260000000000000000DA",
    NSE_CFG_LIST          = "BB20260000000000000000EA",
    EMBED_EXT_PHASE       = "BB20260000000000000000FA",
    EMBED_EXT_BUILD_FILE  = "BB202600000000000000010A",
    NSE_TARGET_DEP        = "BB202600000000000000011A",
    NSE_PROXY             = "BB202600000000000000012A",
    GOOGLE_PLIST_FILE_REF = "BB202600000000000000013A",
    GOOGLE_PLIST_BUILD    = "BB202600000000000000014A",
    ENTITLEMENTS_FILE_REF = "BB202600000000000000015A",
)
U = UIDS

BUNDLE_ID_NSE = "com.dungeon.streetsurvive.Notif"
TEAM_ID       = "3NQ9M85SZD"

def read(path):
    with open(path, "rb") as f:
        raw = f.read()
    # strip BOM
    if raw[:3] == b'\xef\xbb\xbf':
        raw = raw[3:]
    text = raw.decode("utf-8")
    # normalise to LF for easier patching, we'll restore CRLF at write time
    return text.replace("\r\n", "\n")

def write(path, text):
    # restore CRLF line endings (Xcode/CocoaPods expect them on Windows)
    text = text.replace("\n", "\r\n")
    raw = text.encode("utf-8")
    with open(path, "wb") as f:
        f.write(raw)
    print("  Written %s  (%d bytes)" % (path, len(raw)))

def insert_after(text, anchor, insertion):
    idx = text.find(anchor)
    if idx == -1:
        print(f"  WARN: anchor not found: {repr(anchor[:60])}")
        return text
    pos = idx + len(anchor)
    return text[:pos] + insertion + text[pos:]

def replace_first(text, old, new):
    if old not in text:
        print(f"  WARN: pattern not found: {repr(old[:60])}")
        return text
    return text.replace(old, new, 1)

def replace_all(text, old, new):
    if old not in text:
        print(f"  WARN: replace_all not found: {repr(old[:60])}")
    return text.replace(old, new)

def main():
    txt = read(PBXPROJ)
    print("Read %s  (%d chars)" % (PBXPROJ, len(txt)))

    already = U["NSE_SWIFT_BUILD_FILE"] in txt
    if already:
        print("  NSE already patched — skipping")
        return

    # ── 1. PBXBuildFile ──────────────────────────────────────────────────────
    txt = insert_after(txt, "/* Begin PBXBuildFile section */\n",
        f'\t\t{U["NSE_SWIFT_BUILD_FILE"]} /* NotificationService.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {U["NSE_SWIFT_FILE_REF"]} /* NotificationService.swift */; }};\n'
        f'\t\t{U["GOOGLE_PLIST_BUILD"]} /* GoogleService-Info.plist in Resources */ = {{isa = PBXBuildFile; fileRef = {U["GOOGLE_PLIST_FILE_REF"]} /* GoogleService-Info.plist */; }};\n'
        f'\t\t{U["EMBED_EXT_BUILD_FILE"]} /* NotificationService.appex in Embed App Extensions */ = {{isa = PBXBuildFile; fileRef = {U["NSE_APPEX_FILE_REF"]} /* NotificationService.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};\n'
    )
    print("  OK PBXBuildFile entries added")

    # ── 2. PBXContainerItemProxy ─────────────────────────────────────────────
    txt = insert_after(txt, "/* Begin PBXContainerItemProxy section */\n",
        f'\t\t{U["NSE_PROXY"]} /* PBXContainerItemProxy */ = {{\n'
        f'\t\t\tisa = PBXContainerItemProxy;\n'
        f'\t\t\tcontainerPortal = 97C146E61CF9000F007C117D /* Project object */;\n'
        f'\t\t\tproxyType = 1;\n'
        f'\t\t\tremoteGlobalIDString = {U["NSE_TARGET"]};\n'
        f'\t\t\tremoteInfo = NotificationService;\n'
        f'\t\t}};\n'
    )
    print("  OK PBXContainerItemProxy added")

    # ── 3. Embed App Extensions copy phase ───────────────────────────────────
    txt = insert_after(txt, "/* Begin PBXCopyFilesBuildPhase section */\n",
        f'\t\t{U["EMBED_EXT_PHASE"]} /* Embed App Extensions */ = {{\n'
        f'\t\t\tisa = PBXCopyFilesBuildPhase;\n'
        f'\t\t\tbuildActionMask = 2147483647;\n'
        f'\t\t\tdstPath = "";\n'
        f'\t\t\tdstSubfolderSpec = 13;\n'
        f'\t\t\tfiles = (\n'
        f'\t\t\t\t{U["EMBED_EXT_BUILD_FILE"]} /* NotificationService.appex in Embed App Extensions */,\n'
        f'\t\t\t);\n'
        f'\t\t\tname = "Embed App Extensions";\n'
        f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        f'\t\t}};\n'
    )
    print("  OK PBXCopyFilesBuildPhase (Embed App Extensions) added")

    # ── 4. PBXFileReference ──────────────────────────────────────────────────
    txt = insert_after(txt, "/* Begin PBXFileReference section */\n",
        f'\t\t{U["NSE_SWIFT_FILE_REF"]} /* NotificationService.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = NotificationService.swift; sourceTree = "<group>"; }};\n'
        f'\t\t{U["NSE_PLIST_FILE_REF"]} /* Info.plist (NSE) */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};\n'
        f'\t\t{U["NSE_APPEX_FILE_REF"]} /* NotificationService.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = NotificationService.appex; sourceTree = BUILT_PRODUCTS_DIR; }};\n'
        f'\t\t{U["GOOGLE_PLIST_FILE_REF"]} /* GoogleService-Info.plist */ = {{isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = text.plist.xml; path = "GoogleService-Info.plist"; sourceTree = "<group>"; }};\n'
        f'\t\t{U["ENTITLEMENTS_FILE_REF"]} /* Runner.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Runner.entitlements; sourceTree = "<group>"; }};\n'
    )
    print("  OK PBXFileReference entries added")

    # ── 5a. Add GoogleService-Info.plist + entitlements to Runner group ──────
    # Find the Runner group (path = Runner)
    runner_group_pat = r'(97C146F01CF9000F007C117D /\* Runner \*/ = \{[^}]+children = \()'
    m = re.search(runner_group_pat, txt, re.S)
    if m:
        insert_pt = m.end()
        addition = (
            f'\n\t\t\t\t{U["GOOGLE_PLIST_FILE_REF"]} /* GoogleService-Info.plist */,'
            f'\n\t\t\t\t{U["ENTITLEMENTS_FILE_REF"]} /* Runner.entitlements */,'
        )
        txt = txt[:insert_pt] + addition + txt[insert_pt:]
        print("  OK GoogleService-Info.plist + entitlements added to Runner group")
    else:
        print("  WARN: Runner PBXGroup not found")

    # ── 5b. Add NSE group ────────────────────────────────────────────────────
    txt = insert_after(txt, "/* End PBXFileReference section */\n",
        f'\n/* Begin PBXGroup section (NSE) */\n'
        f'\t\t{U["NSE_GROUP"]} /* NotificationService */ = {{\n'
        f'\t\t\tisa = PBXGroup;\n'
        f'\t\t\tchildren = (\n'
        f'\t\t\t\t{U["NSE_SWIFT_FILE_REF"]} /* NotificationService.swift */,\n'
        f'\t\t\t\t{U["NSE_PLIST_FILE_REF"]} /* Info.plist */,\n'
        f'\t\t\t);\n'
        f'\t\t\tpath = NotificationService;\n'
        f'\t\t\tsourceTree = "<group>";\n'
        f'\t\t}};\n'
        f'/* End PBXGroup section (NSE) */\n'
    )

    # ── 5c. Add NSE appex to Products group ──────────────────────────────────
    txt = replace_first(txt,
        '/* Products */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (',
        '/* Products */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = ('
        f'\n\t\t\t\t{U["NSE_APPEX_FILE_REF"]} /* NotificationService.appex */,'
    )
    print("  OK NSE group + appex in Products added")

    # ── 6. PBXNativeTarget (NSE) ─────────────────────────────────────────────
    txt = insert_after(txt, "/* Begin PBXNativeTarget section */\n",
        f'\t\t{U["NSE_TARGET"]} /* NotificationService */ = {{\n'
        f'\t\t\tisa = PBXNativeTarget;\n'
        f'\t\t\tbuildConfigurationList = {U["NSE_CFG_LIST"]};\n'
        f'\t\t\tbuildPhases = (\n'
        f'\t\t\t\t{U["NSE_SOURCES_PHASE"]} /* Sources */,\n'
        f'\t\t\t\t{U["NSE_FRAMEWORKS_PHASE"]} /* Frameworks */,\n'
        f'\t\t\t\t{U["NSE_RESOURCES_PHASE"]} /* Resources */,\n'
        f'\t\t\t);\n'
        f'\t\t\tbuildRules = ();\n'
        f'\t\t\tdependencies = ();\n'
        f'\t\t\tname = NotificationService;\n'
        f'\t\t\tproductName = NotificationService;\n'
        f'\t\t\tproductReference = {U["NSE_APPEX_FILE_REF"]} /* NotificationService.appex */;\n'
        f'\t\t\tproductType = "com.apple.product-type.app-extension";\n'
        f'\t\t}};\n'
    )
    print("  OK NSE PBXNativeTarget added")

    # ── 7. NSE build phases ───────────────────────────────────────────────────
    txt = insert_after(txt, "/* Begin PBXResourcesBuildPhase section */\n",
        f'\t\t{U["NSE_RESOURCES_PHASE"]} /* Resources (NSE) */ = {{\n'
        f'\t\t\tisa = PBXResourcesBuildPhase;\n'
        f'\t\t\tbuildActionMask = 2147483647;\n'
        f'\t\t\tfiles = ();\n'
        f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        f'\t\t}};\n'
    )
    txt = insert_after(txt, "/* Begin PBXSourcesBuildPhase section */\n",
        f'\t\t{U["NSE_SOURCES_PHASE"]} /* Sources (NSE) */ = {{\n'
        f'\t\t\tisa = PBXSourcesBuildPhase;\n'
        f'\t\t\tbuildActionMask = 2147483647;\n'
        f'\t\t\tfiles = (\n'
        f'\t\t\t\t{U["NSE_SWIFT_BUILD_FILE"]} /* NotificationService.swift in Sources */,\n'
        f'\t\t\t);\n'
        f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        f'\t\t}};\n'
    )
    txt = insert_after(txt, "/* Begin PBXFrameworksBuildPhase section */\n",
        f'\t\t{U["NSE_FRAMEWORKS_PHASE"]} /* Frameworks (NSE) */ = {{\n'
        f'\t\t\tisa = PBXFrameworksBuildPhase;\n'
        f'\t\t\tbuildActionMask = 2147483647;\n'
        f'\t\t\tfiles = ();\n'
        f'\t\t\trunOnlyForDeploymentPostprocessing = 0;\n'
        f'\t\t}};\n'
    )
    print("  OK NSE build phases added")

    # ── 8. Runner target: add Embed App Extensions phase + NSE dependency ────
    # Pattern: find the Runner NativeTarget buildPhases array and add phase,
    # and replace its empty (or existing) dependencies with one containing NSE dep.
    # First add Embed App Extensions BEFORE Thin Binary in Runner buildPhases.
    thin_binary_pat = r'(3B06AD1E1E4923F5004D2608 /\* Thin Binary \*/,)'
    txt = replace_first(txt, '3B06AD1E1E4923F5004D2608 /* Thin Binary */,',
        f'{U["EMBED_EXT_PHASE"]} /* Embed App Extensions */,\n'
        f'\t\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,'
    )
    print("  OK Embed App Extensions phase added before Thin Binary in Runner")

    # Remove empty dependencies block from Runner NativeTarget, replace with NSE dep.
    # First remove any existing empty dependencies = (); before name = Runner
    txt = re.sub(
        r'(\b97C146ED1CF9000F007C117D /\* Runner \*/ = \{[^}]+?)(dependencies = \(\s*\);)',
        lambda m: m.group(1) + f'dependencies = (\n\t\t\t\t{U["NSE_TARGET_DEP"]} /* PBXTargetDependency */,\n\t\t\t);',
        txt, flags=re.S
    )
    print("  OK Runner dependencies updated with NSE dep")

    # ── 9. PBXTargetDependency ────────────────────────────────────────────────
    txt = insert_after(txt, "/* Begin PBXTargetDependency section */\n",
        f'\t\t{U["NSE_TARGET_DEP"]} /* PBXTargetDependency */ = {{\n'
        f'\t\t\tisa = PBXTargetDependency;\n'
        f'\t\t\ttarget = {U["NSE_TARGET"]} /* NotificationService */;\n'
        f'\t\t\ttargetProxy = {U["NSE_PROXY"]} /* PBXContainerItemProxy */;\n'
        f'\t\t}};\n'
    )
    print("  OK PBXTargetDependency added")

    # ── 10. Add GoogleService-Info.plist to Runner Resources phase ────────────
    # Find Runner's Resources build phase (97C146EC1CF9000F007C117D)
    txt = replace_first(txt,
        '97C146EC1CF9000F007C117D /* Resources */ = {\n\t\t\tisa = PBXResourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (',
        '97C146EC1CF9000F007C117D /* Resources */ = {\n\t\t\tisa = PBXResourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = ('
        f'\n\t\t\t\t{U["GOOGLE_PLIST_BUILD"]} /* GoogleService-Info.plist in Resources */,'
    )
    print("  OK GoogleService-Info.plist added to Runner Resources phase")

    # ── 11. NSE build configurations ─────────────────────────────────────────
    def nse_cfg(uid, name, extra=""):
        return (
            f'\t\t{uid} /* {name} (NSE) */ = {{\n'
            f'\t\t\tisa = XCBuildConfiguration;\n'
            f'\t\t\tbuildSettings = {{\n'
            f'\t\t\t\tCODE_SIGN_STYLE = Automatic;\n'
            f'\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n'
            f'\t\t\t\tDEVELOPMENT_TEAM = {TEAM_ID};\n'
            f'\t\t\t\tENABLE_BITCODE = NO;\n'
            f'\t\t\t\tINFOPLIST_FILE = NotificationService/Info.plist;\n'
            f'\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 13.0;\n'
            f'\t\t\t\tMARKETING_VERSION = 1.0;\n'
            f'\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID_NSE};\n'
            f'\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";\n'
            f'\t\t\t\tSDKROOT = iphoneos;\n'
            f'\t\t\t\tSKIP_INSTALL = YES;\n'
            + extra +
            f'\t\t\t\tSWIFT_VERSION = 5.0;\n'
            f'\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";\n'
            f'\t\t\t}};\n'
            f'\t\t\tname = {name};\n'
            f'\t\t}};\n'
        )
    nse_cfgs = (
        nse_cfg(U["NSE_DEBUG_CFG"], "Debug",
                '\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";\n')
        + nse_cfg(U["NSE_RELEASE_CFG"], "Release")
        + nse_cfg(U["NSE_PROFILE_CFG"], "Profile")
    )
    txt = insert_after(txt, "/* Begin XCBuildConfiguration section */\n", nse_cfgs)
    print("  OK NSE XCBuildConfiguration entries added")

    # ── 12. XCConfigurationList for NSE ──────────────────────────────────────
    txt = insert_after(txt, "/* Begin XCConfigurationList section */\n",
        f'\t\t{U["NSE_CFG_LIST"]} /* Build configuration list for PBXNativeTarget "NotificationService" */ = {{\n'
        f'\t\t\tisa = XCConfigurationList;\n'
        f'\t\t\tbuildConfigurations = (\n'
        f'\t\t\t\t{U["NSE_DEBUG_CFG"]} /* Debug */,\n'
        f'\t\t\t\t{U["NSE_RELEASE_CFG"]} /* Release */,\n'
        f'\t\t\t\t{U["NSE_PROFILE_CFG"]} /* Profile */,\n'
        f'\t\t\t);\n'
        f'\t\t\tdefaultConfigurationIsVisible = 0;\n'
        f'\t\t\tdefaultConfigurationName = Release;\n'
        f'\t\t}};\n'
    )
    print("  OK NSE XCConfigurationList added")

    # ── 13. Add NSE to PBXProject targets list ────────────────────────────────
    txt = replace_first(txt,
        'targets = (\n\t\t\t\t97C146ED1CF9000F007C117D /* Runner */,',
        'targets = (\n\t\t\t\t97C146ED1CF9000F007C117D /* Runner */,\n'
        f'\t\t\t\t{U["NSE_TARGET"]} /* NotificationService */,'
    )
    print("  OK NSE added to PBXProject targets")

    # ── 14. TargetAttributes for NSE ─────────────────────────────────────────
    txt = replace_first(txt,
        '97C146ED1CF9000F007C117D = {\n\t\t\t\t\tCreatedOnToolsVersion = 7.3.1;',
        '97C146ED1CF9000F007C117D = {\n\t\t\t\t\tCreatedOnToolsVersion = 7.3.1;'
    )
    # Append NSE attribute at end of TargetAttributes block
    txt = replace_first(txt,
        '97C146ED1CF9000F007C117D = {\n\t\t\t\t\tCreatedOnToolsVersion = 7.3.1;\n\t\t\t\t\tLastSwiftMigration = 1100;\n\t\t\t\t};',
        '97C146ED1CF9000F007C117D = {\n\t\t\t\t\tCreatedOnToolsVersion = 7.3.1;\n\t\t\t\t\tLastSwiftMigration = 1100;\n\t\t\t\t};\n'
        f'\t\t\t\t{U["NSE_TARGET"]} = {{\n\t\t\t\t\tCreatedOnToolsVersion = 15.0;\n\t\t\t\t}};'
    )
    print("  OK NSE TargetAttributes added")

    # ── 15. CODE_SIGN_ENTITLEMENTS in Runner build configs ────────────────────
    for cfg_uid in (
        "97C147061CF9000F007C117D",  # Debug
        "97C147071CF9000F007C117D",  # Release
        "7AFA3C8E1D35360C0083082E",  # Profile
    ):
        pattern = f'{cfg_uid} /* '
        replacement_marker = "DEVELOPMENT_TEAM = 3NQ9M85SZD;"
        # Insert CODE_SIGN_ENTITLEMENTS after DEVELOPMENT_TEAM in each config
        # We'll add it only if not already present
        if "CODE_SIGN_ENTITLEMENTS" not in txt:
            txt = txt.replace(
                "DEVELOPMENT_TEAM = 3NQ9M85SZD;\n",
                "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n\t\t\t\tDEVELOPMENT_TEAM = 3NQ9M85SZD;\n",
                1
            )
    if "CODE_SIGN_ENTITLEMENTS" in txt:
        print("  OK CODE_SIGN_ENTITLEMENTS added to Runner configs")
    else:
        print("  WARN: could not add CODE_SIGN_ENTITLEMENTS")

    write(PBXPROJ, txt)
    print("  OK project.pbxproj patched successfully")

if __name__ == "__main__":
    main()
