#!/usr/bin/env perl

# blaze-init, create or recover a BlazeBlogger repository
# Copyright (C) 2008, 2009 Jaromir Hradilek

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
use Text::Wrap;
use File::Basename;
use File::Spec::Functions;
use Getopt::Long;

# General script information:
use constant NAME    => basename($0, '.pl');        # Script name.
use constant VERSION => '0.0.1';                    # Script version.

# General script settings:
our $blogdir = '.';                                 # Repository location.
our $verbose = 1;                                   # Verbosity level.

# Set up the __WARN__ signal handler:
$SIG{__WARN__} = sub {
  print STDERR NAME . ": " . (shift);
};

# Display given message and terminate the script:
sub exit_with_error {
  my $message      = shift || 'An unspecified error has occurred.';
  my $return_value = shift || 1;

  print STDERR NAME . ": $message\n";
  exit $return_value;
}

# Display usage information:
sub display_help {
  my $NAME = NAME;

  # Print the message to the STDOUT:
  print << "END_HELP";
Usage: $NAME [-qV] [-b directory]
       $NAME -h | -v

  -b, --blogdir directory     specify the directory where the BlazeBlogger
                              repository is to be placed
  -q, --quiet                 avoid displaying unnecessary messages
  -V, --verbose               display all messages; the default option
  -h, --help                  display this help and exit
  -v, --version               display version information and exit
END_HELP

  # Return success:
  return 1;
}

# Display version information:
sub display_version {
  my ($NAME, $VERSION) = (NAME, VERSION);

  # Print the message to the STDOUT:
  print << "END_VERSION";
$NAME $VERSION

Copyright (C) 2008, 2009 Jaromir Hradilek
This program is free software; see the source for copying conditions. It is
distributed in the hope  that it will be useful,  but WITHOUT ANY WARRANTY;
without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PAR-
TICULAR PURPOSE.
END_VERSION

  # Return success:
  return 1;
}

# Create given directories:
sub make_directories {
  my $dirs = shift || die 'Missing argument';
  my $mask = shift || 0777;

  # Process each directory:
  foreach my $dir (sort @$dirs) {
    # Skip existing directories:
    unless (-d $dir) {
      # Create the directory:
      mkdir($dir, $mask) || exit_with_error("Creating `$dir': $!", 13);
    }
  }

  # Return success:
  return 1;
}

# Write string to the given file:
sub write_to_file {
  my $file = shift || die 'Missing argument';
  my $text = shift || '';

  # Open the file for writing:
  open(FILE, ">$file") or return 0;

  # Write given string to the file::
  print FILE $text;

  # Close the file:
  close(FILE);

  # Return success:
  return 1;
}

# Add given string to the log file
sub add_to_log {
  my $text = shift || 'Something miraculous has just happened!';
  my $file = catfile($blogdir, '.blaze', 'log');

  # Open the log file for appending:
  open(LOG, ">>$file") or return 0;

  # Write to the log file: 
  print LOG "Date: " . localtime(time) . "\n\n";
  print LOG wrap('    ', '    ', $text);
  print LOG "\n\n";

  # Close the file:
  close(LOG);

  # Return success:
  return 1;
}

# Set up the options parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Process command-line options:
GetOptions(
  'help|h'        => sub { display_help();    exit 0; },
  'version|v'     => sub { display_version(); exit 0; },
  'quiet|q'       => sub { $verbose = 0;     },
  'verbose|V'     => sub { $verbose = 1;     },
  'blogdir|b=s'   => sub { $blogdir = $_[1]; },
);

# Detect superfluous options:
exit_with_error("Invalid option `$ARGV[0]'.", 22) if (scalar(@ARGV) != 0);

# Create the directory tree:
make_directories [
  catdir($blogdir, '.blaze'),                       # Root directory.
  catdir($blogdir, '.blaze', 'lang'),               # Translations.
  catdir($blogdir, '.blaze', 'theme'),              # Templates.
  catdir($blogdir, '.blaze', 'style'),              # Stylesheets.
  catdir($blogdir, '.blaze', 'pages'),              # Static pages.
  catdir($blogdir, '.blaze', 'pages', 'head'),      # Pages' headers.
  catdir($blogdir, '.blaze', 'pages', 'body'),      # Pages' bodies.
  catdir($blogdir, '.blaze', 'posts'),              # Blog posts.
  catdir($blogdir, '.blaze', 'posts', 'head'),      # Posts' headers.
  catdir($blogdir, '.blaze', 'posts', 'body'),      # Posts' bodies.
];

