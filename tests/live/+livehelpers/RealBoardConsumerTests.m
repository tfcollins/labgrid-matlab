classdef (SharedTestFixtures={labgrid.fixtures.BoardFixture(livehelpers.testPart(), Wait=900)}) ...
        RealBoardConsumerTests < matlab.unittest.TestCase
    % Live consumer: the fixture boots $LG_TEST_PART and the test talks to iiod.
    methods (Test)
        function iiodAnswers(testCase)
            lease = labgrid.Lease.fromEnvironment();
            testCase.assertNotEmpty(lease);
            t = tcpclient(lease.host(), 30431, Timeout=15);
            testCase.verifyTrue(isvalid(t));
            clear t
        end
    end
end
