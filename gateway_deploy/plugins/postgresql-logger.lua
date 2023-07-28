local bp_manager_mod = require("apisix.utils.batch-processor-manager")
local log_util       = require("apisix.utils.log-util")
local core           = require("apisix.core")
local http           = require("resty.http")
local url            = require("net.url")
local bit            = require("bit")

local ngx            = ngx
local tostring       = tostring
local str_byte       = string.byte


--导入依赖
local pgmoon = require "pgmoon"
local plugin_name = "postgresql-logger"
local batch_processor_manager = bp_manager_mod.new(plugin_name)

local schema = {
    type = "object",
    properties = {
        host = { type = "string" },      -- postgresql服务器ip
        port = { type = "string" },      -- postgresql服务端口
        dbname = { type = "string" },    -- postgresql日志表所在数据库
        username = { type = "string" },  -- postgresql用户名
        password = { type = "string" },  -- postgresql密码
        tablename = { type = "string" }, -- postgresql日志表
        log_format = { type = "object" },
        encrypt = { type = "boolean", default = false }, -- postgresql 密码是否加密
        include_req_body = { type = "boolean", default = false },
        include_resp_body = { type = "boolean", default = false },
    },
    required = { "host", "port", "dbname", "username", "password", "tablename" }
    --apisix插件必须配置的参数，在apisix开启时会检查每个插件的配置是否有误，插件有误则该转发会失效
}

-- 日志格式元数据
local metadata_schema = {
    type = "object",
    properties = {
        log_format = {
            ["route_id"] = "$route_id",
            ["client_addr"] = "$remote_addr",
            ["iso_time"] = "$time_iso8601",
            ["timestamp"] = "$msec",
            ["time_cost"] = "$request_time",
            ["request_length"] = "$request_length",
            ["connection"] = "$connection",
            ["connection_requests"] = "$connection_requests",
            ["uri"] = "$uri",
            ["ori_request"] = "$request",
            ["query_string"] = "$query_string",
            ["status"] = "$status",
            ["bytes_sent"] = "$body_bytes_sent",
            ["referer"] = "$http_referer",
            ["user_agent"] = "$http_user_agent",
            ["forwarded_for"] = "$http_x_forwarded_for",
            ["host"] = "$host",
            ["node"] = "$hostname",
            ["upstream"] = "$upstream_addr",
            ["request_id"] = "$sent_http_x_request_id"
        }
    },
}


-- 插件元数据
local _M = {
    version = 0.1,
    priority = 393,
    name = plugin_name,
    schema = batch_processor_manager:wrap_schema(schema),
    metadata_schema = metadata_schema,
}

--conf就是我们进行插件配置的信息，这些信息会和schema对比，验证配置的格式合法性和是否缺失等等
function _M.check_schema(conf, schema_type)
    if schema_type == core.schema.TYPE_METADATA then
        return core.schema.check(metadata_schema, conf)
    end
    return core.schema.check(schema, conf)
end

local password_map = {} -- 密码map
local salt = 7
-- ASCII映射表
local mappingTable = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

-- decrypt函数将经过加密的内容还原为原始内容
function decrypt(encrypted)
    -- 将encrypted进行循环右移解密
    local pos = salt % #encrypted
    pos = #encrypted - pos
    encrypted = encrypted:sub(pos + 1) .. encrypted:sub(1, pos)

    local plaintext = ""
    local len = #mappingTable

    for i = 1, #encrypted do
        local char = encrypted:sub(i, i)
        local index = mappingTable:find(char, 1, true)
        if index then
            local newIndex = (index - salt - 1 + len) % len + 1
            plaintext = plaintext .. mappingTable:sub(newIndex, newIndex)
        else
            plaintext = plaintext .. char
        end
    end

    return plaintext
end

