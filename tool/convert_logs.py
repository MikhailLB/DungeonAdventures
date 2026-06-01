import re, os

# Files that use debugPrint in the hub/main layer.
targets = [
    ("lib/main.dart", "hub/infra/hub_log.dart"),
    ("lib/hub/infra/hub_dispatch.dart", "hub_log.dart"),
    ("lib/hub/infra/install_tracker.dart", "hub_log.dart"),
    ("lib/hub/infra/signal_relay.dart", "hub_log.dart"),
    ("lib/hub/infra/cold_tap_reader.dart", "hub_log.dart"),
    ("lib/hub/pages/vault_splash.dart", "../infra/hub_log.dart"),
]

for path, imp in targets:
    if not os.path.exists(path):
        print("SKIP (missing):", path)
        continue
    txt = open(path, encoding="utf-8").read()
    if "debugPrint(" not in txt:
        print("no debugPrint:", path)
        continue
    n = txt.count("debugPrint(")
    txt = txt.replace("debugPrint(", "hubLog(() => ")
    # add import after the last existing import line
    if "hub_log.dart" not in txt:
        lines = txt.split("\n")
        last_import = 0
        for i, l in enumerate(lines):
            if l.startswith("import "):
                last_import = i
        lines.insert(last_import + 1, "import '%s';" % imp)
        txt = "\n".join(lines)
    open(path, "w", encoding="utf-8").write(txt)
    print("converted %d in %s" % (n, path))

print("done")
