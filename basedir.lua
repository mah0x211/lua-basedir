--
-- Copyright (C) 2022 Masatoshi Fukunaga
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
-- modules
local concat = table.concat
local error = error
local format = string.format
local sub = string.sub
local open = io.open
local isa = require('isa')
local is_boolean = isa.boolean
local is_string = isa.string
local is_table = isa.table
local getcwd = require('getcwd')
local mediatypes = require('mediatypes')
local path = require('path')
local normalize = path.normalize
local exists = path.exists
local readdir = path.readdir
local stat = path.stat
local extname = path.extname
local new_regex = require('regex').new
-- constants
-- init for libmagic
local Magic
do
    local libmagic = require('libmagic')
    Magic = libmagic.open(libmagic.MIME_ENCODING, libmagic.NO_CHECK_COMPRESS,
                          libmagic.SYMLINK)
    Magic:load()
end

--- get_charset
---@param pathname string
---@return string charset
local function get_charset(pathname)
    return Magic:file(pathname)
end

--- @class mediatypes
--- @field getmime function

--- @class regexp
--- @field match function

--- @class BaseDir
--- @field basedir string
--- @field follow_symlinks boolean
--- @field mime mediatypes
--- @field re_ignore regexp
local BaseDir = {}
BaseDir.__index = BaseDir

--- stat
--- @param rpath string
--- @return table<string, any> stat
--- @return string err
function BaseDir:stat(rpath)
    -- convert relative-path to absolute-path
    local pathname, apath = self:realpath(rpath)
    local info, err = stat(pathname, self.follow_symlinks)

    if not info then
        if err then
            return nil, format('failed to stat: %s - %s', apath, err)
        end
        return nil
    end

    -- regular file
    if info.type == 'reg' then
        local ext = extname(apath)

        return {
            ['type'] = info.type,
            pathname = pathname,
            rpath = apath,
            size = info.size,
            ctime = info.ctime,
            mtime = info.mtime,
            ext = ext,
            charset = get_charset(pathname),
            mime = ext and self.mime:getmime(ext:gsub('^.', '')),
        }
    end

    -- other
    return {
        ['type'] = info.type,
        pathname = pathname,
        rpath = apath,
        ctime = info.ctime,
        mtime = info.mtime,
    }
end

--- realpath
--- @param rpath string
--- @return string apath
--- @return string rpath
function BaseDir:realpath(rpath)
    rpath = normalize(rpath)
    return self.basedir .. rpath, rpath
end

--- open
--- @param rpath string
--- @return file* f
--- @return string err
function BaseDir:open(rpath)
    local apath = self:realpath(rpath)
    return open(apath)
end

--- read
--- @param rpath string
--- @return string content
--- @return string err
function BaseDir:read(rpath)
    local f, ferr = self:open(rpath)
    if ferr then
        return nil, ferr
    end

    local src, err = f:read('*a')
    f:close()
    if err then
        return nil, err
    end

    return src
end

--- readdir
--- @param rpath string
--- @return table<string, table[]> entries
--- @return string err
function BaseDir:readdir(rpath)
    local pathname, dirpath = self:realpath(rpath)
    local entries, derr = readdir(pathname)

    -- failed to readdir
    if not entries then
        if derr then
            return nil, format('failed to readdir %s - %s', rpath, derr)
        end
        return nil
    end

    local list = {}
    for i = 1, #entries do
        -- not ignoring files
        if not self.re_ignore:match(entries[i]) then
            local entry = entries[i]
            local info, err = self:stat(normalize(dirpath, entry))

            -- failed to get stat
            if err then
                return nil, err
            end

            local stats = list[info.type]
            if not stats then
                stats = {}
                list[info.type] = stats
            end
            stats[#stats + 1] = info

            -- remove type field
            info.type = nil
            -- add entry field
            info.entry = entry
        end
    end

    return list
end

--- new
--- @param pathname string
--- @param opts table
--- @return BaseDir
local function new(pathname, opts)
    if not is_string(pathname) then
        error('pathname must be string')
    elseif sub(pathname, 1, 1) ~= '/' then
        -- change relative-path to absolute-path
        pathname = normalize(getcwd(), pathname)
    end

    -- check basedir existing
    local basedir, err = exists(pathname)
    if err then
        error(format('failed to access the pathname %q: %s', pathname, err))
    elseif not basedir then
        error(format('failed to access the pathname %q not found', pathname))
    end

    -- check type of entry
    local info, serr = stat(basedir)
    if serr then
        error(format('failed to get info %q: %s', pathname, serr))
    elseif info.type ~= 'dir' then
        error(format('pathname %q is not directory', pathname))
    end

    -- check opts
    opts = opts or {}
    if not is_table(opts) then
        error('opts must be table')
    end

    -- mediatypes
    if opts.mimetypes ~= nil and not is_string(opts.mimetypes) then
        error('opts.mimetypes must be string')
    end
    local mime = mediatypes.new(opts.mimetypes)

    -- follow symlinks option
    if opts.follow_symlinks ~= nil and not is_boolean(opts.follow_symlinks) then
        error('opts.follow_symlinks must be boolean')
    end
    local follow_symlinks = opts.follow_symlinks == true

    -- set ignoreRegex list
    local ignore = {
        -- default ignore pattern
        '^[.].*$',
    }
    if opts.ignore ~= nil then
        if not is_table(opts.ignore) then
            error('opts.ignore must be table')
        end

        for i, pattern in ipairs(opts.ignore) do
            if not is_string(pattern) then
                error(format('opts.ignore#%d pattern must be string', i))
            end

            -- evalulate
            local _, perr = new_regex(pattern, 'i')
            if perr then
                error(format('opts.ignore#%d pattern cannot be compiled: %s', i,
                             perr))
            end

            ignore[#ignore + 1] = pattern
        end
    end
    -- compile patterns
    local pattern = '(?:' .. concat(ignore, '|') .. ')'
    local re_ignore, perr = new_regex(pattern, 'i')
    if perr then
        error(format('opts.ignore: %q - %s', pattern, perr))
    end

    return setmetatable({
        basedir = basedir,
        follow_symlinks = follow_symlinks,
        mime = mime,
        ignore = ignore,
        re_pattern = pattern,
        re_ignore = re_ignore,
    }, BaseDir)
end

return {
    new = new,
}
