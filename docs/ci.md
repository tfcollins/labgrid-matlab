# CI integration

## The contract

`adi-lg request` (labgrid-plugins) does everything hardware-related, then runs your command:

```bash
adi-lg request --part adrv9371 [--carrier zc706] --wait 1800 [--power-down] \
  --run "matlab -batch \"addpath('toolbox'); labgrid.runTests('test', Part='adrv9371')\""
```

- It matches a live board (`GET /api/match`), reserves and acquires it, boots it, verifies
  `iiod`, and exports `IIO_URI`, `LG_PLACE`, `LG_CARRIER`, `HW_DAUGHTER`, `HW_CARRIER` to the child.
- When the child exits, the board is released (and powered down with `--power-down`).
- Its own exit codes: `10` no matching board, `11` unavailable, `12` boot/provision failure,
  `130` interrupted; otherwise the child's exit code.

## `labgrid.runTests`

```matlab
results = labgrid.runTests(target, ...
    Part="adrv9371", Carrier="", Tags=[], ...
    JUnit="labgrid-junit.xml", Summary="labgrid-summary.json", ...
    FilterByAvailability=false, Verbosity=2);
```

- `target` is anything `testsuite` accepts (folder, class names, package) or a `TestSuite`.
- `Part` keeps only classes whose `BoardFixture` asks for that part (carrier-agnostic unless
  `Carrier` is given). An empty selection raises `warning("labgrid:emptySelection", ...)` and
  still writes a summary with `total: 0`.
- Runs with `TestRunner.withTextOutput`, `labgrid.plugins.LabgridPlugin`,
  `DiagnosticsValidationPlugin` and `XMLPlugin.producingJUnitFormat(JUnit)`.
- **Never calls `exit()`.** MATLAB R2025b can crash inside `exit()` after writing the JUnit file,
  so the process exit code is not trustworthy. Decide pass/fail from the files.

### Summary JSON

```json
{
  "total": 12, "passed": 11, "failed": 0, "incomplete": 1, "duration": 83.2,
  "place": "bq", "uri": "ip:10.0.0.132", "daughter": "adrv9371", "carrier": "zc706",
  "coordinator": "10.0.0.41:20408", "junit": "labgrid-junit.xml",
  "skipped": [ {"part": "ad9081", "carrier": "zcu102", "tests": 4, "reason": "no live place for 'ad9081'"} ]
}
```

`failed` counts results with `Failed == true` (errored tests count as both failed and
incomplete). `skipped` is always an array. The board fields come from the per-result details the
plugin records, so they are filled on both the CI and interactive paths.

A minimal shell verdict:

```bash
python3 - labgrid-summary.json <<'PY'
import json, sys; s = json.load(open(sys.argv[1]))
print(f"{s['total']} tests, {s['passed']} passed, {s['failed']} failed, {s['incomplete']} incomplete on {s['place']}")
sys.exit(2 if s["failed"] else 0)       # all-incomplete == "no board" == not red, by convention
PY
```

### Filtering by availability

For a suite that spans several boards, `FilterByAvailability=true` asks the coordinator once per
distinct `(Part, Carrier)` fixture and drops the classes whose board is not live right now,
listing them under `skipped`. It needs the REST API (`LG_COORDINATOR` or `LG_API`).

## GitHub Actions

labgrid-plugins ships a reusable workflow, `matlab-hw-request.yml`, that discovers boards from a
`board_map.yaml`, runs one leg per board on the right self-hosted runner, wraps MATLAB in
`adi-lg request --run`, and parses the JUnit. Its `run-matlab.sh` step can call
`labgrid.runTests` instead of `runHWTests`:

```bash
"$MATLAB_BIN" -batch "cd('$GITHUB_WORKSPACE'); addpath(genpath('hdl')); addpath(genpath('test')); \
  addpath('labgrid-matlab/toolbox'); \
  labgrid.runTests('test', Part=getenv('HW_DAUGHTER'), JUnit='${MATLAB_BOARD}_HWTestResults.xml')"
```

This repository's own `.github/workflows/ci.yml` runs `buildtool test` on a self-hosted MATLAB
runner on every push and, on manual dispatch with `live=true`, `buildtool testLive` against the
coordinator (`vars.LG_COORDINATOR`, `vars.LG_TEST_PART`, `vars.MATLAB_BIN`).

## Result details for dashboards

Every `TestResult` carries `Details.labgrid = struct(place, carrier, daughter, uri, source)`.
Prism uploads or custom reporters can use it to tag results with the board that ran them.
