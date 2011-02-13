#!/bin/sh

# blaze, a command wrapper for BlazeBlogger
# Copyright (C) 2009-2011 Jaromir Hradilek

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
VERSION='1.1.2'

# Get the command if any, and shift command line options:
COMMAND=$1
shift

# Substitute aliases:
case "$COMMAND" in
  "ed")         COMMAND="edit";;
  "in")         COMMAND="init";;
  "ls")         COMMAND="list";;
  "mk")         COMMAND="make";;
  "rm" | "del") COMMAND="remove";;
  "cf" | "cfg") COMMAND="config";;
  "vs" | "ver") COMMAND="version";;
esac

# Parse the command and perform an appropriate action:
case "$COMMAND" in
  "add" | "log" | "edit" | "init" | "list" | "make" | "config" | "remove")
    # Run the selected utility:
    exec blaze-$COMMAND "$@"
    ;;
  "-h" | "--help" | "help")
    # Get the command, if any:
    COMMAND=$1

    # Parse the command, and display its usage:
    case "$COMMAND" in
      "add" | "log" | "edit" | "init" | "list" | "make" | "config" | "remove")
        # Display the utility usage information:
        exec blaze-$COMMAND --help
        ;;
      *)
        # Display the list of available commands:
        echo "Usage: $NAME COMMAND [OPTION...]"
        echo
        echo "Basic commands:"
        echo "  init     create or recover a BlazeBlogger repository"
        echo "  config   display or set BlazeBlogger configuration options"
        echo "  add      add a blog post or page to a BlazeBlogger repository"
        echo "  edit     edit a blog post or page in a BlazeBlogger repository"
        echo "  remove   remove a blog post or page from a BlazeBlogger repository"
        echo "  list     list blog posts or pages in a BlazeBlogger repository"
        echo "  make     generate a blog from a BlazeBlogger repository"
        echo "  log      display a BlazeBlogger repository log"
        echo
        echo "Additional commands:"
        echo "  help [COMMAND]  display usage information on the selected command"
        echo "  man [COMMAND]   display a manual page for the selected command"
        echo "  version         display version information"
        echo
        echo "Command aliases:"
        echo "  in       init"
        echo "  ed       edit"
        echo "  ls       list"
        echo "  mk       make"
        echo "  cf, cfg  config"
        echo "  rm, del  remove"
        echo "  vs, ver  version"

        # Return success:
        exit 0
        ;;
    esac
    ;;
  "man")
    # Get the command, if any:
    COMMAND=$1

    # Parse the command, and display its manual page:
    case "$COMMAND" in
      "add" | "log" | "edit" | "init" | "list" | "make" | "config" | "remove")
        # Display the utility usage information:
        exec man blaze-$COMMAND
        ;;
      *)
        # Display a general manual page:
        exec man blaze
        ;;
    esac
    ;;
  "-v" | "--version" | "version")
    # Display version information:
    echo "BlazeBlogger $VERSION"
    echo
    echo "Copyright (C) 2008-2011 Jaromir Hradilek"
    echo "This program is free software; see the source for copying conditions. It is"
    echo "distributed in the hope  that it will be useful,  but WITHOUT ANY WARRANTY;"
    echo "without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PAR-"
    echo "TICULAR PURPOSE."

    # Return success:
    exit 0
    ;;
  *)
    # Respond to a wrong or missing command:
    echo "Usage: $NAME COMMAND [OPTION...]" >&2
    echo "Try \`$NAME help' for more information." >&2

    # Return failure:
    exit 22
    ;;
esac
