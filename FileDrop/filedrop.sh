#!/bin/sh

#/////////////////////////////////////////////////
# user settings
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#-> editor to be used for file processing
USE_EDITOR="xed -w +"
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


#/////////////////////////////////////////////////
# user/system settings
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#-> for option -f: folder for cache, file will be temporary stored
TMP_DIR="/tmp"
#-> default file with access token
DEFAULT_ACCESS_TOKEN_FILE="./pvt/access_token_plain.txt" #"$HOME/.filedrop/access_token_plain.txt"
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


##################################################
#_________________________________________________
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
# from here on: if the script is finished, usually no need to edit things
#_________________________________________________
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##################################################


#/////////////////////////////////////////////////
# gloabal variables, info- and error-output functions
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
FILEDROP_VERSION="0.0.1"

TASK_TODO=""
ACCESS_TOKEN=""

TASKARG_ONE=""
TASKARG_TWO=""


InfoPrint() {
	printf "$1"
}
InfoEcho() {
	echo "$1"
}
ErrorEcho() {
	echo "$1" >&2
}
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


#/////////////////////////////////////////////////
# check for needed commands and programms
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CheckForNeededCmds() {
	local NEEDED_CMDS="$1"
	local CMD_NAME=""

	for CMD_NAME in ${NEEDED_CMDS}; do
		if ! command -v "${CMD_NAME}" > /dev/null; then #alternative: ! type  "${CMD_NAME}"
			ErrorEcho "Error: "${CMD_NAME}" needed."
			exit 1
		fi
	done
}

CheckForNeededCmds "curl sed basename dirname cat mktemp touch awk grep"
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


#/////////////////////////////////////////////////
# arguments, options and task
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

