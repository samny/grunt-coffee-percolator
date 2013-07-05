###
grunt-percolator-task
https://github.com/samny/grunt-percolator-task

Original CakeFile by Justin Windle (Soulwire)
https://github.com/soulwire/Coffee-Percolator

Copyright (c) 2013 Samuel Nystedt
Licensed under the MIT license.
###

module.exports = (grunt)->

    ###
    --------------------------------------------------

      Dependancies

    --------------------------------------------------
    ###

    fs = require 'fs'
    {exec} = require 'child_process'

    ###
    --------------------------------------------------

      Constants

    --------------------------------------------------
    ###

    FILETYPE = 'coffee'
    REGEX_IS_FILETYPE = /\.coffee$/
    REGEX_IS_NOT_FILETYPE = /\.(?!coffee)/
    REGEX_FILENAME = /\.\w+$/i
    REGEX_IMPORT = /#\s?import\s+?([\w\.\-\/\*]+)/g

    ###
    --------------------------------------------------

      Node construct for building topological
      graphs.

    --------------------------------------------------
    ###

    class Node
        constructor: ( @name, @content, @edges =[] ) ->
        add: ( edges... ) -> @edges = @edges.concat edges

    ###
    --------------------------------------------------

      Recursively traverses a directory and
      returns a list of all .coffee files.

    --------------------------------------------------
    ###

    traverse = ( path, result = [] ) ->

        files = fs.readdirSync path
        map = {}

        for file in files

            file = "#{path}/#{file}"
            stat = fs.statSync file

            if stat.isFile() and REGEX_IS_FILETYPE.test file then result.push file
            else if stat.isDirectory() then traverse file, result

        result

    ###
    --------------------------------------------------

      Loads and indexes a list of files

    --------------------------------------------------
    ###

    catalog = ( list, done, result = [] ) ->

        process = (file, content)->
            if content then result.push new Node file, content else throw 'Error reading file'
            done result if result.length is list.length

        process(file, grunt.file.read(file, 'utf8')) for file in list

    ###
    --------------------------------------------------

      Recursively resolves dependancies

    --------------------------------------------------
    ###

    resolve = ( node, result = [] ) ->

        resolve edge, result for edge in node.edges when edge not in result
        result.push node
        result


    ###
    --------------------------------------------------

      Builds main source by resolving and
      concatenating depandancies before passing
      the output to the CoffeeScript compiler

    --------------------------------------------------
    ###
    helper = (command, callback) ->
        exec command, (err, stdout, stderr) ->
            if err or stderr
                callback err or stderr, stdout
                return
            callback null, stdout

    grunt.registerMultiTask 'percolator', 'Concatenate CoffeeScript ordered by imports', ->

        options = grunt.config(this.name) || {}

        source = this.data.source || '.'
        output = this.data.output || 'scripts.min.js'
        main = this.data.main || 'main.coffee'
        opts = this.data.opts || '--lint'
        doCompile = this.data.compile || true

        
        # Use JS mode if main script file is .js
        jsMode = /\.js$/.test main

        if jsMode 
            doCompile = false
            FILETYPE = 'js'
            REGEX_IS_FILETYPE = /\.js$/
            REGEX_IS_NOT_FILETYPE = /\.(?!js)/
            REGEX_IMPORT = /\/\/\s?import\s+?([\w\.\-\/\*]+)/g


        task = this;
        files = traverse source

        # Process them into Nodes

        catalog files, ( nodes ) ->

            # Map all source paths to Nodes
            map = {}
            add = ( node, name ) -> ( map[ name ] ?= [] ).push node

            for node in nodes

                path = node.name.replace( REGEX_FILENAME, '' ).split '/'
                last = path.pop()

                add node, path.slice( 0, index ).concat( '*' ).join '/' for index in [ 0..path.length ]
                add node, path.concat( last ).join '/'
                add node, node.name

            # Compute edges

            for node in nodes
                while match = REGEX_IMPORT.exec node.content

                    if target = match[1]

                        key = [ source, target ].join '/'
                        # Testing if file exists for each iteration to allow for '.' in filenames (ie. jquery.plugin.js) when using dot syntax in imports
                        while not map[ key ]
                            failedKey = key
                            target = target.replace REGEX_IS_NOT_FILETYPE, '/'
                            key = [ source, target ].join '/'
                            if key is failedKey then grunt.fail.warn("No file matching import: #{key}")

                        if map[ key ] then node.add link for link in map[ key ]

            # Build dependency graph

            path = [ source, main ].join '/'
            link = map[ path ]?[0]

            # Resolve dependancies

            if link then chain = resolve link
            else throw "Root node not found: #{path}"

            # Concatenate contents into one file
            content = ( node.content for node in chain ).join '\n\n'

            merged = output.replace( REGEX_FILENAME, '' ) + '.' + FILETYPE
            writtenContent = grunt.file.write merged, content

            throw 'Error: failed to write file' if not writtenContent

            if jsMode
                grunt.log.ok("Concatenated #{main} and it's dependency chain into: #{output}")

            if doCompile
                done = task.async();
                helper "coffee -c #{opts} #{merged}", (error, stdout)->
                    if error then throw error else
                        if fs.existsSync merged then fs.unlink merged, ( error ) -> throw error if error

                    grunt.log.ok("CoffeeScript compiled into: #{output}")
                    done()