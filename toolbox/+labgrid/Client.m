classdef Client
    % labgrid.Client  Read-only client for the labgrid coordinator dashboard REST API.
    %
    %   c = labgrid.Client()                         base URL from $LG_API / $LG_COORDINATOR
    %   c = labgrid.Client(BaseURL="http://host:8000/api")
    %
    %   c.health()                 struct: status, coordinator_connected, coordinator_address
    %   c.places()                 struct array (see labgrid.internal.decodePlaces)
    %   c.place("bq")              one place struct
    %   c.match("adrv9371", Carrier="zc706")
    %                              struct: satisfiable, place, image, strategy, runner, reason, ...
    %
    %   Errors: "labgrid:coordinatorUnreachable" when the request cannot be made,
    %   "labgrid:httpError" for any non-2xx status (message carries status + body detail).
    %
    %   Transport (for tests) is a function handle  [status, bodyText] = f(url).

    properties (SetAccess = immutable)
        BaseURL (1,1) string
        Timeout (1,1) double = 10
    end

    properties (Access = private)
        Transport
    end

    methods
        function obj = Client(opts)
            arguments
                opts.BaseURL (1,1) string = ""
                opts.Timeout (1,1) double = 10
                opts.Transport = []
            end
            if strlength(opts.BaseURL) == 0
                opts.BaseURL = labgrid.config.apiUrl();
            end
            obj.BaseURL = regexprep(opts.BaseURL, "/+$", "");
            obj.Timeout = opts.Timeout;
            if isempty(opts.Transport)
                obj.Transport = @(url) labgrid.internal.httpGet(url, obj.Timeout);
            else
                obj.Transport = opts.Transport;
            end
        end

        function h = health(obj)
            h = obj.getJson("/health");
            h.status = string(h.status);
        end

        function p = places(obj)
            p = labgrid.internal.decodePlaces(obj.getText("/places"));
        end

        function p = place(obj, name)
            arguments
                obj
                name (1,1) string
            end
            p = labgrid.internal.decodePlaces(obj.getText("/places/" + name));
            p = p(1);
        end

        function m = match(obj, part, opts)
            arguments
                obj
                part (1,1) string
                opts.Carrier (1,1) string = ""
            end
            q = "/match?part=" + urlencode(part);
            if strlength(opts.Carrier) > 0
                q = q + "&carrier=" + urlencode(opts.Carrier);
            end
            raw = obj.getJson(q);
            m = struct("satisfiable", logical(raw.satisfiable), ...
                "place", orEmpty(raw, "place"), "image", orEmpty(raw, "image"), ...
                "strategy", orEmpty(raw, "strategy"), "runner", orEmpty(raw, "runner"), ...
                "reason", orEmpty(raw, "reason"), "reservationFilter", struct(), "flash", []);
            if isfield(raw, "reservation_filter") && isstruct(raw.reservation_filter)
                m.reservationFilter = raw.reservation_filter;
            end
            if isfield(raw, "flash")
                m.flash = raw.flash;
            end
        end
    end

    methods (Access = private)
        function txt = getText(obj, path)
            url = obj.BaseURL + path;
            try
                [status, body] = obj.Transport(url);
            catch err
                error("labgrid:coordinatorUnreachable", ...
                    "Coordinator REST API at %s is unreachable: %s", obj.BaseURL, err.message);
            end
            if status < 200 || status >= 300
                error("labgrid:httpError", "GET %s returned HTTP %d: %s", url, status, ...
                    labgrid.internal.httpDetail(body));
            end
            txt = string(body);
        end

        function data = getJson(obj, path)
            data = jsondecode(char(obj.getText(path)));
        end
    end
end

function v = orEmpty(s, field)
if isfield(s, field) && ~isempty(s.(field))
    v = string(s.(field));
else
    v = "";
end
end
