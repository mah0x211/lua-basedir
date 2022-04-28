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
local find = string.find
local format = string.format
local open = io.open
local remove = os.remove
local sub = string.sub
local type = type
local replace = require('string.replace')
local error = require('error')
local errno = error.errno
local getcwd = require('getcwd')
local fstat = require('fstat')
local mkdir = require('mkdir')
local opendir = require('opendir')
local realpath = require('realpath')
local rmdir = require('rmdir')
local basename = require('basename')
-- constants
local ENOENT = errno.ENOENT

--- @class BaseDir
--- @field basedir string
--- @field follow_symlink boolean
local BaseDir = {}
BaseDir.__index = BaseDir

--- normalize
--- @param pathname string
--- @return string rpath
function BaseDir:normalize(pathname)
    return assert(realpath('/' .. pathname, nil, false))
end

--- dirname
--- @param pathname string
--- @return string dirname
--- @return string filename
function BaseDir:dirname(pathname)
    local rpath = self:normalize(pathname)
    local filename = basename(rpath)

    -- filename does not exists
    if filename == '/' then
        return rpath, ''
    end

    -- extract dirname
    local dlen = #rpath - #filename
    -- remove trailing-slash from dirname
    if dlen > 1 then
        dlen = dlen - 1
    end

    return sub(rpath, 1, dlen), filename
end

--- realpath
--- @param pathname string
--- @return string apath
--- @return string err
--- @return string rpath
function BaseDir:realpath(pathname)
    local base = self.basedir
    local blen = #base
    local rpath = self:normalize(pathname)
    local apath, err, eno = realpath(base .. rpath)

    if err then
        if errno[eno] == ENOENT then
            return nil
        end
        return nil, err
    elseif not self.follow_symlink and
        (sub(apath, 1, blen) ~= base or #apath > blen and
            sub(apath, blen + 1, blen + 1) ~= '/') then
        -- absolute path is not placed at the base directory
        return nil
    end

    return apath, nil, rpath
end

--- stat
--- @param pathname string
--- @return table<string, any> stat
--- @return string err
function BaseDir:stat(pathname)
    -- convert relative-path to absolute-path
    local apath, err, rpath = self:realpath(pathname)
    if not apath then
        return nil, err
    end

    local stat, eno
    stat, err, eno = fstat(apath, false)
    if err then
        if errno[eno] == ENOENT then
            return nil
        end
        return nil, format('failed to stat: %s - %s', rpath, err)
    end

    -- append absolute paths
    stat.pathname = apath
    stat.rpath = rpath
    return stat
end

--- remove
--- @param pathanme string
--- @return boolean ok
--- @return string err
function BaseDir:remove(pathanme)
    local rpath = self.basedir .. self:normalize(pathanme)
    local ok, err = remove(rpath)

    if not ok then
        return false, replace(err, self.basedir)
    end

    return true
end

--- open
--- @param pathname string
--- @param mode? string
--- @return file* f
--- @return string err
function BaseDir:open(pathname, mode)
    if mode == nil then
        mode = 'r'
    elseif type(mode) ~= 'string' then
        error('mode must be string', 2)
    end

    local apath, err = self:realpath(pathname)
    if not apath then
        -- got error or mode is not creation mode
        if err or not find(mode, '^[wa]') then
            return nil, err
        end

        local dirpath, filename = self:dirname(pathname)
        apath, err = self:realpath(dirpath)
        if not apath then
            return nil, err
        end
        apath = apath .. '/' .. filename
    end
    return open(apath, mode)
end

--- read
--- @param pathname string
--- @return string content
--- @return string err
function BaseDir:read(pathname)
    local f, ferr = self:open(pathname)
    if not f then
        return nil, ferr
    end

    local src, err = f:read('*a')
    f:close()
    if err then
        return nil, err
    end

    return src
end

--- rmdir
--- @param pathname string
--- @param recursive? boolean
--- @return boolean ok
--- @return string err
function BaseDir:rmdir(pathname, recursive)
    local apath = self.basedir .. self:normalize(pathname)
    return rmdir(apath, recursive)
end

--- mkdir
--- @param pathname string
--- @param mode string|integer
--- @return boolean ok
--- @return string err
--- @return integer errno
function BaseDir:mkdir(pathname, mode)
    local apath = self.basedir .. self:normalize(pathname)
    return mkdir(apath, mode, true, self.follow_symlink)
end

--- opendir
--- @param pathname string
--- @return userdata dir
--- @return string err
function BaseDir:opendir(pathname)
    local apath = self.basedir .. self:normalize(pathname)
    local dir, derr, eno = opendir(apath, self.follow_symlink)

    if dir then
        return dir
    elseif errno[eno] ~= ENOENT then
        return nil, format('failed to opendir %s: %s', pathname, derr)
    end
end

--- readdir
--- @param pathname string
--- @return string[] entries
--- @return string err
function BaseDir:readdir(pathname)
    local dir, err = self:opendir(pathname)
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
        return nil, format('failed to readdir %s: %s', pathname, err)
    end

    return list
end

--- new
--- @param pathname string
--- @param follow_symlink? boolean
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
