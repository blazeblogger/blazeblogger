#!/usr/bin/env perl

# blaze-init - creates or recovers a BlazeBlogger repository
# Copyright (C) 2008-2011 Jaromir Hradilek

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

use strict;
use warnings;
use File::Basename;
use File::Path;
use File::Spec::Functions;
use Getopt::Long;

# General script information:
use constant NAME    => basename($0, '.pl');        # Script name.
use constant VERSION => '1.2.0';                    # Script version.

# General script settings:
our $blogdir = '.';                                 # Repository location.
our $force   = 0;                                   # Force files rewrite?
our $verbose = 1;                                   # Verbosity level.

# Set up the __WARN__ signal handler:
$SIG{__WARN__} = sub {
  print STDERR NAME . ": " . (shift);
};

# Display an error message, and terminate the script:
sub exit_with_error {
  my $message      = shift || 'An error has occurred.';
  my $return_value = shift || 1;

  # Display the error message:
  print STDERR NAME . ": $message\n";

  # Terminate the script:
  exit $return_value;
}

# Display a warning message:
sub display_warning {
  my $message = shift || 'A warning was requested.';

  # Display the warning message:
  print STDERR "$message\n";

  # Return success:
  return 1;
}

# Display usage information:
sub display_help {
  my $NAME = NAME;

  # Display the usage:
  print << "END_HELP";
Usage: $NAME [-fqV] [-b DIRECTORY]
       $NAME -h|-v

  -b, --blogdir DIRECTORY     specify a directory in which the BlazeBlogger
                              repository is to be placed
  -f, --force                 revert existing configuration, theme, and
                              language files to their initial state
  -q, --quiet                 do not display unnecessary messages
  -V, --verbose               display all messages, including a list of
                              created files
  -h, --help                  display this help and exit
  -v, --version               display version information and exit
END_HELP

  # Return success:
  return 1;
}

# Display version information:
sub display_version {
  my ($NAME, $VERSION) = (NAME, VERSION);

  # Display the version:
  print << "END_VERSION";
$NAME $VERSION

Copyright (C) 2008-2011 Jaromir Hradilek
This program is free software; see the source for copying conditions. It is
distributed in the hope  that it will be useful,  but WITHOUT ANY WARRANTY;
without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PAR-
TICULAR PURPOSE.
END_VERSION

  # Return success:
  return 1;
}

# Create the default configuration file:
sub create_conf {
  # Prepare the configuration file name:
  my $file = catfile($blogdir, '.blaze', 'config');

  # Unless explicitly requested, do not overwrite the existing file:
  return 1 if (-e $file && !$force);

  # Open the file for writing:
  open(FILE, ">$file") or return 0;

  # Write the default configuration to the file:
  print FILE << 'END_CONFIG';
## This is the default BlazeBlogger configuration file. The recommended way
## to set up your blog is to leave  this file intact,  and use blaze-config
## instead.  However, if you prefer to configure BlazeBlogger by hand, read
## the instructions below,  and replace the value on the right of the equal
## sign.

## General blog settings. Available options are:
##
##   title         A title of your blog.
##   subtitle      A subtitle of your blog.
##   description   A brief description of your blog.
##   keywords      A comma-separated list of keywords.
##   theme         A theme for your blog. It must point to an existing file
##                 in the .blaze/theme/ directory.
##   style         A style sheet for your blog.  It must point to  an exis-
##                 ting file in the .blaze/style/ directory.
##   lang          A translation of your blog. It must point to an existing
##                 file in the .blaze/lang/ directory.
##   posts         A number of blog posts to be listed on a single page.
##
[blog]
title=Blog Title
subtitle=blog subtitle
description=blog description
keywords=blog keywords
theme=default.html
style=default.css
lang=en_US
posts=10

## Color settings. Available options are:
##
##   list          A boolean  to enable (true) or disable (false) colors in
##                 the blaze-list output.
##   log           A boolean  to enable (true) or disable (false) colors in
##                 the blaze-log output.
##
[color]
list=false
log=false

## Advanced BlazeBlogger settings. Available options are:
##
##   doctype       A document type.  It can be  either  html  for HTML,  or
##                 xhtml for the XHTML standard.
##   extension     A file extension.
##   encoding      A character encoding. It has to be in a form that is re-
##                 cognized by W3C standards.
##   editor        An external  text  editor.  When  supplied, this  option
##                 overrides the system-wide settings.
##   processor     An external application  to be used to process newly ad-
##                 ded or edited blog posts and pages. You must supply %in%
##                 and %out% in place of an input and output file name res-
##                 pectively.
##
[core]
doctype=html
extension=html
encoding=UTF-8
editor=
processor=

## RSS feed settings. Available options are:
##
##  baseurl        A URL of your blog, for example "http://example.com/".
##  posts          A number of blog posts to be listed in the feed.
##  fullposts      A boolean to enable (true)  or disable (false) inclusion
##                 of the whole content of a blog post in the feed.
##
[feed]
baseurl=
posts=10
fullposts=false

## Advanced post settings. Available options are:
##
##  author         A location of a blog post author name.  It can either be
##                 placed above the post (top),  below it (bottom),  or no-
##                 where on the page (none).
##  date           A location  of a date  of publishing.  It can  either be
##                 placed above the post (top),  below it (bottom),  or no-
##                 where on the page (none).
##  tags           A location of post tags. They can either be placed above
##                 the post (top),  below it (bottom),  or  nowhere  on the
##                 page (none).
##
[post]
author=top
date=top
tags=top

## User settings. Available options are:
##
##   name          Your full name to be used in the copyright notice,  and
##                 as the default post author.
##   nickname      Your nickname  to be used  as the  default  post author.
##                 When supplied, this option overrides the  above setting.
##   email         Your email address.
##
[user]
name=admin
nickname=
email=admin@localhost

END_CONFIG

  # Close the file:
  close(FILE);

  # Report success:
  print "Created $file\n" if $verbose > 1;

  # Return success:
  return 1;
}

