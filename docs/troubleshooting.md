# Troubleshooting

## Tests are Incomplete and the banner says "no board lease in environment"

The fixture found no `IIO_URI` and could not start a session. Check, in order:

1. `labgrid.Session.isAvailable()` is `true`. If not, install labgrid-plugins or set
   `LG_ADI_LG_BIN` to the venv's `adi-lg`.
2. `getenv("LG_COORDINATOR")` is `host:20408`.
3. The board is not busy: `labgrid.Client().place("bq").acquired` is `""`. If someone holds it,
   the fixture waits `Wait` seconds, then gives up with `labgrid:boardUnavailable` → Incomplete.

## `labgrid:provisionFailed` ... 'XilinxDeviceJTAGAttributes' object has no attribute 'serial'

The `adi-lg` you are using is older than the lab's exporter configuration (the exporter sets a
JTAG cable `serial`, added in labgrid-plugins `b270919`). Install `adi-lg` from a current
checkout into a fresh venv and point `LG_ADI_LG_BIN` at it. The board was released; nothing to
clean up.

## `labgrid:coordinatorUnreachable`

The REST API (`labgrid.config.apiUrl()`, normally `http://<host>:8000/api`) did not answer. From
a shell: `curl http://<host>:8000/api/health`. If the gRPC port works but REST does not, set
`LG_API` explicitly.

## Python errors mentioning `libstdc++`, `GLIBCXX`, `libcurl` or OpenSSL in the adi-lg log

MATLAB exports its own `LD_LIBRARY_PATH` to child processes. `labgrid.Session` already strips it
(`env -u LD_LIBRARY_PATH`). If you run `adi-lg` yourself from MATLAB with `system`, do the same.

## A board stayed reserved after MATLAB crashed

The hold script watches the MATLAB PID and exits within a second of it disappearing; `adi-lg`
then releases. If the record is still there:

```matlab
labgrid.Session.reap(Client=labgrid.Client())
```

or, from a shell, `labgrid-client -x <coordinator> -p <place> release`.

## `labgrid.runTests` reports `total: 0`

`Part=`/`Tags=` selected nothing (a `labgrid:emptySelection` warning was printed). Check the
class's `BoardFixture` part spelling, and that the test folder is on the path.

## MATLAB exits with a segfault at the end of a `-batch` run

Known R2025b behaviour in `exit()` after the JUnit plugin has written its file. `labgrid.runTests`
does not call `exit()`; decide pass/fail from `labgrid-junit.xml` / `labgrid-summary.json`.

## `runtests` on Windows: "labgrid.Session needs a POSIX shell"

The interactive path is Linux/macOS only. Run under `adi-lg request --run` instead.
