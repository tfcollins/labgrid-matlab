function part = testPart()
% Board part for live tests: $LG_TEST_PART, default adrv9009 (place "nemo").
part = string(getenv("LG_TEST_PART"));
if strlength(part) == 0
    part = "adrv9009";
end
end
