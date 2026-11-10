classdef (TestTags = {'live'}) LiveBoardTest < matlab.unittest.TestCase
    % Boots a real board through the coordinator. Needs $LG_COORDINATOR, adi-lg, and a free
    % board for $LG_TEST_PART (default adrv9009). Each test takes minutes.

    properties
        Part
        Client
    end

    methods (TestClassSetup)
        function prerequisites(testCase)
            testCase.assumeNotEmpty(getenv("LG_COORDINATOR"), "set LG_COORDINATOR=host:20408");
            testCase.assumeTrue(labgrid.Session.isAvailable(), "adi-lg not found");
            testCase.Part = string(getenv("LG_TEST_PART"));
            if strlength(testCase.Part) == 0, testCase.Part = "adrv9009"; end
            testCase.Client = labgrid.Client();
            m = testCase.Client.match(testCase.Part);
            testCase.assumeTrue(m.satisfiable, "no live board for " + testCase.Part + ": " + m.reason);
        end
    end

    methods (Test)
        function sessionBootsVerifiesIiodAndReleases(testCase)
            s = labgrid.Session.request(testCase.Part, Wait=900, BootBudget=900);
            testCase.addTeardown(@() s.release());
            testCase.verifyTrue(startsWith(s.Lease.URI, "ip:"), "lease URI: " + s.Lease.URI);
            testCase.verifyEqual(s.Lease.Daughter, testCase.Part);
            p = testCase.Client.place(s.Lease.Place);
            testCase.verifyNotEqual(p.acquired, "", "coordinator should show the place acquired");
            t = tcpclient(s.Lease.host(), 30431, Timeout=15);
            testCase.verifyTrue(isvalid(t), "iiod should accept connections");
            clear t
            s.release();
            testCase.verifyTrue(helpers.waitUntil(@() strlength(testCase.Client.place(s.Lease.Place).acquired) == 0, 60), ...
                "place should be released on the coordinator");
        end

        function fixtureDrivesAConsumerSuite(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            dir = string(testCase.applyFixture(TemporaryFolderFixture).Folder);
            testCase.applyFixture(EnvironmentVariableFixture("LG_TEST_PART", testCase.Part));
            results = labgrid.runTests("livehelpers.RealBoardConsumerTests", ...
                JUnit=fullfile(dir, "j.xml"), Summary=fullfile(dir, "s.json"));
            testCase.verifyTrue(all([results.Passed]), "consumer suite should pass on the real board");
            s = jsondecode(fileread(fullfile(dir, "s.json")));
            testCase.verifyNotEqual(string(s.place), "");
            testCase.verifyTrue(startsWith(string(s.uri), "ip:"));
        end
    end
end
