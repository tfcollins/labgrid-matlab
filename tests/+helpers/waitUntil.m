function ok = waitUntil(pred, timeoutSeconds, pollSeconds)
% Poll pred() until it returns true or timeoutSeconds elapse. Returns the final pred() value.
arguments
    pred (1,1) function_handle
    timeoutSeconds (1,1) double
    pollSeconds (1,1) double = 0.1
end
t0 = tic;
ok = pred();
while ~ok && toc(t0) < timeoutSeconds
    pause(pollSeconds);
    ok = pred();
end
end
