classdef FakeAdiLgTest < matlab.unittest.TestCase
    % tests/+fakes/bin/adi-lg — bash shim with the `adi-lg request --run` contract, for Session tests.

    properties
        Dir
        Shim
    end

    methods (TestMethodSetup)
        function setup(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            testCase.assumeTrue(isunix, "bash only");
            testCase.Dir = string(testCase.applyFixture(TemporaryFolderFixture).Folder);
            testCase.Shim = fullfile(helpers.repoRoot(), "tests", "+fakes", "bin", "adi-lg");
            for n = ["FAKE_ADI_LG_EXIT", "FAKE_ADI_LG_DELAY", "FAKE_ADI_LG_URI", "FAKE_ADI_LG_PLACE", ...
                     "FAKE_ADI_LG_CARRIER", "FAKE_ADI_LG_LOG"]
                testCase.applyFixture(EnvironmentVariableFixture(n, ""));
            end
            helpers.withLeaseEnv(testCase);
        end
    end

    methods (Test)
        function runsChildWithExportedLeaseVariables(testCase)
            out = fullfile(testCase.Dir, "env.txt");
            [status, ~] = system(sprintf("bash '%s' request --part adrv9371 --carrier zc706 --wait 5 --run 'env > %s'", ...
                testCase.Shim, out));
            testCase.verifyEqual(status, 0);
            env = string(fileread(out));
            testCase.verifySubstring(env, "IIO_URI=ip:127.0.0.1");
            testCase.verifySubstring(env, "HW_DAUGHTER=adrv9371");
            testCase.verifySubstring(env, "LG_CARRIER=zc706");
            testCase.verifySubstring(env, "HW_CARRIER=zc706");
            testCase.verifySubstring(env, "LG_PLACE=fake-place");
        end

        function propagatesChildExitCode(testCase)
            [status, ~] = system(sprintf("bash '%s' request --part x --run 'exit 7'", testCase.Shim));
            testCase.verifyEqual(status, 7);
        end

        function exitKnobShortCircuitsBeforeChild(testCase)
            setenv("FAKE_ADI_LG_EXIT", "10");
            marker = fullfile(testCase.Dir, "ran");
            [status, out] = system(sprintf("bash '%s' request --part x --run 'touch %s' 2>&1", testCase.Shim, marker));
            testCase.verifyEqual(status, 10);
            testCase.verifyFalse(isfile(marker));
            testCase.verifySubstring(out, "No matching board");
        end

        function withoutRunPrintsUriAndExits(testCase)
            setenv("FAKE_ADI_LG_URI", "ip:10.9.9.9");
            [status, out] = system(sprintf("bash '%s' request --part x", testCase.Shim));
            testCase.verifyEqual(status, 0);
            testCase.verifySubstring(out, "ip:10.9.9.9");
        end

        function sigtermStopsChildAndExits130(testCase)
            exitFile = fullfile(testCase.Dir, "exit");
            childMarker = fullfile(testCase.Dir, "child.pid");
            shimMarker = fullfile(testCase.Dir, "shim.pid");
            helpers.startBackground(sprintf("bash '%s' request --part x --run 'echo $PPID > %s; echo $$ > %s; sleep 60'", ...
                testCase.Shim, shimMarker, childMarker), exitFile);
            testCase.assertTrue(helpers.waitUntil(@() isfile(childMarker) && isfile(shimMarker), 10), "child never started");
            childPid = str2double(strtrim(fileread(childMarker)));
            shimPid = str2double(strtrim(fileread(shimMarker)));
            system(sprintf("kill -TERM %d", shimPid));
            testCase.assertTrue(helpers.waitUntil(@() isfile(exitFile), 10), "shim did not exit on SIGTERM");
            testCase.verifyEqual(str2double(strtrim(fileread(exitFile))), 130);
            testCase.verifyTrue(helpers.waitUntil(@() ~helpers.pidAlive(childPid), 5), "child should be killed");
        end

        function logsInvocationWhenAsked(testCase)
            log = fullfile(testCase.Dir, "calls.log");
            setenv("FAKE_ADI_LG_LOG", log);
            system(sprintf("bash '%s' request --part adrv9371 --power-down --run true", testCase.Shim));
            testCase.verifySubstring(string(fileread(log)), "--part adrv9371 --power-down");
        end

        function delayKnobPostponesBoot(testCase)
            setenv("FAKE_ADI_LG_DELAY", "1");
            t = tic;
            [status, ~] = system(sprintf("bash '%s' request --part x --run true", testCase.Shim));
            testCase.verifyEqual(status, 0);
            testCase.verifyGreaterThan(toc(t), 0.9);
        end
    end
end
