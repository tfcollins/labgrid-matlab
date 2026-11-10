classdef SessionTest < matlab.unittest.TestCase
    % labgrid.Session — interactive board acquisition via `adi-lg request --run`.

    methods (TestMethodSetup)
        function clearEnv(testCase)
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            testCase.applyFixture(EnvironmentVariableFixture("LG_ADI_LG_BIN", ""));
        end
    end

    methods (Test)
        function isAvailableIsFalseForMissingExecutable(testCase)
            setenv("LG_ADI_LG_BIN", "/nonexistent/dir/adi-lg");
            testCase.verifyFalse(labgrid.Session.isAvailable());
        end

        function isAvailableIsTrueForExistingExecutablePath(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            dir = string(testCase.applyFixture(TemporaryFolderFixture).Folder);
            bin = fullfile(dir, "adi-lg");
            writelines("#!/usr/bin/env bash" + newline + "exit 0", bin);
            fileattrib(bin, "+x");
            setenv("LG_ADI_LG_BIN", bin);
            testCase.verifyTrue(labgrid.Session.isAvailable());
        end

        function isAvailableResolvesBareNameOnPath(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            dir = string(testCase.applyFixture(TemporaryFolderFixture).Folder);
            bin = fullfile(dir, "adi-lg");
            writelines("#!/usr/bin/env bash" + newline + "exit 0", bin);
            fileattrib(bin, "+x");
            testCase.applyFixture(EnvironmentVariableFixture("PATH", dir + pathsep + getenv("PATH")));
            testCase.verifyTrue(labgrid.Session.isAvailable());
        end

        function isAvailableIsFalseWhenBareNameNotOnPath(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            dir = string(testCase.applyFixture(TemporaryFolderFixture).Folder);   % empty dir as the whole PATH
            testCase.applyFixture(EnvironmentVariableFixture("PATH", dir));
            testCase.verifyFalse(labgrid.Session.isAvailable());
        end
    end
end
