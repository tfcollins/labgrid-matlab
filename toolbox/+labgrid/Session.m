classdef Session < handle
    % labgrid.Session  Hold a labgrid-booted board for the lifetime of a MATLAB session.
    %
    %   s = labgrid.Session.request("adrv9371", Carrier="zc706")   % blocks until booted
    %   s.Lease.URI                                                % "ip:10.0.0.132"
    %   s.release()                                                % give the board back
    %
    %   Implementation: spawns `adi-lg request --part ... --run "bash lg-hold.sh ..."`; the hold
    %   script writes the exported lease to a JSON file and then blocks until release() creates a
    %   sentinel file, this MATLAB process dies, or HoldTimeout elapses. When it exits, adi-lg
    %   releases the coordinator reservation. Each live session is recorded under
    %   labgrid.config.sessionsDir() so labgrid.Session.reap() can clean up after a crash.
    %
    %   tf = labgrid.Session.isAvailable()   true when the adi-lg executable can be found
    %   a  = labgrid.Session.reap(Client=c)  remove dead session records; kill sessions whose
    %                                        place the coordinator no longer shows as acquired
    %
    %   Errors from request(): labgrid:unsupportedPlatform, labgrid:adiLgNotFound,
    %   labgrid:noMatchingBoard, labgrid:boardUnavailable, labgrid:provisionFailed,
    %   labgrid:interrupted, labgrid:adiLgUsage, labgrid:adiLgFailed, labgrid:bootTimeout.

    properties (SetAccess = private)
        Lease labgrid.Lease = labgrid.Lease.empty(0, 0)
        Part (1,1) string = ""
        Carrier (1,1) string = ""
        Pid (1,1) double = 0
        LogFile (1,1) string = ""
        Released (1,1) logical = false
    end

    properties (Access = private)
        Backend
        WorkDir (1,1) string = ""
        ReleaseFile (1,1) string = ""
        SessionFile (1,1) string = ""
        ReleaseTimeout (1,1) double = 30
    end

    methods (Static)
        function tf = isAvailable()
            bin = labgrid.config.adiLgBin();
            if contains(bin, filesep)
                tf = isfile(bin);
                return
            end
            dirs = split(string(getenv("PATH")), pathsep);
            tf = any(arrayfun(@(d) strlength(d) > 0 && isfile(fullfile(d, bin)), dirs));
        end

        function s = request(part, opts)
            arguments
                part (1,1) string
                opts.Carrier (1,1) string = ""
                opts.Wait (1,1) double = 1800          % seconds adi-lg queues for a free board
                opts.PowerDown (1,1) logical = false
                opts.HoldTimeout (1,1) double = 4*3600 % hold-script backstop, seconds
                opts.BootBudget (1,1) double = 600     % seconds allowed for boot after the wait
                opts.LogFile (1,1) string = ""
                opts.Poll (1,1) double = 0.5
                opts.Backend = labgrid.internal.ShellBackend()
            end
            if ispc
                error("labgrid:unsupportedPlatform", ...
                    "labgrid.Session needs a POSIX shell; on Windows run under `adi-lg request --run` instead.");
            end
            if ~labgrid.Session.isAvailable()
                error("labgrid:adiLgNotFound", ...
                    "'%s' not found. Install labgrid-plugins (pip install adi-labgrid-plugins) or set %s.", ...
                    labgrid.config.adiLgBin(), labgrid.config.EnvAdiLgBin);
            end

            s = labgrid.Session();
            s.Backend = opts.Backend;
            s.Part = part;
            s.Carrier = opts.Carrier;
            s.WorkDir = string(tempname("/tmp")) + "-labgrid";
            mkdir(s.WorkDir);
            leaseFile = fullfile(s.WorkDir, "lease.json");
            exitFile = fullfile(s.WorkDir, "exit");
            s.ReleaseFile = fullfile(s.WorkDir, "release");
            if strlength(opts.LogFile) == 0
                opts.LogFile = fullfile(s.WorkDir, "adi-lg.log");
            end
            s.LogFile = opts.LogFile;

            q = @labgrid.internal.ShellBackend.quote;
            hold = sprintf('bash %s %s %s %d %d %g', q(labgrid.Session.holdScript()), q(leaseFile), ...
                q(s.ReleaseFile), feature("getpid"), round(opts.HoldTimeout), opts.Poll);
            cmd = q(labgrid.config.adiLgBin()) + " request --part " + q(part);
            if strlength(opts.Carrier) > 0
                cmd = cmd + " --carrier " + q(opts.Carrier);
            end
            cmd = cmd + sprintf(" --wait %d", round(opts.Wait));
            if opts.PowerDown
                cmd = cmd + " --power-down";
            end
            cmd = cmd + " --run " + q(hold);

            s.Pid = s.Backend.start(cmd, s.LogFile, exitFile);
            deadline = tic;
            budget = opts.Wait + opts.BootBudget;
            while ~isfile(leaseFile)
                if ~s.Backend.isAlive(s.Pid)
                    code = labgrid.Session.readExitCode(exitFile);
                    s.Released = true;
                    throw(labgrid.internal.exitCodeToError(code, labgrid.Session.tail(s.LogFile)));
                end
                if toc(deadline) > budget
                    s.Backend.kill(s.Pid);
                    labgrid.Session.waitUntilDead(s.Backend, s.Pid, 10);
                    s.Released = true;
                    error("labgrid:bootTimeout", ...
                        "No board lease after %g s (wait %g + boot budget %g); adi-lg stopped.%s", ...
                        budget, opts.Wait, opts.BootBudget, ...
                        newline + labgrid.Session.tail(s.LogFile));
                end
                pause(opts.Poll);
            end
            j = jsondecode(fileread(leaseFile));
            s.Lease = labgrid.Lease(URI=string(j.uri), Place=string(j.place), Carrier=string(j.carrier), ...
                Daughter=string(j.daughter), Source="session");
            s.writeSessionFile();
        end

        function actions = reap(opts)
            % Clean up session records left behind by crashed MATLAB processes.
            arguments
                opts.Client = []
            end
            backend = labgrid.internal.ShellBackend();
            d = labgrid.config.sessionsDir();
            files = dir(fullfile(d, "*.json"));
            actions = struct("file", {}, "pid", {}, "place", {}, "action", {});
            for f = files(:)'
                file = string(fullfile(f.folder, f.name));
                try
                    j = jsondecode(fileread(file));
                catch
                    delete(file);
                    actions(end+1) = struct("file", file, "pid", NaN, "place", "", "action", "removed-corrupt"); %#ok<AGROW>
                    continue
                end
                place = string(j.place);
                if ~backend.isAlive(j.pid)
                    delete(file);
                    action = "removed-dead";
                elseif ~isempty(opts.Client) && labgrid.Session.placeIsFree(opts.Client, place)
                    backend.kill(j.pid);
                    delete(file);
                    action = "killed-orphan";
                else
                    action = "kept";
                end
                actions(end+1) = struct("file", file, "pid", j.pid, "place", place, "action", action); %#ok<AGROW>
            end
        end
    end

    methods
        function release(s)
            if s.Released
                return
            end
            s.Released = true;
            if strlength(s.ReleaseFile) > 0
                fclose(fopen(s.ReleaseFile, "w"));
            end
            if s.Pid > 0 && ~labgrid.Session.waitUntilDead(s.Backend, s.Pid, s.ReleaseTimeout)
                s.Backend.kill(s.Pid);
                labgrid.Session.waitUntilDead(s.Backend, s.Pid, 10);
            end
            if strlength(s.SessionFile) > 0 && isfile(s.SessionFile)
                delete(s.SessionFile);
            end
        end

        function delete(s)
            try
                s.release();
            catch
            end
        end
    end

    methods (Access = private)
        function writeSessionFile(s)
            d = labgrid.config.sessionsDir();
            if ~isfolder(d)
                mkdir(d);
            end
            s.SessionFile = fullfile(d, sprintf("%s-%d.json", s.Lease.Place, s.Pid));
            rec = struct("pid", s.Pid, "place", s.Lease.Place, "part", s.Part, "carrier", s.Lease.Carrier, ...
                "uri", s.Lease.URI, "started", string(datetime("now", TimeZone="UTC", Format="yyyy-MM-dd'T'HH:mm:ss'Z'")), ...
                "matlabPid", feature("getpid"), "workDir", s.WorkDir, "logFile", s.LogFile, ...
                "releaseFile", s.ReleaseFile);
            writelines(jsonencode(rec, PrettyPrint=true), s.SessionFile);
        end
    end

    methods (Static, Access = private)
        function p = holdScript()
            p = fullfile(fileparts(fileparts(mfilename("fullpath"))), "bin", "lg-hold.sh");
        end

        function code = readExitCode(exitFile)
            t0 = tic;
            while ~isfile(exitFile) && toc(t0) < 5
                pause(0.1);
            end
            if isfile(exitFile)
                code = str2double(strtrim(fileread(exitFile)));
            else
                code = NaN;
            end
            if ~isfinite(code)
                code = -1;
            end
        end

        function t = tail(logFile, n)
            if nargin < 2
                n = 20;
            end
            t = "";
            if ~isfile(logFile)
                return
            end
            lines = string(splitlines(strtrim(fileread(logFile))));
            t = join(lines(max(1, end-n+1):end), newline);
        end

        function dead = waitUntilDead(backend, pid, timeout)
            t0 = tic;
            dead = ~backend.isAlive(pid);
            while ~dead && toc(t0) < timeout
                pause(0.2);
                dead = ~backend.isAlive(pid);
            end
        end

        function tf = placeIsFree(client, place)
            try
                p = client.place(place);
                tf = strlength(p.acquired) == 0;
            catch
                tf = false;   % cannot tell -> keep the session
            end
        end
    end
end
