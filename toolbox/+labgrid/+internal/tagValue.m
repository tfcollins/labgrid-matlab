function v = tagValue(tags, name)
% labgrid.internal.tagValue  Look up a place tag by its original (hyphenated) name.
%   jsondecode renames keys such as "daughter-board" to "daughter_board" via
%   matlab.lang.makeValidName; this applies the same mapping to the lookup key.
%   Returns "" when the tag is absent.
arguments
    tags (1,1) struct
    name (1,1) string
end
key = matlab.lang.makeValidName(char(name));
if isfield(tags, key)
    v = string(tags.(key));
else
    v = "";
end
end