#-> if no arguments defined, exit with error
if [ $# -eq 0 ]; then
	ErrorEcho "Error: no specified option(s) or task."
	InfoEcho "For help use option -h (--help)"
	exit 1
fi

#-> print help
PrintHelp() {
echo "\
filedrop $FILEDROP_VERSION

Usage: filedrop [options ...] [FILE] ...

If no access token is specified (-a, -t), attempt to use the file:
${DEFAULT_ACCESS_TOKEN_FILE}

Options:

-f, --file FILE           Process or create and process a file
-g, --get FILE DST        Download a file to destination
-u, --upload FILE DST     Upload a local file to destination
--del, --delete FILE/DIR  Deleted a file or folder.
-e, --editor EDITOR       Use a specific editor for opening the file, editor
                          has to block the script (like \"nano\", \"xed -w\")
                          only useful with option -f (--file)
-z, --zip DIRPATH DST     Download a complete folder as a zip-file
-l, --ls PATH             List folders and files
--lrec, --lrecusive PATH  List folders and files recursive
--mv, --move SRC DST      Move or rename a file or folder
--space                   Display used and allocated space in bytes

-a, --token TOKEN         Dropbox access token
-t, --tokenfile FILE      File with the dropbox access token

-h, --help                Display help and exit
--version                 Show version and exit

Examples:

filedrop -a TOKEN tea.txt    Process/create the file with the name \"tea.txt\"
filedrop tea.txt             Same as above, attempt to use default tokenfile
filedrop cb/tea.txt          Same as above, but inside the folder cb
filedrop --del tea.txt       Delete the file \"tea.txt\"
filedrop -l /                List files in top directory
filedrop -z \"/info\" \"./\"     Download the complete folder \"/info\" as a 
                             zip-file into the current folder
filedrop --lsrec /           List all folders and files from everywhere

$ remdrop.sh -u \"./info/std.txt\" \"tee/cup\"     
                           uploads std.txt into the folder tee/cup
"
}

#-> if no argument is available, exit with error
CheckArgAvailable() {
	local NUM_ARG=$1
	local NAME_OPT="$2"

	if [ $NUM_ARG -eq 0 ]; then
		ErrorEcho "Error: missing argument for ${NAME_OPT}"
		exit 1
	fi
}

#-> if task is already set, exit with error
CheckTaskAlreadySet() {
	local NAME_OPT="$1"

	if [ -n "$TASK_TODO" ]; then
		ErrorEcho "Error: previous option in conflict with ${NAME_OPT}."
		exit 1	
	fi
}


#-> validate arguments and set global variables
while [ $# -gt 0 ]; do
	case "$1" in
	-f|--file)
		shift
		CheckTaskAlreadySet "-f (--file)"
		CheckArgAvailable $# "-f (--file)"
		TASKARG_ONE="$1"
		TASK_TODO="down_and_up"
		;;
	-g|--get)
		shift
		CheckTaskAlreadySet "-g (--get)"
		CheckArgAvailable $# "-g (--get)"
		TASKARG_ONE="$1"
		shift
		CheckArgAvailable $# "-g (--get), second argument"
		TASKARG_TWO="$1"
		if [ -z "$TASKARG_TWO" ] || [ ! -d "$TASKARG_TWO" ]; then
			ErrorEcho "Error: directory \"${TASKARG_TWO}\" does not exist, invalid destination for -g (--get)"
			exit 1
		fi	
		TASK_TODO="get_stuff"
		;;
	-u|--upload)
		shift
		CheckTaskAlreadySet "-u (--upload)"
		CheckArgAvailable $# "-u (--upload)"
		TASKARG_ONE="$1"
		if [ -z "$TASKARG_ONE" ] || [ ! -e "$TASKARG_ONE" ]; then
			ErrorEcho "Error: file ${TASKARG_ONE} does not exist, invalid file for -u (--upload)"
			exit 1
		fi		
		shift
		CheckArgAvailable $# "-u (--upload), second argument"
		TASKARG_TWO="$1"
		TASK_TODO="upload_file"
		;;
	--del|--delete)
		shift
		CheckTaskAlreadySet "--del (--delete)"
		CheckArgAvailable $# "--del (--delete)"
		TASKARG_ONE="$1"
		TASK_TODO="delete_stuff"
		;;
	-e|--editor)
		shift
		CheckArgAvailable $# "-e (--editor)"
		USE_EDITOR="$1"
		;;
	-a|--token)
		shift
		if [ -n "$ACCESS_TOKEN" ]; then
			ErrorEcho "Error: option -a (--token) in conflict with the previous option -t (--tokenfile). Only one method should be used."
			exit 1	
		fi
		CheckArgAvailable $# "-a (--token)"
		ACCESS_TOKEN="$1"
		;;
	-t|--tokenfile)
		shift
		if [ -n "$ACCESS_TOKEN" ]; then
			ErrorEcho "Error: option -t (--tokenfile) in conflict with the previous option -a (--token). Only one method should be used."
			exit 1	
		fi
		CheckArgAvailable $# "-t (--tokenfile)"
		if [ -z "$1" ] || [ ! -e "$1" ]; then
			ErrorEcho "Error: file ${1} does not exist, invalid file for -t (--tokenfile)"
			exit 1
		fi
		ACCESS_TOKEN=$(cat "$1")
		;;
	-z|--zip)
		shift
		CheckTaskAlreadySet "-z (--zip)"
		CheckArgAvailable $# "-z (--zip)"	
		TASKARG_ONE="$1"
		#-> pre-check for easy/common errors
		if [ -z "$TASKARG_ONE" ] || [ "$TASKARG_ONE" = "./" ] || [ "$TASKARG_ONE" = "/" ] || [ "$TASKARG_ONE" = "." ]; then
			ErrorEcho "Error: invalid path (first argument) for -z (--zip)."
			exit 1
		fi
		shift
		CheckArgAvailable $# "-z (--zip), second argument"
		TASKARG_TWO="$1"
		if [ -z "$TASKARG_TWO" ] || [ ! -d "$TASKARG_TWO" ]; then
			ErrorEcho "Error: directory \"${TASKARG_TWO}\" does not exist, invalid destination for -z (--zip)."
			exit 1
		fi
		TASK_TODO="download_zip"
		;;
	-l|--ls)
		shift
		CheckTaskAlreadySet "-l (--ls)"
		CheckArgAvailable $# "-l (--ls)"
		TASKARG_ONE="$1"
		TASK_TODO="list_dir"
		;;
	--lrec|--lrecusive)
		shift
		CheckTaskAlreadySet "--lrec (--lrecusive)"
		CheckArgAvailable $# "--lrec (--lrecusive)"
		TASKARG_ONE="$1"
		TASK_TODO="list_recusive"
		;;
	--mv|--move)
		shift
		CheckTaskAlreadySet "--mv (--move)"
		CheckArgAvailable $# "--mv (--move)"
		TASKARG_ONE="$1"	
		shift
		CheckArgAvailable $# "--mv (--move), second argument"
		TASKARG_TWO="$1"
		TASK_TODO="move_file"
		;;
	--space)
		TASK_TODO="space_usage"
		;;
	-h|--help)
		PrintHelp
		exit 0
		;;
	--version)
		echo "$FILEDROP_VERSION"
		exit 0
		;;
	-*|--*)
		ErrorEcho "Error: unrecognised option $1"
		exit 1
		;;
	*)
		if [ -n "$TASK_TODO" ]; then
			ErrorEcho "Error: options conflict, default argument should not be specified."
			exit 1	
		fi
		TASKARG_ONE="$1"
		TASK_TODO="down_and_up"
		;;
	esac
	shift
