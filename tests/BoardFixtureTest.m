classdef BoardFixtureTest < matlab.unittest.TestCase
    % labgrid.fixtures.BoardFixture — environment hand-over path (adi-lg request --run).

    methods (Test)
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
