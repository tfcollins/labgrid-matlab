classdef LabgridPluginTest < matlab.unittest.TestCase
    % labgrid.plugins.LabgridPlugin — reporting-only runner plugin.

    methods (Test)
        function recordsLeaseInResultDetails(testCase)
            import matlab.unittest.TestRunner
            helpers.withLeaseEnv(testCase, "IIO_URI", "ip:10.0.0.132", "LG_PLACE", "bq", ...
                "LG_CARRIER", "zc706", "HW_DAUGHTER", "adrv9371");
            runner = TestRunner.withNoPlugins;
            runner.addPlugin(labgrid.plugins.LabgridPlugin);
            results = runner.run(testsuite("helpers.BoardConsumerTests"));
            d = results(1).Details.labgrid;
            testCase.verifyEqual(d.place, "bq");
            testCase.verifyEqual(d.uri, "ip:10.0.0.132");
            testCase.verifyEqual(d.carrier, "zc706");
            testCase.verifyEqual(d.daughter, "adrv9371");
        end

        function leavesDetailsAloneWithoutLease(testCase)
            import matlab.unittest.TestRunner
            helpers.withLeaseEnv(testCase);
            runner = TestRunner.withNoPlugins;
            runner.addPlugin(labgrid.plugins.LabgridPlugin);
            results = runner.run(testsuite("helpers.PlainTests"));
            testCase.verifyFalse(isfield(results(1).Details, "labgrid"));
        end

        function printsBannerNamingTheBoard(testCase)
            import matlab.unittest.TestRunner
            import matlab.automation.streams.ToFile
            helpers.withLeaseEnv(testCase, "IIO_URI", "ip:10.0.0.132", "LG_PLACE", "bq");
            out = fullfile(tempname + ".txt");
            testCase.addTeardown(@() delete(out));
            runner = TestRunner.withNoPlugins;
            runner.addPlugin(labgrid.plugins.LabgridPlugin(ToFile(out)));
            runner.run(testsuite("helpers.PlainTests"));
            txt = string(fileread(out));
            testCase.verifySubstring(txt, "bq");
            testCase.verifySubstring(txt, "ip:10.0.0.132");
        end
    end
end
