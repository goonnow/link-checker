use URI;
use Web::Scraper;
use AnyEvent;
use AnyEvent::HTTP;
use HTTP::Tiny;
use Timer::Simple ();
use Data::Dump qw(dump);

my $t = Timer::Simple->new();
$t->start();

my $url =  $ARGV[0] || "http://www.startsiden.no/";

my $links = scraper {
    process "a", "links[]" => sub {
        my $elem = shift;

        my $href = $elem->attr('href');
        $href =~ s|^/|$url|g;
        return {
            title => $elem->attr('title'),
            alt => $elem->attr('alt'),
            id => $elem->attr('id'),
            class => $elem->attr('class'),
            href => $href,
        };
    };
};

my $res = $links->scrape( URI->new($url) );

my @links = remove_dup($res->{links});
my $total = scalar @links;
my $bad   = 0;

my $start_time = time;
my $filename = "check-$start_time.log";
print 'filename : '.$filename."\n";
print "There're $total links\n";

my $cv = AnyEvent->condvar; 
for my $l ( @links ) {
    #my $response = HTTP::Tiny->new->get($l->{href});

    $cv->begin;
    http_request GET => $l->{href}, sub {
        my ($body, $hdr) = @_;

        if( $hdr->{Status} =~ /^2/ ){
            print "GOOD\t $l->{href}\n";
        }else {
            print "BAD\t$l->{href} \t $hdr->{Status}\n";

            open ( MYFILE, ">>$filename");
            print MYFILE "$l->{href}\n";
            close MYFILE;

        }
        $cv->end;

    };

    #if( $response->{success} ) {
        #print "GOOD\t $l->{href}\n"; 
    #}else{
    #}
}

$cv->recv;
$t->stop();

#print "=== Found $bad bad links from $total links in $url\n";
#printf "In total took : ", $t->hms;

sub remove_dup {
    my $links  = shift;
    my @new;

    foreach my $l ( @{$links} ) {
        my $found = 0;

        # Check dup loop
        foreach my $c ( @new ) {
            if( $l->{href} eq $c->{href} ){
                $found=1;
                last;
            }
        }

        if( !$found ) {
            push( @new, $l );
        }
    }
    return @new;
}
