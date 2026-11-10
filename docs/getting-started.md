# Getting started

## Prerequisites

- MATLAB R2025b (the release this toolbox is tested on). R2023b+ should work but is untested.
- Network access to the coordinator's REST API (`http://<coordinator>:8000/api`).
- For the interactive path only: a POSIX host (Linux/macOS), `bash`, and the `adi-lg` CLI from
  [labgrid-plugins](https://github.com/tfcollins/labgrid-plugins):

  ```bash
  uv venv ~/.venvs/labgrid && uv pip install --python ~/.venvs/labgrid/bin/python \
      "adi-labgrid-plugins @ git+https://github.com/tfcollins/labgrid-plugins.git"
  ```

  The CLI must be at least as new as the lab's exporters (see
  [Troubleshooting](troubleshooting.md#provisionfailed-xilinxdevicejtagattributes-has-no-attribute-serial)).

## Install the toolbox

From a checkout:

```matlab
addpath("/path/to/labgrid-matlab/toolbox");
```

Or build and install the `.mltbx`:

```bash
matlab -batch "buildtool package"       # writes releases/labgrid-matlab.mltbx
```
```matlab
matlab.addons.install("releases/labgrid-matlab.mltbx");
```

## Point it at your coordinator

```matlab
setenv("LG_COORDINATOR", "10.0.0.41:20408");    % gRPC host:port, same value adi-lg uses
c = labgrid.Client();
c.health()                                        % status: "ok", coordinator_connected: true
c.places()                                        % one struct per place: name, daughter, carrier, acquired, ...
c.match("adrv9371")                               % satisfiable, place, image, reason
```

If your `adi-lg` is not on `PATH`:

```matlab
setenv("LG_ADI_LG_BIN", "/home/me/.venvs/labgrid/bin/adi-lg");
```

## Run the example on a real board

Interactive (the fixture asks the coordinator for the board, waits for the boot, runs, releases):

```matlab
runtests("examples/ExampleBoardTests.m")
```

CI-style (labgrid boots first, MATLAB runs inside the reservation):

```bash
adi-lg request --part adrv9371 --run \
  "matlab -batch \"addpath('toolbox'); labgrid.runTests('examples', Part='adrv9371')\""
```

Either way you should see a banner like

```
[labgrid] board bq (adrv9371 on zc706) at ip:10.0.0.132 [session] (coordinator: 10.0.0.41:20408)
```

followed by the test output, `labgrid-junit.xml` and `labgrid-summary.json` in the working
directory.

## Next

- [Writing tests](writing-tests.md) to make your own classes board-aware.
- [CI integration](ci.md) to run them from GitHub Actions.
