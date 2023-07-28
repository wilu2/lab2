local core              = require("apisix.core")
local ngx               = ngx
local decode_base64     = ngx.decode_base64
local req_set_body_data = ngx.req.set_body_data
local http              = require("resty.http")
local url               = require("net.url")

local schema            = {
    type = "object",
    properties = {
        disable = {type = "boolean", default = false}
    },
}


local _M = {
    version  = 0.1,
    priority = 395,
    name     = "request-body-hooker",
    schema   = schema,
}

function _M.check_schema(conf)
    return core.schema.check(schema, conf)
end

function _M.rewrite(conf, ctx)
    local content_type = core.request.header(ctx, "Content-Type")

    if content_type == "application/json" then
        local request_body, err = core.request.get_body(nil, ctx)
        if err ~= nil or request_body == nil then
            core.log.error("failed to get body: ", err)
        else
            local body = core.json.decode(request_body)
            if body ~= nil and body.file_base64 ~= nil then
                local rewrite_body = decode_base64(body.file_base64)
                core.request.set_header(ctx, "Content-Type", "application/octet-stream")
                req_set_body_data(rewrite_body)
            end
        end
    end
end

return _M
