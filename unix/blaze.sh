#!/bin/sh

# blaze, a command wrapper for BlazeBlogger
# Copyright (C) 2009 Jaromir Hradilek

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
VERSION='1.0.0'

# Get user supplied command (if any):
COMMAND=$1

# Shift command-line options:
shift

# Parse command and perform appropriate action:
case "$COMMAND" in
  "add" | "log" | "edit" | "init" | "list" | "make" | "config" | "remove")
    # Run selected core utility:
    exec blaze-$COMMAND "$@"
    ;;
  "submit" | "gallery")
    # Make sure that blazeblogger-extras are installed:
    if ! which blaze-$COMMAND > /dev/null 2>&1; then
      # Report failure:
      echo "$NAME: Unable to find \`blaze-$COMMAND'." >&2
      echo "Are blazeblogger-extras installed?" >&2

      # Return failure:
      exit 127
    fi

    # Run selected extra utility:
    exec blaze-$COMMAND "$@"
    ;;
  "-h" | "--help" | "help")
    # Get user supplied command (if any):
    COMMAND=$1

    # Parse command and display its usage:
    case "$COMMAND" in
      "add" | "log" | "edit" | "init" | "list" | "make" | "config" | "remove")
        # Display core utility usage information:
        exec blaze-$COMMAND --help
        ;;
      "submit" | "gallery")
        # Make sure that blazeblogger-extras are installed:
        if ! which blaze-$COMMAND > /dev/null 2>&1; then
          # Report failure:
          echo "$NAME: Unable to find \`blaze-$COMMAND'." >&2
          echo "Are blazeblogger-extras installed?" >&2

          # Return failure:
          exit 127
        fi

        # Display extra utility usage information:
        exec blaze-$COMMAND --help
        ;;
      *)
        # Display list of available commands:
        echo "Usage: $NAME COMMAND [OPTION...]"
        echo
        echo "Basic commands:"
        echo "  init     Create or recover a BlazeBlogger repository."
        echo "  config   Display or set the BlazeBlogger repository options."
        echo "  add      Add new post or a page to the BlazeBlogger repository."
        echo "  edit     Edit a post or page in the BlazeBlogger repository."
        echo "  remove   Remove a post or page from the BlazeBlogger repository."
        echo "  list     Browse the content of the BlazeBlogger repository."
        echo "  make     Generate static content from the BlazeBlogger repository."
        echo "  log      Display the BlazeBlogger repository log."
        echo
        echo "Extra commands:"
        echo "  submit   Upload the static content to the remote server."
        echo "  gallery  Create a simple image gallery."
        echo
        echo "Additional commands:"
        echo "  help [COMMAND]  Display usage information (on specified command)."
        echo "  man [COMMAND]   Display manual page (on specified command)."
        echo "  version         Display version information."
        echo
        echo "Type \`$NAME help COMMAND' for command details."

        # Return success:
        exit 0
        ;;
    esac
    ;;
  "man")
    # Get user supplied command (if any):
    COMMAND=$1

    # Parse command and display its manual page:
    case "$COMMAND" in
      "add" | "log" | "edit" | "init" | "list" | "make" | "config" | "remove")
        # Display core utility usage information:
        exec man blaze-$COMMAND
        ;;
      "submit" | "gallery")
        # Display extra utility usage information:
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
    echo "Copyright (C) 2008, 2009 Jaromir Hradilek"
    echo "This program is free software; see the source for copying conditions. It is"
    echo "distributed in the hope  that it will be useful,  but WITHOUT ANY WARRANTY;"
    echo "without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PAR-"
    echo "TICULAR PURPOSE."

    # Return success:
    exit 0
    ;;
  *)
    # Respond to wrong/missing command:
    echo "Usage: $NAME COMMAND [OPTION...]" >&2
    echo "Try \`$NAME help' for more information." >&2

    # Return failure:
    exit 22
    ;;
esac
