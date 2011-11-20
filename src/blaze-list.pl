#!/usr/bin/env perl

# blaze-list - lists blog posts or pages in the BlazeBlogger repository
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

use strict;
use warnings;
use File::Basename;
use File::Spec::Functions;
use Getopt::Long;
use Term::ANSIColor;
use Text::Wrap;

# General script information:
use constant NAME    => basename($0, '.pl');        # Script name.
use constant VERSION => '1.2.0';                    # Script version.

# General script settings:
our $blogdir    = '.';                              # Repository location.
our $verbose    = 1;                                # Verbosity level.
our $compact    = 0;                                # Use compact listing?
our $coloured   = undef;                            # Use colors?
our $reverse    = 0;                                # Use reverse order?
our $number     = 0;                                # Listed records limit.

# Global variables:
our $conf       = {};                               # Configuration.

# Command line options:
my  $type       = 'post';                           # Type: post or page.
my  $id         = '';                               # ID search pattern.
my  $title      = '';                               # Title search pattern.
my  $author     = '';                               # Name search pattern.
my  $year       = '';                               # Year search pattern.
my  $month      = '';                               # Month search pattern.
my  $day        = '';                               # Day search pattern.
my  $tag        = '';                               # Tag search pattern.

# Set up the __WARN__ signal handler:
$SIG{__WARN__}  = sub {
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
Usage: $NAME [-cpqrsCPSV] [-b DIRECTORY] [-I ID] [-a AUTHOR]
                  [-t TITLE] [-T TAG] [-d DAY] [-m MONTH] [-y YEAR]
                  [-n NUMBER]
       $NAME -h|-v

  -b, --blogdir DIRECTORY     specify a directory in which the BlazeBlogger
                              repository is placed
  -I, --id ID                 display a single blog post or a page
  -a, --author AUTHOR         list blog posts or pages by selected author
  -t, --title TITLE           list blog posts or pages with matching title
  -T, --tag TAG               list blog posts or pages with matching tag
  -d, --day DAY               list blog posts or pages from selected day
  -m, --month MONTH           list blog posts or pages from selected month
  -y, --year YEAR             list blog posts or pages from selected year
  -n, --number NUMBER         specify a number of blog posts or pages to
                              be listed
  -p, --pages                 list pages
  -P, --posts                 list blog posts
  -S, --stats                 display repository statistics
  -s, --short                 display blog posts or pages on a single line
  -r, --reverse               display blog posts or pages in reverse order
  -c, --color                 enable colored output
  -C, --no-color              disable colored output
  -q, --quiet                 do not display unnecessary messages
  -V, --verbose               display all messages
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

Copyright (C) 2009-2011 Jaromir Hradilek
This program is free software; see the source for copying conditions. It is
distributed in the hope  that it will be useful,  but WITHOUT ANY WARRANTY;
without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PAR-
TICULAR PURPOSE.
END_VERSION

  # Return success:
  return 1;
}

# Translate a date to the YYYY-MM-DD form:
sub date_to_string {
  my @date = localtime(shift);
  return sprintf("%d-%02d-%02d", ($date[5] + 1900), ++$date[4], $date[3]);
}

# Read data from the INI file:
sub read_ini {
  my $file    = shift || die 'Missing argument';

  # Initialize required variables:
  my $hash    = {};
  my $section = 'default';

  # Open the file for reading:
  open(INI, "$file") or return 0;

  # Process each line:
  while (my $line = <INI>) {
    # Parse the line:
    if ($line =~ /^\s*\[([^\]]+)\]\s*$/) {
      # Change the section:
      $section = $1;
    }
    elsif ($line =~ /^\s*(\S+)\s*=\s*(\S.*)$/) {
      # Add the option to the hash:
      $hash->{$section}->{$1} = $2;
    }
  }

  # Close the file:
  close(INI);

  # Return the result:
  return $hash;
}

# Read the content of the configuration file:
sub read_conf {
  # Prepare the file name:
  my $file = catfile($blogdir, '.blaze', 'config');

  # Parse the file:
  if (my $conf = read_ini($file)) {
    # Return the result:
    return $conf;
  }
  else {
    # Report failure:
    display_warning("Unable to read the configuration.");

    # Return an empty configuration:
    return {};
  }
}

