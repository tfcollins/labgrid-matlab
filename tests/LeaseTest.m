classdef LeaseTest < matlab.unittest.TestCase
    % Unit tests for labgrid.Lease (value class describing a booted board).

    methods (TestMethodSetup)
        function clearEnv(testCase)
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            names = ["IIO_URI", "LG_PLACE", "LG_CARRIER", "HW_DAUGHTER", "HW_CARRIER"];
            for n = names
                testCase.applyFixture(EnvironmentVariableFixture(n, ""));
            end
        end
    end

    methods (Test)
        function fromEnvironmentIsEmptyWithoutIioUri(testCase)
            lease = labgrid.Lease.fromEnvironment();
            testCase.verifyEmpty(lease);
        end

        function fromEnvironmentReadsAdiLgRequestVariables(testCase)
            setenv("IIO_URI", "ip:10.0.0.132");
            setenv("LG_PLACE", "bq");
            setenv("LG_CARRIER", "zc706");
            setenv("HW_DAUGHTER", "adrv9371");
            lease = labgrid.Lease.fromEnvironment();
            testCase.verifyEqual(lease.URI, "ip:10.0.0.132");
            testCase.verifyEqual(lease.Place, "bq");
            testCase.verifyEqual(lease.Carrier, "zc706");
            testCase.verifyEqual(lease.Daughter, "adrv9371");
            testCase.verifyEqual(lease.Source, "env");
        end

        function fromEnvironmentFallsBackToHwCarrier(testCase)
            setenv("IIO_URI", "ip:10.0.0.132");
            setenv("HW_CARRIER", "zcu102");
            lease = labgrid.Lease.fromEnvironment();
            testCase.verifyEqual(lease.Carrier, "zcu102");
        end

        function constructorAcceptsNameValuePairs(testCase)
            lease = labgrid.Lease(URI="ip:1.2.3.4", Place="nemo", Carrier="zc706", ...
                Daughter="adrv9009", Source="session");
            testCase.verifyEqual(lease.URI, "ip:1.2.3.4");
            testCase.verifyEqual(lease.Place, "nemo");
            testCase.verifyEqual(lease.Source, "session");
            testCase.verifyEqual(lease.Carrier, "zc706");
            testCase.verifyEqual(lease.Daughter, "adrv9009");
        end

        function hostStripsIpPrefix(testCase)
            lease = labgrid.Lease(URI="ip:10.0.0.132");
            testCase.verifyEqual(lease.host(), "10.0.0.132");
        end

        function hostOfNonIpUriIsEmptyString(testCase)
            lease = labgrid.Lease(URI="usb:1.2.3");
            testCase.verifyEqual(lease.host(), "");
        end

        function tagLookupUsesOriginalHyphenatedNames(testCase)
            tags = struct("daughter_board", "adrv9371", "carrier", "zc706", ...
                "boot_strategy", "BootFPGASoCTFTP");
            lease = labgrid.Lease(URI="ip:1.2.3.4", Tags=tags);
            testCase.verifyEqual(lease.tag("daughter-board"), "adrv9371");
            testCase.verifyEqual(lease.tag("boot-strategy"), "BootFPGASoCTFTP");
            testCase.verifyEqual(lease.tag("carrier"), "zc706");
        end

        function tagLookupOfMissingTagIsEmptyString(testCase)
            lease = labgrid.Lease(URI="ip:1.2.3.4");
            testCase.verifyEqual(lease.tag("hdl-config"), "");
        end

        function toEnvironmentProducesAdiLgVariableNames(testCase)
            lease = labgrid.Lease(URI="ip:1.2.3.4", Place="bq", Carrier="zc706", Daughter="adrv9371");
            env = lease.toEnvironment();
            testCase.verifyEqual(env.IIO_URI, "ip:1.2.3.4");
            testCase.verifyEqual(env.LG_PLACE, "bq");
            testCase.verifyEqual(env.LG_CARRIER, "zc706");
            testCase.verifyEqual(env.HW_CARRIER, "zc706");
            testCase.verifyEqual(env.HW_DAUGHTER, "adrv9371");
        end

        function toEnvironmentOmitsUnknownFields(testCase)
            lease = labgrid.Lease(URI="ip:1.2.3.4");
            env = lease.toEnvironment();
            testCase.verifyEqual(fieldnames(env), {'IIO_URI'});
        end

        function stringConversionIsReadable(testCase)
            lease = labgrid.Lease(URI="ip:1.2.3.4", Place="bq", Daughter="adrv9371");
            s = string(lease);
            testCase.verifySubstring(s, "bq");
            testCase.verifySubstring(s, "ip:1.2.3.4");
            testCase.verifySubstring(s, "adrv9371");
        end
    end
end
