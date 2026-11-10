# labgrid-matlab

`matlab.unittest` fixtures and a runner for hardware owned by a
[labgrid](https://labgrid.readthedocs.io/) coordinator.

The coordinator, through [labgrid-plugins](https://github.com/tfcollins/labgrid-plugins) and its
`adi-lg request` CLI, reserves, boots and verifies a board. MATLAB only *consumes* the booted
board: a shared fixture provides the libIIO URI, a runner plugin records which board ran, and a
`matlab -batch`-safe runner writes JUnit results without calling `exit()`.

## Install

```matlab
addpath("labgrid-matlab/toolbox")          % from a checkout
% or: matlab.addons.install("labgrid-matlab.mltbx")   (built by `buildtool package`)
```

Requirements: MATLAB R2023b+ (tested on R2025b). For the interactive path also `adi-lg`
(`pip install adi-labgrid-plugins`) on a POSIX host and `LG_COORDINATOR=host:20408`.

## Two ways in, one data model

**CI / wrapped.** labgrid boots first, MATLAB runs inside the reservation:

```bash
adi-lg request --part adrv9371 --run \
  "matlab -batch \"addpath('labgrid-matlab/toolbox'); labgrid.runTests('test', Part='adrv9371')\""
```

**Interactive.** MATLAB asks labgrid for a board and holds it for the session:

```matlab
setenv LG_COORDINATOR 10.0.0.41:20408
s = labgrid.Session.request("adrv9371");   % reserve + boot + verify iiod (minutes)
s.Lease.URI                                % "ip:10.0.0.132"
% ... run tests, talk to the device ...
s.release();                               % or clear s
```

Test classes declare the board they need with a shared fixture. For its lifetime the fixture
exports `IIO_URI`, `LG_PLACE`, `LG_CARRIER`, `HW_DAUGHTER`, `HW_CARRIER`, so existing tests that
read `getenv('IIO_URI')` work unchanged, and CI and interactive runs look identical to test code:

```matlab
classdef (SharedTestFixtures={labgrid.fixtures.BoardFixture("adrv9371")}) ...
        AD9371Tests < matlab.unittest.TestCase
    methods (Test)
        function capture(testCase)
            rx = adi.AD9371.Rx(uri=getenv("IIO_URI"));
            testCase.verifyNotEmpty(rx());
        end
    end
end
```

How the fixture resolves a board:

| Situation | Result |
|---|---|
| `IIO_URI` set by `adi-lg request --run` and part matches (or no part tag) | uses it; never released by MATLAB |
| `IIO_URI` set but for a different part | tests **Incomplete** |
| no `IIO_URI`, `adi-lg` available | `labgrid.Session.request(part)`; released after the last class using it |
| no `IIO_URI`, no `adi-lg` / no coordinator / board busy | tests **Incomplete** |
| no matching board exists, or boot fails | tests **Failed** |

One board serves every class in a suite that asks for the same part/carrier. Select tests by
board with `matlab.unittest.selectors.HasSharedTestFixture(labgrid.fixtures.BoardFixture("adrv9371"))`
or `labgrid.runTests(..., Part="adrv9371")`.

## API

| | |
|---|---|
| `labgrid.fixtures.BoardFixture(part, Carrier=, Wait=, PowerDown=)` | shared fixture described above |
| `labgrid.runTests(target, Part=, Carrier=, Tags=, JUnit=, Summary=, FilterByAvailability=, Verbosity=)` | build, select, run; writes JUnit XML + `labgrid-summary.json`; returns `TestResult`; never `exit()`s |
| `labgrid.plugins.LabgridPlugin` | reporting-only `TestRunnerPlugin`: banner + `Details.labgrid` (place, carrier, daughter, uri) per result |
| `labgrid.Session.request(part, Carrier=, Wait=, PowerDown=, HoldTimeout=, BootBudget=, LogFile=)` | hold a booted board; `.Lease`, `.release()`, `.LogFile` |
| `labgrid.Session.reap(Client=)` | clean up session records left by crashed MATLABs |
| `labgrid.Lease` | value: `URI`, `Place`, `Carrier`, `Daughter`, `Source`; `fromEnvironment()`, `host()`, `tag("daughter-board")` |
| `labgrid.Client(BaseURL=)` | read-only REST: `health()`, `places()`, `place(name)`, `match(part, Carrier=)` |
| `labgrid.config` | env-var names and resolution (`apiUrl()`, `coordinator()`, `adiLgBin()`, `home()`) |

Error identifiers: `labgrid:noMatchingBoard`, `labgrid:boardUnavailable`, `labgrid:provisionFailed`,
`labgrid:bootTimeout`, `labgrid:adiLgNotFound`, `labgrid:coordinatorUnreachable`, `labgrid:httpError`.

### Environment variables

| Variable | Meaning |
|---|---|
| `LG_COORDINATOR` | gRPC `host:port` of the coordinator (what `adi-lg` uses); REST URL is derived as `http://host:8000/api` |
| `LG_API` | override the REST base URL |
| `LG_ADI_LG_BIN` | path to `adi-lg` (default: `adi-lg` on `PATH`) |
| `LG_MATLAB_HOME` | state directory (default `~/.labgrid-matlab`; session records live in `sessions/`) |
| `IIO_URI`, `LG_PLACE`, `LG_CARRIER`, `HW_DAUGHTER`, `HW_CARRIER` | the lease hand-over from `adi-lg request --run`, also exported by the fixture |

### How the interactive path holds a board

`labgrid.Session` runs `adi-lg request --part <p> --run "bash toolbox/bin/lg-hold.sh ..."`.
The hold script writes the exported lease to a JSON file and blocks until `release()` creates a
sentinel file, the MATLAB process dies, or `HoldTimeout` (4 h) elapses; when it exits, `adi-lg`
releases the coordinator reservation. The CLI is launched with `env -u LD_LIBRARY_PATH` so the
Python stack does not pick up MATLAB's bundled libraries. Linux/macOS only; on Windows use the
CI form. `runInParallel` is not supported (each worker would request its own board).

## Development

```bash
matlab -batch "buildtool test"       # unit tests, no hardware (fake adi-lg shim in tests/+fakes/bin)
matlab -batch "buildtool testLive"   # needs LG_COORDINATOR, adi-lg and a free board (LG_TEST_PART, default adrv9009)
matlab -batch "buildtool package"    # releases/labgrid-matlab.mltbx
scripts/remote-matlab-test.sh test   # same, on a lab host with a licensed MATLAB (see the script)
```

See `examples/` for a minimal consumer and `examples/migrate-transceiver-toolbox.md` for the
one-line migration of existing ADI toolbox test suites. Design notes:
`docs/superpowers/specs/2026-11-09-labgrid-matlab-design.md`.

License: Apache-2.0.
