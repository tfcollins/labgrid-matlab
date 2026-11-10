# labgrid-matlab

MATLAB test plugin for hardware owned by a [labgrid](https://labgrid.readthedocs.io/) coordinator.

The coordinator (via [labgrid-plugins](https://github.com/tfcollins/labgrid-plugins) and its
`adi-lg request` CLI) reserves, boots and verifies a board. MATLAB only *consumes* the booted
board: a `matlab.unittest` shared fixture provides the libIIO URI, a runner plugin records
which board ran, and a `matlab -batch`-safe runner writes JUnit results without calling `exit()`.

## Two ways in, one data model

**CI / wrapped** — labgrid boots first, MATLAB runs inside the reservation:

```bash
adi-lg request --part adrv9371 --run \
  "matlab -batch \"addpath(genpath('toolbox')); labgrid.runTests('test', Part='adrv9371')\""
```

**Interactive** — MATLAB asks labgrid for a board and holds it for the session:

```matlab
s = labgrid.Session.request("adrv9371");   % spawns adi-lg request, waits for boot
s.Lease.URI                                % "ip:10.0.0.132"
% ... run tests, poke the device ...
s.release();                               % board goes back to the coordinator
```

Test classes declare the board they need with a shared fixture; the fixture exports
`IIO_URI` (and `LG_PLACE`, `LG_CARRIER`, `HW_DAUGHTER`, `HW_CARRIER`) for its lifetime, so
existing tests that read `getenv('IIO_URI')` work unchanged:

```matlab
classdef (SharedTestFixtures={labgrid.fixtures.BoardFixture("adrv9371")}) ...
        AD9371Tests < matlab.unittest.TestCase
    methods (Test)
        function capture(testCase)
            rx = adi.AD9371.Rx(uri=getenv("IIO_URI"));
            data = rx();
            testCase.verifyNotEmpty(data);
        end
    end
end
```

Status: under construction. See `docs/superpowers/specs/` for the design.

## Development

Unit tests (no hardware, needs a licensed MATLAB R2025b):

```bash
matlab -batch "buildtool test"
# or, from a host without a MATLAB license, run on a lab host:
scripts/remote-matlab-test.sh test
```

License: Apache-2.0.
