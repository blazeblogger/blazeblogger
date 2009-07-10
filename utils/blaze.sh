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
VERSION='0.8.1'

# Get user supplied command (if any):
COMMAND=$1

# Shift command-line options:
shift

# Parse command and perform appropriate action:
case "$COMMAND" in
  "add")    exec blaze-add    "$@";;
  "log")    exec blaze-log    "$@";;
  "edit")   exec blaze-edit   "$@";;
  "init")   exec blaze-init   "$@";;
  "list")   exec blaze-list   "$@";;
  "make")   exec blaze-make   "$@";;
  "config") exec blaze-config "$@";;
  "remove") exec blaze-remove "$@";;
  "-v" | "--version" | "version")
    # Display version information:
    echo "$NAME $VERSION"
    echo
    echo "Copyright (C) 2009 Jaromir Hradilek"
    echo "This program is free software; see the source for copying conditions. It is"
    echo "distributed in the hope  that it will be useful,  but WITHOUT ANY WARRANTY;"
    echo "without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PAR-"
    echo "TICULAR PURPOSE."

    # Return success:
    exit 0
    ;;
  "-h" | "--help" | "help")
    # Display usage information:
    echo "Usage: $NAME command [option...]"
    echo
    echo "Available commands:"
    echo "  init    Create or recover a BlazeBlogger repository."
    echo "  config  Display or set the BlazeBlogger repository options."
    echo "  add     Add new post or a page to the BlazeBlogger repository."
    echo "  edit    Edit a post or page in the BlazeBlogger repository."
    echo "  remove  Remove a post or page from the BlazeBlogger repository."
    echo "  list    Browse the content of the BlazeBlogger repository."
    echo "  make    Generate static content from the BlazeBlogger repository."
    echo "  log     Display the BlazeBlogger repository log."
    echo
    echo "Type \`$NAME command --help' for command details."

    # Return success:
    exit 0
    ;;
  *)
    # Respond to wrong/missing command:
    echo "Usage: $NAME command [options]" >&2
    echo "Try \`$NAME help' for more information." >&2

    # Return failure:
    exit 22
esac