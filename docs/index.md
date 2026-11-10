# labgrid-matlab documentation

`labgrid-matlab` lets `matlab.unittest` suites consume boards that a
[labgrid](https://labgrid.readthedocs.io/) coordinator owns, boots and verifies. MATLAB never
touches power, SD muxes or JTAG: it receives a booted board (a libIIO URI plus place metadata),
runs tests, and hands the board back.

| Page | Read it when |
|---|---|
| [Getting started](getting-started.md) | first install; running the example against a lab board |
| [Writing tests](writing-tests.md) | declaring which board a test class needs; migrating existing `HardwareTests` suites |
| [CI integration](ci.md) | wiring `labgrid.runTests` into `adi-lg request --run` / GitHub Actions; reading results |
| [Interactive sessions](interactive.md) | holding a board from the MATLAB prompt; how the hold works; cleaning up |
| [API reference](api.md) | every public class, function, option, error identifier and environment variable |
| [Troubleshooting](troubleshooting.md) | the errors you will meet and what they mean |
| [Design](../docs/superpowers/specs/2026-11-09-labgrid-matlab-design.md) | why it is built this way |

## The model in one picture

```
            CI / wrapped                                  interactive
 ─────────────────────────────────          ────────────────────────────────────────
 adi-lg request --part X --run "matlab …"    MATLAB: labgrid.Session.request("X")
   │ reserve → boot → verify iiod              │ spawns adi-lg request --part X --run lg-hold.sh
   │ exports IIO_URI, LG_PLACE, …              │ hold script writes lease.json, then blocks
   ▼                                           ▼
 labgrid.fixtures.BoardFixture("X")  ◀── same fixture, same env vars ──▶  tests read getenv("IIO_URI")
   │                                           │
   ▼ (child exits → adi-lg releases)           ▼ release() → sentinel file → hold exits → adi-lg releases
```

Both paths end in the same place: `IIO_URI` and friends are set while the fixture is active, and
the coordinator reservation is released when the last test class that needed the board is done.
