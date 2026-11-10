function results = runTests(target, opts)
% labgrid.runTests  Run a test suite against a labgrid-booted board; safe for `matlab -batch`.
%
%   results = labgrid.runTests(target, Name=Value)
%
%   target   anything testsuite() accepts (folder, class name(s), package) or a TestSuite.
%   Part     only run tests whose BoardFixture asks for this part (via HasSharedTestFixture).
%   Carrier  carrier to pair with Part when selecting.
%   Tags     keep only tests carrying all of these TestTags.
%   JUnit    JUnit XML output path (default "labgrid-junit.xml").
%   Summary  JSON summary path (default "labgrid-summary.json"): total/passed/failed/incomplete,
%            place/uri/daughter/carrier of the environment lease, coordinator.
%   Verbosity  text output detail 0..4 (default 2).
%   FilterByAvailability  ask the coordinator (GET /api/match) whether each board the suite's
%            BoardFixtures need is live; drop the tests of boards that are not (default false).
%            Dropped boards are listed under "skipped" in the summary JSON.
%   Client   labgrid.Client to use for the availability check (default labgrid.Client()).
%
%   This function never calls exit(): MATLAB R2025b can crash in exit() after writing the JUnit
%   file, so CI must read pass/fail from the JUnit XML or the summary JSON, not the exit code.
arguments
    target
    opts.Part (1,1) string = ""
    opts.Carrier (1,1) string = ""
    opts.Tags string = string.empty
    opts.JUnit (1,1) string = "labgrid-junit.xml"
    opts.Summary (1,1) string = "labgrid-summary.json"
    opts.Verbosity (1,1) double = 2
    opts.FilterByAvailability (1,1) logical = false
    opts.Client = []
end
import matlab.unittest.TestRunner
import matlab.unittest.plugins.XMLPlugin
import matlab.unittest.plugins.DiagnosticsValidationPlugin
import matlab.unittest.selectors.HasSharedTestFixture
import matlab.unittest.selectors.HasTag

if isa(target, "matlab.unittest.TestSuite")
    suite = target;
else
    suite = testsuite(target);
end
if strlength(opts.Part) > 0
    suite = suite.selectIf(HasSharedTestFixture( ...
        labgrid.fixtures.BoardFixture(opts.Part, Carrier=opts.Carrier)));
end
for t = opts.Tags(:)'
    suite = suite.selectIf(HasTag(t));
end

skipped = struct("part", {}, "carrier", {}, "tests", {}, "reason", {});
if opts.FilterByAvailability
    client = opts.Client;
    if isempty(client)
        client = labgrid.Client();
    end
    for f = boardFixturesIn(suite)
        m = client.match(f.Part, Carrier=f.Carrier);
        if m.satisfiable
            continue
        end
        before = numel(suite);
        suite = suite.selectIf(~HasSharedTestFixture(f));
        dropped = before - numel(suite);
        label = f.Part;
        if strlength(f.Carrier) > 0
            label = label + " on " + f.Carrier;
        end
        fprintf("[labgrid] skipping %d test(s) needing %s: %s\n", dropped, label, m.reason);
        skipped(end+1) = struct("part", f.Part, "carrier", f.Carrier, "tests", dropped, "reason", m.reason); %#ok<AGROW>
    end
end

if opts.Verbosity > 0
    runner = TestRunner.withTextOutput(OutputDetail=opts.Verbosity);
else
    runner = TestRunner.withNoPlugins;
end
runner.addPlugin(labgrid.plugins.LabgridPlugin);
runner.addPlugin(DiagnosticsValidationPlugin);
runner.addPlugin(XMLPlugin.producingJUnitFormat(opts.JUnit));

results = runner.run(suite);

lease = labgrid.Lease.fromEnvironment();
if isempty(lease)
    lease = labgrid.Lease();
end
summary = struct( ...
    "total", numel(results), ...
    "passed", nnz([results.Passed]), ...
    "failed", nnz([results.Failed]), ...
    "incomplete", nnz([results.Incomplete]), ...
    "duration", sum([results.Duration]), ...
    "place", lease.Place, "uri", lease.URI, "daughter", lease.Daughter, "carrier", lease.Carrier, ...
    "coordinator", string(getenv(labgrid.config.EnvCoordinator)), ...
    "junit", opts.JUnit, ...
    "skipped", skipped);
writelines(jsonencode(summary, PrettyPrint=true), opts.Summary);
end

function fixtures = boardFixturesIn(suite)
% Distinct (Part, Carrier) BoardFixtures used by the suite, as a row of fixture objects.
fixtures = labgrid.fixtures.BoardFixture.empty(1, 0);
for i = 1:numel(suite)
    for f = suite(i).SharedTestFixtures
        if ~isa(f, "labgrid.fixtures.BoardFixture") || strlength(f.Part) == 0
            continue
        end
        if any(arrayfun(@(g) g.Part == f.Part && g.Carrier == f.Carrier, fixtures))
            continue
        end
        fixtures(end+1) = f; %#ok<AGROW>
    end
end
end
