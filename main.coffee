#!/usr/bin/env coffee

readline = require 'readline'
_ = require "lodash"
storage = require 'node-persist'
moment = require 'moment'
colors = require 'colors'
fs = require 'fs'
spawn = require("child_process").spawnSync

magisterJs = require "magister.js"
Magister = magisterJs.Magister
MagisterSchool = magisterJs.MagisterSchool

mahGisterDir = "#{process.env.HOME || process.env.HOMEPATH || process.env.USERPROFILE}/.MahGister"

days = [
	"sunday"
	"monday"
	"tuesday"
	"wednesday"
	"thursday"
	"friday"
	"saturday"
]

shortDays = [
	"zo"
	"ma"
	"di"
	"wo"
	"do"
	"vr"
	"za"
]

all = days.concat shortDays

clearConsole = -> `console.log('\033[2J\033[1;0H')`

showHelp = (exit = false) ->
	repeat = (org, length = process.stdout.columns) ->
		res = ""
		res += org for i in [0...length]
		return res

	cent = (s, xAxis = process.stdout.columns) -> repeat(" ", (xAxis / 2) - s.length / 2) + s + repeat(" ", (xAxis / 2) - s.length / 2)

	console.log repeat "-"
	console.log cent("MahGister").bold.red
	console.log cent "(c) 2015 Lieuwe Rooijakkers"
	console.log repeat "-"

	for key in _(commands).keys().sort().value()
		command = commands[key]
		console.log key.bold + ": #{command.description}"
		for param in (command.params ? [])
			console.log ""
			console.log "    " + param.name.underline + " [#{param.type}]: #{param.description}" +
				if not param.optional? or param.optional is no then ""
				else if param.optional is yes then " (optional)".red
				else " (default: #{param.optional})".red
			if param.example? then console.log "    Example".bold + ": #{param.example}"

		console.log repeat "-"

	if exit
		process.exit 0
	else
		rl.prompt()

commands =
	"help":
		description: "What do you expect?"
	"who":
		description: "Returns the name of the current logged in user."
	"clear":
		description: "Clears the screen."
	"appointments":
		description: "Shows a list of the appointments of the user."
		params: [
			{
				name: "days"
				type: "Number"
				description: "How many days to add to the current day."
				example: "appointments 2".cyan + " # Gets appointments of the day after tommorow."
				optional: 0
			}
			{
				name: "appointmentId"
				type: "Number"
				description: "The index of the appointment to show details about."
				example: "appointments 2 1".cyan + " # Shows the details of the second appointment of the appointments of the day after tommorow."
				optional: yes
			}
		]
	"homework":
		description: "Returns the homework of the current user."
	"tests":
		description: "Returns the tests of the current user."
	"messages":
		description: "Goes into messages mode and shows a list of messages."
		params: [
			{
				name: "inbox"
				type: "String"
				description: "The name of the inbox to open."
				optional: "Postvak In"
			}
		]
	"messages new":
		description: "Opens the dialog to create a new message."
	"list":
		description: "Requires you to be in messages mode. This will show the current fetched messages."
	"download":
		description: "Requires you to be in messages mode. This will download an attachment."
		params: [
			{
				name: "messageId"
				type: "Number"
				description: "The ID of the message to download the attachment from. Fallsback to the previous message if none is given."
				optional: yes
			}
			{
				name: "attachmentId"
				type: "Number"
				description: "The index of the attachment to download."
				optional: no
			}
		]
	"next":
		description: "Requires you to be in messages mode. Fetches the next x amount of messages. If no amount is given it will use 10."
	"delete":
		description: "Requires you to be in messages mode. Moves a message to the bin."
		params: [
			{
				name: "messageId"
				type: "Number"
				description: "The ID of the message to remove. Fallsback to the previous message if none is given."
				optional: yes
			}
		]
	"done":
		description: "Marks the given appointment as done."
		params: [
			{
				name: "days"
				type: "Number"
				description: "How many days to add to the current day."
				optional: no
			}
			{
				name: "appointmentId"
				type: "Number"
				description: "The index of the appointment to mark as done."
				optional: no
			}
		]
	"exit":
		description: "Exists MahGister."

rl = readline.createInterface
	input: process.stdin
	output: process.stdout
	completer: (s) ->
		filtered = _.keys(commands).filter((k) -> k.indexOf(s.toLowerCase().split(" ")[0]) is 0).map((c) -> c + " ")

		return [(if filtered.length isnt 0 then filtered else _.keys(commands)), s]

storage.initSync
	dir: mahGisterDir

fs.exists './attachments', (r) -> fs.mkdir("attachments") unless r

rl.on "close", -> process.exit 0

