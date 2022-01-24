# lua-basedir

[![test](https://github.com/mah0x211/lua-basedir/actions/workflows/test.yml/badge.svg)](https://github.com/mah0x211/lua-basedir/actions/workflows/test.yml)
[![Coverage Status](https://coveralls.io/repos/github/mah0x211/lua-basedir/badge.svg?branch=master)](https://coveralls.io/github/mah0x211/lua-basedir?branch=master)

lua-basedir is a module that limits file and directory operations to be performed under a specified directory.


## Installation

```
luarocks install basedir
```


## bd = basedir.new( pathname [, opts] )

create a basedir object.

**Parameters**

- `pathname:string`: pathname of the base directory
- `opts:table`
    - `follow_symlinks:boolean`: following symbolic link if true. (default: `false`)
    - `ignore:table`: regular expressions for ignore filename. (default: `{ '^[.].*$' }`)
    - `mimetypes:string`: mime types definition string. (default: `mediatype.default`)


**Returns**

- `bd:basedir`: basedir object

**Example**

```lua
local basedir = require('basedir')
local bd = basedir.new('test_dir')
```


## apath, rpath = bd:realpath( pathname )

converts the pathname to an absolute path after normalizing it based on the base directory.

**Parameters**

- `pathname:string`: pathname string.

**Returns**

- `apath:string`: absolute pathname on filesystem.
- `rpath:string`: normalized pathname.

**Example**

```lua
print( bd:realpath('empty.txt') );
```


## apath, err = bd:exists( pathname )

converts the pathname to an absolute path after normalizing it based on the base directory.

**Parameters**

- `pathname:string`: pathname string.

**Returns**

- `apath:string`: absolute filepath on filesystem, or `nil` if it does not exist.
- `err:string`: error message.

**Example**

```lua
print( bd:exists('./foo/../bar/../baz/../empty.txt') );
```


## f, err = bd:open( pathname )

open the specified file.

**Parameters**

- `pathname:string`: pathname string.

**Returns**

- `f:file`: file on success
- `err:string`: error message on failure.

**Example**

```lua
local f = assert(bd:open('subdir/world.txt'))
print(f:read('*a'))
f:close()
```


## str, err = bd:read( pathname )

reads the contents of the specified file.

**Parameters**

- `pathname:string`: pathname string.

**Returns**

- `str:string`: string on success.
- `err:string`: error message on failure.

**Example**

```lua
local str = assert(bd:read('subdir/world.txt'))
print(str)
```


## entries, err = bd:readdir( pathname )

returns a directory contents of pathname.

**Parameters**

- `pathname:string`: pathname string.

**Returns**

- `entries:table`: `nil` on failure or not found.
- `err:string`: error message.


## info, err = bd:stat( pathname )

obtains information about the file pointed to the specified pathname.

**Parameters**

- `pathname:string`: pathname string.

**Returns**

- `entries:table`: `nil` on failure or not found.
- `err:string`: error message.

