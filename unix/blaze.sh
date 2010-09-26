#!/bin/sh

# blaze, a command wrapper for BlazeBlogger
# Copyright (C) 2009-2010 Jaromir Hradilek

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
VERSION='1.1.0'

# Get the command, if any:
COMMAND=$1

# Shift command line options:
shift

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
        echo "  init     Creates or recovers a BlazeBlogger repository."
        echo "  config   Displays or sets BlazeBlogger configuration options."
        echo "  add      Adds a blog post or a page to the BlazeBlogger repository."
        echo "  edit     Edits a blog post or a page in the BlazeBlogger repository."
        echo "  remove   Removes a blog post or a page from the BlazeBlogger repository."
        echo "  list     Lists blog posts or pages in the BlazeBlogger repository."
        echo "  make     Generates a blog from the BlazeBlogger repository."
        echo "  log      Displays the BlazeBlogger repository log."
        echo
        echo "Additional commands:"
        echo "  help [COMMAND]  Displays usage information on the selected command."
        echo "  man [COMMAND]   Displays a man page for the selected command."
        echo "  version         Displays version information."
        echo
        echo "Type \`$NAME help COMMAND' for command details."

        # Return success:
        exit 0
        ;;
    esac
    ;;
  "man")
    # Get the command, if any:
    COMMAND=$1

    # Parse the command, and display its man page:
    case "$COMMAND" in
      "add" | "log" | "edit" | "init" | "list" | "make" | "config" | "remove")
        # Display the utility usage information:
        exec man blaze-$COMMAND
        ;;
      *)
        # Display general manual page:
        exec man blazeblogger
        ;;
    esac
    ;;
  "-v" | "--version" | "version")
    # Display version information:
    echo "BlazeBlogger $VERSION"
    echo
    echo "Copyright (C) 2008-2010 Jaromir Hradilek"
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
