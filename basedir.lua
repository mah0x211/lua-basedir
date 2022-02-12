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
local assert = assert
local concat = table.concat
local format = string.format
local sub = string.sub
local open = io.open
local error = require('error')
local errno = error.errno
local extname = require('extname')
local getcwd = require('getcwd')
local fstat = require('fstat')
local opendir = require('opendir')
local realpath = require('realpath')
-- constants
local ENOENT = errno.ENOENT

--- @class BaseDir
--- @field basedir string
--- @field follow_symlinks boolean
local BaseDir = {}
BaseDir.__index = BaseDir

--- stat
--- @param rpath string
--- @return table<string, any> stat
--- @return string err
function BaseDir:stat(rpath)
    -- convert relative-path to absolute-path
    local pathname, apath = self:realpath(rpath)
    local info, err, eno = fstat(pathname, self.follow_symlinks)

    if err then
        if errno[eno] == ENOENT then
            return nil
        end
        return nil, format('failed to stat: %s - %s', apath, err)
    end

    -- regular file
    if info.type == 'file' then
        local ext = extname(apath)

        return {
            type = info.type,
            pathname = pathname,
            rpath = apath,
            size = info.size,
            ctime = info.ctime,
            mtime = info.mtime,
            ext = ext,
        }
    end

    -- other
    return {
        type = info.type,
        pathname = pathname,
        rpath = apath,
        ctime = info.ctime,
        mtime = info.mtime,
    }
end

--- normalize
--- @vararg string
--- @return string
local function normalize(...)
    return assert(realpath('/' .. concat({
        ...,
    }, '/'), nil, false))
end

--- realpath
--- @param rpath string
--- @return string apath
--- @return string rpath
function BaseDir:realpath(rpath)
    rpath = normalize(rpath)
    return self.basedir .. rpath, rpath
end

--- exists
--- @param rpath string
--- @return string|nil apath
--- @return string err
function BaseDir:exists(rpath)
    rpath = self:realpath(rpath)

    local apath, err, eno = realpath(rpath)
    if eno then
        if errno[eno] == ENOENT then
            return nil
        end
        return nil, err
    end

    return apath
end

--- tofile
--- @param rpath string
--- @return string|nil apath
--- @return string err
function BaseDir:tofile(rpath)
    local apath, err = self:exists(rpath)
    if err then
        return nil, err
    end

    local info
    info, err = fstat(apath)
    if err or info.type ~= 'file' then
        return nil, err
    end

    return apath
end

--- todir
--- @param rpath string
--- @return string|nil apath
--- @return string err
function BaseDir:todir(rpath)
    local apath, err = self:exists(rpath)
    if err then
        return nil, err
    end

    local info
    info, err = fstat(apath)
    if err or info.type ~= 'directory' then
        return nil, err
    end

    return apath
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

--- opendir
--- @param rpath string
--- @return userdata dir
--- @return string err
function BaseDir:opendir(rpath)
    local pathname = self:realpath(rpath)
    local dir, err, eno = opendir(pathname)

    -- failed to opendir
    if not dir then
        if errno[eno] == ENOENT then
            return nil
        end
        return nil, format('failed to opendir %s: %s', rpath, err)
    end

    return dir
end

--- readdir
--- @param rpath string
--- @return string[] entries
--- @return string err
function BaseDir:readdir(rpath)
    local dir, err = self:opendir(rpath)
    if not dir then
        return nil, err
    end

    local list = {}
    local entry
    entry, err = dir:readdir()
    while entry do
        -- ignore '.' and '..' entries
        if entry ~= '.' and entry ~= '..' then
            list[#list + 1] = entry
        end
        entry, err = dir:readdir()
    end
    dir:closedir()
    -- failed to readdir
    if err then
        return nil, format('failed to readdir %s - %s', rpath, err)
    end

    return list
end

--- new
--- @param pathname string
--- @param follow_symlink boolean
--- @return BaseDir
local function new(pathname, follow_symlink)
    if type(pathname) ~= 'string' then
        error('pathname must be string')
    elseif follow_symlink ~= nil and type(follow_symlink) ~= 'boolean' then
        error('follow_symlink must be boolean')
    end

    local basedir = pathname
    if sub(basedir, 1, 1) ~= '/' then
        -- prepend current working direcotry
        basedir = getcwd() .. '/' .. basedir
    end

    -- normalize
    basedir = assert(realpath(basedir, nil, false))
    -- resolve pathname
    follow_symlink = follow_symlink == true
    if follow_symlink then
        local err
        basedir, err = realpath(basedir)
        if err then
            error(format('failed to access the pathname %q: %s', pathname, err))
        end
    end

    -- check type of entry
    local stat, err = fstat(basedir, follow_symlink)
    if err then
        error(format('failed to get stat %q: %s', pathname, err))
    elseif stat.type ~= 'directory' then
        error(format('pathname %q is not directory', pathname))
    end

    return setmetatable({
        basedir = basedir,
        follow_symlink = follow_symlink,
    }, BaseDir)
end

return {
    new = new,
}