# Create the default configuration file:
write_to_file(catfile($blogdir, '.blaze', 'config'), << 'END_CONFIG');
## This is the default BlazeBlogger configuration file. The recommended way
## to set up your blog is to leave this file intact and use blaze-config(1)
## instead.  Nevertheless, if you prefer to configure the settings by hand,
## simply uncomment the desired option  (i.e. remove the hash sign from the
## beginning of the line) and replace the value next to the equal sign.

## The following are the blog related settings, having the direct influence
## on the way the whole thing looks. The options are as follows:
##
##   title    - The blog title.
##   subtitle - The blog subtitle, supposedly a brief, single-line descrip-
##              tion of what should the occasional visitor  expect to find.
##   theme    - The blog theme;  the value should point to an existing file
##              in the .blaze/theme directory.
##   style    - The blog style; the value should point to an existing file,
##              either  in  .blaze/style,  or in the  destination directory
##              where the static content is to be placed.
##   lang     - The blog language;  the value  should point to an  existing
##              file in the .blaze/lang directory.
##   posts    - Number of posts to be listed on a single page;  the default
##              value is 10.
##   url      - The blog base url; required for RSS feed only.
##
[blog]
#title=My Blog
#subtitle=yet another blog
#theme=graylines.html
#style=graylines.css
#lang=en_GB
#posts=10
#url=http://127.0.0.1/

## The following are the core settings,  affecting the way the BlazeBlogger
## works. The options are as follows:
##
##   editor    - An external text editor to be used for editing purposes.
##   encoding  - Records  encoding in the form  recognised by the  W3C HTML
##               4.01 standard (e.g. the default UTF-8).
##   extension - File extension for the generated pages.
##
[core]
#editor=vi
#encoding=UTF-8
#extension=html

## The following are the user related settings. The options are as follows:
##
##   user  - User's name  to be used as a default posts' author  and in the
##           copyright notice.
##   email - User's e-mail;  so far,  this option is not actually used any-
##           where.
##
[user]
#name=admin
#email=admin@localhost

END_CONFIG

# Create the default theme file:
write_to_file(catfile($blogdir, '.blaze', 'theme', 'graylines.html'),
              << 'END_THEME');
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
                      "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
  <!-- content-type -->
  <!-- generator -->
  <!-- date -->
  <!-- stylesheet -->
  <!-- rss -->
  <title><!-- title --></title>
</head>

<body>

<div id="wrapper">
  <div id="header">
    <h1><a href="#"><!-- title --></a></h1>
    <!-- subtitle -->
  </div>

  <div id="container">
<!-- content -->
  </div>

  <div class="sidebar">
    <ul>
      <li>
        <h2>Pages</h2>
        <ul>
<!-- pages -->
        </ul>
      </li>

      <li>
        <h2>Tags</h2>
        <ul>
<!-- tags -->
        </ul>
      </li>

      <li>
        <h2>Archive</h2>
        <ul>
<!-- archive -->
        </ul>
      </li>
    </ul>
  </div>

  <div id="footer">
    Copyright &copy; <!-- year --> <!-- name -->.
    Powered by <a href="http://blaze.blackened.cz/">BlazeBlogger</a> using
    the <a href="http://zacklive.com/my-first-wordpress-theme-gray-lines/">
    Gray Lines</a> theme.
  </div>
</div>

</body>
</html>
END_THEME

# Create the default stylesheet:
write_to_file(catfile($blogdir, '.blaze', 'style', 'graylines.css'),
              << "END_STYLE");
/* Gray Lines design (C) 2008 Zack, <http://zacklive.com>
 * BlazeBlogger port (C) 2009 Jaromir Hradilek, <http://blackened.cz/>
 *
 * Released under the GNU GPL, <http://www.gnu.org/licenses/gpl.html>.
 */

body, h1, h2, h3, h4, h5, h6, blockquote, p, form {
	margin: 0;
	padding: 0;
}

body {
	margin: 0;
	font-family: Arial, helvetica, Georgia, Sans-serif;
	font-size: 12px;
	text-align: center;
	vertical-align: top;
	background: #ffffff;
	color: #000000;	
}

