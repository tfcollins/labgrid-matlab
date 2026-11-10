function [status, body] = httpGet(url, timeout)
% labgrid.internal.httpGet  Default Client transport: GET url, return [statusCode, bodyText].
%   Raises on connection failure; never raises on HTTP error statuses (the Client does).
import matlab.net.http.RequestMessage
import matlab.net.http.HTTPOptions
import matlab.net.http.MediaType
opts = HTTPOptions(ConnectTimeout=timeout, ConvertResponse=false);
req = RequestMessage(matlab.net.http.RequestMethod.GET);
req = req.addFields(matlab.net.http.field.AcceptField(MediaType("application/json")));
resp = req.send(matlab.net.URI(url), opts);
status = double(resp.StatusCode);
body = resp.Body.Data;
if isa(body, "uint8")
    body = native2unicode(body(:)', "UTF-8");
end
body = string(body);
end