--发送日志，conf是插件配置
local function send_postgresql_data(conf, entries)
    local err_msg    -- 错误信息
    local res = true -- 发送是否成功
    local password = conf.password
    -- core.log.error(core.json.delay_encode(entries))
    if conf.encrypt then
        if password_map[conf.password] then
            password = password_map[conf.password] -- 使用已解密的密码
        else
            password = decrypt(conf.password) -- 解密密码
            password_map[conf.password] = password -- 存储解密结果到 map
        end
    end

    local pg = pgmoon.new({
        host = conf.host,
        port = conf.port,
        password = password,
        database = conf.dbname,
        user = conf.username
    })
    local success, err = pg:connect()
    if err then
        res = false;
        err_msg = "connect postgresql server failure";
        return res, err_msg;
    end
    for i = 1, #entries do
        local entry = entries[i]
        local timestamp = math.floor(entry.timestamp)
        local year, month, day = os.date("%Y", timestamp), os.date("%m", timestamp), os.date("%d", timestamp)
        local hour, min = os.date("%H", timestamp), os.date("%M", timestamp)
        local minutestamp = os.time({ year = year, month = month, day = day, hour = hour, min = min, sec = 0 })
        local hourstamp = os.time({ year = year, month = month, day = day, hour = hour, min = 0, sec = 0 })
        local datestamp = os.time({ year = year, month = month, day = day, hour = 0, min = 0, sec = 0 })

        -- 获取本周开始的时间戳
        local weeklystamp = os.time({
            year = year,
            month = month,
            day = os.date("%d", timestamp) - os.date("%w", timestamp) + 1,
            hour = 0,
            min = 0,
            sec = 0,
        })
        -- 如果本周第一天是 %w 为 0 的时间（即周日），则需要减去 7 天（604800 秒）
        if tonumber(os.date("%w", weeklystamp)) == 0 then
            weeklystamp = weeklystamp - 604800
        end

        -- 获取本月开始的时间戳
        local monthstamp = os.time({ year = year, month = month, day = 1, hour = 0, min = 0, sec = 0 })
        local yearstamp = os.time({ year = year, month = 1, day = 1, hour = 0, min = 0, sec = 0 })

        local data = {
            route_id = entry.route_id,
            request_id = entry.request_id,
            client_addr = entry.client_addr,
            iso_time = entry.iso_time,
            timestamp = timestamp,
            datestamp = datestamp,
            minutestamp = minutestamp,
            hourstamp = hourstamp,
            weeklystamp = weeklystamp,
            monthstamp = monthstamp,
            yearstamp = yearstamp,
            time_cost = entry.time_cost,
            request_length = entry.request_length,
            connection = entry.connection,
            connection_requests = entry.connection_requests,
            uri = entry.uri,
            ori_request = entry.ori_request,
            query_string = entry.query_string,
            status = entry.status,
            bytes_sent = entry.bytes_sent,
            referer = entry.referer,
            user_agent = entry.user_agent,
            forwarded_for = entry.forwarded_for,
            host = entry.host,
            node = entry.hostname,
            upstream = entry.upstream,
        }

        local keys = {}
        local values = {}
        for k, v in pairs(data) do
            table.insert(keys, k)
            table.insert(values, ngx.quote_sql_str(v)) -- Quote the values to avoid SQL injection
        end

        local sql = [[
            INSERT INTO access_log (
                ]] .. table.concat(keys, ', ') .. [[
            ) VALUES (
                ]] .. table.concat(values, ', ') .. [[
            )
        ]]

        local res, err = pg:query(sql)
        -- core.log.error(sql)
        if err ~= 1 then
            res = flase
            err_msg = "insert table error"
            return res, err_msg
        end
    end

    pg:disconnect()
    return res, err_msg
end

function _M.body_filter(conf, ctx)
    log_util.collect_body(conf, ctx)
end

--生成日志格式，metadata是插件元数据配置
local function gen_log_format(metadata)
    local log_format = {}
    --如果我们没有设置格式，，apisix也没有默认则为空则
    if metadata == nil then
        return log_format
    end

    for k, var_name in pairs(metadata.properties.log_format) do
        if var_name:byte(1, 1) == str_byte("$") then
            -- $开头则获取环境变量
            log_format[k] = { true, var_name:sub(2) }
        else
            log_format[k] = { false, var_name }
        end
    end
    --向apisix报告日志格式更新的行为
    -- core.log.error("log_format: ", core.json.delay_encode(log_format))
    return log_format
end

--apisix最终去执行的是这个方法去记录日志
function _M.log(conf, ctx)
    local log_format = gen_log_format(metadata_schema)
    local entry = core.table.new(0, core.table.nkeys(log_format))
    for k, var_attr in pairs(log_format) do
        if var_attr[1] then
            entry[k] = ctx.var[var_attr[2]]
        else
            entry[k] = var_attr[2]
        end
    end
    -- core.log.error(core.json.delay_encode(entry))

    -- local entry = log_util.get_log_entry(plugin_name, conf, ctx)
    -- local entry = log_util.get_full_log(ngx, conf)

    if batch_processor_manager:add_entry(conf, entry) then
        return
    end

    -- Generate a function to be executed by the batch processor
    local func = function(entries, batch_max_size)
        local data, err

        if batch_max_size == 1 then
            data = entries[1]
        else
            data = {}
            for i = 1, #entries do
                core.table.insert(data, entries[i])
            end
        end

        if not data then
            return false, 'error occurred while encoding the data: ' .. err
        end

        return send_postgresql_data(conf, data)
    end

    batch_processor_manager:add_entry_to_new_processor(conf, entry, ctx, func)
end

return _M
