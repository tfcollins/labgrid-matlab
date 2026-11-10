function places = decodePlaces(text)
% labgrid.internal.decodePlaces  Decode GET /api/places (array) or /api/places/{name} (object).
%   Returns a struct array with a fixed field set regardless of how jsondecode shaped the
%   input (struct array when all places share fields, cell array otherwise):
%     name, tags, daughter, carrier, bootStrategy, hdlConfig, acquired, acquiredUsername, reservation
%   Null JSON values become "".
raw = jsondecode(char(text));
if iscell(raw)
    items = raw;
elseif isstruct(raw)
    items = num2cell(raw(:));
else
    error("labgrid:badResponse", "Expected a JSON object or array of places.");
end
places = repmat(template(), 0, 1);
for k = 1:numel(items)
    places(end+1, 1) = normalize(items{k}); %#ok<AGROW>
end
end

function p = normalize(item)
p = template();
p.name = str(item, "name");
if isfield(item, "tags") && isstruct(item.tags)
    p.tags = item.tags;
end
p.daughter = labgrid.internal.tagValue(p.tags, "daughter-board");
p.carrier = labgrid.internal.tagValue(p.tags, "carrier");
p.bootStrategy = labgrid.internal.tagValue(p.tags, "boot-strategy");
p.hdlConfig = labgrid.internal.tagValue(p.tags, "hdl-config");
p.acquired = str(item, "acquired");
p.acquiredUsername = str(item, "acquired_username");
p.reservation = str(item, "reservation");
end

function v = str(item, field)
if isfield(item, field) && ~isempty(item.(field)) && (ischar(item.(field)) || isstring(item.(field)))
    v = string(item.(field));
else
    v = "";
end
end

function p = template()
p = struct("name", "", "tags", struct(), "daughter", "", "carrier", "", "bootStrategy", "", ...
    "hdlConfig", "", "acquired", "", "acquiredUsername", "", "reservation", "");
end
