require('luacov')
local unpack = unpack or table.unpack
local testcase = require('testcase')
local basedir = require('basedir')

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
                TESTDIR,
                '',
            },
            match = 'opts must be table',
        },
        {
            arg = {
                TESTDIR,
                {
                    mimetypes = 1,
                },
            },
            match = 'opts.mimetypes must be string',
        },
        {
            arg = {
                TESTDIR,
                {
                    mimetypes = '',
                    follow_symlinks = 1,
                },
            },
            match = 'opts.follow_symlinks must be boolean',
        },
        {
            arg = {
                TESTDIR,
                {
                    mimetypes = '',
                    follow_symlinks = false,
                    ignore = true,
                },
            },
            match = 'opts.ignore must be table',
        },
        {
            arg = {
                TESTDIR,
                {
                    mimetypes = '',
                    follow_symlinks = false,
                    ignore = {
                        1,
                    },
                },
            },
            match = 'opts.ignore#1 pattern must be string',
        },
        {
            arg = {
                TESTDIR,
                {
                    mimetypes = '',
                    follow_symlinks = false,
                    ignore = {
                        '||[',
                    },
                },
            },
            match = 'opts.ignore#1 pattern cannot be compiled',
        },
    }) do
        local err = assert.throws(basedir.new, unpack(v.arg))
        assert.match(err, v.match, false)
    end
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
    assert.match(err, 'No .+ file or directory', false)
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
    assert.match(err, 'No .+ file or directory', false)
end

function testcase.readdir()
    local r = basedir.new(TESTDIR)

    -- test that read entries
    local entries, err = r:readdir('/')
    assert.is_nil(err)
    -- confirm that contains 'empty.txt' and 'hello.txt'
    local files = {
        ['empty.txt'] = true,
        ['hello.txt'] = true,
    }
    for _, stat in ipairs(entries.file) do
        assert(files[stat.entry], string.format('unknown entry: %s', stat.rpath))
        files[stat.entry] = nil
    end
    assert.empty(files)

    -- confirm that contains 'subdir'
    assert.equal(#entries.directory, 1)
    local dirs = {
        ['subdir'] = true,
    };
    for _, stat in ipairs(entries.directory) do
        assert(dirs[stat.entry], string.format('unknown entry: %s', stat.rpath))
        dirs[stat.entry] = nil;
    end
    assert.empty(dirs)

    -- test that returns nil if it does not exist
    entries, err = r:readdir('/noent')
    assert.is_nil(entries)
    assert.is_nil(err, 'foo')
end

function testcase.realpath()
    local r = basedir.new(TESTDIR)

    -- test that converts relative path to absolute path based on base directory
    local pathname, apath = r:realpath('./foo/../bar/../baz/qux/../empty.txt')
    assert.match(pathname, TESTDIR .. '/baz/empty.txt$', false)
    assert.equal(apath, '/baz/empty.txt')
end

function testcase.exists()
    local r = basedir.new(TESTDIR)

    -- test that returns the absolute path on filesystem if the pathname exists
    for rpath, pattern in pairs({
        ['./foo/../bar/../empty.txt'] = '/empty.txt$',
        ['./foo/../bar/../subdir'] = '/subdir$',
    }) do
        local pathname = assert(r:exists(rpath))
        assert.match(pathname, TESTDIR .. pattern, false)
    end
end

function testcase.tofile()
    local r = basedir.new(TESTDIR)

    -- test that returns the absolute pathname on filesystem if the file exists
    local pathname = assert(r:tofile('./foo/../bar/../empty.txt'))
    assert.match(pathname, TESTDIR .. '/empty.txt$', false)
end

function testcase.todir()
    local r = basedir.new(TESTDIR)

    -- test that returns the absolute pathname on filesystem if the directory exists
    local pathname = assert(r:todir('./foo/../bar/../subdir'))
    assert.match(pathname, TESTDIR .. '/subdir$', false)
end

function testcase.stat()
    local r = basedir.new(TESTDIR)

    -- test that get stat of file
    local info, err = r:stat('empty.txt')
    assert.is_nil(err)
    -- confirm field definitions
    for _, k in pairs({
        'charset',
        'ctime',
        'ext',
        'mime',
        'mtime',
        'pathname',
        'rpath',
        'type',
    }) do
        assert(info[k], string.format('field %q is not defined', k))
    end
    -- confirm field value
    assert.equal(info.type, 'file')
    assert.equal(info.ext, '.txt')
    assert.equal(info.mime, 'text/plain')
    assert.equal(info.rpath, '/empty.txt')
    assert.match(info.pathname, '/test_dir/empty.txt$', false)

    -- test that return nil if it does not exist
    info, err = r:stat('empty.txta')
    assert.is_nil(info)
    assert.is_nil(err)
end
