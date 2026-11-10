function pid = startBackground(cmd, exitFile)
% Start a shell command in the background; its exit code is written to exitFile when it ends.
% Returns the PID of the wrapper shell running cmd.
arguments
    cmd (1,1) string
    exitFile (1,1) string
end
wrapper = sprintf('bash -c ''%s; echo $? > "%s"'' > /dev/null 2>&1 & echo $!', ...
    strrep(cmd, "'", "'\''"), exitFile);
[status, out] = system(wrapper);
assert(status == 0, "could not start background command: %s", out);
pid = str2double(strtrim(out));
end