done

#-> if there's no access token, check for default token-file, otherwise exit
if [ -z "$ACCESS_TOKEN" ]; then
	if [ ! -e "$DEFAULT_ACCESS_TOKEN_FILE" ]; then
		ErrorEcho "Error: access token is needed (option -a, --token or -t, --fokenfile)."
		exit 1		
	fi
	ACCESS_TOKEN=$(cat "$DEFAULT_ACCESS_TOKEN_FILE")
fi
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<



#/////////////////////////////////////////////////
# functions for main switch
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

#-> check if a file or folder ($1, DROPPATH_TO_CHECK) exists, return "true", "false" or "error"
DropFileOrFolderExists() {
	local DROPPATH_TO_CHECK="$1"

	local HTTP_STATUS_CODE=$(curl --silent --output "/dev/null" --write-out "%{http_code}" \
		--request POST https://api.dropboxapi.com/2/files/get_metadata \
		--header "Authorization: Bearer ${ACCESS_TOKEN}" \
		--header "Content-Type: application/json" \
		--data "{\"path\": \"${DROPPATH_TO_CHECK}\"}")

	local CURL_EXIST_EXIT_STATUS=$?
	if [ $CURL_EXIST_EXIT_STATUS -ne 0 ]; then
		ErrorEcho "Error in DropFileOrFolderExists: curl exit code ${CURL_EXIST_EXIT_STATUS}."
		echo "error"
	elif [ $HTTP_STATUS_CODE -eq 200 ]; then
		echo "true"
	elif [ $HTTP_STATUS_CODE -eq 409 ]; then
		echo "false"
	else
		ErrorEcho "Error in DropFileOrFolderExists: HTTP status code ${HTTP_STATUS_CODE}."
		echo "error"
	fi
}


