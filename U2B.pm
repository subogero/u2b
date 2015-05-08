# Copyright: SZABO Gergely <szg@subogero.com>, GNU LGPL v2.1
package WWW::U2B;
use strict;
use URI::Escape;

use Exporter 'import';
our @EXPORT_OK = qw(search extract_streams playback download suffix uid);

sub search; sub extract_streams; sub suffix; sub uid;

my $base = 'https://www.youtube.com';
my $fifo = '.u2bfifo';
my $jar = '.u2bjar';

# Query, URL-encoded
sub search {
    my $url = "$base/results?search_query=" . join('+', @_);
    my $resp = `curl $url 2>/dev/null`;
    my @hits = $resp =~ /(href="\/watch.+?"|title="[^"]+?"|img src=".+?jpg")/g;
    my %seen;
    $seen{$_}++ foreach @hits;
    @hits = grep { my $n = /watch/ ? 2 : 1; $seen{$_} == $n } @hits;
    my @vids;
    my $hit;
    foreach (@hits) {
        my ($key, $val) = /^(.+)="(.+)"/;
        $key =~ s/=.+//;
        if ($key eq 'href' && $val ne $hit->{$key}) {
            if (keys %$hit) {
                push @vids, {
                    thumbnail => "https:$hit->{'img src'}",
                    label => $hit->{title},
                    name => "$base$hit->{href}",
                }
            }
            $hit = {};
            $hit->{$key} = $val;
        }
        next unless keys %$hit;
        $hit->{$key} = $val unless $hit->{$key};
    }
    return @vids;
}

# Extract stream URLs and metadata from a video HTML page:
# Look for quoted string after "url_encoded_fmt_stream_map":
# uri_unescape string
# Comma-split for list of stream data (comma inside quote does not split)
# Split each part by "\u0026" for url, itag, type, quality, fallback_host keys
# Return list of parts, each a hashref of url, itag, type, quality, extension
sub extract_streams {
    unlink $jar;
    my $html = `curl -c $jar -L $_[0] 2>/dev/null`;
    return unless $html =~ /url_encoded_fmt_stream_map":"(.+?)"/;
    my $map = uri_unescape $1;
    my ($stream, @streams);
    while ($map) {
        $stream .= $1 if $map =~ s/^([^,"]+)//;
        $stream .= $1 if $map =~ s/^("[^"]+?")//;
        if ($map eq '' || $map =~ s/^,//) {
            push @streams, $stream;
            $stream = '';
        }
    }
    my @result;
    foreach my $str (@streams) {
        my %fields = map { split /=/, $_, 2 } split /\\u0026/, $str;
        $fields{extension} = suffix $fields{itag};
        push @result, \%fields;
    }
    return @result;
}

# Playback an object returned by extract_streams
sub playback {
    my $player = shift;
    my $stream = shift;
    -e $fifo and unlink $fifo;
    system "mkfifo $fifo" and die "Unable to create $fifo";
    system "curl -c $jar -L '$stream->{url}' >>$fifo 2>/dev/null &";
    system "$player $fifo";
}

# Download an object returned by extract_streams
sub download {
    my $video = shift;
    my $stream = shift;
    my $vid = uid $video->{name};
    my $txt = $video->{label};
    my $pic = $video->{thumbnail};
    my $ext = $stream->{extension};
    my $url = $stream->{url};
    print "Downloading $vid.$ext - $txt\n";
    system "curl -c jar -L '$url' >$vid.$ext";
    (my $th_ext = $pic) =~ s/^.+\.//;
    system "curl -c jar -L '$pic' >$vid.$th_ext 2>/dev/null";
    if (open TXT, ">$vid.txt") {
        print TXT "$txt\n";
        close TXT;
    }
}

# Map itag format ids to file extensions
sub suffix {
    my $itag = shift;
    return $itag =~ /^(43|44|45|46)$/ ? 'webm'
         : $itag =~ /^(18|22|37|38)$/ ? 'mp4'
         : $itag =~ /^(13|17|36)$/    ? '3gp'
         :                              'flv';
}

sub uid {
    my $url = shift;
    my $uid = $url;
    die "$url: no valid video URL or ID" unless $uid =~ s/^(.+=)?(.{11})$/$2/;
    return $uid;
}

1;
__END__

=head1 NAME

WWW:U2B - YouTube search, download, playback

=head1 SYNOPSIS

  use WWW::U2B qw(search extract_streams playback download uid);

  my @hits = search qw(Foo Bar Baz);
  my @streams = extract_streams $hits[0]->{name};
  print $streams[0]->{url};
  download $hits[0], $streams[0];
  playback 'mplayer', $streams[0];

=head1 DESCRIPTION

This module provides YouTube search, download and playback without
depending on the YouTube v2 or v3 API.

=head1 DATA STRUCTURES

=head2 Search hit

Represents a YouTube video:
  { name => page URL, label => title, thumbnail => thumbnail image URL }

search() returns a list of these.
extract_streams() and download() take one as parameter.

=head2 Stream

Represents a playable, downloadable video stream:
  { url => x, itag => x, type => x, quality => x, extension => file ext }

extract_streams() returns a list of these.
download() and playback() take one as a parameter.

=head1 FILES

WWW::U2B must have write access to the currect dir of the using process
to create some files.

=head2 Temporary files

  .u2bjar - cookie jar for YouTube
  .u2bfifo - playback streams the video through this FIFO from curl

The FIFO is necessary because not all players are able to use the cookie
provided by YouTube.

=head2 Downloaded files

Named after the 11-character YouTube ID of the video:

  xxxxxxxxxxx.yyy - the video file
  xxxxxxxxxxx.jpg - thumbnail image
  xxxxxxxxxxx.txt - contains the title of the video

=head1 COPYRIGHT

Copyright 2015 SZABO Gergely C<< <szg@subogero.com> >>

License: GNU LGPL v2.1

=cut
