# lua-basedir

[![test](https://github.com/mah0x211/lua-basedir/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-basedir/actions/workflows/test.yml)
[![Coverage Status](https://coveralls.io/repos/github/mah0x211/lua-basedir/badge.svg?branch=master)](https://coveralls.io/github/mah0x211/lua-basedir?branch=master)

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


## apath, rpath = basedir:realpath( pathname )

converts the pathname to an absolute path after normalizing it based on the base directory.

**Parameters**

- `pathname:string`: pathname string.

**Returns**

- `apath:string`: absolute pathname on filesystem.
- `rpath:string`: normalized pathname.

**Example**

```lua
local basedir = require('basedir')
local bd = basedir.new('test_dir')
print( bd:realpath('empty.txt') );
```


## apath, err = basedir:exists( pathname )

converts the pathname to an absolute path after normalizing it based on the base directory.

**Parameters**

- `pathname:string`: pathname string.

**Returns**

- `apath:string`: absolute filepath on filesystem, or `nil` if it does not exist.
- `err:string`: error message.

**Example**

```lua
local basedir = require('basedir')
local bd = basedir.new('test_dir')
print( bd:exists('./foo/../bar/../baz/../empty.txt') );
```


## apath, err = basedir:tofile( pathname )

converts the pathname to an absolute filepath after normalizing it based on the base directory.

**Parameters**

- `pathname:string`: pathname string.

**Returns**

- `apath:string`: absolute filepath on filesystem, or `nil` if it does not exist.
- `err:string`: error message.

**Example**

```lua
local basedir = require('basedir')
local bd = basedir.new('test_dir')
print( bd:tofile('./foo/../bar/../baz/../empty.txt') );
```


## apath, err = basedir:todir( pathname )

converts the pathname to an absolute dirpath after normalizing it based on the base directory.

**Parameters**

- `pathname:string`: pathname string.

**Returns**

- `apath:string`: absolute dirpath on filesystem, or `nil` if it does not exist.
- `err:string`: error message.

**Example**

```lua
local basedir = require('basedir')
local bd = basedir.new('test_dir')
print( bd:todir('./foo/../bar/../baz/../subdir') );
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


## entries, err = basedir:readdir( pathname )

returns a directory contents of pathname.

**Parameters**

- `pathname:string`: pathname string.

**Returns**

- `entries:string[]`: `nil` on failure or not found.
- `err:string`: error message.


## info, err = basedir:stat( pathname )

obtains information about the file pointed to the specified pathname.

**Parameters**

- `pathname:string`: pathname string.

**Returns**

- `entries:table`: `nil` on failure or not found.
- `err:string`: error message.

