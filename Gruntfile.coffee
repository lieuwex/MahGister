fs = require "fs"

module.exports = (grunt) ->
	grunt.initConfig
		pkg: grunt.file.readJSON "package.json"
		coffee:
			compile:
				files:
						"bin/MahGister": [ "main.coffee" ]

	grunt.loadNpmTasks "grunt-contrib-coffee"

	grunt.registerTask "head", ->
		grunt.file.write "bin/MahGister", "#!/usr/bin/env node\n" + grunt.file.read "bin/MahGister"
		fs.chmodSync "bin/MahGister", "777"

	grunt.registerTask "default", [ "coffee", "head" ]