# Create the default theme file:
sub create_theme {
  # Prepare the theme file name:
  my $file = catfile($blogdir, '.blaze', 'theme', 'default.html');

  # Unless explicitly requested, do not overwrite the existing file:
  return 1 if (-e $file && !$force);

  # Open the file for writing:
  open(FILE, ">$file") or return 0;

  # Write the default theme to the file:
  print FILE << 'END_THEME';
<!-- START-DOCUMENT -->
<head>
  <!-- content-type -->
  <!-- generator -->
  <!-- copyright -->
  <!-- date -->
  <!-- description -->
  <!-- keywords -->
  <!-- stylesheet -->
  <!-- feed -->
  <title><!-- page-title --></title>
</head>

<body>

<div id="wrapper">
  <div id="shadow">
    <div id="heading">
      <h1><a href="%home%" rel="index"><!-- title --></a></h1>
      <!-- subtitle -->
    </div>

    <div id="menu">
      <ul>
<li><a href="%home%" rel="index">Home</a></li>
<!-- pages -->
      </ul>
    </div>
  </div>

  <div id="content">
<!-- content -->
  </div>

  <div id="sidebar">
    <h2>Categories</h2>
    <ul>
<!-- tags -->
    </ul>

    <h2>Archive</h2>
    <ul>
<!-- archive -->
    </ul>

    <h2>Links</h2>
    <ul>
<li><a href="http://blaze.blackened.cz">BlazeBlogger</a></li>
    </ul>
  </div>

  <div id="footer">
    Copyright &copy; <!-- year --> <!-- name -->.
    Powered by <a href="http://blaze.blackened.cz/">BlazeBlogger</a>.
  </div>
</div>

</body>
<!-- END-DOCUMENT -->
END_THEME

  # Close the file:
  close(FILE);

  # Report success:
  print "Created $file\n" if $verbose > 1;

  # Return success:
  return 1;
}

