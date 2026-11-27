#!/bin/bash
# Adds the on-device insight plugin to the generated iOS project (run after `npx cap add ios`).
set -euo pipefail
cp native/ArcInsightPlugin.swift ios/App/App/ArcInsightPlugin.swift
cat > /tmp/inject_plugin.rb <<'RUBY'
require 'xcodeproj'
proj = Xcodeproj::Project.open('ios/App/App.xcodeproj')
target = proj.targets.find { |t| t.name == 'App' } or abort 'App target not found'
group = proj.main_group.find_subpath('App', true)
ref = group.new_file('ArcInsightPlugin.swift')
target.add_file_references([ref])
proj.save
RUBY
RUBY_BIN=$(head -1 "$(command -v pod)" | sed 's/^#!//')
"$RUBY_BIN" /tmp/inject_plugin.rb
SB=$(find ios/App/App -name Main.storyboard | head -1)
echo "storyboard: $SB"
grep -n "CAPBridgeViewController" "$SB"
sed -i '' -e 's/customClass="CAPBridgeViewController"/customClass="ArcBridgeViewController"/' -e 's/customModule="Capacitor"/customModule="App"/' -e 's/customModuleProvider="target"/customModuleProvider="target"/' "$SB"
grep -n "ArcBridgeViewController" "$SB"
grep -q 'customClass="ArcBridgeViewController"' "$SB"
# Also register the plugin class through the bridge's package class list (the route installed plugins use),
# so the plugin does not depend only on the storyboard class swap.
CFG=ios/App/App/capacitor.config.json
python3 - "$CFG" <<'PY'
import json, sys
p = sys.argv[1]
c = json.load(open(p))
l = c.setdefault('packageClassList', [])
if 'ArcInsightPlugin' not in l:
    l.append('ArcInsightPlugin')
json.dump(c, open(p, 'w'), indent=2)
print('packageClassList:', c['packageClassList'])
PY
{ echo "storyboard class lines:"; grep -n "customClass" "$SB" | head -5; echo "packageClassList:"; python3 -c "import json;print(json.load(open('$CFG')).get('packageClassList'))"; } > /tmp/inject-info.txt
