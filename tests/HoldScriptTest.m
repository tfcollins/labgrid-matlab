classdef HoldScriptTest < matlab.unittest.TestCase
    % toolbox/bin/lg-hold.sh — keeps `adi-lg request --run` alive until released.
    %   usage: bash lg-hold.sh LEASE_JSON RELEASE_FILE PARENT_PID MAX_HOLD_SECONDS [POLL_SECONDS]

    properties
        Dir
        Script
    end

    methods (TestMethodSetup)
        function setup(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            testCase.assumeTrue(isunix, "bash only");
            testCase.Dir = string(testCase.applyFixture(TemporaryFolderFixture).Folder);
            testCase.Script = fullfile(helpers.repoRoot(), "toolbox", "bin", "lg-hold.sh");
            helpers.withLeaseEnv(testCase, "IIO_URI", "ip:10.0.0.132", "LG_PLACE", "bq", ...
                "LG_CARRIER", "zc706", "HW_DAUGHTER", "adrv9371", "HW_CARRIER", "zc706");
        end
    end

    methods (Access = private)
        function [pid, lease, release, exitFile] = startHold(testCase, parentPid, maxHold, poll)
            lease = fullfile(testCase.Dir, "lease.json");
            release = fullfile(testCase.Dir, "release");
            exitFile = fullfile(testCase.Dir, "exit");
            cmd = sprintf("bash '%s' '%s' '%s' %d %g %g", testCase.Script, lease, release, parentPid, maxHold, poll);
            pid = helpers.startBackground(cmd, exitFile);
            testCase.addTeardown(@() system(sprintf("kill %d 2>/dev/null", pid)));
        end

        function code = exitCode(testCase, exitFile)
            testCase.assertTrue(helpers.waitUntil(@() isfile(exitFile), 10), "hold script did not exit");
            code = str2double(strtrim(fileread(exitFile)));
        end
    end

    methods (Test)
        function writesLeaseJsonFromEnvironment(testCase)
            [~, lease, release] = testCase.startHold(0, 60, 0.1);
            testCase.assertTrue(helpers.waitUntil(@() isfile(lease), 10), "lease.json not written");
            j = jsondecode(fileread(lease));
            testCase.verifyEqual(string(j.uri), "ip:10.0.0.132");
            testCase.verifyEqual(string(j.place), "bq");
            testCase.verifyEqual(string(j.carrier), "zc706");
            testCase.verifyEqual(string(j.daughter), "adrv9371");
            testCase.verifyGreaterThan(j.pid, 0);
            fclose(fopen(release, "w"));
        end

        function exitsZeroWhenReleaseFileAppears(testCase)
            [pid, lease, release, exitFile] = testCase.startHold(0, 60, 0.1);
            testCase.assertTrue(helpers.waitUntil(@() isfile(lease), 10));
            testCase.verifyTrue(helpers.pidAlive(pid), "should still be holding");
            fclose(fopen(release, "w"));
            testCase.verifyEqual(testCase.exitCode(exitFile), 0);
        end

        function exitsWhenParentProcessDies(testCase)
            [~, out] = system("sleep 1 & echo $!");
            parent = str2double(strtrim(out));
            [~, lease, ~, exitFile] = testCase.startHold(parent, 60, 0.1);
            testCase.assertTrue(helpers.waitUntil(@() isfile(lease), 10));
            testCase.verifyEqual(testCase.exitCode(exitFile), 2);
        end

        function exitsAfterMaxHold(testCase)
            [~, ~, ~, exitFile] = testCase.startHold(0, 1, 0.1);
            testCase.verifyEqual(testCase.exitCode(exitFile), 3);
        end

        function usageErrorWithoutArguments(testCase)
            [status, ~] = system(sprintf("bash '%s'", testCase.Script));
            testCase.verifyEqual(status, 64);
        end
    end
end
