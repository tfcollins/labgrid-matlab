function withLeaseEnv(testCase, varargin)
% Apply EnvironmentVariableFixtures for a fake adi-lg hand-over, clearing everything first.
% withLeaseEnv(testCase)                      -> all lease vars cleared
% withLeaseEnv(testCase, "IIO_URI", "ip:..")  -> cleared, then the given pairs set
import matlab.unittest.fixtures.EnvironmentVariableFixture
for n = labgrid.config.leaseEnvVars()
    testCase.applyFixture(EnvironmentVariableFixture(n, ""));
end
for k = 1:2:numel(varargin)
    testCase.applyFixture(EnvironmentVariableFixture(string(varargin{k}), string(varargin{k+1})));
end
end
