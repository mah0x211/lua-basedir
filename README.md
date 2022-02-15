# lua-basedir

[![test](https://github.com/mah0x211/lua-basedir/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-basedir/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/mah0x211/lua-basedir/branch/master/graph/badge.svg)](https://codecov.io/gh/mah0x211/lua-basedir)

lua-basedir is a module that limits file and directory operations to be performed under a specified directory.


## Installation

```
luarocks install basedir
```


## bd = basedir.new( pathname [, follow_symlink] )

create a basedir object.

**Parameters**

- `pathname:string`: pathname of the base directory
- `follow_symlink:boolean`: follow symbolic links. (default: `false`)


**Returns**

- `bd:basedir`: basedir object

**Example**

```lua
local basedir = require('basedir')
local bd = basedir.new('test_dir')
```


## rpath = basedir:normalize( pathname )

converts a pathname to an absolute path in the base directory.

**Parameters**

- `pathname:string`: pathname string.

**Returns**

- `rpath:string`: an absolute path in the base directory.

**Example**

```lua
local basedir = require('basedir')
local bd = basedir.new('test_dir')
print(bd:normalize('/foo/../bar/../empty.txt'))
```


## apath, err, rpath = basedir:realpath( pathname )

converts a pathname to an absolute path in the filesystem and in the base directory.


**Parameters**

- `pathname:string`: pathname string.

**Returns**

- `apath:string`: an absolute path in the filesystem.
- `err:string`: error message.
- `rpath:string`: an absolute path in the base directory.

**Example**

```lua
local basedir = require('basedir')
local bd = basedir.new('test_dir')
print(bd:realpath('empty.txt'))
```


## stat, err = basedir:stat( pathname )

obtains information about the file pointed to the specified pathname.

**Parameters**

- `pathname:string`: pathname string.

**Returns**

- `stat:table`: `nil` on failure or not found.
- `err:string`: error message.

```lua
local dump = require('dump')
local basedir = require('basedir')
local bd = basedir.new('test_dir')
local stat = assert(bd:stat('empty.txt'))
-- above code will be output as follows
-- {
--     atime = 1644544401,
--     blksize = 4096,
--     blocks = 0,
--     ctime = 1644544401,
--     dev = 16777220,
--     gid = 20,
--     ino = 12945838645,
--     mode = 33188,
--     mtime = 1644544401,
--     nlink = 1,
--     pathname = "/***/lua-basedir/test/test_dir/empty.txt",
--     rdev = 0,
--     rpath = "/empty.txt",
--     size = 0,
--     type = "file",
--     uid = 504
-- }
```


## f, err = basedir:open( pathname )

open the specified file.

**Parameters**

- `pathname:string`: pathname string.

**Returns**

- `f:file`: file on success
- `err:string`: error message on failure.

**Example**

```lua
local basedir = require('basedir')
local bd = basedir.new('test_dir')
local f = assert(bd:open('subdir/world.txt'))
print(f:read('*a'))
f:close()
```


## str, err = basedir:read( pathname )

reads the contents of the specified file.

**Parameters**

- `pathname:string`: pathname string.

**Returns**

- `str:string`: string on success.
- `err:string`: error message on failure.

**Example**

```lua
local basedir = require('basedir')
local bd = basedir.new('test_dir')
local str = assert(bd:read('subdir/world.txt'))
print(str)
```


## ok, err = basedir:rmdir( pathname [, recursive] )

remove a directory file.

**Parameters**

- `pathname:string`: path of the directory.
- `recursive:boolean`: remove directories and their contents recursively. (default `false`)

**Returns**

- `ok:boolean`: `true` on success.
- `err:string`: error message.


## ok, err = basedir:mkdir( pathname [, mode] )

make directories.

**Parameters**

- `pathname:string`: pathname string.
- `mode:string|integer`: file permissions in octal notation as a string, or integer. (default: `'0777'`)

**Returns**

- `ok:boolean`: `true` on success.
- `err:string`: error message.


## dir, err = basedir:opendir( pathname )

open a [directory stream](https://github.com/mah0x211/lua-opendir).

**Parameters**

- `pathname:string`: pathname string.

**Returns**

- `dir:dir*`: a directory stream.
- `err:string`: error message.


## entries, err = basedir:readdir( pathname )

returns a directory contents of pathname.

**Parameters**

- `pathname:string`: pathname string.

**Returns**

- `entries:string[]`: `nil` on failure or not found.
- `err:string`: error message.


