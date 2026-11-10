function e = exitCodeToError(code, logTail)
% labgrid.internal.exitCodeToError  Map an `adi-lg request` exit code to a typed MException.
%   Codes follow adi_lg_plugins/request/errors.py: 10 no match, 11 unavailable, 12 provision
%   failure, 130 interrupted; 2 is click's usage error. Anything else is "labgrid:adiLgFailed".
arguments
    code (1,1) double
    logTail (1,1) string = ""
end
switch code
    case 10
        e = MException("labgrid:noMatchingBoard", "No matching board (adi-lg exit 10).%s", suffix(logTail));
    case 11
        e = MException("labgrid:boardUnavailable", "Board unavailable (adi-lg exit 11).%s", suffix(logTail));
    case 12
        e = MException("labgrid:provisionFailed", "Board provisioning/boot failed (adi-lg exit 12).%s", suffix(logTail));
    case 130
        e = MException("labgrid:interrupted", "adi-lg was interrupted; board released.%s", suffix(logTail));
    case 2
        e = MException("labgrid:adiLgUsage", "adi-lg rejected its arguments (exit 2).%s", suffix(logTail));
    otherwise
        e = MException("labgrid:adiLgFailed", "adi-lg exited with code %d.%s", code, suffix(logTail));
end
end

function s = suffix(logTail)
if strlength(logTail) == 0
    s = "";
else
    s = newline + "--- adi-lg output (tail) ---" + newline + logTail;
end
end
