fs = require "fs"

module.exports = (grunt) ->
	grunt.initConfig
		pkg: grunt.file.readJSON "package.json"
		coffee:
			compile:
				files:
						"bin/mahgister": [ "main.coffee" ]

	grunt.loadNpmTasks "grunt-contrib-coffee"

	grunt.registerTask "head", ->
		grunt.file.write "bin/mahgister", "#!/usr/bin/env node\n" + grunt.file.read "bin/mahgister"
		fs.chmodSync "bin/mahgister", "777"

	grunt.registerTask "default", [ "coffee", "head" ]
