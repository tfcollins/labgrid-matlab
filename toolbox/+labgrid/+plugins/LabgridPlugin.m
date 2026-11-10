classdef LabgridPlugin < matlab.unittest.plugins.TestRunnerPlugin
    % labgrid.plugins.LabgridPlugin  Reporting-only plugin: records which labgrid board ran each test.
    %
    %   runner.addPlugin(labgrid.plugins.LabgridPlugin)            % banner to stdout
    %   runner.addPlugin(labgrid.plugins.LabgridPlugin(ToFile(f)))  % banner to an OutputStream
    %
    %   Each TestResult gets Details.labgrid = struct(place, carrier, daughter, uri, source) when a
    %   lease is present in the environment while the test runs (exported by BoardFixture or by
    %   `adi-lg request --run`). Acquisition is NOT done here; see labgrid.fixtures.BoardFixture.

    properties (Access = private)
        Stream
    end

    methods
        function plugin = LabgridPlugin(stream)
            arguments
                stream (1,1) matlab.automation.streams.OutputStream = matlab.automation.streams.ToStandardOutput
            end
            plugin.Stream = stream;
        end
    end

    methods (Access = protected)
        function runTestSuite(plugin, pluginData)
            lease = labgrid.Lease.fromEnvironment();
            coord = string(getenv(labgrid.config.EnvCoordinator));
            if isempty(lease)
                plugin.Stream.print("[labgrid] no board lease in environment (coordinator: %s)\n", ...
                    plugin.orNone(coord));
            else
                plugin.Stream.print("[labgrid] board %s (%s on %s) at %s [%s] (coordinator: %s)\n", ...
                    lease.Place, plugin.orNone(lease.Daughter), plugin.orNone(lease.Carrier), ...
                    lease.URI, lease.Source, plugin.orNone(coord));
            end
            runTestSuite@matlab.unittest.plugins.TestRunnerPlugin(plugin, pluginData);
        end

        function runTest(plugin, pluginData)
            runTest@matlab.unittest.plugins.TestRunnerPlugin(plugin, pluginData);
            lease = labgrid.Lease.fromEnvironment();
            if ~isempty(lease)
                pluginData.ResultDetails.append("labgrid", struct( ...
                    "place", lease.Place, "carrier", lease.Carrier, "daughter", lease.Daughter, ...
                    "uri", lease.URI, "source", lease.Source));
            end
        end
    end

    methods (Static, Access = private)
        function s = orNone(s)
            if strlength(s) == 0
                s = "<none>";
            end
        end
    end
end
