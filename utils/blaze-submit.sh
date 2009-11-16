#!/bin/sh
#set -o xtrace

# blaze-submit, upload the static content to the remote server
# Copyright (C) 2009 SKooDA(http://www.skooda.org)

# This program is  free software:  you can redistribute it and/or modify it
# under  the terms  of the  GNU General Public License  as published by the
# Free Software Foundation, version 3 of the License.
#
# This program  is  distributed  in the hope  that it will  be useful,  but
# WITHOUT  ANY WARRANTY;  without  even the implied  warranty of MERCHANTA-
# BILITY  or  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
# License for more details.
#
# You should have received a copy of the  GNU General Public License  along
# with this program. If not, see <http://www.gnu.org/licenses/>.

# General script information:
NAME=${0##*/}
VERSION='0.1'

# Prepare needed parameters:
SERVER_HOST=''
SERVER_PORT='21'
USER_NAME=''
USER_PASSWORD=''
BLOG_DIRECTORY='./'
CONFIG_FILE='./.blaze/config'
REMOTE_DIRECTORY=''

# Shift command-line options:
while [ "$#" -ne "0" ]; do
 case "$1" in
     "-u" | "--username")    USER_NAME="$2";        shift;;
     "-P" | "--password")    USER_PASSWORD="$2";    shift;;
     "-H" | "--host")        SERVER_HOST="$2";      shift;;
     "-p" | "--port")        SERVER_PORT="$2";      shift;;
     "-b" | "--blogdir")     BLOG_DIRECTORY="$2";   shift;;
     "-c" | "--config")      CONFIG_FILE="$2";      shift;;
     "-d" | "--destination") REMOTE_DIRECTORY="$2"; shift;;
     "-h" | "help" | "?" | "--help" | "-help")
       # Display help
       echo "Usage: $NAME [-c file] [-b directory] [-d directory] [-H address]"
       echo "                    [-p port] [-u username] [-P password]"
       echo "       $NAME -h | -v"
       echo
       echo "  -c, --config file           use alternative configuration file"
       echo "  -u, --username username     specify FTP username"
       echo "  -P, --password password     specify FTP password"
       echo "  -H, --host address          specify remote host address"
       echo "  -p, --port port             specify remote host port"
       echo "  -b, --blogdir directory     specify local directory to upload"
       echo "  -d, --destination directory specify destination directory on remote server"
       echo "  -h, --help                  display this help and exit"
       echo "  -v, --version               display version information and exit"

       # Return success:
       exit 0
     ;;
     "-v" | "--version"  | "version")
       # Display version information:
       echo "BlazeBlogger Submit Tool $VERSION"
       echo
       echo "Copyright (C) 2009 SKooDA(http://www.skooda.org)"
       echo "This program is free software; see the source for copying conditions. It is"
       echo "distributed in the hope  that it will be useful,  but WITHOUT ANY WARRANTY;"
       echo "without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PAR-"
       echo "TICULAR PURPOSE."

       # Return success:
       exit 0
     ;;

     *)
         # Incorect parameters
         echo "$NAME: Invalid option: $1" 1>&2
         echo "Try \`$NAME --help' for more information." 1>&2

         # Return fail:
         exit 1
     ;;
  esac
  # Read next parameter
  shift
done

## Read configuration from the config file
# Grab only SUBMIT section
FILE=$(cat $CONFIG_FILE)
START=$(echo "$FILE"|grep -n "\[submit\]"|cut -d: -f1|line)
LENGHT=$(echo "$FILE"|wc -l)
FILE=$(echo "$FILE"|tail -n$(($LENGHT - $START)))
END=$(echo "$FILE"|grep -n "\["|cut -d: -f1|line)
# Test if the submit section is on the end of file
if [ -z $END ]; then END=$(($LENGHT + 1)); else END=$(($END - 1)); fi
FILE=$(echo "$FILE"|head -n${END} )
# Remove the comments
FILE=$(echo "$FILE"|grep -v '^ *#'|cut -d'#' -f1)

## Parse configuration
LENGHT=$(echo "$FILE"|wc -l)
for I in $(seq $LENGHT); do
  LINE=$(echo "$FILE"|tail -n$(($LENGHT - $I + 1))|head -n1)
  # Remove whitespaces
  LINE=$( echo "$LINE" | awk '$1=$1' OFS="" )
  KEY=$(echo "$LINE"|cut -d"=" -f1)
  VALUE=$(echo "$LINE"|cut -d"=" -f2)

  # Parsing information
  case "$KEY" in
    "user" ) USER_NAME=$VALUE;;
    "password" ) USER_PASSWORD=$VALUE;;
    "remote_directory" ) REMOTE_DIRECTORY=$VALUE;;
    "blog_directory" ) BLOG_DIRECTORY=$VALUE;;
    "host" ) SERVER_HOST=$VALUE;;
    "port" ) SERVER_PORT=$VALUE;;
    "method" ) ;; ## Prepared for future
    * ) echo "Warning: Unexpected configuration directive \"$KEY\"!" 1>&2
  esac
done

## Send data
echo "Sending data: $BLOG_DIRECTORY ---> $USER_NAME:$USER_PASSWORD@$SERVER_HOST:$SERVER_PORT$REMOTE_DIRECTORY";

lftp $SERVER_HOST -u $USER_NAME,"$USER_PASSWORD" -p $SERVER_PORT -e "mirror -R $BLOG_DIRECTORY $REMOTE_DIRECTORY; exit;" exit;
