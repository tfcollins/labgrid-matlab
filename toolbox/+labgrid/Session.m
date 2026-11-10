classdef Session < handle
    % labgrid.Session  Hold a labgrid-booted board for the lifetime of a MATLAB session.
    %
    %   tf = labgrid.Session.isAvailable()   true when the adi-lg executable can be found

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
    end
end
