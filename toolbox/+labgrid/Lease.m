classdef Lease
    % labgrid.Lease  A booted board handed over by the labgrid coordinator.
    %
    %   lease = labgrid.Lease.fromEnvironment() reads the variables that `adi-lg request --run`
    %   exports (IIO_URI, LG_PLACE, LG_CARRIER, HW_DAUGHTER, HW_CARRIER) and returns an empty
    %   Lease array when IIO_URI is unset.
    %
    %   lease = labgrid.Lease(URI=..., Place=..., Carrier=..., Daughter=..., Tags=..., Source=...)
    %
    %   lease.host()            host part of an "ip:<host>" URI ("" otherwise)
    %   lease.tag("daughter-board")  place tag by its original (hyphenated) name
    %   lease.toEnvironment()   struct of env-var name -> value for the non-empty fields

    properties
        URI (1,1) string = ""        % libIIO URI, e.g. "ip:10.0.0.132"
        Place (1,1) string = ""      % labgrid place name
        Carrier (1,1) string = ""    % carrier board tag, e.g. "zc706"
        Daughter (1,1) string = ""   % daughter board / part, e.g. "adrv9371"
        Tags (1,1) struct = struct() % place tags as decoded by jsondecode (hyphens -> underscores)
        Source (1,1) string = ""     % "env" (handed over by adi-lg) or "session" (labgrid.Session)
    end

    methods (Static)
        function lease = fromEnvironment()
            c = labgrid.config;
            uri = string(getenv(c.EnvIioUri));
            if strlength(uri) == 0
                lease = labgrid.Lease.empty(0, 0);
                return
            end
            carrier = string(getenv(c.EnvCarrier));
            if strlength(carrier) == 0
                carrier = string(getenv(c.EnvHwCarrier));
            end
            lease = labgrid.Lease(URI=uri, Place=string(getenv(c.EnvPlace)), Carrier=carrier, ...
                Daughter=string(getenv(c.EnvHwDaughter)), Source="env");
        end
    end

    methods
        function obj = Lease(opts)
            arguments
                opts.URI (1,1) string = ""
                opts.Place (1,1) string = ""
                opts.Carrier (1,1) string = ""
                opts.Daughter (1,1) string = ""
                opts.Tags (1,1) struct = struct()
                opts.Source (1,1) string = ""
            end
            obj.URI = opts.URI;
            obj.Place = opts.Place;
            obj.Carrier = opts.Carrier;
            obj.Daughter = opts.Daughter;
            obj.Tags = opts.Tags;
            obj.Source = opts.Source;
        end

        function h = host(obj)
            if startsWith(obj.URI, "ip:")
                h = extractAfter(obj.URI, "ip:");
            else
                h = "";
            end
        end

        function v = tag(obj, name)
            arguments
                obj
                name (1,1) string
            end
            key = matlab.lang.makeValidName(char(name));
            if isfield(obj.Tags, key)
                v = string(obj.Tags.(key));
            else
                v = "";
            end
        end

        function env = toEnvironment(obj)
            c = labgrid.config;
            env = struct();
            if strlength(obj.URI) > 0, env.(c.EnvIioUri) = obj.URI; end
            if strlength(obj.Place) > 0, env.(c.EnvPlace) = obj.Place; end
            if strlength(obj.Carrier) > 0
                env.(c.EnvCarrier) = obj.Carrier;
                env.(c.EnvHwCarrier) = obj.Carrier;
            end
            if strlength(obj.Daughter) > 0, env.(c.EnvHwDaughter) = obj.Daughter; end
        end

        function s = string(obj)
            s = sprintf("%s (%s on %s) -> %s [%s]", obj.Place, obj.Daughter, obj.Carrier, obj.URI, obj.Source);
        end
    end
end
