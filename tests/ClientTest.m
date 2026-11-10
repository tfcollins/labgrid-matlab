classdef ClientTest < matlab.unittest.TestCase
    % labgrid.Client — read-only REST client for the coordinator dashboard API.

    properties (Constant)
        Recorded = fullfile(helpers.repoRoot(), "tests", "recorded")
    end

    methods (Access = private)
        function [client, seen] = clientServing(testCase, status, body)
            % A client whose transport answers every request with (status, body) and records URLs.
            seen = {};
            function [s, b] = transport(url)
                seen{end+1} = string(url); %#ok<AGROW>
                s = status; b = body;
            end
            client = labgrid.Client(BaseURL="http://coord:8000/api", Transport=@transport);
            testCase.addTeardown(@() []);
        end

        function txt = recorded(testCase, name)
            txt = string(fileread(fullfile(testCase.Recorded, name)));
        end
    end

    methods (Test)
        function placesParsesRecordedResponse(testCase)
            client = testCase.clientServing(200, testCase.recorded("places.json"));
            p = client.places();
            testCase.verifyClass(p, "struct");
            testCase.verifyNumElements(p, 9);
            testCase.verifyEqual(p(1).name, "bq");
            testCase.verifyEqual(p(1).daughter, "adrv9371");
            testCase.verifyEqual(p(1).carrier, "zc706");
            testCase.verifyEqual(p(1).bootStrategy, "BootFPGASoCTFTP");
            testCase.verifyEqual(p(1).acquired, "");
            testCase.verifyEqual(labgrid.internal.tagValue(p(1).tags, "board-location"), "bq");
        end

        function placesWithDifferingTagSetsStillFormAStructArray(testCase)
            body = ['[{"name":"a","tags":{"carrier":"zc706"},"acquired":null,"acquired_username":null,"reservation":null},' ...
                    '{"name":"b","tags":{},"acquired":"web-dashboard/analog","acquired_username":"analog","reservation":null}]'];
            client = testCase.clientServing(200, body);
            p = client.places();
            testCase.verifyNumElements(p, 2);
            testCase.verifyEqual([p.name], ["a", "b"]);
            testCase.verifyEqual(p(2).acquired, "web-dashboard/analog");
            testCase.verifyEqual(p(2).daughter, "");
        end

        function placeRequestsByNameAndReturnsOne(testCase)
            [client, ~] = testCase.clientServing(200, testCase.recorded("place_bq.json"));
            p = client.place("bq");
            testCase.verifyEqual(p.name, "bq");
            testCase.verifyEqual(p.daughter, "adrv9371");
        end

        function requestUrlsAreBuiltFromBaseUrl(testCase)
            urls = {};
            function [s, b] = transport(url)
                urls{end+1} = string(url); %#ok<AGROW>
                s = 200; b = testCase.recorded("match_satisfiable.json");
            end
            client = labgrid.Client(BaseURL="http://coord:8000/api/", Transport=@transport);
            client.match("adrv9371", Carrier="zc706");
            testCase.verifyEqual(urls{1}, "http://coord:8000/api/match?part=adrv9371&carrier=zc706");
        end

        function matchParsesSatisfiableResponse(testCase)
            client = testCase.clientServing(200, testCase.recorded("match_satisfiable.json"));
            m = client.match("adrv9371");
            testCase.verifyTrue(m.satisfiable);
            testCase.verifyEqual(m.place, "bq");
            testCase.verifyEqual(m.image, "2023_R2_P1");
            testCase.verifyEqual(m.runner, "hw-bq");
        end

        function matchParsesUnsatisfiableResponse(testCase)
            client = testCase.clientServing(200, testCase.recorded("match_unsatisfiable.json"));
            m = client.match("adrv9002");
            testCase.verifyFalse(m.satisfiable);
            testCase.verifySubstring(m.reason, "no live place");
            testCase.verifyEqual(m.place, "");
        end

        function healthParsesRecordedResponse(testCase)
            client = testCase.clientServing(200, testCase.recorded("health.json"));
            h = client.health();
            testCase.verifyEqual(h.status, "ok");
            testCase.verifyTrue(h.coordinator_connected);
        end

        function httpErrorStatusRaisesTypedError(testCase)
            client = testCase.clientServing(404, '{"detail":"place not found"}');
            testCase.verifyError(@() client.place("nope"), "labgrid:httpError");
            try
                client.place("nope");
            catch err
                testCase.verifySubstring(err.message, "404");
                testCase.verifySubstring(err.message, "place not found");
            end
        end

        function transportFailureRaisesUnreachable(testCase)
            function [s, b] = transport(~)
                error("MATLAB:webservices:ConnectionRefused", "Connection refused");
            end
            client = labgrid.Client(BaseURL="http://coord:8000/api", Transport=@transport);
            testCase.verifyError(@() client.health(), "labgrid:coordinatorUnreachable");
        end

        function baseUrlDefaultsFromEnvironment(testCase)
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            testCase.applyFixture(EnvironmentVariableFixture("LG_API", ""));
            testCase.applyFixture(EnvironmentVariableFixture("LG_COORDINATOR", "10.0.0.41:20408"));
            client = labgrid.Client();
            testCase.verifyEqual(client.BaseURL, "http://10.0.0.41:8000/api");
        end
    end
end
