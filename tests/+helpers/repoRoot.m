function root = repoRoot()
% Absolute path of the labgrid-matlab checkout (tests/+helpers/repoRoot.m -> ../..).
root = string(fileparts(fileparts(fileparts(mfilename("fullpath")))));
end
