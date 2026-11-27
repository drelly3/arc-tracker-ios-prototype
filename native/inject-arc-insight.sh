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
