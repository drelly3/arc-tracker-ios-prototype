# Native simulator UI test screenshots

Workflow run: https://github.com/drelly3/arc-tracker-ios-prototype/actions/runs/45510681223

Captured by an XCUITest UI-test target injected into the Capacitor project during CI,
driving the real app shell on an iPhone simulator: gate, the first-run archetype
picker (choosing The Strategist), Start Here after the pick, the Archetypes tab,
Setup (saving a synthetic name + habit), the configured Today log line, and Progress.

The name "Native CI Test" and habit "Meditate for 10 minutes" are synthetic test data
that live only in the simulator's local storage. During this run the production API
host (animemindset.com) was pinned to 127.0.0.1 in the runner's /etc/hosts (verified
by a failing curl in the run log), so no request from the app could leave for
production. These are native simulator renders of the prototype web app inside the
Capacitor shell via the preview/sample key path. This does not test real sync,
real devices, the camera, or push.
