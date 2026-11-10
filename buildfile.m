function plan = buildfile
% Build plan for labgrid-matlab.
%   buildtool test      unit tests (no hardware; excludes tag "live")
%   buildtool testLive  live tests against the coordinator / a free board
%   buildtool package   build releases/labgrid-matlab.mltbx
import matlab.buildtool.tasks.TestTask

plan = buildplan(localfunctions);

root = plan.RootFolder;
addpath(fullfile(root, "toolbox"));  % TestTask SourceFiles is for coverage only; tests need the toolbox on the path
addpath(fullfile(root, "tests"));    % +helpers package, shared by unit and live tests
% Unit tests live directly in tests/; live (hardware) tests live in tests/live and are
% excluded here by not recursing into subfolders.
plan("test") = TestTask(fullfile(root, "tests"), ...
    SourceFiles=fullfile(root, "toolbox"), ...
    IncludeSubfolders=false, ...
    TestResults=fullfile(root, "tests", "tmp", "unit-results.xml"), ...
    OutputDetail="concise");

plan("testLive") = TestTask(fullfile(root, "tests", "live"), ...
    SourceFiles=fullfile(root, "toolbox"), ...
    TestResults=fullfile(root, "tests", "tmp", "live-results.xml"));

plan.DefaultTasks = "test";
end

function packageTask(context)
% Package the toolbox into releases/labgrid-matlab.mltbx
root = context.Plan.RootFolder;
tbx = fullfile(root, "toolbox");
opts = matlab.addons.toolbox.ToolboxOptions(tbx, "c1dc3eb6-8b1f-46a3-9642-8f8d406b1f5b", ...
    ToolboxName="labgrid-matlab", ...
    ToolboxVersion=labgrid.internal.version(), ...
    Summary="matlab.unittest fixtures and runner for labgrid-coordinator-owned hardware", ...
    AuthorName="Analog Devices, Inc.", ...
    ToolboxMatlabPath=tbx, ...
    OutputFile=fullfile(root, "releases", "labgrid-matlab.mltbx"));
if ~isfolder(fullfile(root, "releases")), mkdir(fullfile(root, "releases")); end
matlab.addons.toolbox.packageToolbox(opts);
end
