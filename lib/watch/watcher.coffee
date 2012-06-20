watch =  require 'chokidar'
color =  require("ansi-color").set
path =   require 'path'
wrench = require 'wrench'
fs =     require 'fs'
logger = require '../util/logger'

class Watcher

  compilers:[]

  startWatch: (@origDir, @destDir, @ignored) ->
    files = wrench.readdirSyncRecursive(@origDir)
    files = files.filter (file) => fs.statSync(path.join(@origDir, file)).isFile()

    addTotal = 0
    watcher = watch.watch(@origDir, {persistent:true})
    watcher.on "change", (f) => @_findCompiler(f, @_updated)
    watcher.on "unlink", (f) => @_findCompiler(f, @_removed)
    watcher.on "add", (f) =>
      @_findCompiler(f, @_created)
      @_startupFinished() if ++addTotal is files.length

    logger.info "Watching #{@origDir}"

  _startupFinished: ->
    compiler.doneStartup() for ext, compiler of @compilers when compiler.doneStartup?

  registerCompilers: (compilers) ->
    @compilers.push(compiler) for compiler in compilers

  _findCompiler: (fileName, callback) ->
    return if @ignored.some((str) -> fileName.has(str))
    extension = path.extname(fileName).substring(1)
    return unless extension?.length > 0
    compiler = @compilers.find (comp) ->
      for ext in comp.getExtensions()
        return true if extension is ext
      return false
    if compiler?
      callback(fileName, compiler)
    else
      logger.warn "No compiler has been registered: #{extension}"

  _created: (f, compiler) => @_executeCompilerMethod(f, compiler.created, "created")
  _updated: (f, compiler) => @_executeCompilerMethod(f, compiler.updated, "updated")
  _removed: (f, compiler) => @_executeCompilerMethod(f, compiler.removed, "removed")

  _executeCompilerMethod: (fileName, compilerMethod, name) =>
    if compilerMethod?
      compilerMethod(fileName)
    else
      logger.error "Compiler method #{name} does not exist, doing nothing for #{fileName}"

module.exports = (config) ->

  originationDir = path.join(config.root, config.watch.originationDir)
  destinationDir = path.join(config.root, config.watch.destinationDir)

  watcher = new Watcher
  watcher.startWatch(originationDir, destinationDir, config.watch.ignored)
  watcher