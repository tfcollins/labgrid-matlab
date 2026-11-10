classdef PlainTests < matlab.unittest.TestCase
    % Test-only class with no board fixture.
    methods (Test)
        function passes(testCase)
            testCase.verifyTrue(true);
        end
        function fails(testCase)
            testCase.verifyTrue(false, "intentional failure for runner tests");
        end
    end
end
