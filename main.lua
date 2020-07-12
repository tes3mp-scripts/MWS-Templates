local lustache = require("lustache")
local CHUNKS = {
    heads = {},
    bodies = {}
}

local function trimFloat(value)
    return string.format("%.6f", value)
end

local function chunk(name, head, body, chunks)
    chunks = chunks or CHUNKS
    if head then
        chunks.heads[name] = head
    end
    if body then
        chunks.bodies[name] = body
    end
end

local function defaultChunks()
    return tableHelper.shallowCopy(CHUNKS)
end

local function render(text, env)
    return lustache:render(text, env)
end

local function process(text, env, chunks, included)
    env = env or {}
    chunks = chunks or CHUNKS
    included = included or {}
    local text = string.gsub(text, "``.-``", function(name)
        name = string.sub(name, 3, -3)
        if not chunks.heads[name] then
            error("[MWS-Template] Unknown chunk head " .. name)
        end
        if not included[name] then
            included[name] = true
            return process(chunks.heads[name], env, chunks, included)
        else
            return ""
        end
    end)
    return render((string.gsub(text,  "`.-`", function(name)
        name = string.sub(name, 2, -2)
        if not chunks.bodies[name] then
            error("[MWS-Template] Unknown chunk body " .. name)
        end
        if chunks.heads[name] ~= nil and not included[name] then
            error("[MWS-Template] Missing chunk head for " .. name)
        end
        return process(chunks.bodies[name], env, chunks, included)
    end)), env)
end

-- included chunks

chunk('PI', nil, [[3.1415926]])

-- Bhaskara sine approximation
chunk('SINE',
[[
float SINE_in
float SINE_out
float SINE_xTx
]],
[[
set SINE_out to 1.0
if ( SINE_in < 0 )
    set SINE_out to -1.0
    set SINE_in to -SINE_in
endif
set SINE_xTx to ((180 - SINE_in) * SINE_in)
set SINE_out to ( SINE_out * 4 * SINE_xTx / (40500 - SINE_xTx) )
]])

chunk('COSINE',
[[
``SINE``
float COSINE_in
float COSINE_out
]],
[[
set SINE_in to 90 - COSINE_in
`SINE`
set COSINE_out to SINE_out
]])

local LN_body = { "LN_out = 0" }
local steps = 5
table.insert(LN_body, "set LN_t to (" .. 2 / (2 * steps + 1) .. ")")
for k = steps - 1, 0, -1 do
    table.insert(LN_body, "set LN_t to ( LN_t * (LN_in - 1) / (LN_in + 1) )")
    table.insert(LN_body, "set LN_t to ( LN_t * (LN_in - 1) / (LN_in + 1) )")
    table.insert(LN_body, "set LN_t to ( LN_t + " .. 2 / (2 * k + 1) .. ")")
end
table.insert(LN_body, "set LN_t to ( LN_t * (LN_in - 1) / (LN_in + 1) )")
table.insert(LN_body, "set LN_out to ( LN_t )")
chunk('LN',
[[
float LN_in
float LN_out
float LN_t
]],
table.concat(LN_body, "\n")
)

chunk('MODULO',
[[
float MODULO_a
float MODULO_n
short MODULO_d
float MODULO_out
]],
[[
set MODULO_d to ( MODULO_a / MODULO_n )
set MODULO_out to ( MODULO_a - MODULO_n * MODULO_d )
]])


chunk('noPickUp',
nil,
[[
if ( OnActivate == 1 )
    return
endif
]])

chunk('noEquip',
nil,
[[
if ( OnPCEquip == 1 )
    return
endif
]])

-- functions to mimic included chunk behaviour on the server

local function sine(x)
    x = x * 180 / math.pi
    local coeff = 1
    if x < 0 then
        coeff = -1
        x = -x
    end
    local xTx = x * (180 - x)
    return coeff * 4 * xTx / (40500 - xTx)
end

local function cosine(x)
    return sine(math.pi * 0.5 - x)
end


return {
    process = process,
    chunk = chunk,
    defaultChunks = defaultChunks,
    render = render,
    trimFloat = trimFloat,
    mimics = {
        sine = sine,
        cosine = cosine
    }
}