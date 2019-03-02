#!/bin/bash
files=(/etc/gotify/cli-bash.json $HOME/.gotify/cli-bash.json .cli-bash.json)
for filepath in "${files[@]}"
do
	if [ -f $filepath ]; then
		break;
	fi
done
case $1 in
"init")
	echo "init"
	read -p 'fullUrl: ' fullurl
	echo "connecting..."
	response=$(curl -sSf "$fullurl/version" || echo "$?")
	if (( ${#response} < 4 )); then
		echo "failed."
		$0 $1
		exit
	fi
	echo "Success!"
	version=$(echo $response | awk 'BEGIN { FS="\""; RS="," }; { if ($2 == "version") {print "v"$4}; if($2 == "buildDate") {print "@"$4} }' ORS='')
	echo "Gotify $version"
	echo ""
	echo "Configure an application token"
	echo "1. Enter an application-token"
	echo "2. Create an application token (with user/pass)"
	notselected=true
	while ($notselected); do
		read -p 'Enter 1 or 2 or c(ancel): ' answer
		echo "answer: $answer"
		if echo "$answer" | grep "1"; then
			notselected=false
			tokenrequest=true
			read -p "Application Token: " appToken
		elif echo "$answer" | grep "2"; then
			notselected=false
			loginrequest=true
			while ($loginrequest); do
				echo "Enter Credentials (only used for creating the token not saved afterwards)"
				read -p 'Username: ' username
				old_stty_cfg=$(stty -g)
				stty -echo
				read -p 'Password: ' password
				stty $old_stty_cfg
				echo ""
				echo "connecting..."
				response=$(curl -sSfu "$username:$password" "$fullurl/current/user" || echo "$?")
				if (( ${#response} < 4 )); then
					echo "login failed."
				else
					loginrequest=false
				fi
			done
			read -p "Application name: " appname
			read -p "Application description (can be empty): " appdesc
			response=$(curl -sSf -X POST -H "Content-Type: application/json" -u "$username:$password" "$fullurl/application" -d "{\"description\": \"$appdesc\",  \"name\": \"$appname\"}")
			appToken=$(echo $response | awk 'BEGIN { FS="\""; RS="," }; { if($2 == "token") {print $4} }')
		fi
		echo $appToken
		response=$(curl -sSf -X POST -H "Content-Type: application/json" -H "X-Gotify-Key: $appToken" "$fullurl/message" -d "{  \"message\": \"testMessage\",  \"priority\": 0,  \"title\": \"gotify-BASH\"}" || echo "$?")
		if (( ${#response} < 4 )); then
			echo "test message failed."
			exit
		else
			tokenrequest=false
		fi
		while (true); do
			echo "Where to put the config file?"
			for i in "${!files[@]}"
			do
				printf "%s\t%s\n" "$(($i + 1))" "${files[$i]}"
			done
			read -p "Enter a number: " filenumber
			if [[ "$filenumber" =~ ^[1-${#files[@]}]$ ]]; then
				filepath=${files[$(($filelocation - 1))]}
				break;
			fi
		done
		mkdir -p $(dirname "$filepath")
		echo -e "{\n\t\"token\": \"$appToken\",\n\t\"url\": \"$fullurl\"\n}" > $filepath
	done
	;;
"version"|"v"|"-v"|"--version")
	echo "no version nummering used..."
	;;
"config")
	cat "$filepath"
	;;
"push"|"p")
	shift
	fileData=$(cat $filepath || echo "$?")
	if (( ${#fileData} < 4 )); then
		echo "data file error. try $0 init"
		exit
	fi
	token=$(echo $fileData | awk 'BEGIN { FS="\""; RS="," }; { if($2 == "token") {print $4} }')
	url=$(echo $fileData | awk 'BEGIN { FS="\""; RS="," }; { if($2 == "url") {print $4} }')
	title=""
	priority=0
	message=""
	quiet=false
	while [[ "$#" -gt 0 ]]; do case $1 in
		-h|--help|help)
			cat << EOF
NAME:
   gotify-bash push - Pushes a message

USAGE:
   gotify-bash push [command options] <message-text>

OPTIONS:
   --priority value, -p value  Set the priority (default: 0)
   --title value, -t value     Set the title (empty for app name)
   --token value               Override the app token
   --url value                 Override the Gotify URL
   --quiet, -q                 Do not output anything (on success)
EOF
			exit
		;;
		-p|--priority)
			priority=$2
			shift
		;;
		--title|-t)
			title=$2
			shift
		;;
		--token)
			token=$2
			shift
		;;
		--url)
			url=$2
			shift
		;;
		-q|--quiet)
			quiet=true
		;;
		*)
			break;
		;;
	esac;shift;done
	message=$@
	if [[ "$#" -eq 0 ]]; then
		echo "a message must be set as argument"
		exit
	fi
	response=$(curl -s -w "%{http_code}" -X POST -H "Content-Type: application/json" -H "X-Gotify-Key: $token" "$url/message" -d "{\"message\": \"$message\",  \"priority\": $priority,  \"title\": \"$title\"}")
	case ${response: -3} in
		000)
			echo "curl request error"
			;;
		200)
			if ! ($quiet); then
				echo "message created"
			fi
			;;
		*)
			echo "request error code ${response: -3}"
			echo "response: ${response::-3}"
			;;
	esac
	;;
	"help"|"--help"|"-v"|""|*)
cat << EOF
NAME:
   Gotify-bash - The unofficial bash implemention of Gotify-CLI

USAGE:
   gotify-bash [global options] command [command options] [arguments...]

VERSION:
   1.2.0

COMMANDS:
     init        Initializes the Gotify-CLI
     version, v  Shows the version
     config      Shows the config
     push, p     Pushes a message
     help, h     Shows a list of commands

GLOBAL OPTIONS:
   --help, -h     show help
   --version, -v  print the version
EOF
;;
esac
