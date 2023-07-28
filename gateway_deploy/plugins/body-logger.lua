local log_util    = require("apisix.utils.log-util")
local core        = require("apisix.core")
local ngx         = ngx

local schema      = {
    type = "object",
    properties = {
        path = { type = "string" },
    },
    required = { "path" },
}


local _M = {
    version  = 0.1,
    priority = 390,
    name     = "body-logger",
    schema   = schema,
}

function _M.check_schema(conf)
    return core.schema.check(schema, conf)
end

-- 判断目录是否存在
function check_dir_exist(dir_path)
    local success, message = pcall(function()
        local f = io.open(dir_path, "r")
        if f ~= nil then
            io.close(f)
            return true
        else
            return false
        end
    end)

    -- 如果出错，则目录不存在
    if not success then
        return false
    end

    return message
end

-- 向文件写入内容
local function write_data_to_file(file_path, data)
    local file, err = io.open(file_path, "w")
    if not file then
        core.log.error("failed to create file: ", file_path, ", error info: ", err)
    else
        if data == nil or data == "" then
            core.log.error("failed to write file: ", file_path, ", error info: data is nil or ''")
        else
            local ok, err = file:write(data)
            if not ok then
                core.log.error("failed to write file: ", file_path, ", error info: ", err)
            end
            file:close()
        end
    end
end

-- 将请求和返回值写入到文件
local function write_file_data(conf, request_body, response_body, request_id)
    local response_body = core.json.encode(response_body, true)
    local date = os.date("%Y-%m-%d")
    local dir_path = conf.path .. "/" .. date
    local file_path_req = string.format("%s/%s.req", dir_path, request_id)
    local file_path_resp = string.format("%s/%s.resp", dir_path, request_id)

    if not check_dir_exist(dir_path) then
        os.execute("mkdir -p " .. dir_path)
    end

    write_data_to_file(file_path_req, request_body)
    write_data_to_file(file_path_resp, response_body)
end

function _M.access(ctx)
    local request_body, err = core.request.get_body(nil, ctx)
    if not request_body then
        request_body = ""
        if err then
            core.log.error("failed to get body: ", err)
        end
    end
    ngx.ctx.request_body = request_body
end

function _M.body_filter(conf, ctx)
    conf.include_resp_body = true
    log_util.collect_body(conf, ctx)
end

function _M.log(conf, ctx)
    local request_id = ngx.header["X-Request-Id"]
    local response_body = ctx.resp_body
    local request_body = ngx.ctx.request_body
    write_file_data(conf, request_body, response_body, request_id)
end

return _M
