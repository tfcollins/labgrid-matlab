classdef (TestTags = {'live'}) LiveCoordinatorTest < matlab.unittest.TestCase
    % Read-only checks against the real coordinator REST API. Needs $LG_COORDINATOR.

    properties
        Client
    end

    methods (TestClassSetup)
        function connect(testCase)
            testCase.assumeNotEmpty(getenv("LG_COORDINATOR"), "set LG_COORDINATOR=host:20408");
            testCase.Client = labgrid.Client();
        end
    end

    methods (Test)
        function healthReportsCoordinatorConnected(testCase)
            h = testCase.Client.health();
            testCase.verifyEqual(h.status, "ok");
            testCase.verifyTrue(h.coordinator_connected);
        end

        function placesCarryBoardTags(testCase)
            p = testCase.Client.places();
            testCase.verifyNotEmpty(p);
            testCase.verifyTrue(any(strlength([p.daughter]) > 0), "at least one place has a daughter-board tag");
        end

        function matchForTheTestPartIsSatisfiable(testCase)
            part = string(getenv("LG_TEST_PART"));
            if strlength(part) == 0, part = "adrv9009"; end
            m = testCase.Client.match(part);
            testCase.verifyTrue(m.satisfiable, m.reason);
            testCase.verifyNotEqual(m.place, "");
        end
    end
end
