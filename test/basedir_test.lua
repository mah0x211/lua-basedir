require('luacov')
local unpack = unpack or table.unpack
local testcase = require('testcase')
local basedir = require('basedir')
local mkdir = require('mkdir')
local rmdir = require('rmdir')

local TESTDIR = 'test_dir'

function testcase.new()
    -- test that create a basedir objrect
    assert(basedir.new(TESTDIR))

    -- test that throws an error
    for _, v in ipairs({
        {
            arg = {},
            match = 'pathname must be string',
        },
        {
            arg = {
                'unknown-dir',
            },
            match = 'No .+ directory',
        },
        {
            arg = {
                TESTDIR .. '/hello.txt',
            },
            match = 'is not directory',
        },
        {
            arg = {
                TESTDIR,
                '',
            },
            match = 'follow_symlink must be boolean',
        },
    }) do
        local err = assert.throws(basedir.new, unpack(v.arg))
        assert.match(err, v.match, false)
    end
end

function testcase.normalize()
    local r = basedir.new(TESTDIR)

    -- test that converts pathname to absolute path in the base directory
    local pathname = r:normalize('./foo/../bar/../baz/qux/../empty.txt')
    assert.equal(pathname, '/baz/empty.txt')
end

function testcase.dirname()
    local r = basedir.new(TESTDIR)

    -- test that split pathname into dirname and filename
    for _, v in ipairs({
        {
            pathname = './foo/../bar/../baz/qux/../empty.txt',
            dirname = '/baz',
            filename = 'empty.txt',
        },
        {
            pathname = './foo/../empty.txt',
            dirname = '/',
            filename = 'empty.txt',
        },
        {
            pathname = './empty.txt',
            dirname = '/',
            filename = 'empty.txt',
        },
        {
            pathname = 'empty.txt/..',
            dirname = '/',
            filename = '',
        },
    }) do
        local dirname, filename = r:dirname(v.pathname)
        assert.equal(dirname, v.dirname)
        assert.equal(filename, v.filename)
    end
end

function testcase.realpath()
    local r = basedir.new(TESTDIR)

    -- test that converts relative path to absolute path based on base directory
    for _, v in ipairs({
        {
            pathname = './foo/../bar/../baz/qux/../../empty.txt',
            match_apath = TESTDIR .. '/empty%.txt$',
            equal_rpath = '/empty.txt',
        },
        {
            pathname = '/',
            match_apath = TESTDIR,
            equal_rpath = '/',
        },
    }) do
        local apath, err, rpath = r:realpath(v.pathname)
        assert(apath, err)
        assert.match(apath, v.match_apath, false)
        assert.equal(rpath, v.equal_rpath)
    end

    -- test that return nil if pathname is links to the outside of base directory
    local apath, err, rpath = r:realpath('./subdir/example.lua')
    assert.is_nil(apath)
    assert.is_nil(err)
    assert.is_nil(rpath)

    -- test that resolved pathname if follow_symlink option is true
    r = basedir.new(TESTDIR, true)
    apath, err, rpath = r:realpath('./subdir/example.lua')
    assert(apath, err)
    assert.match(apath, 'test/example%.lua$', false)
    assert.equal(rpath, '/subdir/example.lua')
end

function testcase.stat()
    local r = basedir.new(TESTDIR)

    -- test that get stat of file
    local info, err = r:stat('empty.txt')
    assert.is_nil(err)
    -- confirm field definitions
    for _, k in pairs({
        'ctime',
        'mtime',
        'pathname',
        'rpath',
        'type',
    }) do
        assert(info[k], string.format('field %q is not defined', k))
    end
    -- confirm field value
    assert.equal(info.type, 'file')
    assert.equal(info.rpath, '/empty.txt')
    assert.match(info.pathname, '/test_dir/empty.txt$', false)

    -- test that return nil if it does not exist
    info, err = r:stat('empty.txta')
    assert.is_nil(info)
    assert.is_nil(err)
end

