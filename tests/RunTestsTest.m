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

    methods (Access = private)
        function client = clientMatchingOnly(testCase, parts)
            % A Client whose /match says "satisfiable" only for the given parts.
            rec = fullfile(helpers.repoRoot(), "tests", "recorded");
            function [s, b] = transport(url)
                s = 200;
                part = extractBetween(string(url), "part=", optionalPattern("&" + wildcardPattern) + textBoundary("end"));
                if any(part == parts)
                    b = string(fileread(fullfile(rec, "match_satisfiable.json")));
                else
                    b = string(fileread(fullfile(rec, "match_unsatisfiable.json")));
                end
            end
            client = labgrid.Client(BaseURL="http://x/api", Transport=@transport);
            testCase.addTeardown(@() []);
        end
    end

    methods (Test)
        % --- FilterByAvailability ------------------------------------------------------
        function availabilityFilterDropsTestsWhoseBoardHasNoLiveMatch(testCase)
            helpers.withLeaseEnv(testCase, "IIO_URI", "ip:10.0.0.132", "HW_DAUGHTER", "adrv9371");
            results = labgrid.runTests(["helpers.BoardConsumerTests", "helpers.OtherBoardConsumerTests", "helpers.PlainTests"], ...
                FilterByAvailability=true, Client=testCase.clientMatchingOnly("adrv9371"), ...
                JUnit=fullfile(testCase.Dir, "j.xml"), Summary=fullfile(testCase.Dir, "s.json"), Verbosity=0);
            names = string({results.Name});
            testCase.verifyNumElements(results, 4);
            testCase.verifyFalse(any(contains(names, "OtherBoardConsumerTests")));
            testCase.verifyTrue(any(contains(names, "PlainTests")), "tests without a board fixture are kept");
        end

        function availabilityFilterKeepsEverythingWhenAllBoardsMatch(testCase)
            helpers.withLeaseEnv(testCase, "IIO_URI", "ip:10.0.0.132");
            results = labgrid.runTests(["helpers.BoardConsumerTests", "helpers.OtherBoardConsumerTests"], ...
                FilterByAvailability=true, Client=testCase.clientMatchingOnly(["adrv9371", "ad9081"]), ...
                JUnit=fullfile(testCase.Dir, "j.xml"), Summary=fullfile(testCase.Dir, "s.json"), Verbosity=0);
            testCase.verifyNumElements(results, 3);
        end

        function availabilityFilterRecordsSkippedBoardsInSummary(testCase)
            helpers.withLeaseEnv(testCase, "IIO_URI", "ip:10.0.0.132");
            summary = fullfile(testCase.Dir, "s.json");
            labgrid.runTests(["helpers.BoardConsumerTests", "helpers.OtherBoardConsumerTests"], ...
                FilterByAvailability=true, Client=testCase.clientMatchingOnly("adrv9371"), ...
                JUnit=fullfile(testCase.Dir, "j.xml"), Summary=summary, Verbosity=0);
            s = jsondecode(fileread(summary));
            testCase.verifyNumElements(s.skipped, 1);
            testCase.verifyEqual(string(s.skipped(1).part), "ad9081");
            testCase.verifyEqual(string(s.skipped(1).carrier), "zcu102");
            testCase.verifyEqual(s.skipped(1).tests, 1);
            testCase.verifySubstring(string(s.skipped(1).reason), "no live place");
        end

        function availabilityFilterQueriesEachBoardOnce(testCase)
            helpers.withLeaseEnv(testCase, "IIO_URI", "ip:10.0.0.132");
            urls = {};
            function [s, b] = transport(url)
                urls{end+1} = string(url); %#ok<AGROW>
                s = 200; b = string(fileread(fullfile(helpers.repoRoot(), "tests", "recorded", "match_satisfiable.json")));
            end
            client = labgrid.Client(BaseURL="http://x/api", Transport=@transport);
            labgrid.runTests(["helpers.BoardConsumerTests", "helpers.OtherBoardConsumerTests", "helpers.PlainTests"], ...
                FilterByAvailability=true, Client=client, ...
                JUnit=fullfile(testCase.Dir, "j.xml"), Summary=fullfile(testCase.Dir, "s.json"), Verbosity=0);
            testCase.verifyEqual(sort(string(urls)), sort(["http://x/api/match?part=ad9081&carrier=zcu102", ...
                "http://x/api/match?part=adrv9371"]));
        end

        function availabilityFilterSurfacesAnUnreachableCoordinator(testCase)
            helpers.withLeaseEnv(testCase);
            client = labgrid.Client(BaseURL="http://x/api", Transport=@(url) error("boom:boom", "no route"));
            testCase.verifyError(@() labgrid.runTests("helpers.BoardConsumerTests", FilterByAvailability=true, Client=client, ...
                JUnit=fullfile(testCase.Dir, "j.xml"), Summary=fullfile(testCase.Dir, "s.json"), Verbosity=0), ...
                "labgrid:coordinatorUnreachable");
        end

        % --- basics --------------------------------------------------------------------
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