#-> fit/process the path ($1, MOD_DROPPATH) for dropbox (e.g. "./daa/foo/" -> "/daa/foo")
ModPathForDrop() {
	local MOD_DROPPATH="$1"

	#-> not '.' at the beginning
	local FIRST_CHAR=$(echo "${MOD_DROPPATH}" | sed "s/\(^.\).*/\1/")
	if [ "${FIRST_CHAR}" = "." ] ; then
		MOD_DROPPATH=$(echo "${MOD_DROPPATH}" | sed "s/^.\{1\}//")
	fi
	#-> need a '/' at the beginning, replace // with /
	MOD_DROPPATH=$(echo "/${MOD_DROPPATH}" | sed "s,//,/,g")
	#-> check if the last sign is a '/', if so remove it
 	local LAST_CHAR=$(echo "${MOD_DROPPATH}" | sed -e "s/.*\(.\)$/\1/")
	if [ "${LAST_CHAR}" = "/" ] && [ ${#MOD_DROPPATH} -ne 1 ] ; then
		MOD_DROPPATH=$(echo "${MOD_DROPPATH}" | sed "s/.$//")
	fi

	echo "$MOD_DROPPATH"
}



#-> download a folder as a zip-file ($1 -> $2, ARG_DATAPATH -> DSTPATH_ZIP)
DownloadZip() {
	local ARG_DATAPATH="$1"
	local DSTPATH_ZIP="$2"
	local MOD_PATH_ZIP="$(ModPathForDrop "$ARG_DATAPATH")"
	local DROP_FOLDER_EXISTS=$(DropFileOrFolderExists "$MOD_PATH_ZIP")
	if [ "$DROP_FOLDER_EXISTS" != "true" ]; then
		ErrorEcho "Error in DownloadZip: Folder ${ARG_DATAPATH} does not exist."
		exit 1
	fi
	local ZIPFILENAME="$(basename "${ARG_DATAPATH}")"
	local DSTFILEPATH_ZIP="${DSTPATH_ZIP}/${ZIPFILENAME}.zip"
	DSTFILEPATH_ZIP=$(echo "${DSTFILEPATH_ZIP}" | sed -e "s,//,/,g" -e "s,//,/,g") # for convenience two times: replace // with /

	local HTTP_STATUS_CODE=$(curl --silent --output "${DSTFILEPATH_ZIP}" --write-out "%{http_code}" \
		--request POST https://content.dropboxapi.com/2/files/download_zip \
		--header "Authorization: Bearer ${ACCESS_TOKEN}" \
		--header "Dropbox-API-Arg: {\"path\": \"${MOD_PATH_ZIP}\"}")

	local CURL_ZIP_EXIT_STATUS=$?
	if [ $CURL_ZIP_EXIT_STATUS -ne 0 ]; then
		ErrorEcho "Error in DownloadZip: curl exit code ${CURL_ZIP_EXIT_STATUS}."
		exit 1
	elif [ $HTTP_STATUS_CODE -ne 200 ]; then
		ErrorEcho "Error in DownloadZip: HTTP status code ${HTTP_STATUS_CODE}."
		exit 1
	else
		InfoEcho "${ZIPFILENAME}.zip downloaded."
	fi
}


#-> upload a file ($1 -> $2, UPLOAD_DATAFILE -> UPLOAD_DSTPATH)
UploadFile() {
	local UPLOAD_DATAFILE="$1"
	local UPLOAD_DSTPATH="$2"
	local MOD_UPLOAD_DSTPATH="$(ModPathForDrop "$UPLOAD_DSTPATH")"
	local FILENAME_UPLOAD="$(basename "$UPLOAD_DATAFILE")"
	local DSTFILEPATH_UP="${MOD_UPLOAD_DSTPATH}/${FILENAME_UPLOAD}"
	DSTFILEPATH_UP=$(echo "$DSTFILEPATH_UP" | sed "s,//,/,g") # replace // with /

	local FILESIZE_BYTES=$(stat "$UPLOAD_DATAFILE" -c %s)
	if [ $FILESIZE_BYTES -gt 150000000 ]; then # 150 MB = 157286400 bytes ? 150000000 bytes
		ErrorEcho "Error in UploadFile: not able to upload a file larger than 150 MB."
		exit 1
	fi

	local HTTP_STATUS_CODE=$(curl --silent --output "/dev/null" --write-out "%{http_code}" \
		--request POST https://content.dropboxapi.com/2/files/upload \
		--header "Authorization: Bearer ${ACCESS_TOKEN}" \
		--header "Content-Type: application/octet-stream" \
		--header "Dropbox-API-Arg: {\"path\": \"${DSTFILEPATH_UP}\", \"mode\": \"overwrite\"}" \
		--data-binary @"${UPLOAD_DATAFILE}")
	local CURL_UP_EXIT_STATUS=$?
	if [ $CURL_UP_EXIT_STATUS -ne 0 ]; then
		ErrorEcho "Error in UploadFile: curl exit code ${CURL_UP_EXIT_STATUS}."
		exit 1
	elif [ $HTTP_STATUS_CODE -ne 200 ]; then
		ErrorEcho "Error in UploadFile: HTTP status code ${HTTP_STATUS_CODE}."
		exit 1
	else
		InfoEcho "${FILENAME_UPLOAD} uploaded."
	fi
}


#-> download a file ($1 -> $2, ARG_DATAPATH -> DSTPATH_GET)
GetFile() {
	local ARG_DATAPATH="$1"
	local DSTPATH_GET="$2"
	local MOD_DOWNLOAD_DATAFILE="$(ModPathForDrop "$ARG_DATAPATH")"
	local DROP_FILE_EXISTS=$(DropFileOrFolderExists "$MOD_DOWNLOAD_DATAFILE")
	if [ "$DROP_FILE_EXISTS" != "true" ]; then
		ErrorEcho "Error in GetFile: File ${ARG_DATAPATH} does not exist."
		exit 1
	fi
	local FILENAME_DOWNLOAD="$(basename "$ARG_DATAPATH")"
	local DSTFILEPATH_DOWN="${DSTPATH_GET}/${FILENAME_DOWNLOAD}"
	DSTFILEPATH_DOWN=$(echo "$DSTFILEPATH_DOWN" | sed "s,//,/,g") # replace // with /

	local HTTP_STATUS_CODE=$(curl --silent --output "${DSTFILEPATH_DOWN}" --write-out "%{http_code}" \
		--request POST https://content.dropboxapi.com/2/files/download \
		--header "Authorization: Bearer ${ACCESS_TOKEN}" \
		--header "Dropbox-API-Arg: {\"path\": \"${MOD_DOWNLOAD_DATAFILE}\"}")
	local CURL_DOWN_EXIT_STATUS=$?
	if [ $CURL_DOWN_EXIT_STATUS -ne 0 ]; then
		ErrorEcho "Error in GetFile: curl exit code ${CURL_DOWN_EXIT_STATUS}."
		exit 1
	elif [ $HTTP_STATUS_CODE -ne 200 ]; then
		ErrorEcho "Error in GetFile: HTTP status code ${HTTP_STATUS_CODE}."
		exit 1
	else
		InfoEcho "${FILENAME_DOWNLOAD} downloaded."
	fi
}


#-> download or create a file ($1, ARG_DATAPATH), open/process it with an editor, upload
DownAndUp() {
	local ARG_DATAPATH="$1"
	local NEWCREATEDFILE=0
	local DAU_EDITOR=""
	#-> set the editor for the requested file
	if [ -n "$USE_EDITOR" ] && command -v ${USE_EDITOR} > /dev/null 2>&1; then
		DAU_EDITOR="$USE_EDITOR"
	elif command -v xed > /dev/null 2>&1; then
		DAU_EDITOR="xed -w +"
	elif command -v nano > /dev/null 2>&1; then
		DAU_EDITOR="nano +999999,999999"
	elif command -v code > /dev/null 2>&1; then
		DAU_EDITOR="code -w"
	elif command -v vi > /dev/null 2>&1; then
		DAU_EDITOR="vi"
	else
		ErrorEcho "Error in DownAndUp: no editor found."
		exit 1
	fi
	
	#-> create temporary folder
	local TMP_STORE_DIR="$(mktemp --directory "${TMP_DIR}/Temp_f_d_XXXXXXXXX")"
	local MKTEMP_TMPDIR_EXIT_STATUS=$?
	if [ $MKTEMP_TMPDIR_EXIT_STATUS -ne 0 ]; then
		ErrorEcho "Error in DownAndUp: mktemp exit code ${MKTEMP_TMPDIR_EXIT_STATUS}."
		if [ -d "$TMP_STORE_DIR" ]; then
			rm --recursive --force ${TMP_STORE_DIR}
		fi
		exit 1
	fi
	trap "rm --recursive --force ${TMP_STORE_DIR}" 0 1 2 3

	local FILENAME_DOWNLOAD="$(basename "$ARG_DATAPATH")"
	local TMP_STORE_FILE="${TMP_STORE_DIR}/${FILENAME_DOWNLOAD}"	

	local MOD_DOWNLOAD_DATAFILE="$(ModPathForDrop "$ARG_DATAPATH")"
	local DROP_FILE_EXISTS=$(DropFileOrFolderExists "$MOD_DOWNLOAD_DATAFILE")
	if [ "$DROP_FILE_EXISTS" = "true" ]; then
		GetFile "$ARG_DATAPATH" "$TMP_STORE_DIR"
	elif [ "$DROP_FILE_EXISTS" = "false" ]; then
		touch "$TMP_STORE_FILE"
		local TOUCH_EXIT_STATUS=$?
		if [ $TOUCH_EXIT_STATUS -ne 0 ]; then
			ErrorEcho "Error in DownAndUp: touch exit code ${TOUCH_EXIT_STATUS}."
			exit 1
		fi
		NEWCREATEDFILE=1
		InfoEcho "${FILENAME_DOWNLOAD} (temporarily) created."
	else
		ErrorEcho "Error in DownAndUp: DropFileOrFolderExists returned error."
		exit 1
	fi

	if [ ! -e "$TMP_STORE_FILE" ]; then
		ErrorEcho "Error in DownAndUp: temporary file not found."
		exit 1
	fi

	#-> store pre-opening/pre-processed file-time 
	local FILETIME_PRE=$(stat "$TMP_STORE_FILE" -c %Y)
	#-> open file with editor
	eval "${DAU_EDITOR} \"${TMP_STORE_FILE}\""
	local DAU_EDITOR_EXIT_STATUS=$?
	if [ $DAU_EDITOR_EXIT_STATUS -ne 0 ]; then
		ErrorEcho "Error in DownAndUp: ${DAU_EDITOR} failed with exit code ${DAU_EDITOR_EXIT_STATUS}."
		exit 1
	fi
	#-> store post-opening/post-processed file-time 
	local FILETIME_POST=$(stat "$TMP_STORE_FILE" -c %Y)

	#-> if the file was edited or new created, upload
	if [ $FILETIME_PRE -ne $FILETIME_POST ] || [ $NEWCREATEDFILE -eq 1 ] ; then
		local UPLOAD_DSTPATH="$(dirname "$ARG_DATAPATH")"
		UploadFile "$TMP_STORE_FILE" "$UPLOAD_DSTPATH"
	else
		InfoEcho "${FILENAME_DOWNLOAD} not modified."
	fi

	rm --recursive --force ${TMP_STORE_DIR}
	trap - 0 1 2 3
}

#-> delete a file or foler ($1, ARG_DATAPATH)
DeleteStuff() {
	local ARG_DATAPATH="$1"
	local MOD_DOWNLOAD_DATAFILE="$(ModPathForDrop "$ARG_DATAPATH")"
	local DROP_STUFF_EXISTS=$(DropFileOrFolderExists "$MOD_DOWNLOAD_DATAFILE")
	if [ "$DROP_STUFF_EXISTS" != "true" ]; then
		ErrorEcho "Error in DeleteStuff: Folder ${ARG_DATAPATH} does not exist."
		exit 1
	fi

	local HTTP_STATUS_CODE=$(curl --silent --output "/dev/null" --write-out "%{http_code}" \
		--request POST https://api.dropboxapi.com/2/files/delete_v2 \
		--header "Authorization: Bearer ${ACCESS_TOKEN}" \
		--header "Content-Type: application/json" \
		--data "{\"path\": \"${MOD_DOWNLOAD_DATAFILE}\"}")
	local CURL_DEL_EXIT_STATUS=$?
	if [ $CURL_DEL_EXIT_STATUS -ne 0 ]; then
		ErrorEcho "Error in DeleteStuff: curl exit code ${CURL_DEL_EXIT_STATUS}."
		exit 1
	elif [ $HTTP_STATUS_CODE -eq 409 ]; then
		ErrorEcho "Error in DeleteStuff: Folder ${ARG_DATAPATH} does not exist."
		exit 1
	elif [ $HTTP_STATUS_CODE -ne 200 ]; then
		ErrorEcho "Error in DeleteStuff: HTTP status code ${HTTP_STATUS_CODE}."
		exit 1
	else
		InfoEcho "${ARG_DATAPATH} deleted."
	fi
}

#-> display/list files and folers inside path ($1, ARG_DATAPATH)
ListStorage() {
	local ARG_DATAPATH="$1"
	local LS_DSTDIR=""
	local LS_RECUSIVE="false"

	if [ $# -eq 2 ] && [ "$2" = "recusive" ]; then
		LS_RECUSIVE="true"
	fi

	if [ -z "$ARG_DATAPATH" ] || [ "$ARG_DATAPATH" = "." ] || [ "$ARG_DATAPATH" = "/" ] || [ "$ARG_DATAPATH" = "./" ]; then
		LS_DSTDIR=""
	else
		LS_DSTDIR="$(ModPathForDrop "$ARG_DATAPATH")"
		local DROP_DST_EXISTS=$(DropFileOrFolderExists "$LS_DSTDIR")
		if [ "$DROP_DST_EXISTS" != "true" ]; then
			ErrorEcho "Error in ListStorage: File ${ARG_DATAPATH} does not exist."
			exit 1
		fi
	fi

	local TMP_FILE="$(mktemp "${TMP_DIR}/Temp_f_d_LS.XXXXXXXXX")"
	local MKTEMP_TMP_EXIT_STATUS=$?
	if [ $MKTEMP_TMP_EXIT_STATUS -ne 0 ]; then
		if [ -e "$TMP_FILE" ]; then
			rm --force ${TMP_FILE}
		fi
		ErrorEcho "Error in ListStorage: mktemp exit code ${MKTEMP_TMP_EXIT_STATUS}."
		exit 1
	fi
	trap "rm --force ${TMP_FILE}" 0 1 2 3	

	local HTTP_STATUS_CODE=$(curl --silent --output "${TMP_FILE}" --write-out "%{http_code}" \
		--request POST https://api.dropboxapi.com/2/files/list_folder \
		--header "Authorization: Bearer ${ACCESS_TOKEN}" \
		--header "Content-Type: application/json" \
		--data "{\"path\": \"${LS_DSTDIR}\",\"recursive\": ${LS_RECUSIVE}, \"limit\": 2000}")
	local CURL_DOWN_EXIT_STATUS=$?
	if [ $CURL_DOWN_EXIT_STATUS -ne 0 ]; then
		ErrorEcho "Error in ListStorage: curl exit code ${CURL_DOWN_EXIT_STATUS}."
		exit 1
	elif [ $HTTP_STATUS_CODE -ne 200 ]; then
		ErrorEcho "Error in ListStorage: HTTP status code ${HTTP_STATUS_CODE}."
		exit 1
	fi
	local PATH_DIS=""
	PATH_DIS=$(sed "s/{/\n/g" "${TMP_FILE}" | grep ".tag" | awk -F"\": |\", " "{ print \$2 \$6}" \
		| sed -e "s/\"/[/" -e "s/\"/] /")	

	echo "$PATH_DIS"

	rm --force "${TMP_FILE}"
	trap - 0 1 2 3
}

#-> move or rename file or folder ($1 -> $2, ARG_DATAPATH -> DSTPATH_MVTO)
MoveFile() {
	local ARG_DATAPATH="$1"
	local DSTPATH_MVTO="$2"
	local MOD_FROM_PATH="$(ModPathForDrop "$ARG_DATAPATH")"
	local DROP_FILE_EXISTS=$(DropFileOrFolderExists "$MOD_FROM_PATH")
	if [ "$DROP_FILE_EXISTS" != "true" ]; then
		ErrorEcho "Error in MoveFile: File ${ARG_DATAPATH} does not exist."
		exit 1
	fi
	local MOD_TO_DATAPATH="$(ModPathForDrop "$DSTPATH_MVTO")"

	local HTTP_STATUS_CODE=$(curl --silent --output "${DSTFILEPATH_DOWN}" --write-out "%{http_code}" \
		--request POST https://api.dropboxapi.com/2/files/move_v2 \
		--header "Authorization: Bearer ${ACCESS_TOKEN}" \
		--header "Content-Type: application/json" \
		--data "{\"from_path\": \"${MOD_FROM_PATH}\",\"to_path\": \"${MOD_TO_DATAPATH}\",\"allow_shared_folder\": false,\"autorename\": true}")
	local CURL_MOVE_EXIT_STATUS=$?
	if [ $CURL_MOVE_EXIT_STATUS -ne 0 ]; then
		ErrorEcho "Error in MoveFile: curl exit code ${CURL_MOVE_EXIT_STATUS}."
		exit 1
	elif [ $HTTP_STATUS_CODE -ne 200 ]; then
		ErrorEcho "Error in MoveFile: HTTP status code ${HTTP_STATUS_CODE}."
		exit 1
	else
		InfoEcho "${MOD_FROM_PATH} moved to ${MOD_TO_DATAPATH}."
	fi
}


#-> display used and allocated space in bytes
SpaceUsage() {
	local TMP_FILE="$(mktemp "${TMP_DIR}/Temp_f_d_SU.XXXXXXXXX")"
	local MKTEMP_TMP_EXIT_STATUS=$?
	if [ $MKTEMP_TMP_EXIT_STATUS -ne 0 ]; then
		if [ -e "$TMP_FILE" ]; then
			rm --force ${TMP_FILE}
		fi
		ErrorEcho "Error in SpaceUsage: mktemp exit code ${MKTEMP_TMP_EXIT_STATUS}."
		exit 1
	fi
	trap "rm --force ${TMP_FILE}" 0 1 2 3	

	local HTTP_STATUS_CODE=$(curl --silent --output "${TMP_FILE}" --write-out "%{http_code}" \
		--request POST https://api.dropboxapi.com/2/users/get_space_usage \
		--header "Authorization: Bearer ${ACCESS_TOKEN}")

	local CURL_SPACE_EXIT_STATUS=$?
	if [ $CURL_SPACE_EXIT_STATUS -ne 0 ]; then
		ErrorEcho "Error in SpaceUsage: curl exit code ${CURL_SPACE_EXIT_STATUS}."
		exit 1
	elif [ $HTTP_STATUS_CODE -ne 200 ]; then
		ErrorEcho "Error in SpaceUsage: HTTP status code ${HTTP_STATUS_CODE}."
		exit 1
	fi

	local PATH_DIS=""
	PATH_DIS=$(sed "s/[,{]/\n/g" "${TMP_FILE}" | grep -E "used|allocated" | sed -e "s/[ \"]//" -e "s/[}\"]//g")
	echo "Space usage (bytes):"
	echo "$PATH_DIS"

	rm --force "${TMP_FILE}"
	trap - 0 1 2 3
}


#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


#/////////////////////////////////////////////////
# main switch
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
case "$TASK_TODO" in
	download_zip)
		DownloadZip "$TASKARG_ONE" "$TASKARG_TWO" #"$ARG_DATAPATH" $DSTPATH_ZIP
		;;
	upload_file)
		UploadFile "$TASKARG_ONE" "$TASKARG_TWO" #"$UPLOAD_DATAFILE" "$UPLOAD_DSTPATH"
		;;
	get_stuff)
		GetFile "$TASKARG_ONE" "$TASKARG_TWO" #"$ARG_DATAPATH" "$DSTPATH_GET"
		;;
	down_and_up)
		DownAndUp "$TASKARG_ONE" #"$ARG_DATAPATH"
		;;
	delete_stuff)
		DeleteStuff "$TASKARG_ONE" #"$ARG_DATAPATH"
		;;
	list_dir)
		ListStorage "$TASKARG_ONE" #"$ARG_DATAPATH"
		;;
	list_recusive)
		ListStorage "$TASKARG_ONE" "recusive" #"$ARG_DATAPATH" "recursive"
		;;
	move_file)
		MoveFile "$TASKARG_ONE" "$TASKARG_TWO"
		;;
	space_usage)
		SpaceUsage
		;;
	*)
		ErrorEcho "Error: should not get here."
		exit 1
		;;
esac

exit 0
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<




