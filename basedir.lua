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
local remove = os.remove
local rename = os.rename
local sub = string.sub
local type = type
local replace = require('string.replace')
local errorf = require('error').format
local getcwd = require('getcwd')
local fopen = require('io.fopen')
local fstat = require('fstat')
local mkdir = require('mkdir')
local opendir = require('opendir')
local realpath = require('realpath')
local rmdir = require('rmdir')
local basename = require('basename')
local ENOENT = require('errno').ENOENT

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

--- realpath resolve the pathname to the absolute path in the base directory.
--- if the pathname is not placed at the base directory, then return nil without error.
--- @param pathname string
--- @return string? apath
--- @return any err
--- @return string? rpath
function BaseDir:realpath(pathname)
    local base = self.basedir
    local blen = #base
    local rpath = self:normalize(pathname)
    local apath, err = realpath(base .. rpath)

    if err then
        if err.type == ENOENT then
            -- ignore ENOENT error
            return nil
        end
        return nil, errorf('failed to realpath()', err)
    elseif not self.follow_symlink and
        (sub(apath, 1, blen) ~= base or #apath > blen and
            sub(apath, blen + 1, blen + 1) ~= '/') then
        -- absolute path is not placed at the base directory
        return nil
    end

    return apath, nil, rpath
end

--- stat returns a table containing information about a file.
--- if the pathname is not placed at the base directory, then return nil without error.
--- @param pathname string
--- @return table<string, any> stat
--- @return any err
function BaseDir:stat(pathname)
    -- convert relative-path to absolute-path
    local apath, err, rpath = self:realpath(pathname)
    if not apath then
        return nil, err
    end

    local stat
    stat, err = fstat(apath, false)
    if err then
        if err.type == ENOENT then
            -- ignore ENOENT error
            return nil
        end
        return nil, errorf('failed to fstat()', err)
    end

    -- append absolute paths
    stat.pathname = apath
    stat.rpath = rpath
    return stat
end

--- remove
--- @param pathanme string
--- @return boolean ok
--- @return any err
function BaseDir:remove(pathanme)
    local rpath = self.basedir .. self:normalize(pathanme)
    local ok, err = remove(rpath)
    if not ok then
        return false,
               errorf('failed to remove(): %q', replace(err, self.basedir))
    end

    return true
end

--- rename
--- @param oldpath string
--- @param newpath string
--- @return boolean ok
--- @return any err
function BaseDir:rename(oldpath, newpath)
    local base = self.basedir
    oldpath = base .. self:normalize(oldpath)
    newpath = base .. self:normalize(newpath)

    local ok, err = rename(oldpath, newpath)
    if not ok then
        return false, errorf('failed to rename()', err)
    end

    return true
end

--- put
--- @param extpath string
--- @param newpath string
--- @return boolean ok
--- @return any err
function BaseDir:put(extpath, newpath)
    newpath = self.basedir .. self:normalize(newpath)

    local ok, err = rename(extpath, newpath)
    if not ok then
        return false, errorf('failed to rename()', err)
    end

    return true
end

--- open returns a file object.
--- if the pathname is not placed at the base directory, then return nil without error.
--- @param pathname string
--- @param mode? string
---| '"r"' # read-only (default)
---| '"w"' # write-only
---| '"a"' # append-only
---| '"r+"' # read-write
---| '"w+"' # read-write
---| '"a+"' # read-write
--- @return file* f
--- @return any err
function BaseDir:open(pathname, mode)
    if mode == nil then
        mode = 'r'
    elseif type(mode) ~= 'string' or not find(mode, '^[rwa]%+?') then
        error('mode must be string of "r", "w", "a", "r+", "w+", "a+"')
    end

    local apath, err = self:realpath(pathname)
    if err then
        return nil, errorf('failed to realpath()', pathname)
    elseif not apath then
        -- try to resolve the pathname as a directory pathname
        local dirpath, filename = self:dirname(pathname)
        apath, err = self:realpath(dirpath)
        if err then
            return nil, errorf('failed to realpath()', err)
        elseif not apath then
            return nil
        end
        apath = apath .. '/' .. filename
    end

    local f
    f, err = fopen(apath, mode)
    if not f then
        if err.type == ENOENT then
            -- ignore ENOENT error
            return nil
        end
        return nil, errorf('failed to fopen()', err)
    end
    return f
end

--- read returns the content of the file.
--- if the pathname is not placed at the base directory, then return nil with no error.
--- @param pathname string
--- @return string content
--- @return any err
function BaseDir:read(pathname)
    local f, err = self:open(pathname)
    if err then
        return nil, errorf('failed to open()', err)
    elseif not f then
        return nil
    end

    local src
    src, err = f:read('*a')
    f:close()
    if err then
        return nil, errorf('failed to read()', err)
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
--- @return any err
function BaseDir:mkdir(pathname, mode)
    local apath = self.basedir .. self:normalize(pathname)
    return mkdir(apath, mode, true, self.follow_symlink)
end

--- opendir returns a directory object.
--- if the pathname is not placed at the base directory, then return nil with no error.
--- @param pathname string
--- @return userdata dir
--- @return any err
function BaseDir:opendir(pathname)
    local apath = self.basedir .. self:normalize(pathname)
    local dir, err = opendir(apath, self.follow_symlink)
    if err then
        if err.type == ENOENT then
            -- ignore ENOENT error
            return nil
        end
        return nil, errorf('failed to opendir()', err)
    end

    return dir
end

--- readdir returns a list of directory entries.
--- if the pathname is not placed at the base directory, then return nil with no error.
--- @param pathname string
--- @return string[] entries
--- @return any err
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

    if err then
        return nil, errorf('failed to readdir()', err)
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
            error(format('failed to access the pathname %q: %s', pathname,
                         tostring(err)))
        end
    end

    -- check type of entry
    local stat, err = fstat(basedir, follow_symlink)
    if err then
        error(format('failed to get stat %q: %s', pathname, tostring(err)))
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
