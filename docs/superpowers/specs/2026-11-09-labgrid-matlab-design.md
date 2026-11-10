# labgrid-matlab design (2026-11-09)

Approved plan-mode design, copied verbatim from the plan file for in-repo reference.

## Context

**Goal.** The labgrid coordinator (10.0.0.41, REST `:8000/api`, gRPC `:20408`) owns and boots lab boards. MATLAB should only *consume* an already-booted board: run `matlab.unittest` suites against it and release it when done. The user wants this as a reusable MATLAB "test plugin" instead of per-toolbox hand-rolled code. New repo: `~/dev/labgrid-matlab` (currently empty, not yet `git init`).

**What exists today (reuse, don't rebuild).**
- `adi-lg request --part <p> [--carrier <c>] --mode uri --wait N [--power-down] --run "<cmd>"` (labgrid-plugins `adi_lg_plugins/tools/request_cli.py:87-194`, `adi_lg_plugins/request/core.py:186-309`) matches → reserves → acquires → boots → verifies iiod → runs `<cmd>` via `subprocess.Popen(shell=True)` with `IIO_URI`, `LG_PLACE`, `LG_CARRIER`, `HW_DAUGHTER`, `HW_CARRIER` exported → releases when the child exits. SIGTERM/SIGINT to `adi-lg` terminates the child and still releases. Exit codes: 10 no match, 11 unavailable, 12 provision/boot failure, 130 interrupted (`request/errors.py`). **Without `--run` it prints the URI and releases immediately.** No CLI, REST, or MCP path holds a booted board for a separate process; the REST API has no boot endpoint (the API itself shells out to `adi-lg` for health checks, `coordinator/api/app/board_health/runner.py:99`).
- Reusable CI workflow `labgrid-plugins/.github/workflows/matlab-hw-request.yml` already wraps `matlab -batch "...runHWTests('<board>')"` inside `adi-lg request --run` and parses the JUnit XML because **MATLAB R2025b segfaults in `exit()` after writing JUnit**. `adi-lg-hw-ci matlab-matrix` + `test/hw_ci/board_map.yaml` map place tags → `matlab_board`.
- Toolbox tests (TransceiverToolbox / HighSpeedConverterToolbox `test/HardwareTests.m`): abstract `uri`; `TestClassSetup` overwrites it from `getenv('IIO_URI')`; `CheckDevice` → `assumeFail` when no device (Incomplete). `runHWTests(board)` = big `switch` → `testsuite` + `selectIf` + `TestRunner.withTextOutput` + `XMLPlugin.producingJUnitFormat` + `exit(code)`. No fixtures; one reporting `TestRunnerPlugin` (`test/LTE_Tests/details_recording_plugin.m`, pattern for ours). No HTTP client code; no `py.*`.
- Live REST (verified 2026-11-09): `GET /api/health`, `/api/places`, `/api/places/{name}`, `/api/places/{name}/env-yaml`, `/api/match?part=&carrier=` are unauthenticated; mutating + board-health need cookie login. `/api/match` → `{satisfiable, reservation_filter, image, strategy, place, runner, flash, reason}`. Place `tags` keys are hyphenated (`daughter-board`, `boot-strategy`) → `jsondecode` renames via `matlab.lang.makeValidName`; `/api/places` items with differing tag sets decode to a **cell**, not a struct array.
- Local: MATLAB R2025b `/usr/local/MATLAB/R2025b/bin/matlab`. `~/.local/bin/adi-lg` is stale (no `health-check`); for live verification install labgrid-plugins from `~/dev/labgrid-plugins` into a venv (`uv venv ~/.cache/labgrid-matlab/venv && uv pip install -e ~/dev/labgrid-plugins`). Free boards now: `bq` (adrv9371/zc706), `mini2` (ad9081/zcu102), `nemo` (adrv9009/zc706), `nuc` (daq3/vcu118), `lablp`, `tron`.

**MATLAB framework facts that shape the design** (from reading R2025b sources): `runtests` accepts no plugins → anything that must work from plain `runtests` has to be a *fixture*. `matlab.unittest.selectors.Selector` is not a public extension point → select by part with `HasSharedTestFixture(BoardFixture("<part>"))`, which dispatches on `isCompatible`. `Fixture` has `assumeFail` (marks every test using the fixture Incomplete). Java `ProcessBuilder.environment()` is a JVM-startup snapshot and dies under `-nojvm` → use `system()`. MATLAB exports its own `LD_LIBRARY_PATH` to children, which breaks Python grpc/cryptography → launch `adi-lg` with `env -u LD_LIBRARY_PATH`.

## Design

**Principles (my calls; user opted out of Q&A):**
1. MATLAB never boots hardware; it delegates to `adi-lg request`. No Python inside MATLAB.
2. Two entry paths, one data model. **(A) CI / wrapped:** `adi-lg request --run "matlab -batch ..."` → package reads env vars. **(B) Interactive:** MATLAB spawns `adi-lg request --run "bash lg-hold.sh ..."` and keeps that child alive for the life of a `labgrid.Session`; release = sentinel file → child exits → `adi-lg` releases. Test code cannot tell A from B because the fixture exports the same env vars.
3. Acquisition lives in the **shared fixture** (framework-managed lifetime, works with `runtests`); the **TestRunnerPlugin** is reporting-only.
4. REST client is read-only in v1 (`/health`, `/places`, `/places/{name}`, `/match`); no login.
5. Runner never calls `exit()`; it writes JUnit + a summary JSON and CI reads those (existing convention).
6. Linux/macOS only for path B (bash hold script); `Session` errors clearly on `ispc`. `runInParallel` unsupported in v1 (detect `getCurrentTask()`, error).
7. Standalone `+labgrid` namespace (not `+adi`). Packaged with `matlab.addons.toolbox.ToolboxOptions` via `buildfile.m`, no `.prj`.

**Repo layout**
```
toolbox/
  +labgrid/
    Lease.m                 value class: Place, Carrier, Daughter, URI, Tags(struct), Source("env"|"session"); fromEnvironment(); tag(name); isempty
    Client.m                REST read client; ctor (BaseURL=, Transport=fn handle for tests); health(), places(), place(name), match(part, Carrier=)
    Session.m               handle; static request(part, opts) → Session; Lease; release(); delete; static reap()
    runTests.m              matlab -batch entry: suite → select → run (plugins) → JUnit + summary; returns TestResult; no exit()
    config.m                env-var names + resolution: LG_COORDINATOR → API URL (host:8000), LG_API override, LG_ADI_LG_BIN
    +fixtures/BoardFixture.m    Fixture(Part, Carrier=, Wait=, PowerDown=); env lease or Session; exports env vars; isCompatible on Part+Carrier
    +plugins/LabgridPlugin.m    TestRunnerPlugin: banner + ResultDetails.append("labgrid", struct(place,carrier,daughter,uri))
    +internal/
      Backend.m               abstract: start(cmd, logFile) → pid; isAlive(pid); kill(pid)   (v2 swap point for `adi-lg request --hold`)
      ShellBackend.m          system("env -u LD_LIBRARY_PATH nohup adi-lg ... > log 2>&1 & echo $!")
      decodePlaces.m          jsondecode → normalize cell/struct → Lease-like structs; tag lookup via makeValidName
      exitCodeToError.m       10/11/12/130 → labgrid:noMatchingBoard / boardUnavailable / provisionFailed / interrupted
  bin/lg-hold.sh            writes lease JSON, then loops: exit if release-file exists, parent MATLAB pid dead, or max-hold elapsed
tests/
  +fakes/bin/adi-lg         bash shim: parses --part/--carrier/--run, exports fake env, runs child; env knobs FAKE_ADI_LG_EXIT, FAKE_ADI_LG_DELAY
  recorded/*.json           /api/places, /api/match (satisfiable + not) captured from 10.0.0.41
  LeaseTest.m ClientTest.m SessionTest.m BoardFixtureTest.m RunTestsTest.m LabgridPluginTest.m   (unit; no hardware)
  live/LiveCoordinatorTest.m live/LiveBoardTest.m   (TestTags "live"; need coordinator / a free board)
examples/
  ExampleBoardTests.m       minimal consumer class: SharedTestFixtures = {labgrid.fixtures.BoardFixture("adrv9371")}
  migrate-transceiver-toolbox.md   one-line migration recipe for HardwareTests subclasses + runHWTests replacement
buildfile.m                 matlab.buildtool: "test" (unit only), "testLive", "package" (ToolboxOptions → releases/labgrid-matlab.mltbx)
.github/workflows/ci.yml    self-hosted MATLAB runner (label hw-coordinator or a MATLAB-capable runner): buildtool test; live tests manual dispatch only
README.md  LICENSE (Apache-2.0, matches labgrid-plugins)  CLAUDE.md
```

**Key behaviours**
- `Lease.fromEnvironment()`: empty Lease if `IIO_URI` unset; else URI/Place/Carrier/Daughter from `IIO_URI`/`LG_PLACE`/`LG_CARRIER`/`HW_DAUGHTER`, Source="env". `lease.tag("daughter-board")` applies `matlab.lang.makeValidName` to the key.
- `Session.request(part, Carrier=, Wait=1800, PowerDown=false, HoldTimeout=hours(4), BootBudget=seconds(600), LogFile=)`: on `ispc` → error `labgrid:unsupportedPlatform`. Builds `adi-lg request --part P [--carrier C] --wait W [--power-down] --run "bash <toolbox>/bin/lg-hold.sh <lease.json> <release> <matlabPid> <holdSecs>"`; starts via `ShellBackend`; polls for `<lease.json>` until `Wait + BootBudget`; if child exits first → `exitCodeToError` with last 20 log lines; writes `~/.labgrid-matlab/sessions/<token>.json` (pid, place, started). `release()`: touch `<release>`, wait ≤30 s, then `kill -TERM` (adi-lg still releases on SIGTERM), remove session file. `reap()`: for each session file whose pid is dead or whose place `/api/places/{name}` shows `acquired == null`, delete; for live orphans, `kill -TERM`.
- `BoardFixture(Part, Carrier=, ...)`: ctor stores args only (class-load time; no I/O). `setup`: `env = Lease.fromEnvironment()`; if non-empty and (Part=="" or env.Daughter==Part) → use it (Source env, never released); elseif non-empty but mismatched → `assumeFail("env lease is <X>, fixture wants <Part>")`; else `Session.request(...)`, `addTeardown(@release)`. Error policy on session failure: `boardUnavailable` → `assumeFail` (Incomplete, like today's no-device path); `noMatchingBoard`/`provisionFailed` → rethrow (must be red). Then `setenv` the five vars for the fixture lifetime (`addTeardown` restores previous values) so legacy `HardwareTests.UpdateURIFromEnv` works untouched. `isCompatible`: same Part & Carrier. `SetupDescription` includes place + URI.
- `LabgridPlugin`: `runTestSuite` prints banner (coordinator URL, lease place/URI if env lease present); `runTest` appends `labgrid` struct to `ResultDetails` (reads current env lease, which the fixture has exported). Pattern: `details_recording_plugin.m`.
- `runTests(target, Part=, Carrier=, Tags=, JUnit="labgrid-junit.xml", Summary="labgrid-summary.json", FilterByAvailability=false, Verbosity=)`: `testsuite(target)`; if `Part` given → `selectIf(HasSharedTestFixture(BoardFixture(Part,Carrier)))`; if `FilterByAvailability` → enumerate distinct `BoardFixture`s in `suite.SharedTestFixtures`, `Client.match` each, drop unmatched with one log line each; `TestRunner.withTextOutput` + `LabgridPlugin` + `DiagnosticsValidationPlugin` + `XMLPlugin.producingJUnitFormat`; write summary `{total, passed, failed, incomplete, place, uri, coordinator}`; return results. Document: all-Incomplete = "no board" (CI counts as success today).
- `Client`: `matlab.net.http.RequestMessage` + `HTTPOptions(ConnectTimeout=10)`; non-2xx → `labgrid:http:<status>`; connection failure → `labgrid:coordinatorUnreachable`. `Transport` injection = function handle `(uri) → (statusCode, bodyText)` so unit tests feed recorded JSON.

