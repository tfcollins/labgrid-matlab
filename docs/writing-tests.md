# Writing tests

## Declare the board a class needs

Add `labgrid.fixtures.BoardFixture` as a shared test fixture. The argument is the coordinator's
`daughter-board` tag (what `adi-lg request --part` matches on): `ad9361`, `adrv9002`,
`adrv9371`, `ad9081`, `daq3`, ...

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

Options:

```matlab
labgrid.fixtures.BoardFixture("ad9081", Carrier="zcu102")       % pin the carrier
labgrid.fixtures.BoardFixture("daq3", Wait=600, PowerDown=true) % interactive path: queue time, power off after
labgrid.fixtures.BoardFixture()                                 % "whatever board the environment hands me"
```

While the fixture is active, `IIO_URI`, `LG_PLACE`, `LG_CARRIER`, `HW_DAUGHTER` and `HW_CARRIER`
are set (and restored afterwards). Test code reads them with `getenv`, or uses
`labgrid.Lease.fromEnvironment()` for a typed view:

```matlab
lease = labgrid.Lease.fromEnvironment();
lease.URI        % "ip:10.0.0.132"
lease.host()     % "10.0.0.132"
lease.Place      % "bq"
lease.Daughter   % "adrv9371"
```

## What the fixture does on setup

| Situation | Outcome |
|---|---|
| `IIO_URI` already set (by `adi-lg request --run`) and part/carrier match or are untagged | adopts it; MATLAB never releases it |
| `IIO_URI` set but `HW_DAUGHTER` / carrier differ from the fixture | every test in the class is **Incomplete** (assumption failure) |
| no `IIO_URI`, `adi-lg` found | `labgrid.Session.request(part, ...)`; released when the last class using the fixture finishes |
| no `IIO_URI`; no `adi-lg`, no `LG_COORDINATOR`, or the board is busy | **Incomplete** |
| no matching board exists, or the boot fails | **Failed** (the error carries the `adi-lg` log tail) |

"Incomplete, not Failed" for the no-board cases mirrors the existing ADI toolbox convention
(`CheckDevice` → `assumeFail`): running the suite on a laptop without a lab never goes red.

## One board, many classes

Fixtures with equal `Part` and `Carrier` are *compatible*: the framework sets the fixture up
once before the first class that needs it and tears it down after the last. A suite that needs
two different boards acquires them one after the other, never both at once.

Select tests by board:

```matlab
import matlab.unittest.selectors.HasSharedTestFixture
suite = testsuite("test");
suite = suite.selectIf(HasSharedTestFixture(labgrid.fixtures.BoardFixture("adrv9371")));
% or, carrier-agnostic:
labgrid.runTests("test", Part="adrv9371");
```

## Migrating an existing `HardwareTests` suite

TransceiverToolbox / HighSpeedConverterToolbox classes already read `getenv('IIO_URI')` in a
`TestClassSetup`. Add the fixture and nothing else changes:

```matlab
% before
classdef AD9371Tests < HardwareTests
% after
classdef (SharedTestFixtures={labgrid.fixtures.BoardFixture("adrv9371")}) AD9371Tests < HardwareTests
```

`runHWTests(board)` (the big `switch` + `exit()`) can be replaced by
`labgrid.runTests("test", Part=getenv("HW_DAUGHTER"), JUnit="HWTestResults.xml")`; see
[CI integration](ci.md). The full recipe is in `examples/migrate-transceiver-toolbox.md`.

## Not supported

- `runInParallel`: each worker would request its own board. Run serially.
- Windows for the interactive path (the hold script is bash). The CI path works anywhere
  `adi-lg` runs.
