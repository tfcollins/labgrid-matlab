# API reference

All names live in the `labgrid` namespace (`toolbox/+labgrid`).

## `labgrid.fixtures.BoardFixture`

`matlab.unittest.fixtures.Fixture`, meant for `SharedTestFixtures`.

```matlab
labgrid.fixtures.BoardFixture(part, Carrier="", Wait=1800, PowerDown=false)
```

| Member | Meaning |
|---|---|
| `Part`, `Carrier` | what the class needs; `""` part = any board the environment offers |
| `Wait`, `PowerDown` | forwarded to `labgrid.Session.request` on the interactive path |
| `Lease` | the `labgrid.Lease` in use after setup |
| `SetupDescription` | `labgrid board <place> (<part> on <carrier>) at <uri> [<source>]` |

Compatibility (`isCompatible`): equal `Part` and `Carrier`.

## `labgrid.runTests`

```matlab
results = labgrid.runTests(target, Part="", Carrier="", Tags=string.empty, ...
    JUnit="labgrid-junit.xml", Summary="labgrid-summary.json", ...
    FilterByAvailability=false, Client=[], Verbosity=2)
```

Returns `matlab.unittest.TestResult`. Never calls `exit()`. See [CI integration](ci.md) for the
summary schema.

## `labgrid.plugins.LabgridPlugin`

```matlab
labgrid.plugins.LabgridPlugin()                                  % banner to stdout
labgrid.plugins.LabgridPlugin(matlab.automation.streams.ToFile(f))
```

Reporting only: prints one banner per `runTestSuite`, appends
`Details.labgrid = struct(place, carrier, daughter, uri, source)` to each result that ran with a
lease in the environment.

## `labgrid.Session`

```matlab
s = labgrid.Session.request(part, Carrier="", Wait=1800, PowerDown=false, ...
        HoldTimeout=14400, BootBudget=600, LogFile="", Poll=0.5)
s.Lease  s.Part  s.Carrier  s.Pid  s.LogFile  s.Released
s.release()
labgrid.Session.isAvailable()        % adi-lg resolvable?
labgrid.Session.reap(Client=[])      % struct array: file, pid, place, action
```

`Pid` is the PID of a small shell wrapper that supervises `adi-lg` (forwards SIGTERM, records
the exit code); it lives exactly as long as `adi-lg` does.

## `labgrid.Lease`

Value class.

```matlab
labgrid.Lease(URI="", Place="", Carrier="", Daughter="", Tags=struct(), Source="")
labgrid.Lease.fromEnvironment()   % empty Lease array when IIO_URI is unset
lease.host()                      % "10.0.0.132" for "ip:10.0.0.132", else ""
lease.tag("daughter-board")       % place tag by original name ("" if absent)
lease.toEnvironment()             % struct: IIO_URI, LG_PLACE, LG_CARRIER, HW_CARRIER, HW_DAUGHTER
string(lease)
```

`Source` is `"env"` (hand-over from `adi-lg request --run`) or `"session"`.

## `labgrid.Client`

Read-only REST client (`matlab.net.http`), no login required for these endpoints.

```matlab
c = labgrid.Client(BaseURL="", Timeout=10, Transport=[])
c.health()                 % struct: status, coordinator_connected, coordinator_address
c.places()                 % struct array: name, tags, daughter, carrier, bootStrategy, hdlConfig,
                           %               acquired, acquiredUsername, reservation  ("" for null)
c.place("bq")
c.match("adrv9371", Carrier="")
                           % struct: satisfiable, place, image, strategy, runner, reason,
                           %         reservationFilter, flash
```

`BaseURL` defaults to `labgrid.config.apiUrl()`. `Transport` is `[status, body] = f(url)` for tests.

Errors: `labgrid:coordinatorUnreachable`, `labgrid:httpError` (status + FastAPI `detail` in the
message).

## `labgrid.config`

| Function | Source |
|---|---|
| `coordinator()` | `LG_COORDINATOR` (error `labgrid:noCoordinator` if unset) |
| `apiUrl()` | `LG_API`, else `http://<LG_COORDINATOR host>:8000`; always ends in `/api` |
| `adiLgBin()` | `LG_ADI_LG_BIN`, default `"adi-lg"` |
| `home()`, `sessionsDir()` | `LG_MATLAB_HOME`, default `~/.labgrid-matlab` (+ `/sessions`) |
| `leaseEnvVars()` | `["IIO_URI" "LG_PLACE" "LG_CARRIER" "HW_DAUGHTER" "HW_CARRIER"]` |

## Environment variables

| Variable | Read by | Meaning |
|---|---|---|
| `LG_COORDINATOR` | `config`, `adi-lg` | gRPC `host:port` of the coordinator |
| `LG_API` | `config` | REST base URL override |
| `LG_ADI_LG_BIN` | `Session` | path to `adi-lg` |
| `LG_MATLAB_HOME` | `Session` | state directory |
| `IIO_URI`, `LG_PLACE`, `LG_CARRIER`, `HW_DAUGHTER`, `HW_CARRIER` | `Lease`, fixture, plugin | the lease hand-over; exported by the fixture while active |

## Error identifiers

`labgrid:noCoordinator`, `labgrid:coordinatorUnreachable`, `labgrid:httpError`,
`labgrid:badResponse`, `labgrid:adiLgNotFound`, `labgrid:unsupportedPlatform`,
`labgrid:spawnFailed`, `labgrid:noMatchingBoard`, `labgrid:boardUnavailable`,
`labgrid:provisionFailed`, `labgrid:bootTimeout`, `labgrid:interrupted`, `labgrid:adiLgUsage`,
`labgrid:adiLgFailed`; warning `labgrid:emptySelection`.

## Files

| Path | Role |
|---|---|
| `toolbox/bin/lg-hold.sh` | hold script run by `adi-lg request --run` on the interactive path |
| `tests/+fakes/bin/adi-lg` | bash shim implementing the `request --run` contract for unit tests |
| `buildfile.m` | `buildtool test` / `testLive` / `package` |
