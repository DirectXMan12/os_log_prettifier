#!/usr/bin/perl -w
# vim: set ts=2 sw=2 et:

use strict;
use Term::ANSIColor;
use Getopt::Long;
use Data::Dump qw(pp);

my $maxlines = 0;         # > 0: output lines 0 .. $maxlines
my $taillines = 0;        # > 0: output lines -$taillines .. -1
my $hideraw = 1;          # set: hide *.messaging.ops.raw messages
my @skipsources = ();     # set: skip messages with these sources
my $strip_u = 1;          # clothes are optional when reading logfiles (strip 'u' designator on unicode strings)
my $highlightcontent = 1; # set: highlight the 'content=' key in message bodies
GetOptions(
  'maxlines=i'        => \$maxlines,
  'taillines=i'       => \$taillines,
  'hideraw!'          => \$hideraw,
  'skipsource=s@'     => \@skipsources,
  'stripu!'           => \$strip_u,
  'highlightcontent!' => \$highlightcontent
);

my @input_lines = ();

if ($taillines)
{
  foreach (@ARGV)
  {
    open(LESSIN, "tail -$taillines $_ |");
    while(<LESSIN>)
    {
      chomp;
      push @input_lines, $_;
    }
    close(LESSIN);
  }
}
else
{
  while (<>)
  {
    last if $maxlines && @input_lines > $maxlines;
    chomp;
    push @input_lines, $_; # read in all the lines
  }
}

my @structured_lines =  ();
my $valid_operations = join('|', qw(OPEN SENT RECV RCVD REST READ RETR RACK));
foreach (@input_lines)
{
  my $orig = $_;
  my @metadata = (/^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}\.\d{1,3}) (\d+) (DEBUG|INFO|ERROR) ([a-zA-Z0-9_.]+) \[(-|(?:[a-zA-Z0-9\-]+ .+ .+))\] (.+)$/);
  my ($date, $time, $pid, $lvl, $src, $req_id, $rest) = @metadata;
  #print STDOUT join(' -- ', $date,$time,$pid,$lvl,$src);
  #print STDOUT "\n";
  my %hsh = (date => $date, time => $time, pid => $pid, level => $lvl, source => $src, req_id => $req_id, raw => $orig);

  if ($rest =~ /^($valid_operations)\[([a-f0-9]+)\]: (.+)$/)
  {
    $hsh{msg} = {operation => $1, some_num => $2, body => $3};
  }
  else
  {
    $hsh{msg} = {body => $rest};
  }

  push @structured_lines, \%hsh;
}

if (-t STDOUT)
{
  if(open LESS, '|less -R')
  {
    close(STDOUT);
    *STDOUT = *LESS;
  }
}

LINE: foreach (@structured_lines)
{
  my %line = %$_;

  unless ($line{level} && $line{date} && $line{time} && $line{source} && $line{pid})
  {
    print colored("ERROR: ", 'bold white on_bright_red'), colored("$line{raw}", "on_bright_red"), "\n";
    next;
  }

  next if $hideraw && $line{source} =~ /^\w+\.messaging\.io\.raw$/;

  for my $src (@skipsources)
  {
    next LINE if $line{source} =~ qr/^\Q$src\E$/;
  }

  print colored("$line{date} $line{time}", 'yellow'), " $line{pid} ";
  if ($line{level} eq 'DEBUG')
  {
    print colored($line{level}, 'bold cyan');
  }
  elsif ($line{level} eq 'INFO')
  {
    print colored($line{level}, 'bold green');
  }
  elsif ($line{level} eq 'ERROR')
  {
    print colored($line{level}, 'bold red');
  }
  else
  {
    print colored($line{level}, 'bold');
  }

  print " ", colored("$line{source}", 'blue'), colored(" [$line{req_id}] ", 'bold');

  my %msg = %{$line{msg}};
  if ($line{msg}->{operation})
  {
    print colored("$msg{operation}", 'magenta'), " ";
    print colored("[$msg{some_num}]", 'bold'), " ";
    $msg{body} =~ s/(content)=/colored($1, 'bold') . '='/e if ($highlightcontent);
  }

  if ($strip_u) # waring: X-Rated code, viewer discretion advised
  {
    my $body = $msg{body};
    $body =~ s/u'(.+?)(?!\\)'/'$1'/g;
    print "$body\n";
  }
  else
  {
    print "$msg{body}\n";
  }
}

close LESS if (tell(LESS) > 0)
