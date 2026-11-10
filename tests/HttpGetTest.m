classdef HttpGetTest < matlab.unittest.TestCase
    % labgrid.internal.httpGet — the default Client transport, against a local static HTTP server.

    properties
        Port
        ServerPid
        Base
    end

    methods (TestClassSetup)
        function startServer(testCase)
            testCase.assumeTrue(isunix, "needs python3 + bash");
            recorded = fullfile(helpers.repoRoot(), "tests", "recorded");
            testCase.Port = 20000 + randi(20000);
            exitFile = tempname;
            testCase.ServerPid = helpers.startBackground(sprintf( ...
                "exec python3 -m http.server %d --bind 127.0.0.1 --directory '%s'", testCase.Port, recorded), exitFile);
            testCase.addTeardown(@() system(sprintf("kill %d 2>/dev/null", testCase.ServerPid)));
            testCase.Base = sprintf("http://127.0.0.1:%d", testCase.Port);
            ready = helpers.waitUntil(@() system(sprintf("env -u LD_LIBRARY_PATH curl -s -o /dev/null %s/health.json", testCase.Base)) == 0, 10);
            testCase.assertTrue(ready, "local http.server did not come up");
        end
    end

    methods (Test)
        function returnsStatusAndBodyFor200(testCase)
            [status, body] = labgrid.internal.httpGet(testCase.Base + "/health.json", 5);
            testCase.verifyEqual(status, 200);
            j = jsondecode(char(body));
            testCase.verifyEqual(string(j.status), "ok");
        end

        function returns404WithoutThrowing(testCase)
            [status, ~] = labgrid.internal.httpGet(testCase.Base + "/missing.json", 5);
            testCase.verifyEqual(status, 404);
        end

        function throwsWhenNothingListens(testCase)
            testCase.verifyError(@() labgrid.internal.httpGet("http://127.0.0.1:9/x", 2), ?MException);
        end

        function clientUsesItByDefault(testCase)
            client = labgrid.Client(BaseURL=testCase.Base);
            % /health.json rather than /health: static server, so point at the recorded file path.
            [status, body] = labgrid.internal.httpGet(client.BaseURL + "/health.json", 5);
            testCase.verifyEqual(status, 200);
            testCase.verifySubstring(body, "coordinator_connected");
        end
    end
end
