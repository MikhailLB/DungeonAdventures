import sys
sys.stdout.reconfigure(encoding='utf-8')
src = open('tool/patch_pbxproj.py', encoding='utf-8').read()
src = src.replace('\u2713', 'OK')
open('tool/patch_pbxproj.py', 'w', encoding='utf-8').write(src)
print('done')
