classdef (SharedTestFixtures={labgrid.fixtures.BoardFixture("adrv9371")}) ...
        ExampleBoardTests < matlab.unittest.TestCase
    % Minimal consumer of a labgrid-booted board.
    %
    % CI (board booted by labgrid first):
    %   adi-lg request --part adrv9371 --run \
    %     "matlab -batch \"addpath(genpath('toolbox')); labgrid.runTests('examples', Part='adrv9371')\""
    %
    % Interactive (the fixture asks the coordinator itself):
    %   >> setenv LG_COORDINATOR 10.0.0.41:20408
    %   >> runtests examples/ExampleBoardTests.m

    methods (Test)
        function iiodIsReachable(testCase)
            uri = string(getenv("IIO_URI"));
            testCase.assumeTrue(startsWith(uri, "ip:"), "only ip: URIs are probed here");
            host = extractAfter(uri, "ip:");
            t = tcpclient(host, 30431, Timeout=10);   % iiod
            testCase.verifyTrue(isvalid(t));
            clear t
        end

        function leaseDescribesTheBoard(testCase)
            lease = labgrid.Lease.fromEnvironment();
            testCase.verifyNotEmpty(lease);
            testCase.verifyEqual(lease.Daughter, "adrv9371");
            testCase.verifyNotEqual(lease.Place, "");
        end
    end
end
