function tf = pidAlive(pid)
% True when a process with this PID exists (POSIX).
[status, ~] = system(sprintf("kill -0 %d 2>/dev/null", pid));
tf = status == 0;
end
