require('luacov')
local unpack = unpack or table.unpack
local testcase = require('testcase')
local basedir = require('basedir')
local mkdir = require('mkdir')

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
    assert.equal(content, 'world')
    f:close()

    -- test that cannot open a file if it does not exist
    f, err = r:open('foo/bar/unknown/file')
    assert.is_nil(f)
    assert.is_nil(err)
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

function testcase.opendir()
    local r = basedir.new(TESTDIR)

    -- test that read entries
    local dir, err = r:opendir('/')
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
