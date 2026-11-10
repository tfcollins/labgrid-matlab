classdef (SharedTestFixtures={labgrid.fixtures.BoardFixture("daq3", Carrier="vcu118", Wait=7, PowerDown=true)}) ...
        OptionsBoardConsumerTests < matlab.unittest.TestCase
    % Test-only consumer exercising BoardFixture options forwarded to adi-lg.
    methods (Test)
        function seesIioUri(testCase)
            testCase.verifyNotEmpty(getenv("IIO_URI"));
        end
    end
end
