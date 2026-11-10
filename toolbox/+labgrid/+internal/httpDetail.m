function d = httpDetail(body)
% labgrid.internal.httpDetail  Best-effort extraction of FastAPI's {"detail": ...} from an error body.
d = string(body);
try
    j = jsondecode(char(body));
    if isstruct(j) && isfield(j, "detail")
        d = string(jsonencode(j.detail));
        d = erase(d, """");
    end
catch
end
end
