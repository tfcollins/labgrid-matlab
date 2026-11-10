classdef RunTestsTest < matlab.unittest.TestCase
    % labgrid.runTests — matlab -batch entry point; writes JUnit + summary, never exits.

    properties
        Dir
    end

    methods (TestMethodSetup)
        function tempDir(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            testCase.Dir = testCase.applyFixture(TemporaryFolderFixture).Folder;
        end
    end

    methods (Test)
        function writesJUnitAndSummary(testCase)
            helpers.withLeaseEnv(testCase, "IIO_URI", "ip:10.0.0.132", "LG_PLACE", "bq", ...
                "LG_CARRIER", "zc706", "HW_DAUGHTER", "adrv9371");
            junit = fullfile(testCase.Dir, "j.xml");
            summary = fullfile(testCase.Dir, "s.json");
            results = labgrid.runTests("helpers.BoardConsumerTests", JUnit=junit, Summary=summary, ...
                Verbosity=0);
            testCase.verifyClass(results, "matlab.unittest.TestResult");
            testCase.verifyTrue(isfile(junit));
            s = jsondecode(fileread(summary));
            testCase.verifyEqual(s.total, 2);
            testCase.verifyEqual(s.passed, 2);
            testCase.verifyEqual(s.failed, 0);
            testCase.verifyEqual(s.incomplete, 0);
            testCase.verifyEqual(string(s.place), "bq");
            testCase.verifyEqual(string(s.uri), "ip:10.0.0.132");
        end

        function countsFailuresAndIncompletes(testCase)
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            helpers.withLeaseEnv(testCase);   % no board -> BoardConsumerTests incomplete
            testCase.applyFixture(EnvironmentVariableFixture("LG_ADI_LG_BIN", "/nonexistent/adi-lg"));
            summary = fullfile(testCase.Dir, "s.json");
            labgrid.runTests(["helpers.PlainTests", "helpers.BoardConsumerTests"], ...
                JUnit=fullfile(testCase.Dir, "j.xml"), Summary=summary, Verbosity=0);
            s = jsondecode(fileread(summary));
            testCase.verifyEqual(s.total, 4);
            testCase.verifyEqual(s.passed, 1);
            testCase.verifyEqual(s.failed, 1);
            testCase.verifyEqual(s.incomplete, 2);
        end

        function partSelectsOnlyMatchingFixtures(testCase)
            helpers.withLeaseEnv(testCase, "IIO_URI", "ip:10.0.0.132", "HW_DAUGHTER", "adrv9371");
            results = labgrid.runTests(["helpers.BoardConsumerTests", "helpers.OtherBoardConsumerTests"], ...
                Part="adrv9371", JUnit=fullfile(testCase.Dir, "j.xml"), ...
                Summary=fullfile(testCase.Dir, "s.json"), Verbosity=0);
            testCase.verifyNumElements(results, 2);
            testCase.verifyTrue(all(contains(string({results.Name}), "BoardConsumerTests")));
        end

        function acceptsAPrebuiltSuite(testCase)
            helpers.withLeaseEnv(testCase);
            suite = testsuite("helpers.PlainTests");
            results = labgrid.runTests(suite, JUnit=fullfile(testCase.Dir, "j.xml"), ...
                Summary=fullfile(testCase.Dir, "s.json"), Verbosity=0);
            testCase.verifyNumElements(results, 2);
        end

        function tagsFilterTheSuite(testCase)
            helpers.withLeaseEnv(testCase);
            results = labgrid.runTests("helpers.PlainTests", Tags="nonexistent-tag", ...
                JUnit=fullfile(testCase.Dir, "j.xml"), Summary=fullfile(testCase.Dir, "s.json"), Verbosity=0);
            testCase.verifyEmpty(results);
        end
    end
end
