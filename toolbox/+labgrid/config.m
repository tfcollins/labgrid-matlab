classdef config
    % labgrid.config  Environment-derived settings shared by the labgrid toolbox.
    %
    %   labgrid.config.coordinator()   gRPC host:port from $LG_COORDINATOR
    %   labgrid.config.apiUrl()        REST base URL ending in /api, from $LG_API or derived
    %                                  from $LG_COORDINATOR (host:8000)
    %   labgrid.config.adiLgBin()      adi-lg executable ($LG_ADI_LG_BIN, default "adi-lg")
    %   labgrid.config.leaseEnvVars()  environment variables exported by `adi-lg request --run`
    %
    %   These names are the single source of truth for every env-var the toolbox reads or writes.

    properties (Constant)
        EnvCoordinator = "LG_COORDINATOR"
        EnvApi = "LG_API"
        EnvAdiLgBin = "LG_ADI_LG_BIN"
        EnvIioUri = "IIO_URI"
        EnvPlace = "LG_PLACE"
        EnvCarrier = "LG_CARRIER"
        EnvHwDaughter = "HW_DAUGHTER"
        EnvHwCarrier = "HW_CARRIER"
        DefaultApiPort = 8000
    end

    methods (Static)
        function names = leaseEnvVars()
            names = [labgrid.config.EnvIioUri, labgrid.config.EnvPlace, labgrid.config.EnvCarrier, ...
                labgrid.config.EnvHwDaughter, labgrid.config.EnvHwCarrier];
        end

        function coord = coordinator()
            coord = string(getenv(labgrid.config.EnvCoordinator));
            if strlength(coord) == 0
                error("labgrid:noCoordinator", ...
                    "%s is not set. Point it at the labgrid coordinator, e.g. 10.0.0.41:20408.", ...
                    labgrid.config.EnvCoordinator);
            end
        end

        function url = apiUrl()
            url = string(getenv(labgrid.config.EnvApi));
            if strlength(url) == 0
                coord = labgrid.config.coordinator();
                host = extractBefore(coord + ":", ":");
                url = sprintf("http://%s:%d", host, labgrid.config.DefaultApiPort);
            end
            url = regexprep(url, "/+$", "");
            if ~endsWith(url, "/api")
                url = url + "/api";
            end
        end

        function bin = adiLgBin()
            bin = string(getenv(labgrid.config.EnvAdiLgBin));
            if strlength(bin) == 0
                bin = "adi-lg";
            end
        end
    end
end
