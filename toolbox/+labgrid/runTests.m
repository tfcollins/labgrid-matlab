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
    "junit", opts.JUnit);
writelines(jsonencode(summary, PrettyPrint=true), opts.Summary);
end