if _.contains ["--help", "-h"], _.last(process.argv).toLowerCase() then showHelp yes

main = (val, magister) ->
	clearConsole()
	magister ?= new Magister(val.school, val.userName, val.password)

	magister.ready (err) ->
		if err?
			console.err "Magister returned error while logging in."
			process.exit 32

		m = this
		homeworkResults = null
		lastMessage = null
		console.log "Welcome, #{m.profileInfo().firstName()}"

		rl.prompt()
		rl.on "line", (l) ->
			splitted = l.trim().split " "
			params = splitted[1..]
			switch splitted[0]
				when "who"
					if m.profileInfo().namePrefix()?
						console.log "#{m.profileInfo().firstName()} #{m.profileInfo().namePrefix()} #{m.profileInfo().lastName()}"
					else
						console.log "#{m.profileInfo().firstName()} #{m.profileInfo().lastName()}"
					rl.prompt()

				when "clear"
					clearConsole()
					rl.prompt()

				when "appointments"
					inf = params[0]
					inf ?= 0
					id = params[1]
					date = (
						if (val = /^-?\d+$/.exec(inf)?[0])?
							new moment().add +val, "days"

						else if _.contains all, inf.toLowerCase()
							x = moment()
							while days[x.weekday()] isnt inf.toLowerCase() and shortDays[x.weekday()] isnt inf.toLowerCase()
								x.add 1, "days"
							x

						else if inf[0] is "-" and _.contains all, inf[1..].toLowerCase()
							x = moment()
							while days[x.weekday()] isnt inf[1..].toLowerCase() and shortDays[x.weekday()] isnt inf[1..].toLowerCase()
								x.add -1, "days"
							x

						else
							moment inf
					).toDate()

					if _.isNaN date.getTime() # User entered invalid date.
						console.log "Invalid date or day delta entered.".red.bold
						rl.prompt()
						return

					m.appointments date, no, (e, r) ->
						if e? then console.log "Error: #{e.message}"
						else
							if id?
								appointment = r[+id]
								unless appointment
									console.log "Appointment ##{id} not found on #{days[moment(date).weekday()]}.".red.bold
									rl.prompt()
									return

								s = ""
								s += days[moment(appointment.begin()).weekday()] + "    "
								if (val = appointment.classes()[0])?
									s += val + " "
									if appointment.location()?
										s += "#{appointment.location()}    "
								else
									s += appointment.description() + "    "
								if appointment.scrapped()
									s += "SCRAPPED".cyan
								else
									s += (
										contentTrimmed = appointment.content().trim()
										contentReplaced = contentTrimmed.replace(/[\n\r]+/g, "\n\n")

										if contentTrimmed.split(/[\n\r]+/g).length > 1
											"\n\n" + contentReplaced
										else
											contentReplaced
									)

								if appointment.isDone() then s = s.dim

								console.log ( switch appointment.infoType()
									when 1 then s.blue
									when 2, 3, 4, 5 then s.red
									else s
								)
							else
								console.log "Appointments for #{moment(date).format "dddd D MMMM YYYY"}\n".underline
								for appointment, i in r then do (appointment) ->
									addZero = (s) -> if r.length > 10 and ("" + s).length isnt 2 then "0#{s}" else s
									s = "#{addZero i}: "
									if appointment.beginBySchoolHour()?
										s += "[#{appointment.beginBySchoolHour()}] "
									else
										s += "[ ] "

									if appointment.fullDay()
										s += "   Full Day  \t"
									else
										s += "#{moment(appointment.begin()).format("HH:mm")} - #{moment(appointment.end()).format("HH:mm")}	"
									if appointment.scrapped()
										s += "SCRAPPED".cyan
									else
										s += appointment.description()

									if appointment.isDone() then s = s.dim

									console.log ( switch appointment.infoType()
										when 1 then s.blue
										when 2, 3, 4, 5 then s.red
										else s
									)

						rl.prompt()

				when "homework"
					if params.length is 0
						filterAndShow = (appointments) ->
							appointments = _.filter(appointments, (a) -> not a.isDone() and not a.fullDay() and a.content()? and _.contains [1..5], a.infoType())

							index = 0
							for weekday in [0..6]
								filtered = _.filter(appointments, (a) -> moment(a.begin()).weekday() is weekday)
								continue if filtered.length is 0

								s = ""
								s += days[weekday] + ": "
								for a, i in filtered
									s += "#{a.classes()[0]} [#{index++}]"
									s += ", " if i + 1 isnt filtered.length

								if _.any(filtered, (a) -> a.infoType() > 1)
									console.log s.red
								else
									console.log s

						if homeworkResults?
							filterAndShow homeworkResults
							rl.prompt()
						else
							m.appointments new Date(), moment().add(7, "days").toDate(), no, (e, r) ->
								if e? then console.log "Error: #{e.message}".red.bold
								else
									filterAndShow r
									homeworkResults = _.filter(r, (a) -> not a.isDone() and not a.fullDay() and a.content()? and _.contains [1..5], a.infoType())

								rl.prompt()

					else if _.isNaN +params[0]
						console.log "Use homework <index>".red.bold
						rl.prompt()

					else if homeworkResults?
						appointment = homeworkResults[+params[0]]

						unless appointment?
							rl.prompt()
							return

						s = ""
						s += days[moment(appointment.begin()).weekday()] + "    "
						s += appointment.classes()[0] + "    "
						s += appointment.content().trim().replace(/[\n\r]+/g, "; ")

						if appointment.isDone() then s = s.dim

						console.log if appointment.infoType() > 1 then s.red else s
						rl.prompt()

					else
						m.appointments new Date(), moment().add(7, "days").toDate(), no, (e, r) ->
							if e? then console.log "Error: #{e.message}".red.bold
							else
								homeworkResults = _.filter(r, (a) -> not a.fullDay() and a.content()? and _.contains [1..5], a.infoType())
								appointment = homeworkResults[+params[0]]

								unless appointment?
									rl.prompt()
									return

								s = ""
								s += days[moment(appointment.begin()).weekday()] + "    "
								s += appointment.classes()[0] + "    "
								s += appointment.content().trim().replace(/[\n\r]+/g, "; ")

								if appointment.isDone() then s = s.dim

								console.log if appointment.infoType() > 1 then s.red else s

								rl.prompt()

				when "tests"
					filterAndShow = (appointments) ->
						appointments = _.filter(appointments, (a) -> not a.fullDay() and a.content()? and a.infoType() > 1)
						first = yes
						for appointment in appointments then do (appointment) ->
							s = ""
							s += days[moment(appointment.begin()).weekday()] + ": "
							s += appointment.classes()[0] + "    "
							s += appointment.content().trim().replace(/[\n\r]+/g, "; ")

							if appointment.isDone() then s = s.dim

							console.log("--------------------") unless first
							console.log s.red
							first = no

					if homeworkResults?
						filterAndShow homeworkResults
						rl.prompt()
					else
						m.appointments new Date(), moment().add(7, "days").toDate(), no, (e, r) ->
							if e? then console.log "Error: #{e.message}"
							else
								filterAndShow r
								homeworkResults = _.filter(r, (a) -> not a.fullDay() and a.content()? and _.contains [1..5], a.infoType())

							rl.prompt()

				when "messages"
					folder = m.inbox() # Use inbox as default MessageFolder.

					if params[0]? then limit = +params[0]
					if _.isNaN(limit)
						if params[0].toLowerCase() is "new"
							editor = process.env.EDITOR ? "vi"
							file = "#{mahGisterDir}/MESSAGE_EDIT"
							fs.writeFileSync file, "to (seperator: ','): \nsubject: \n\n### Type body under this line###\n\n"

							resp = spawn editor, [file], stdio: "inherit"
							if resp.status isnt 0 or resp.error?
								console.log "Error while trying to spawn editor proccess, falling back to ol' VI."
								resp = spawn "vi", [ file ], stdio: "inherit"

							data = _.reject fs.readFileSync(file, encoding: "utf8").split("\n"), (s) -> s.indexOf("###") is 0

							namesRaw = data[0].split(":")[2..].join ":"
							names = (x.trim() for x in namesRaw.split ",")

							subject = data[1].split(":")[1..].join ":"

							body = data[2..].join "\n"

							m.composeAndSendMessage subject.trim(), body.trim(), names
							console.log "Sent message to #{names.join(', ')}."

							fs.unlink file # fuck errors

							rl.prompt()
							return
						else
							folder = m.messageFolders(params[0])[0]
							limit = if params[1]? then +params[1] else null

					folder.messages limit, (e, r) ->
						if e? then console.log "Error: #{e.message}".red.bold
						else
							save = (attachment) ->
								attachment.download no, (e, r) ->
									if e? then console.log "Error: #{e.message}".red.bold
									else
										rl.write null, {ctrl: true, name: 'u'}
										console.log "Downloaded #{attachment.name()}"
										fs.writeFile "./attachments/#{attachment.name()}", r, (e) -> throw e if e?

									ask()

							list = -> for msg, i in r then do (msg) ->
								s = "[#{i}] "
								s += "#{msg.sender().description()} "
								s += msg.subject()

								console.log s

							ask = ->
								rl.question "msg> ", (id) ->
									val = id.trim()

									if val.length is 0
										rl.prompt()
										return

									if val.toLowerCase() is "list"
										list()
										ask()
										return

									if val.toLowerCase().indexOf("next") isnt -1 and (amount = +val.split(" ")[1..]) > 0
										m.inbox().messages amount, "skip #{limit}", (err, newMessages) ->
											r = r.concat newMessages ? []
											list()
											ask()

										return

									if val.toLowerCase() is "exit"
										rl.close()
										return

									splitted = val.toLowerCase().split(" ")
									if splitted.length is 2 and splitted[0].toLowerCase() is "download"
										if lastMessage?
											save lastMessage.attachments()[+splitted[1]]
										else
											console.log "No message provided and none read. Read a message or provide one using download <message id> <attachment id>.".red.bold

										ask()
										return

									else if splitted.length is 3 and splitted[0].toLowerCase() is "download"
										save r[+splitted[1]].attachments()[+splitted[2]]
										ask()
										return

									if val.toLowerCase() is "delete"
										if lastMessage?
											(msg = lastMessage).move m.bin()
											_.remove r, msg
										else
											console.log "No message provided and none read. Read a message or provide one using delete <message id> <attachment id>.".red.bold

										ask()
										return

									else if splitted.length is 2 and splitted[0].toLowerCase() is "delete"
										(msg = r[+splitted[1]]).move m.bin()
										_.remove r, msg
										ask()
										return

									else if _.isNaN(+val)
										if val.length is 0 then console.log "Expected command or number.".red.bold
										else console.log "Unknown command: #{val}".red.bold
										ask()
										return

									if +val < 0 or +val >= r.length
										console.log "Given index (#{+val}) out of bounds.".red.bold
										ask()
										return

									mail = r[+val]
									sendDate = moment mail.sendDate()
									recipients = mail.recipients()[..].map((p) -> p.description()).join ", "
									attachments = mail.attachments().map((a) -> a.name()).join ", "

									console.log ""

									console.log "From: #{mail.sender().description()}\n" +
									"Sent: #{days[sendDate.weekday()]} #{sendDate.format('DD-M-YYYY HH:mm:ss')}\n" +
									"To: #{recipients}\n" +
									"Subject: #{mail.subject()}\n" +
									"Attachments: #{attachments}\n\n" +
									"\"#{mail.body()}\""

									lastMessage = mail

									ask()

							list()
							ask()

				when "done"
					if params.length < 2
						console.log "Use done <day> <appointmentId>"
						rl.prompt()
						return

					inf = params[0]
					date = (
						if (val = /^-?\d+$/.exec(inf)?[0])?
							new moment().add val, "days"

						else if _.contains all, inf.toLowerCase()
							x = moment()
							while days[x.weekday()] isnt inf.toLowerCase() and shortDays[x.weekday()] isnt inf.toLowerCase()
								x.add 1, "days"
							x

						else if inf[0] is "-" and _.contains all, inf[1..].toLowerCase()
							x = moment()
							while days[x.weekday()] isnt inf[1..].toLowerCase() and shortDays[x.weekday()] isnt inf[1..].toLowerCase()
								x.add -1, "days"
							x

						else
							moment inf
					).toDate()

					m.appointments date, no, (e, r) ->
						if e? then console.log "Error: #{e.message}"
						else
							appointment = r[+params[1]]
							if appointment?
								appointment.isDone yes
							else
								console.log "Appointment ##{params[1]} not found on #{days[moment(date).weekday()]}."

							rl.prompt()

				when "exit" then rl.close()

				when "" then rl.prompt()

				else showHelp()

if (val = storage.getItem("user"))? then main val
else
	userInfo =
		school: null
		userName: null
		password: null

	askSchool = (cb) ->
		rl.question "What's your school name? ", (a) ->
			MagisterSchool.getSchools a, (e, r) ->
				if e? or r.length is 0
					console.log "No schools found with query: #{a}"
					askSchool cb
				else if r.length > 1
					console.log "[#{i}] #{school.name}" for school, i in r
					rl.question "What's your school? ", (a) ->
						userInfo.school = r[+a]
						cb()
				else
					userInfo.school = r[0]
					cb()

	askUser = ->
		rl.question "What's your username? ", (name) -> rl.question "What's your password? ", (pass) ->
			x = setTimeout ( ->
				console.log "Wrong username and/or password. Or other error."
				askUser()
			), 5000

			new Magister(userInfo.school, name, pass).ready (m) ->
				userInfo.userName = name
				userInfo.password = pass
				clearTimeout x

				storage.setItem "user", userInfo
				main userInfo, m

	askSchool askUser
