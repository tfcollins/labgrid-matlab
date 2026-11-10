# CLAUDE.md — labgrid-matlab

MATLAB toolbox (`toolbox/+labgrid`) that lets `matlab.unittest` suites consume boards booted by a
labgrid coordinator. Design spec: `docs/superpowers/specs/2026-11-09-labgrid-matlab-design.md`.

## Ground rules
- MATLAB never boots hardware. Booting is `adi-lg request` (Python CLI from
  https://github.com/tfcollins/labgrid-plugins, checkout at `~/dev/labgrid-plugins`). No `py.*`.
- The runner never calls `exit()` — MATLAB R2025b segfaults in `exit()` after writing JUnit. CI
  decides pass/fail from the JUnit XML / `labgrid-summary.json`.
- Acquisition lives in `labgrid.fixtures.BoardFixture` (shared fixture). `labgrid.plugins.LabgridPlugin`
  is reporting-only. Select tests by board with `HasSharedTestFixture(BoardFixture("<part>"))`.
- Spawn `adi-lg` with `env -u LD_LIBRARY_PATH` (MATLAB's libstdc++ breaks Python grpc).
- TDD: write the failing MATLAB test first (`tests/*Test.m`), watch it fail, then implement.

## Running tests
- `matlab -batch "buildtool test"` — unit tests only (tag `live` excluded). Fake `adi-lg` shim lives in
  `tests/+fakes/bin/`.
- `matlab -batch "buildtool testLive"` — needs coordinator `10.0.0.41` and a free board. Long; use the
  watch-build skill, never foreground polling. On nemo use the CI venv's CLI, which matches the
  exporters: `LG_COORDINATOR=10.0.0.41:20408 LG_ADI_LG_BIN=$HOME/.cache/matlab-hw-request/venv/bin/adi-lg
  LG_TEST_PART=adrv9009` (the stale `~/.local/bin/adi-lg`, labgrid 25.0.1, cannot boot the current rigs).
- No licensed MATLAB on this workstation: `scripts/remote-matlab-test.sh [task]` rsyncs the repo to
  nemo (`/mnt/onetb/scratch/labgrid-matlab`) and runs `buildtool` there with
  `/mnt/onetb/MATLAB/R2025b/bin/matlab`.

## Coordinator facts
REST `http://10.0.0.41:8000/api` (GET `/health`, `/places`, `/places/{name}`, `/match?part=&carrier=`
are unauthenticated). gRPC `10.0.0.41:20408` (`LG_COORDINATOR`). Recorded responses for tests:
`tests/recorded/*.json`.
