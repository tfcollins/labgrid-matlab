classdef BoardFixtureTest < matlab.unittest.TestCase
    % labgrid.fixtures.BoardFixture — environment hand-over path (adi-lg request --run).

    methods (Access = private)
        function useShim(testCase)
            % Route the fixture's interactive path through the fake adi-lg.
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            import matlab.unittest.fixtures.TemporaryFolderFixture
            testCase.assumeTrue(isunix, "bash only");
            dir = string(testCase.applyFixture(TemporaryFolderFixture).Folder);
            shim = fullfile(helpers.repoRoot(), "tests", "+fakes", "bin", "adi-lg");
            helpers.withLeaseEnv(testCase);
            testCase.applyFixture(EnvironmentVariableFixture("LG_ADI_LG_BIN", shim));
            testCase.applyFixture(EnvironmentVariableFixture("LG_MATLAB_HOME", fullfile(dir, "home")));
            testCase.applyFixture(EnvironmentVariableFixture("LG_COORDINATOR", "coord:20408"));
            for n = ["FAKE_ADI_LG_EXIT", "FAKE_ADI_LG_DELAY", "FAKE_ADI_LG_URI", "FAKE_ADI_LG_PLACE", "FAKE_ADI_LG_CARRIER"]
                testCase.applyFixture(EnvironmentVariableFixture(n, ""));
            end
            testCase.applyFixture(EnvironmentVariableFixture("FAKE_ADI_LG_LOG", fullfile(dir, "calls.log")));
        end

        function n = shimProcesses(~)
            [~, out] = system("pgrep -f 'adi-lg reques[t] --part' | wc -l");
            n = str2double(strtrim(out));
        end
    end

    methods (Test)
        % --- interactive (session) path ----------------------------------------------
        function sessionPathAcquiresBootsAndReleases(testCase)
            testCase.useShim();
            setenv("FAKE_ADI_LG_URI", "ip:10.0.0.132");
            results = runtests("helpers.BoardConsumerTests");
            testCase.verifyTrue(all([results.Passed]), "consumers should run against the session lease");
            testCase.verifySubstring(string(fileread(getenv("FAKE_ADI_LG_LOG"))), "request --part adrv9371");
            testCase.verifyTrue(helpers.waitUntil(@() testCase.shimProcesses() == 0, 10), "board must be released after the suite");
            testCase.verifyEqual(string(getenv("IIO_URI")), "", "env must be restored");
            testCase.verifyEmpty(dir(fullfile(labgrid.config.sessionsDir(), "*.json")), "session record must be removed");
        end

        function sessionPathBoardBusyMarksTestsIncomplete(testCase)
            testCase.useShim();
            setenv("FAKE_ADI_LG_EXIT", "11");
            results = runtests("helpers.BoardConsumerTests");
            testCase.verifyTrue(all([results.Incomplete]));
            testCase.verifyFalse(any([results.Failed]));
        end

        function sessionPathNoMatchingBoardIsRed(testCase)
            testCase.useShim();
            setenv("FAKE_ADI_LG_EXIT", "10");
            results = runtests("helpers.BoardConsumerTests");
            testCase.verifyTrue(all([results.Failed]));
        end

        function sessionPathBootFailureIsRed(testCase)
            testCase.useShim();
            setenv("FAKE_ADI_LG_EXIT", "12");
            results = runtests("helpers.BoardConsumerTests");
            testCase.verifyTrue(all([results.Failed]));
        end

        function twoBoardsInOneSuiteAreAcquiredOneAfterTheOther(testCase)
            testCase.useShim();
            setenv("FAKE_ADI_LG_URI", "ip:10.0.0.132");
            results = runtests(["helpers.BoardConsumerTests", "helpers.OtherBoardConsumerTests"]);
            testCase.verifyTrue(all([results.Passed]));
            log = string(fileread(getenv("FAKE_ADI_LG_LOG")));
            testCase.verifySubstring(log, "request --part adrv9371");
            testCase.verifySubstring(log, "request --part ad9081 --carrier zcu102");
            testCase.verifyTrue(helpers.waitUntil(@() testCase.shimProcesses() == 0, 10), "both boards released");
        end

        function fixtureOptionsAreForwardedToAdiLg(testCase)
            testCase.useShim();
            results = runtests("helpers.OptionsBoardConsumerTests");
            testCase.verifyTrue(all([results.Passed]));
            testCase.verifySubstring(string(fileread(getenv("FAKE_ADI_LG_LOG"))), ...
                "request --part daq3 --carrier vcu118 --wait 7 --power-down");
        end

        % --- environment hand-over path ------------------------------------------------
        function envLeaseIsUsedAndExportedToConsumers(testCase)
            helpers.withLeaseEnv(testCase, "IIO_URI", "ip:10.0.0.132", "LG_PLACE", "bq", ...
                "LG_CARRIER", "zc706", "HW_DAUGHTER", "adrv9371");
            results = runtests("helpers.BoardConsumerTests");
            testCase.verifyTrue(all([results.Passed]), "all consumer tests should pass");
            testCase.verifyEqual(string(getenv("HW_CARRIER")), "", ...
                "fixture must restore env vars it exported");
        end

        function envLeaseWithDifferentPartMarksTestsIncomplete(testCase)
            helpers.withLeaseEnv(testCase, "IIO_URI", "ip:10.0.0.132", "HW_DAUGHTER", "ad9081");
            results = runtests("helpers.BoardConsumerTests");
            testCase.verifyTrue(all([results.Incomplete]));
            testCase.verifyFalse(any([results.Failed]), "mismatch must not be red");
        end

        function envLeaseWithDifferentCarrierMarksTestsIncomplete(testCase)
            helpers.withLeaseEnv(testCase, "IIO_URI", "ip:10.0.0.132", "HW_DAUGHTER", "ad9081", "LG_CARRIER", "zcu111");
            results = runtests("helpers.OtherBoardConsumerTests");   % wants ad9081 on zcu102
            testCase.verifyTrue(all([results.Incomplete]));
            testCase.verifyFalse(any([results.Failed]));
        end

        function envLeaseWithMatchingCarrierIsUsed(testCase)
            helpers.withLeaseEnv(testCase, "IIO_URI", "ip:10.0.0.132", "HW_DAUGHTER", "ad9081", "LG_CARRIER", "zcu102");
            results = runtests("helpers.OtherBoardConsumerTests");
            testCase.verifyTrue(all([results.Passed]));
        end

        function envLeaseWithoutPartTagSatisfiesAnyFixture(testCase)
            helpers.withLeaseEnv(testCase, "IIO_URI", "ip:10.0.0.132", "LG_CARRIER", "zc706");
            results = runtests("helpers.BoardConsumerTests");
            testCase.verifyTrue(all([results.Passed]), "untagged env lease is trusted");
        end

        function fixtureWithoutPartAcceptsAnyEnvLease(testCase)
            helpers.withLeaseEnv(testCase, "IIO_URI", "ip:10.0.0.5", "HW_DAUGHTER", "daq3");
            results = runtests("helpers.AnyBoardConsumerTests");
            testCase.verifyTrue(all([results.Passed]));
        end

        function noLeaseAndNoAdiLgMarksTestsIncomplete(testCase)
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            helpers.withLeaseEnv(testCase);
            testCase.applyFixture(EnvironmentVariableFixture("LG_ADI_LG_BIN", "/nonexistent/adi-lg"));
            testCase.applyFixture(EnvironmentVariableFixture("LG_COORDINATOR", ""));
            results = runtests("helpers.BoardConsumerTests");
            testCase.verifyTrue(all([results.Incomplete]));
            testCase.verifyFalse(any([results.Failed]));
        end

        function leasePropertyIsPopulatedAfterSetup(testCase)
            helpers.withLeaseEnv(testCase, "IIO_URI", "ip:10.0.0.132", "LG_PLACE", "bq", ...
                "HW_DAUGHTER", "adrv9371");
            f = testCase.applyFixture(labgrid.fixtures.BoardFixture("adrv9371"));
            testCase.verifyEqual(f.Lease.Place, "bq");
            testCase.verifyEqual(f.Lease.URI, "ip:10.0.0.132");
            testCase.verifyEqual(f.Lease.Source, "env");
            testCase.verifySubstring(f.SetupDescription, "bq");
            testCase.verifySubstring(f.SetupDescription, "ip:10.0.0.132");
        end

        function compatibilityFollowsPartAndCarrier(testCase)
            import matlab.unittest.selectors.HasSharedTestFixture
            import labgrid.fixtures.BoardFixture
            suite = testsuite(["helpers.BoardConsumerTests", "helpers.OtherBoardConsumerTests"]);
            testCase.verifyNumElements(suite.selectIf(HasSharedTestFixture(BoardFixture("adrv9371"))), 2);
            testCase.verifyNumElements(suite.selectIf(HasSharedTestFixture(BoardFixture("ad9081", Carrier="zcu102"))), 1);
            testCase.verifyEmpty(suite.selectIf(HasSharedTestFixture(BoardFixture("ad9081", Carrier="zc706"))));
            testCase.verifyEmpty(suite.selectIf(HasSharedTestFixture(BoardFixture("ad9361"))));
        end

        function constructorDoesNoIo(testCase)
            % Class attributes are evaluated at load time; constructing must never touch env/network.
            helpers.withLeaseEnv(testCase);
            f = labgrid.fixtures.BoardFixture("adrv9371");
            testCase.verifyEqual(f.Part, "adrv9371");
            testCase.verifyEmpty(f.Lease);
        end
    end
end
