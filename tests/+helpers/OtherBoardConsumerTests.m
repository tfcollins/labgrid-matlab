classdef (SharedTestFixtures={labgrid.fixtures.BoardFixture("ad9081", Carrier="zcu102")}) ...
        OtherBoardConsumerTests < matlab.unittest.TestCase
    % Test-only consumer of a different board than BoardConsumerTests.
    methods (Test)
        function seesIioUri(testCase)
            testCase.verifyNotEmpty(getenv("IIO_URI"));
        end
    end
end