# Create the default style sheet:
sub create_style {
  # Prepare the style sheet file name:
  my $file = catfile($blogdir, '.blaze', 'style', 'default.css');

  # Unless explicitly requested, do not overwrite the existing file:
  return 1 if (-e $file && !$force);

  # Open the file for writing:
  open(FILE, ">$file") or return 0;

  # Write the default style style sheet to the file:
  print FILE << 'END_STYLE';
/* default.css, the default theme for BlazeBlogger
 * Copyright (C) 2009, 2010 Jaromir Hradilek
 *
 * This program is free software:  you can redistribute it and/or modify it
 * under  the terms of the  GNU General Public License  as published by the
 * Free Software Foundation, version 3 of the License.
 *
 * This program  is  distributed  in the hope  that it will  be useful, but
 * WITHOUT  ANY WARRANTY;  without  even the implied warranty of MERCHANTA-
 * BILITY or  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 * License for more details.
 *
 * You should have received a copy of the  GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

body {
  margin: 0px 0px 10px 0px;
  padding: 0px;
  color: #000000;
  background-color: #e7e7e7;
  font-family: "DejaVu Sans", Arial, sans;
  font-size: small;
}

#wrapper {
  margin: auto;
  padding: 0px;
  width: 768px;
  border-left: 1px solid #d6d6d6;
  border-right: 1px solid #d6d6d6;
  border-bottom: 1px solid #d6d6d6;
  background-color: #ffffff;
}

#shadow {
  margin: 0px;
  padding: 0px;
  border-bottom: 2px solid #e7e7e7;
}

#heading {
  width: 728px;
  padding: 20px;
  background-color: #2e2e2e;
  border-bottom: 2px solid #2a2a2a;
  border-top: 2px solid #323232;
  color: #d0d0d0;
}

#heading a, #heading h1 {
  margin: 0px;
  text-decoration: none;
  color: #ffffff;
}

#heading a:hover {
  text-decoration: underline;
}

#menu {
  width: 768px;
  border-top: 1px solid #5f5f5f;
  border-bottom: 1px solid #3d3d3d;
  background-color: #4e4e4e;
}

#menu ul {
  padding: 4px 15px 4px 15px;
  margin: 0px;
  list-style-type: none;
}

#menu li {
  display: inline;
  padding: 4px 10px 5px 10px;
  margin: 0px;
}

#menu li:hover {
  background-color: #3d3d3d;
  border-bottom: 2px solid #dddddd;
  border-top: 1px solid #4e4e4e;
}

#menu a {
  color: #ffffff;
  font-size: x-small;
  text-decoration: none;
}

#menu a:hover {
  text-decoration: underline;
}

#content {
  float: left;
  margin: 0px;
  padding: 10px 10px 20px 20px;
  width: 528px;
  text-align: justify;
}

#content h2.post {
  margin-bottom: 0px;
  padding-bottom: 0px;
}

#content .post a {
  text-decoration: none;
  color: #9acd32;
}

#content a {
  text-decoration: none;
  color: #4e9a06;
}

#content a:hover {
  text-decoration: underline;
}

#content .information {
  font-size: x-small;
  color: #4e4e4e;
}

#content .information a {
  color: #4e9a06;
  text-decoration: underline;
}

#content .information a:hover {
  text-decoration: none;
}

#content .post-footer {
  font-size: x-small;
  color: #4e4e4e;
  padding: 4px 2px 4px 2px;
  border-top: 1px solid #e7e7e7;
  border-bottom: 1px solid #e7e7e7;
  background-color: #f8f8f8;
}

#content .post-footer a {
  color: #4e9a06;
  text-decoration: underline;
}

#content .post-footer a:hover {
  text-decoration: none;
}

#content .section {
  text-align: right;
  font-size: x-small;
  color: #808080;
}

#content .previous {
  padding: 10px 0px 10px 0px;
  float: left;
}

#content .next {
  padding: 10px 0px 10px 0px;
  float: right;
}

#sidebar {
  float: right;
  margin: 0px;
  padding: 10px 20px 20px 0px;
  width: 180px;
}

#sidebar h2 {
  font-size: small;
}

#sidebar ul {
  list-style-type: none;
  padding-left: 1em;
  margin-left: 0px;
}

#sidebar a {
  text-decoration: underline;
  color: #4e9a06;
}

#sidebar a:hover {
  text-decoration: none;
}

#footer {
  clear: both;
  margin: 0px;
  padding: 10px 20px 10px 20px;
  border-top: 2px solid #e7e7e7;
  border-bottom: 1px solid #3d3d3d;
  background-color: #4e4e4e;
  text-align: right;
  font-size: x-small;
  color: #d0d0d0;
}

#footer a {
  color: #ffffff;
  text-decoration: none;
}

#footer a:hover {
  text-decoration: underline;
}
END_STYLE

  # Close the file:
  close(FILE);

  # Report success:
  print "Created $file\n" if $verbose > 1;

  # Return success:
  return 1;
}

# Create the default localization file:
sub create_lang {
  # Prepare the localization file name:
  my $file = catfile($blogdir, '.blaze', 'lang', 'en_US');

  # Unless explicitly requested, do not overwrite the existing file:
  return 1 if (-e $file && !$force);

  # Open the file for writing:
  open(FILE, ">$file") or return 0;

  # Write the default localization to the file:
  print FILE << 'END_LANG';
[lang]
archive=Archive for
tags=Posts tagged as
taglist=List of tags
previous=&laquo; Previous
next=Next &raquo;
more=Read more &raquo;
postedon=
postedby=by
taggedas=tagged as
january=January
february=February
march=March
april=April
may=May
june=June
july=July
august=August
september=September
october=October
november=November
december=December
END_LANG

  # Close the file:
  close(FILE);

  # Report success:
  print "Created $file\n" if $verbose > 1;

  # Return success:
  return 1;
}

# Add the event to the log:
sub add_to_log {
  my $text = shift || 'Something miraculous has just happened!';

  # Prepare the log file name:
  my $file = catfile($blogdir, '.blaze', 'log');

  # Open the log file for appending:
  open(LOG, ">>$file") or return 0;

  # Write the event to the file:
  print LOG localtime(time) . " - $text\n";

  # Close the file:
  close(LOG);

  # Return success:
  return 1;
}

# Set up the option parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Process command line options:
GetOptions(
  'help|h'        => sub { display_help();    exit 0; },
  'version|v'     => sub { display_version(); exit 0; },
  'force|f'       => sub { $force   = 1;     },
  'quiet|q'       => sub { $verbose = 0;     },
  'verbose|V'     => sub { $verbose = 2;     },
  'blogdir|b=s'   => sub { $blogdir = $_[1]; },
);

# Detect superfluous options:
exit_with_error("Invalid option `$ARGV[0]'.", 22) if (scalar(@ARGV) != 0);

# Decide whether to create or recover the repository:
my $action = (-d catdir($blogdir, '.blaze')) ? 'Recovered' : 'Created';

# Create the directory tree:
eval {
  mkpath(
    [
      catdir($blogdir, '.blaze', 'lang'),
      catdir($blogdir, '.blaze', 'theme'),
      catdir($blogdir, '.blaze', 'style'),
      catdir($blogdir, '.blaze', 'pages', 'head'),
      catdir($blogdir, '.blaze', 'pages', 'body'),
      catdir($blogdir, '.blaze', 'pages', 'raw'),
      catdir($blogdir, '.blaze', 'posts', 'head'),
      catdir($blogdir, '.blaze', 'posts', 'body'),
      catdir($blogdir, '.blaze', 'posts', 'raw'),
    ],
    0 # Do not be verbose.
  );
};

# Make sure the directory tree creation was successful:
exit_with_error("Creating directory tree: $@", 13) if $@;

# Create the default configuration file:
create_conf()
  or display_warning("Unable to create the default configuration file.");

# Create the default theme:
create_theme()
  or display_warning("Unable to create the default theme.");

# Create the default style sheet:
create_style()
  or display_warning("Unable to create the default style sheet.");

# Create the default localization:
create_lang()
  or display_warning("Unable to create the default localization.");

# Create the default log file:
add_to_log("$action a BlazeBlogger repository.")
  or display_warning("Unable to log the event.");

# Report success:
print "$action a BlazeBlogger repository in " .
      catdir($blogdir, '.blaze') . ".\n" if $verbose;

# Return success:
exit 0;

__END__

=head1 NAME

blaze-init - creates or recovers a BlazeBlogger repository

=head1 SYNOPSIS

B<blaze-init> [B<-fqV>] [B<-b> I<directory>]

B<blaze-init> B<-h>|B<-v>

=head1 DESCRIPTION

B<blaze-init> either creates a fresh new BlazeBlogger repository, or
recovers an existing one in case it is corrupted. Optionally, it can also
revert a configuration and default templates to their original state,
leaving all user data (that is, both blog posts and pages) intact.

=head1 OPTIONS

=over

=item B<-b> I<directory>, B<--blogdir> I<directory>

Allows you to specify a I<directory> in which the BlazeBlogger repository
is to be blaced. The default option is a current working directory.

=item B<-f>, B<--force>

Reverts existing configuration, theme, and language files to their initial
state. By default, these files are kept intact.

=item B<-q>, B<--quiet>

Disables displaying of unnecessary messages.

=item B<-V>, B<--verbose>

Enables displaying of all messages, including a list of created files.

=item B<-h>, B<--help>

Displays usage information and exits.

=item B<-v>, B<--version>

Displays version information and exits.

=back

=head1 EXAMPLE USAGE

Create a new blog in a current directory:

  ~]$ blaze-init
  Created a BlazeBlogger repository in .blaze.

Create a new blog in ~/public_html:

  ~]$ blaze-init -b ~/public_html
  Created a BlazeBlogger repository in /home/joe/public_html/.blaze.

Revert a configuration file and default templates to their initial state:

  ~]$ blaze-init -f
  Recovered a BlazeBlogger repository in .blaze.

Or if you want to see what files have been reverted:

  ~]$ blaze-init -fV
  Created .blaze/config
  Created .blaze/theme/default.html
  Created .blaze/style/default.css
  Created .blaze/lang/en_US
  Recovered a BlazeBlogger repository in .blaze.

=head1 SEE ALSO

B<blaze-config>(1), B<blaze-add>(1)

=head1 BUGS

To report a bug or to send a patch, please, add a new issue to the bug
tracker at <http://code.google.com/p/blazeblogger/issues/>, or visit the
discussion group at <http://groups.google.com/group/blazeblogger/>.

=head1 COPYRIGHT

Copyright (C) 2008-2011 Jaromir Hradilek

This program is free software; see the source for copying conditions. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
