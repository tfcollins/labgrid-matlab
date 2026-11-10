# Migrating a toolbox test suite to labgrid-matlab

Target: TransceiverToolbox / HighSpeedConverterToolbox `test/` suites, which today read
`getenv('IIO_URI')` in `HardwareTests.UpdateURIFromEnv` and are launched by
`runHWTests(board)` inside `adi-lg request --run` (`matlab-hw-request.yml`).

## 1. Declare the board a test class needs (one line)

```matlab
% before
classdef AD9371Tests < HardwareTests

% after
classdef (SharedTestFixtures={labgrid.fixtures.BoardFixture("adrv9371")}) AD9371Tests < HardwareTests
```

Nothing else in the class changes. The fixture exports `IIO_URI`, `LG_PLACE`, `LG_CARRIER`,
`HW_DAUGHTER`, `HW_CARRIER` for its lifetime, so `UpdateURIFromEnv` keeps working:

- Under `adi-lg request --run ...` (CI) the fixture adopts the hand-over. If the hand-over is
  for a different part than the class asks for, the class is **Incomplete**, not failed.
- Interactively (no `IIO_URI` set) the fixture runs `adi-lg request` itself and releases the
  board when the last class using it finishes. No `adi-lg` on the machine → Incomplete.

The part name must match the coordinator place tag `daughter-board` (what `adi-lg request
--part` matches on): `ad9361`, `adrv9002`, `adrv9371`, `ad9081`, ...

## 2. Replace `runHWTests(board)` (optional)

`runHWTests` keeps a `switch` from device-tree board names to class-name substrings and calls
`exit()`. With fixtures, selection by board is structural:

```matlab
% matlab -batch "addpath(genpath('hdl')); addpath(genpath('test')); addpath('labgrid-matlab/toolbox'); ..."
labgrid.runTests("test", Part=getenv("HW_DAUGHTER"), JUnit="HWTestResults.xml");
```

`labgrid.runTests` never calls `exit()` (R2025b crashes there after writing JUnit); CI reads
`HWTestResults.xml` or `labgrid-summary.json` exactly as `matlab-hw-request.yml` does today.
`FilterByAvailability=true` drops classes whose board the coordinator cannot offer right now.

## 3. Interactive bring-up at the MATLAB prompt

```matlab
setenv LG_COORDINATOR 10.0.0.41:20408
s = labgrid.Session.request("adrv9371");    % reserve + boot + verify iiod; minutes
rx = adi.AD9371.Rx(uri=s.Lease.URI);
...
s.release();                                % or clear s
```
If MATLAB dies, the hold script notices within seconds and the board is released.
`labgrid.Session.reap()` cleans up stale session records (`~/.labgrid-matlab/sessions`).
