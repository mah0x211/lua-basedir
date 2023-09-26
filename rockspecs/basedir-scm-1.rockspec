package = "basedir"
version = "scm-1"
source = {
    url = "git+https://github.com/mah0x211/lua-basedir.git",
}
description = {
    summary = "lua-basedir is a module that limits file and directory operations to be performed under a specified directory.",
    homepage = "https://github.com/mah0x211/lua-basedir",
    license = "MIT/X11",
    maintainer = "Masatoshi Fukunaga",
}
dependencies = {
    "lua >= 5.1",
    "basename >= 0.1.0",
    "error >= 0.9.0",
    "errno >= 0.3.0",
    "extname >= 0.1.0",
    "fstat >= 0.2.2",
    "getcwd >= 0.2.0",
    "mkdir >= 0.2.2",
    "opendir >= 0.2.1",
    "realpath >= 0.4.0",
    "rmdir >= 0.4.0",
    "string-replace >= 0.1.0",
}
build = {
    type = "builtin",
    modules = {
        basedir = "basedir.lua",
    },
}
