classdef ConfigTest < matlab.unittest.TestCase
    % Unit tests for labgrid.config (environment-derived settings).

    methods (TestMethodSetup)
        function clearEnv(testCase)
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            for n = ["LG_COORDINATOR", "LG_API", "LG_ADI_LG_BIN"]
                testCase.applyFixture(EnvironmentVariableFixture(n, ""));
            end
        end
    end

    methods (Test)
        function apiUrlDerivedFromCoordinatorHost(testCase)
            setenv("LG_COORDINATOR", "10.0.0.41:20408");
            testCase.verifyEqual(labgrid.config.apiUrl(), "http://10.0.0.41:8000/api");
        end

        function apiUrlFromBareCoordinatorHost(testCase)
            setenv("LG_COORDINATOR", "coord.lab");
            testCase.verifyEqual(labgrid.config.apiUrl(), "http://coord.lab:8000/api");
        end

        function lgApiOverridesDerivedUrl(testCase)
            setenv("LG_COORDINATOR", "10.0.0.41:20408");
            setenv("LG_API", "https://lab.example.com/labgrid");
            testCase.verifyEqual(labgrid.config.apiUrl(), "https://lab.example.com/labgrid/api");
        end

        function lgApiWithTrailingApiIsNotDoubled(testCase)
            setenv("LG_API", "http://127.0.0.1:8000/api/");
            testCase.verifyEqual(labgrid.config.apiUrl(), "http://127.0.0.1:8000/api");
        end

        function apiUrlErrorsWhenNothingConfigured(testCase)
            testCase.verifyError(@() labgrid.config.apiUrl(), "labgrid:noCoordinator");
        end

        function coordinatorReturnsEnvValue(testCase)
            setenv("LG_COORDINATOR", "10.0.0.41:20408");
            testCase.verifyEqual(labgrid.config.coordinator(), "10.0.0.41:20408");
        end

        function coordinatorErrorsWhenUnset(testCase)
            testCase.verifyError(@() labgrid.config.coordinator(), "labgrid:noCoordinator");
        end

        function adiLgBinDefaultsToName(testCase)
            testCase.verifyEqual(labgrid.config.adiLgBin(), "adi-lg");
        end

        function adiLgBinHonoursOverride(testCase)
            setenv("LG_ADI_LG_BIN", "/opt/venv/bin/adi-lg");
            testCase.verifyEqual(labgrid.config.adiLgBin(), "/opt/venv/bin/adi-lg");
        end

        function envVarNamesAreCentralised(testCase)
            names = labgrid.config.leaseEnvVars();
            testCase.verifyEqual(names, ["IIO_URI", "LG_PLACE", "LG_CARRIER", "HW_DAUGHTER", "HW_CARRIER"]);
        end
    end
end
