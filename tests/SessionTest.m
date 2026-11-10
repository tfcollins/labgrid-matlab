classdef SessionTest < matlab.unittest.TestCase
    % labgrid.Session — interactive board acquisition via `adi-lg request --run lg-hold.sh`.
    % Uses the fake adi-lg shim (tests/+fakes/bin/adi-lg); no coordinator or hardware.

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
            testCase.applyFixture(EnvironmentVariableFixture("LG_ADI_LG_BIN", testCase.Shim));
            testCase.applyFixture(EnvironmentVariableFixture("LG_MATLAB_HOME", fullfile(testCase.Dir, "home")));
            testCase.applyFixture(EnvironmentVariableFixture("LG_COORDINATOR", "coord:20408"));
            for n = ["FAKE_ADI_LG_EXIT", "FAKE_ADI_LG_DELAY", "FAKE_ADI_LG_URI", "FAKE_ADI_LG_PLACE", ...
                     "FAKE_ADI_LG_CARRIER", "FAKE_ADI_LG_LOG"]
                testCase.applyFixture(EnvironmentVariableFixture(n, ""));
            end
            setenv("FAKE_ADI_LG_LOG", fullfile(testCase.Dir, "calls.log"));
            helpers.withLeaseEnv(testCase);
        end
    end

    methods (Test)
        % --- availability -------------------------------------------------------------
        function isAvailableIsFalseForMissingExecutable(testCase)
            setenv("LG_ADI_LG_BIN", "/nonexistent/dir/adi-lg");
            testCase.verifyFalse(labgrid.Session.isAvailable());
        end

        function isAvailableIsTrueForExistingExecutablePath(testCase)
            testCase.verifyTrue(labgrid.Session.isAvailable());
        end

        function isAvailableResolvesBareNameOnPath(testCase)
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            setenv("LG_ADI_LG_BIN", "");
            testCase.applyFixture(EnvironmentVariableFixture("PATH", fileparts(testCase.Shim) + pathsep + getenv("PATH")));
            testCase.verifyTrue(labgrid.Session.isAvailable());
        end

        function isAvailableIsFalseWhenBareNameNotOnPath(testCase)
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            setenv("LG_ADI_LG_BIN", "");
            testCase.applyFixture(EnvironmentVariableFixture("PATH", testCase.Dir));
            testCase.verifyFalse(labgrid.Session.isAvailable());
        end

        % --- request / release --------------------------------------------------------
        function requestReturnsSessionLeaseAndHoldsTheProcess(testCase)
            s = labgrid.Session.request("adrv9371", Carrier="zc706", Wait=5);
            testCase.addTeardown(@() s.release());
            testCase.verifyEqual(s.Lease.URI, "ip:127.0.0.1");
            testCase.verifyEqual(s.Lease.Place, "fake-place");
            testCase.verifyEqual(s.Lease.Daughter, "adrv9371");
            testCase.verifyEqual(s.Lease.Carrier, "zc706");
            testCase.verifyEqual(s.Lease.Source, "session");
            testCase.verifyTrue(helpers.pidAlive(s.Pid), "adi-lg should still be running");
            testCase.verifySubstring(string(fileread(getenv("FAKE_ADI_LG_LOG"))), ...
                "request --part adrv9371 --carrier zc706 --wait 5");
        end

        function releaseStopsAdiLgAndIsIdempotent(testCase)
            s = labgrid.Session.request("adrv9371", Wait=5);
            pid = s.Pid;
            s.release();
            testCase.verifyTrue(helpers.waitUntil(@() ~helpers.pidAlive(pid), 10), "adi-lg should exit on release");
            testCase.verifyTrue(s.Released);
            s.release();   % no error second time
            testCase.verifySubstring(string(fileread(s.LogFile)), "Released fake-place");
        end

        function deletingTheSessionReleases(testCase)
            s = labgrid.Session.request("adrv9371", Wait=5);
            pid = s.Pid;
            delete(s);
            testCase.verifyTrue(helpers.waitUntil(@() ~helpers.pidAlive(pid), 10));
        end

        function powerDownIsForwarded(testCase)
            s = labgrid.Session.request("adrv9371", Wait=5, PowerDown=true);
            testCase.addTeardown(@() s.release());
            testCase.verifySubstring(string(fileread(getenv("FAKE_ADI_LG_LOG"))), "--power-down");
        end

        function logFileCapturesAdiLgOutput(testCase)
            log = fullfile(testCase.Dir, "my.log");
            s = labgrid.Session.request("adrv9371", Wait=5, LogFile=log);
            testCase.addTeardown(@() s.release());
            testCase.verifyEqual(s.LogFile, log);
            testCase.verifySubstring(string(fileread(log)), "Booted fake-place -> ip:127.0.0.1");
        end

        % --- failure mapping ----------------------------------------------------------
        function noMatchingBoardIsATypedError(testCase)
            setenv("FAKE_ADI_LG_EXIT", "10");
            testCase.verifyError(@() labgrid.Session.request("adrv9002", Wait=5), "labgrid:noMatchingBoard");
        end

        function boardUnavailableIsATypedError(testCase)
            setenv("FAKE_ADI_LG_EXIT", "11");
            testCase.verifyError(@() labgrid.Session.request("adrv9371", Wait=5), "labgrid:boardUnavailable");
        end

        function provisionFailureIsATypedErrorCarryingTheLog(testCase)
            setenv("FAKE_ADI_LG_EXIT", "12");
            try
                labgrid.Session.request("adrv9371", Wait=5);
                testCase.verifyFail("expected an error");
            catch err
                testCase.verifyEqual(string(err.identifier), "labgrid:provisionFailed");
                testCase.verifySubstring(err.message, "boot verification failed");
            end
        end

        function unknownExitCodeIsAGenericFailure(testCase)
            setenv("FAKE_ADI_LG_EXIT", "99");
            testCase.verifyError(@() labgrid.Session.request("adrv9371", Wait=5), "labgrid:adiLgFailed");
        end

        function missingAdiLgIsATypedError(testCase)
            setenv("LG_ADI_LG_BIN", "/nonexistent/adi-lg");
            testCase.verifyError(@() labgrid.Session.request("adrv9371", Wait=5), "labgrid:adiLgNotFound");
        end

        function bootTimeoutKillsAdiLgAndErrors(testCase)
            setenv("FAKE_ADI_LG_DELAY", "20");
            setenv("FAKE_ADI_LG_PLACE", "slow-place");
            testCase.verifyError(@() labgrid.Session.request("slowpart", Wait=0, BootBudget=1), "labgrid:bootTimeout");
            function n = running()
                [~, out] = system("pgrep -f 'request --part slowpar[t]' | wc -l");   % [t] keeps pgrep's own shell out
                n = str2double(strtrim(out));
            end
            testCase.verifyTrue(helpers.waitUntil(@() running() == 0, 10), "adi-lg must be killed after a boot timeout");
        end

        function exitCodeMappingIsExplicit(testCase)
            e = labgrid.internal.exitCodeToError(130, "tail");
            testCase.verifyEqual(string(e.identifier), "labgrid:interrupted");
            e = labgrid.internal.exitCodeToError(2, "usage: ...");
            testCase.verifyEqual(string(e.identifier), "labgrid:adiLgUsage");
            testCase.verifySubstring(e.message, "usage: ...");
        end

        % --- session bookkeeping / reap -----------------------------------------------
        function sessionFileTracksTheLiveSessionAndIsRemovedOnRelease(testCase)
            s = labgrid.Session.request("adrv9371", Wait=5);
            files = dir(fullfile(labgrid.config.sessionsDir(), "*.json"));
            testCase.assertNumElements(files, 1);
            j = jsondecode(fileread(fullfile(files(1).folder, files(1).name)));
            testCase.verifyEqual(j.pid, s.Pid);
            testCase.verifyEqual(string(j.place), "fake-place");
            s.release();
            testCase.verifyEmpty(dir(fullfile(labgrid.config.sessionsDir(), "*.json")));
        end

        function reapRemovesSessionsWhoseProcessIsGone(testCase)
            d = labgrid.config.sessionsDir();
            mkdir(d);
            writelines(jsonencode(struct("pid", 999999, "place", "ghost", "part", "x")), fullfile(d, "ghost.json"));
            actions = labgrid.Session.reap();
            testCase.verifyNumElements(actions, 1);
            testCase.verifyEqual(actions(1).action, "removed-dead");
            testCase.verifyEqual(actions(1).place, "ghost");
            testCase.verifyEmpty(dir(fullfile(d, "*.json")));
        end

        function reapKeepsLiveSessionsWithoutACoordinatorCheck(testCase)
            s = labgrid.Session.request("adrv9371", Wait=5);
            testCase.addTeardown(@() s.release());
            actions = labgrid.Session.reap();
            testCase.verifyEqual(actions(1).action, "kept");
            testCase.verifyTrue(helpers.pidAlive(s.Pid));
        end

        function reapKillsLiveSessionWhosePlaceIsNoLongerAcquired(testCase)
            s = labgrid.Session.request("adrv9371", Wait=5);
            testCase.addTeardown(@() s.release());
            client = labgrid.Client(BaseURL="http://x/api", Transport=@(url) deal(200, ...
                '{"name":"fake-place","tags":{},"acquired":null,"acquired_username":null,"reservation":null}'));
            actions = labgrid.Session.reap(Client=client);
            testCase.verifyEqual(actions(1).action, "killed-orphan");
            testCase.verifyTrue(helpers.waitUntil(@() ~helpers.pidAlive(s.Pid), 10));
            testCase.verifyEmpty(dir(fullfile(labgrid.config.sessionsDir(), "*.json")));
        end

        function reapKeepsLiveSessionWhosePlaceIsStillAcquired(testCase)
            s = labgrid.Session.request("adrv9371", Wait=5);
            testCase.addTeardown(@() s.release());
            client = labgrid.Client(BaseURL="http://x/api", Transport=@(url) deal(200, ...
                '{"name":"fake-place","tags":{},"acquired":"web-dashboard/me","acquired_username":"me","reservation":null}'));
            actions = labgrid.Session.reap(Client=client);
            testCase.verifyEqual(actions(1).action, "kept");
            testCase.verifyTrue(helpers.pidAlive(s.Pid));
        end
    end
end
