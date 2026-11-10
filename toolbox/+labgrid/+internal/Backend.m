classdef (Abstract) Backend
    % labgrid.internal.Backend  How labgrid.Session starts and supervises the adi-lg process.
    %   Swap point for a future `adi-lg request --hold` mode: Session only uses this interface.
    methods (Abstract)
        pid = start(obj, cmd, logFile, exitFile)   % run cmd in the background; exit code -> exitFile
        tf = isAlive(obj, pid)
        kill(obj, pid)                             % polite stop (SIGTERM); adi-lg releases on it
    end
end