function testcase.open()
    local r = basedir.new(TESTDIR)

    -- test that can open file
    local f, err = r:open('subdir/world.txt')
    assert.is_nil(err)
    local content = assert(f:read('*a'))
    f:close()
    assert.equal(content, 'world')

    -- test that cannot open a file if it does not exist
    f, err = r:open('foo/bar/unknown/file')
    assert.is_nil(f)
    assert.is_nil(err)

    -- test that cannot create a file if parent directory is not exist
    f, err = r:open('unknown-dir/write.txt', 'a+')
    assert.is_nil(f)
    assert.is_nil(err)

    -- test that can open a file in write mode
    f = assert(r:open('write.txt', 'a+'))
    assert(f:write('hello new file'))
    f:close()
    f = assert(r:open('write.txt'))
    content = assert(f:read('*a'))
    f:close()
    assert.equal(content, 'hello new file')
    os.remove(TESTDIR .. '/write.txt')

    -- test that throws an error
    err = assert.throws(r.open, r, 'write.txt', {})
    assert.match(err, 'mode must be string')
end

function testcase.read()
    local r = basedir.new(TESTDIR)

    -- test that read file content
    local content, err = r:read('/hello.txt')
    assert.is_nil(err)
    assert.equal(content, 'hello')

    -- test that cannot read file content if it does not exist
    content, err = r:read('/unknown.txt')
    assert.is_nil(content)
    assert.is_nil(err)
end

function testcase.rmdir()
    local r = basedir.new(TESTDIR)
    assert(mkdir(TESTDIR .. '/foo/bar/baz', nil, true, false))

    -- test that remove a directory
    assert(r:rmdir('/foo/bar/baz'))
    local stat = r:stat('/foo/bar/baz')
    assert.is_nil(stat)

    -- test that cannot remove a non-empty directory
    local ok, err = r:rmdir('/foo')
    assert.is_false(ok)
    assert.match(err, 'not empty')
    assert(r:stat('/foo'))

    -- test that recursively remove directories
    assert(r:rmdir('/foo', true))
    stat = r:stat('/foo')
    assert.is_nil(stat)
end

function testcase.mkdir()
    local r = basedir.new(TESTDIR)

    -- test that make a directory
    assert(r:mkdir('/foo/bar', '0700'))
    local stat = assert(r:stat('/foo/bar'))
    assert.equal(stat.type, 'directory')
    assert.equal(stat.perm, '0700')

    assert(rmdir(TESTDIR .. '/foo', true))
end

function testcase.opendir()
    local r = basedir.new(TESTDIR)

    -- test that open diretory
    local dir, err = r:opendir('/')
    assert.is_nil(err)
    assert.match(tostring(dir), 'dir*:')
    dir:closedir()

    -- test that returns nil if it is not directory
    dir, err = r:opendir('/out_of_basedir')
    assert.is_nil(dir)
    assert.re_match(err, 'not a directory', 'i')

    -- test that open symlink directory
    r = basedir.new(TESTDIR, true)
    dir, err = r:opendir('/out_of_basedir')
    assert.is_nil(err)
    assert.match(tostring(dir), 'dir*:')
    dir:closedir()

    -- test that returns nil if it does not exist
    dir, err = r:opendir('/noent')
    assert.is_nil(dir)
    assert.is_nil(err)
end

function testcase.readdir()
    local r = basedir.new(TESTDIR)

    -- test that read entries
    local entries, err = r:readdir('/')
    assert.is_nil(err)
    -- confirm that contains 'empty.txt' and 'hello.txt'
    local files = {
        ['subdir'] = true,
        ['empty.txt'] = true,
        ['hello.txt'] = true,
        ['out_of_basedir'] = true,
    }
    for _, entry in ipairs(entries) do
        assert.not_empty(files)
        assert(files[entry], string.format('unknown entry: %s', entry))
        files[entry] = nil
    end
    assert.empty(files)

    -- test that returns nil if it does not exist
    entries, err = r:readdir('/noent')
    assert.is_nil(entries)
    assert.is_nil(err)
end

function testcase.remove()
    local r = basedir.new(TESTDIR)
    local f = assert(r:open('/foo.txt', 'a'))
    f:close()

    -- test that remove filepath
    assert(r:remove('/foo.txt'))

    -- test that return false if file not exists
    local ok, err = r:remove('/foo.txt')
    assert.is_false(ok)
    assert.match(err, '/foo%.txt.+ file or', false)
end

function testcase.rename()
    local r = basedir.new(TESTDIR)
    local f = assert(r:open('/foo.txt', 'a'))
    f:close()

    -- test that rename filepath to new name
    assert(r:rename('/foo.txt', '/bar.txt'))
    r:remove('/bar.txt')

    -- test that return error if cannot be renamed to newpath
    local ok, err = r:rename('/bar.txt', '/baa/qux/quux.txt')
    assert.is_false(ok)
    assert.match(string.lower(err), 'no such file or', false)
end