# Compose a blog post or a page record:
sub make_record {
  my $type = shift || die 'Missing argument';
  my $id   = shift || die 'Missing argument';
  my ($title, $author, $date, $tags, $url) = @_;

  # Check whether the title is specified:
  if ($title) {
    # Strip trailing spaces:
    $title =~ s/\s+$//;
  }
  else {
    # Assign the default value:
    $title = 'Untitled';

    # Display the appropriate warning:
    display_warning("Missing title in the $type with ID $id. " .
                    "Using `$title' instead.");
  }

  # Check whether the author is specified:
  unless ($author) {
    # Assign the default value:
    $author = $conf->{user}->{name} || 'admin';

    # Report the missing author:
    display_warning("Missing author in the $type with ID $id. " .
                    "Using `$author' instead.");
  }

  # Check whether the date is specified:
  if ($date) {
    # Check whether the format is valid:
    unless ($date =~ /\d{4}-[01]\d-[0-3]\d/) {
      # Use current date instead:
      $date = date_to_string(time);

      # Report the invalid date:
      display_warning("Invalid date in the $type with ID $id. " .
                      "Using `$date' instead.");
    }
  }
  else {
    # Use current date instead:
    $date = date_to_string(time);

    # Report the missing date:
    display_warning("Missing date in the $type with ID $id. " .
                    "Using `$date' instead.");
  }

  # Check whether the tags are specified:
  if ($tags) {
    # Make all tags lower case:
    $tags = lc($tags);

    # Strip superfluous spaces:
    $tags =~ s/\s{2,}/ /g;
    $tags =~ s/\s+$//;

    # Strip trailing commas:
    $tags =~ s/^,+|,+$//g;

    # Remove duplicates:
    my %temp = map { $_, 1 } split(/,+\s*/, $tags);
    $tags = join(', ', sort(keys(%temp)));
  }
  else {
    # Assign the default value:
    $tags = '';
  }

  # Return the composed record:
  return {
    'id'     => $id,
    'title'  => $title,
    'author' => $author,
    'date'   => $date,
    'tags'   => $tags,
    'url'    => $url,
  };
}

# Compare two records:
sub compare_records {
  # Check whether to use reverse order:
  unless ($reverse) {
    return sprintf("%s:%08d", $b->{date}, $b->{id}) cmp
           sprintf("%s:%08d", $a->{date}, $a->{id});
  }
  else {
    return sprintf("%s:%08d", $a->{date}, $a->{id}) cmp
           sprintf("%s:%08d", $b->{date}, $b->{id});
  }
}

# Return a list of blog post or page header records:
sub collect_headers {
  my $type    = shift || 'post';

  # Initialize required variables:
  my @records = ();

  # Prepare the file name:
  my $head    = catdir($blogdir, '.blaze', "${type}s", 'head');

  # Open the headers directory:
  opendir(HEAD, $head) or return @records;

  # Process each file:
  while (my $id = readdir(HEAD)) {
    # Skip both . and ..:
    next if $id =~ /^\.\.?$/;

    # Parse the header data:
    my $data = read_ini(catfile($head, $id)) or next;
    my $date   = $data->{header}->{date};
    my $tags   = $data->{header}->{tags};
    my $author = $data->{header}->{author};
    my $url    = $data->{header}->{url};
    my $title  = $data->{header}->{title};

    # Create the record:
    my $record = make_record($type, $id, $title, $author, $date,
                             $tags, $url);

    # Add the record to the beginning of the list:
    push(@records, $record);
  }

  # Close the directory:
  closedir(HEAD);

  # Return the result:
  return sort compare_records @records;
}

# Display a record:
sub display_record {
  my $record = shift || die 'Missing argument';

  # Check whether to use compact listing:
  unless ($compact) {
    # Check whether colors are enabled:
    unless ($coloured) {
      # Display plain record header:
      print "ID: $record->{id} | Date: $record->{date} | Author: " .
            "$record->{author}\n\n";
    }
    else {
      # Display colored record header:
      print colored ("ID: $record->{id} | Date: $record->{date} | " .
                     "Author: $record->{author}", 'yellow');
      print "\n\n";
    }

    # Display the record body:
    print wrap('    ', ' ' x 11, "Title: $record->{title}\n");
    print wrap('    ', ' ' x 11, "Tags:  $record->{tags}\n")
      if ($type eq 'post');
    print "\n";
  }
  else {
    # Display the short record:
    printf "%-4d | %s | %s\n", $record->{id}, $record->{date},
                               $record->{title};
  }

  # Return success:
  return 1;
}


# Display a list of matching records:
sub display_records {
  my $type    = shift || 'post';
  my $id      = shift || '.*';
  my $author  = shift || '.*';
  my $title   = shift || '';
  my $tag     = shift || '.*';
  my $year    = shift || '....';
  my $month   = shift || '..';
  my $day     = shift || '..';

  # Initialize required variables:
  my $count   = 0;

  # Collect blog post or page headers:
  my @headers = collect_headers($type);

  # Process each header:
  foreach my $record (@headers) {
    # Check whether the record matches the pattern:
    unless ($record->{date}   =~ /^$year-$month-$day$/i &&
            $record->{title}  =~ /^.*$title.*$/i &&
            $record->{tags}   =~ /^(|.*, *)$tag(,.*|)$/i &&
            $record->{author} =~ /^$author$/i &&
            $record->{id}     =~ /^$id$/i) {
      # Skip the record:
      next;
    }

    # Display the record:
    display_record($record);

    # Check whether the limited number of displayed records is requested:
    if ($number > 0) {
      # Increase the displayed records counter:
      $count++;

      # End loop when the counter reaches the limit:
      last if $count == $number;
    }
  }

  # Return success:
  return 1;
}

