# Interactive sessions

## Hold a board from the prompt

```matlab
setenv("LG_COORDINATOR", "10.0.0.41:20408");
s = labgrid.Session.request("adrv9371", Carrier="zc706", Wait=900);
%  -> blocks while adi-lg reserves, boots and verifies iiod (typically 2-5 minutes)
s.Lease                 % Place "bq", URI "ip:10.0.0.132", Daughter "adrv9371", Source "session"
s.LogFile               % adi-lg's full output, useful while a boot is slow
rx = adi.AD9371.Rx(uri=s.Lease.URI);
...
s.release();            % or: clear s
```

Options: `Wait` (seconds to queue for a free board, default 1800), `PowerDown` (power off on
release), `BootBudget` (seconds allowed for the boot after the wait, default 600),
`HoldTimeout` (backstop, default 4 h), `LogFile`.

## How it works

`labgrid.Session` runs

```
adi-lg request --part adrv9371 --carrier zc706 --wait 900 \
   --run "bash <toolbox>/bin/lg-hold.sh <lease.json> <release> <matlab-pid> <hold-seconds> 0.5"
```

in the background (stdout/stderr to `LogFile`). When the board is booted, `adi-lg` starts the
hold script with the lease exported; the script writes `lease.json` and then loops until one of:

| Condition | Script exit | Meaning |
|---|---|---|
| `<release>` file exists | 0 | `s.release()` was called |
| the MATLAB PID is gone | 2 | MATLAB crashed or was killed; the board is not leaked |
| `hold-seconds` elapsed | 3 | backstop |

When the script exits, `adi-lg` releases the reservation. `release()` creates the sentinel, waits
up to 30 s for `adi-lg` to exit, and sends `SIGTERM` if it has not (adi-lg releases on SIGTERM
too). Deleting the `Session` object (`clear s`, end of `-batch`) calls `release()`.

`adi-lg` is launched with `env -u LD_LIBRARY_PATH` so Python does not load MATLAB's bundled
`libstdc++`/OpenSSL.

## Failures

| Error identifier | Cause |
|---|---|
| `labgrid:adiLgNotFound` | `adi-lg` not on `PATH` and `LG_ADI_LG_BIN` unset/wrong |
| `labgrid:noMatchingBoard` | coordinator has no place for that part/carrier (exit 10) |
| `labgrid:boardUnavailable` | all matching places are busy and `Wait` ran out (exit 11) |
| `labgrid:provisionFailed` | boot or iiod verification failed (exit 12); message has the log tail |
| `labgrid:bootTimeout` | no lease within `Wait + BootBudget`; adi-lg was stopped |
| `labgrid:interrupted` | adi-lg got SIGINT/SIGTERM (exit 130) |
| `labgrid:unsupportedPlatform` | Windows |

## Session records and cleanup

Each live session writes `~/.labgrid-matlab/sessions/<place>-<pid>.json` (override the base
directory with `LG_MATLAB_HOME`). After a crash:

```matlab
labgrid.Session.reap()                       % remove records whose process is gone
labgrid.Session.reap(Client=labgrid.Client()) % also stop sessions whose place the coordinator shows as free
```

Each returned row says what happened: `removed-dead`, `killed-orphan`, `kept`, `removed-corrupt`.
