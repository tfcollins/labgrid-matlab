classdef ShellBackend < labgrid.internal.Backend
    % labgrid.internal.ShellBackend  POSIX-shell backend: nohup + a wrapper that forwards SIGTERM
    %   to adi-lg and records its exit code. MATLAB's LD_LIBRARY_PATH is stripped so the Python
    %   CLI loads the system libstdc++/OpenSSL rather than MATLAB's bundled copies.

    methods
        function pid = start(~, cmd, logFile, exitFile)
            arguments
                ~
                cmd (1,1) string
                logFile (1,1) string
                exitFile (1,1) string
            end
            script = "trap 'kill -TERM $child 2>/dev/null' TERM INT; " + cmd + " & child=$!; " + ...
                "wait $child; rc=$?; while kill -0 $child 2>/dev/null; do wait $child; rc=$?; done; " + ...
                "echo $rc > " + labgrid.internal.ShellBackend.quote(exitFile);
            wrapper = "env -u LD_LIBRARY_PATH nohup bash -c " + labgrid.internal.ShellBackend.quote(script) + ...
                " > " + labgrid.internal.ShellBackend.quote(logFile) + " 2>&1 < /dev/null & echo $!";
            [status, out] = system(wrapper);
            if status ~= 0
                error("labgrid:spawnFailed", "Could not start adi-lg: %s", out);
            end
            pid = str2double(strtrim(out));
            if ~isfinite(pid)
                error("labgrid:spawnFailed", "Could not determine adi-lg PID from: %s", out);
            end
        end

        function tf = isAlive(~, pid)
            [status, ~] = system(sprintf("kill -0 %d 2>/dev/null", pid));
            tf = status == 0;
        end

        function kill(~, pid)
            system(sprintf("kill -TERM %d 2>/dev/null", pid));
        end
    end

    methods (Static)
        function q = quote(s)
            % Single-quote s for POSIX sh (MATLAB strings keep backslashes literal).
            q = "'" + strrep(string(s), "'", "'\''") + "'";
        end
    end
end
