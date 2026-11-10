classdef (SharedTestFixtures={labgrid.fixtures.BoardFixture("adrv9371")}) ...
        BoardConsumerTests < matlab.unittest.TestCase
    % Test-only consumer of BoardFixture("adrv9371"); run by the labgrid-matlab unit tests.
    methods (Test)
        function seesIioUri(testCase)
            testCase.verifyEqual(string(getenv("IIO_URI")), "ip:10.0.0.132");
        end
        function seesHwCarrierMirroredFromLgCarrier(testCase)
            testCase.verifyEqual(string(getenv("HW_CARRIER")), "zc706");
        end
    end
end
