-- Exercise the port's real Lua cleanup body against isolated filesystem cases.
-- Run with FreeBSD /usr/libexec/flua PORT_UCL_PATH EXISTING_TEMP_DIRECTORY.
local lfs = require("lfs")
local source_path, scratch = assert(arg[1]), assert(arg[2])
assert(scratch:match("^/tmp/c9%-desktop%-file%-utils%.[%w]+$"), "unexpected fixture root")
local file = assert(io.open(source_path, "r"))
local source = file:read("*a")
file:close()
local cleanup = assert(source:match("cleanup:%s*{.-script:%s*<<EOS\n(.-)\nEOS"), "cleanup body missing")
local cases = {
    { name = "both", files = { "mimeinfo.cache", "intent.cache" } },
    { name = "intent_only", files = { "intent.cache" } },
    { name = "mime_only", files = { "mimeinfo.cache" } },
    { name = "empty", files = {} },
    { name = "applications", files = { "mimeinfo.cache", "intent.cache", "keep.desktop" }, keep = true },
    { name = "uncached_application", files = { "keep.desktop" }, keep = true },
}
for _, case in ipairs(cases) do
    local prefix = scratch .. "/" .. case.name
    assert(lfs.mkdir(prefix))
    assert(lfs.mkdir(prefix .. "/share"))
    local directory = prefix .. "/share/applications"
    assert(lfs.mkdir(directory))
    for _, name in ipairs(case.files) do
        local output = assert(io.open(directory .. "/" .. name, "w"))
        output:write("fixture contents: " .. name .. "\n")
        output:close()
    end
    local pkg = {
        stat = function(path) return lfs.attributes(path) end,
        readdir = function(path)
            local entries = {}
            for entry in lfs.dir(path) do
                if entry ~= "." and entry ~= ".." then entries[#entries + 1] = entry end
            end
            return entries
        end,
    }
    local code = cleanup:gsub("%%%%PREFIX%%%%", function() return prefix end)
        :gsub("%%%%MIMEDIRS%%%%", "share/applications")
    local environment = {
        pkg = pkg,
        ipairs = ipairs,
        os = { remove = function(path)
            assert(path:sub(1, #prefix + 1) == prefix .. "/", "cleanup escaped fixture")
            return os.remove(path)
        end },
    }
    assert(load(code, "desktop-file-utils cleanup", "t", environment))()
    assert(not lfs.attributes(directory .. "/mimeinfo.cache"), case.name .. ": MIME cache remains")
    assert(not lfs.attributes(directory .. "/intent.cache"), case.name .. ": intent cache remains")
    if case.keep then
        local kept = assert(io.open(directory .. "/keep.desktop", "r"))
        assert(kept:read("*a") == "fixture contents: keep.desktop\n", "application contents changed")
        kept:close()
    else
        assert(not lfs.attributes(directory), case.name .. ": empty application directory remains")
    end
    print("PASS cleanup case: " .. case.name)
end