h1 {
font-family: Georgia, Sans-serif;
font-size: 32px;
padding-bottom: 5px;
}

a:link, a:visited {
	text-decoration: none;
	color: #336699;
}

a:hover {
	text-decoration: underline;
	color: #ff0000;
}

p {
	padding: 10px 0 0 0;
}

#wrapper {
	margin: 0 auto 0 auto;
	width: 750px;
	text-align: left;
	padding-top: 30px;
	border-top: 5px solid #EEE;
}

#header {
	float: left;
	width: 750px;
	height: 80px;
	border-bottom: 2px solid #EEE;
}

#container {
	float: left;
	width: 500px;
}

h2.post {
  padding-top: 10px;
	font-family: Georgia, Sans-serif;
	font-size: 18px;
}

.information {
	border-top: 1px solid #EEE;
	margin: 5px 0 0 0;
	color: #AAA;
}

.information a {
	color: #AAA;
	text-decoration: underline;
}
.information a:hover {
	text-decoration: none;
}

.section {
  color: #AAA;
  text-align: right;
}

.navigation {
	padding: 10px 0 0 0;
	font-size: 14px;
	font-weight: bold;
	line-height: 18px;
}

.sidebar {
	float: left;
	width: 239px;
	margin: 0 0 0 10px;
	display: inline;
	border-left: 1px solid #EEE;
}

.sidebar ul {
	list-style-type: none;
	margin: 0;
	padding: 0 10px 0 10px;
}

.sidebar ul li {
	padding: 10px 0 10px 0;
}

.sidebar ul li h2 {
	font-family: Georgia, Sans-serif;
	font-size: 14px;
	padding: 0 0 3px 3px;
	border-bottom: 1px solid #EEE;
}

.sidebar ul ul li {
	padding: 0;
	line-height: 24px;
}

#footer {
	clear: both;
	float: left;
	width: 750px;
	line-height: 18px;
	padding: 7px 10px;
	margin: 15px 0;
	background: #EEE;
}
END_STYLE

# Create the default language file:
write_to_file(catfile($blogdir, '.blaze', 'lang', 'en_GB'),
              << "END_LANG");
[lang]
archive=Archive for
tags=Posts tagged as
previous=&laquo; previous
next=next &raquo;
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

# Get the log file name:
my $logfile = catfile($blogdir, '.blaze', 'log');

# Write to / create the log file:
add_to_log("Created/recovered a BlazeBlogger repository.");

# Report success:
print "Created/recovered a BlazeBlogger repository in " .
      catdir($blogdir, '.blaze') . ".\n" if $verbose;

# Return success:
exit 0;

__END__

=head1 NAME

blaze-init - create or recover a BlazeBlogger repository

=head1 SYNOPSIS

B<blaze-init> [B<-qV>] [B<-b> I<directory>]

B<blaze-init> B<-h> | B<-v>

=head1 DESCRIPTION

B<blaze-init>'s job is either to create a fresh new BlazeBlogger
repository, or to recover an existing one, changing the configuration and
template files back to their original state while leaving the user data
(i.e. both static pages and blog posts) untouched.

=head1 OPTIONS

=over

=item B<-b>, B<--blogdir> I<directory>

Specify the I<directory> where the BlazeBlogger repository is to be placed.
The default option is the current working directory.

=item B<-q>, B<--quiet>

Avoid displaying messages that are not necessary.

=item B<-V>, B<--verbose>

Display all messages. This is the default option.

=item B<-h>, B<--help>

Display usage information and exit.

=item B<-v>, B<--version>

Display version information and exit.

=back

=head1 SEE ALSO

B<perl>(1).

=head1 BUGS

To report bugs please visit the appropriate section on the project
homepage: <http://code.google.com/p/blazeblogger/issues/>.

=head1 AUTHOR

Written by Jaromir Hradilek <jhradilek@gmail.com>.

Permission is granted to copy, distribute and/or modify this document under
the terms of the GNU Free Documentation License, Version 1.3 or any later
version published by the Free Software Foundation; with no Invariant
Sections, no Front-Cover Texts, and no Back-Cover Texts.

A copy of the license is included as a file called FDL in the main
directory of the BlazeBlogger source package.

=head1 COPYRIGHT

Copyright (C) 2008, 2009 Jaromir Hradilek

This program is free software; see the source for copying conditions. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut