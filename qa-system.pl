
use warnings;
use strict;
use feature 'say';
use WWW::Wikipedia;

my $wiki = WWW::Wikipedia->new( clean_html => 1 );
 
# Flag to continue the main loop.
my $run = 1;

# Counts the number of main loops, i.e. the number of questions asked so far.
my $questionCounter = 0;

# Main loop. Get query, expand query, search for queries, pick answer, parse answer, return answer.
while( $run ) {

    say "*** This is a QA system by Jonathan Samson. It will try to answer questions that start with Who, What, When or Where. Enter \"exit\" to leave the program.";

    my $query = <STDIN>;

    # Remove endline character.
    chomp $query;
    lc $query;

    # Remove trailing whitespace
    $query =~ s/^\s+|\s+$//g;

    # If the question does not begin with who, what, when, or where, return a default response.
    if( $query !~ /^(who|what|when|where)/ ) {
        say "Please ask a question that begins with who, what, when or where.";
    }

    say "Count: $questionCounter, $query";



    $questionCounter++;
    if( $query eq "exit" ) {
        $run = 0;
    }
}

## search for 'perl' 
# my $result = $wiki->search( 'perl' );
 
## if the entry has some text print it out
# if ( $result->text() ) { 
#     say $result->text();
# }

# if ( $result->fulltext() ) {
#     say $result->fulltext();
# }

