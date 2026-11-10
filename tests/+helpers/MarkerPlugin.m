classdef MarkerPlugin < matlab.unittest.plugins.TestRunnerPlugin
    % Test-only plugin that writes one line per test so runner tests can prove it was attached.
    properties (Access = private)
        Stream
    end
    methods
        function p = MarkerPlugin(stream)
            p.Stream = stream;
        end
    end
    methods (Access = protected)
        function runTest(p, pluginData)
            p.Stream.print("MarkerPlugin saw %s\n", pluginData.Name);
            runTest@matlab.unittest.plugins.TestRunnerPlugin(p, pluginData);
        end
    end
end
