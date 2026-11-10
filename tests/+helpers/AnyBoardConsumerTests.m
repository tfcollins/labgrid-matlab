classdef (SharedTestFixtures={labgrid.fixtures.BoardFixture()}) ...
        AnyBoardConsumerTests < matlab.unittest.TestCase
    % Test-only consumer that accepts whatever board the environment provides.
    methods (Test)
        function seesIioUri(testCase)
            testCase.verifyNotEmpty(getenv("IIO_URI"));
        end
    end
end