# Display the repository statistics:
sub display_statistics {
  # Collect the necessary metadata:
  my @pages = collect_headers('page');
  my @posts = collect_headers('post');

  # Get desired values:
  my $pages_count = scalar @pages;
  my $posts_count = scalar @posts;
  my $first_post  = ${posts[$#posts]}->{date} if @posts;
  my $last_post   = ${posts[0]}->{date}       if @posts;

  # Check whether to use compact listing:
  unless ($compact) {
    # Display full results:
    print "Number of pages: $pages_count\n";
    print "Number of posts: $posts_count\n";
    print "Last post date:  $last_post\n"  if @posts;
    print "First post date: $first_post\n" if @posts;
  }
  else {
    # Display shortened results:
    printf("There is a total number of $posts_count blog post%s " .
           "and $pages_count page%s in the repository.\n",
           (($posts_count != 1) ? 's' : ''),
           (($pages_count != 1) ? 's' : ''));
  }

  # Return success:
  return 1;
}

# Set up the option parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Process command line options:
GetOptions(
  'help|h'               => sub { display_help();    exit 0; },
  'version|v'            => sub { display_version(); exit 0; },
  'page|pages|p'         => sub { $type     = 'page';  },
  'post|posts|P'         => sub { $type     = 'post';  },
  'stat|stats|S'         => sub { $type     = 'stats'; },
  'number|n=i'           => sub { $number   = $_[1];   },
  'id|I=i'               => sub { $id       = $_[1];   },
  'author|a=s'           => sub { $author   = $_[1];   },
  'title|t=s'            => sub { $title    = $_[1];   },
  'tags|tag|T=s'         => sub { $tag      = $_[1];   },
  'year|y=i'             => sub { $year     = sprintf("%04d", $_[1]); },
  'month|m=i'            => sub { $month    = sprintf("%02d", $_[1]); },
  'day|d=i'              => sub { $day      = sprintf("%02d", $_[1]); },
  'reverse|r'            => sub { $reverse  = 1;       },
  'short|s'              => sub { $compact  = 1;       },
  'no-color|no-colour|C' => sub { $coloured = 0;       },
  'color|colour|c'       => sub { $coloured = 1;       },
  'quiet|q'              => sub { $verbose  = 0;       },
  'verbose|V'            => sub { $verbose  = 1;       },
  'blogdir|b=s'          => sub { $blogdir  = $_[1];   },
);

# Detect superfluous options:
exit_with_error("Invalid option `$ARGV[0]'.", 22) if (scalar(@ARGV) != 0);

# Check whether the repository is present, no matter how naive this method
# actually is:
exit_with_error("Not a BlazeBlogger repository! Try `blaze-init' first.",1)
  unless (-d catdir($blogdir, '.blaze'));

# Read the configuration file:
$conf = read_conf();

# Unless specified on the command line, read the color setup from the
# configuration file:
unless (defined $coloured) {
  # Read required data from the configuration:
  my $temp  = $conf->{color}->{list} || 'false';

  # Set up the output mode:
  $coloured = ($temp =~ /^(true|auto)\s*$/i) ? 1 : 0;
}

# Check whether to list blog posts or pages, or display repository
# statistics:
unless ($type eq 'stats') {
  # Prepare the list of reserved characters:
  my $reserved  = '[\\\\\^\.\$\|\(\)\[\]\*\+\?\{\}]';

  # Escape all reserved characters:
  $id     =~ s/($reserved)/\\$1/g if $id;
  $author =~ s/($reserved)/\\$1/g if $author;
  $title  =~ s/($reserved)/\\$1/g if $title;
  $tag    =~ s/($reserved)/\\$1/g if $tag;
  $year   =~ s/($reserved)/\\$1/g if $year;
  $month  =~ s/($reserved)/\\$1/g if $month;
  $day    =~ s/($reserved)/\\$1/g if $day;

  # Display the list of matching records:
  display_records($type, $id, $author, $title, $tag, $year, $month, $day)
    or exit_with_error("Cannot read repository data.", 13);
}
else {
  # Display the repository statistics:
  display_statistics()
    or exit_with_error("Cannot read repository data.", 13);
}

# Return success:
exit 0;

__END__

=head1 NAME

blaze-list - lists blog posts or pages in the BlazeBlogger repository

=head1 SYNOPSIS

B<blaze-list> [B<-cpqrsCPSV>] [B<-b> I<directory>] [B<-I> I<id>]
[B<-a> I<author>] [B<-t> I<title>] [B<-T> I<tag>] [B<-d> I<day>]
[B<-m> I<month>] [B<-y> I<year>] [B<-n> I<number>]

B<blaze-list> B<-h>|B<-v>

=head1 DESCRIPTION

B<blaze-list> lists existing blog posts or pages in the BlazeBlogger
repository. Additionally, it can also display basic repository statistics.

=head1 OPTIONS

=over

=item B<-b> I<directory>, B<--blogdir> I<directory>

Allows you to specify a I<directory> in which the BlazeBlogger repository
is placed. The default option is a current working directory.

=item B<-I> I<id>, B<--id> I<id>

Allows you to display a single blog post or a page with the specified
I<id>.

=item B<-a> I<author>, B<--author> I<author>

Allows you to list blog posts or pages by the selected I<author>.

=item B<-t> I<title>, B<--title> I<title>

Allows you to list blog posts or pages with matching I<title>.

=item B<-T> I<tag>, B<--tag> I<tag>

Allows you to list blog posts or pages with matching I<tag>.

=item B<-d> I<day>, B<--day> I<day>

Allows you to list blog posts or pages from the specified I<day> of a
month. The value has to be in the C<DD> form.

=item B<-m> I<month>, B<--month> I<month>

Allows you to list blog posts or pages from the specified I<month>. The
value has to be in the C<MM> form.

=item B<-y> I<year>, B<--year> I<year>

Allows you to list blog posts or pages from the specified I<year>. The
value has to be in the C<YYYY> form.

=item B<-n> I<number>, B<--number> I<number>

Allows you to specify a I<number> of blog posts or pages to be listed.

=item B<-p>, B<--page>

Tells B<blaze-list> to list pages.

=item B<-P>, B<--post>

Tells B<blaze-list> to list blog posts. This is the default option.

=item B<-S>, B<--stats>

Tells B<blaze-list> to display statistics.

=item B<-s>, B<--short>

Tells B<blaze-list> to display each blog post or page information on a
single line.

=item B<-r>, B<--reverse>

Tells B<blaze-list> to display blog posts or pages in reverse order.

=item B<-c>, B<--color>

Enables colored output. When supplied, this option overrides the relevant
configuration option.

=item B<-C>, B<--no-color>

Disables colored output. When supplied, this option overrides the relevant
configuration option.

=item B<-q>, B<--quiet>

Disables displaying of unnecessary messages.

=item B<-V>, B<--verbose>

Enables displaying of all messages. This is the default option.

=item B<-h>, B<--help>

Displays usage information and exits.

=item B<-v>, B<--version>

Displays version information and exits.

=back

=head1 EXAMPLE USAGE

List all blog post:

  ~]$ blaze-list
  ID: 11 | 2010-07-05 | Jaromir Hradilek

      Title: Join #blazeblogger on IRC
      Tags:  announcement

  ID: 10 | 2009-12-16 | Jaromir Hradilek

      Title: Debian and Fedora Packages
      Tags:  announcement

  etc.

List all blog post in reverse order:

  ~]$ blaze-list -r
  ID: 1 | 2009-02-10 | Jaromir Hradilek

      Title: BlazeBlogger 0.7.0
      Tags:  release

  ID: 2 | 2009-02-11 | Jaromir Hradilek

      Title: BlazeBlogger 0.7.1
      Tags:  release

  etc.

List all pages:

  ~]$ blaze-list -p
  ID: 5 | 2009-02-10 | Jaromir Hradilek

      Title: Downloads

  ID: 4 | 2009-02-10 | Jaromir Hradilek

      Title: Themes

  etc.

List each blog post on a single line:

  ~]$ blaze-list -s
  ID: 11 | 2010-07-05 | Join #blazeblogger on IRC
  ID: 10 | 2009-12-16 | Debian and Fedora Packages
  etc.

Display a short version of blog statistics:

  ~]$ blaze-list -Ss
  There is a total number of 11 blog posts and 5 pages in the repository.

=head1 SEE ALSO

B<blaze-config>(1), B<blaze-add>(1)

=head1 BUGS

To report a bug or to send a patch, please, add a new issue to the bug
tracker at <http://code.google.com/p/blazeblogger/issues/>, or visit the
discussion group at <http://groups.google.com/group/blazeblogger/>.

=head1 COPYRIGHT

Copyright (C) 2009-2011 Jaromir Hradilek

This program is free software; see the source for copying conditions. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
