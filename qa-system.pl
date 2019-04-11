
use warnings;
use strict;
use feature 'say';
use WWW::Wikipedia;

my $wiki = WWW::Wikipedia->new( clean_html => 1 );

# Counts the number of main loops, i.e. the number of questions asked so far.
my $questionCounter = 0;

# Print intro line.
say "*** This is a QA system by Jonathan Samson. It will try to answer questions that start with Who, What, When or Where. Enter \"exit\" to leave the program.";

# Main loop. Get query, expand query, search for queries, pick answer, parse answer, return answer.
while( 1 ) {

    print "QUESTION: ";

    # Read query from standard input.
    my $query = <STDIN>;
    $questionCounter++;

    # Remove endline character.
    chomp $query;
    $query = lc $query;

    # Remove trailing whitespace
    $query =~ s/^\s+|\s+$//g;

    # If the query equals "exit", quit the program.
    if( $query eq "exit" ) {
        return;
    }

    # If the question does not begin with who, what, when, or where, return a default response.
    if( $query !~ /^(who|what|when|where)/ ) {
        say "Please ask a question that begins with who, what, when or where.";
        next;
    }

    # Store the query expansions here. They should be ordered by most precise to least precise.
    my @queryExpansion = ();
    # Store the answer expansions that correspond to the above query expansions.
    # my @answerExpansion = ();
    # Store the key term here, which we will search for in wikipedia.
    my $keyTerm;

    # Run a bunch of regex matches on the query. If matches, create query expansion.

    #TODO
    say "QUERY: |$query|";

    #Regex pieces.
    my $is = "(is|was|are|were)";
    my $the = "(a|the)";
    my $tangent = "(,[^,]*,)";
    my $it = "(they|it)";
    my $he = "(he|she|they|them)";

    # if( $query =~ /^who is\s+(.*)\s+\?$/ ) {
    if( $query =~ /^who ($is)( $the)? (.*)\?$/ ) {
        $keyTerm = $3;
        push @queryExpansion, qr/((($the $keyTerm)|($keyTerm|he|she))$tangent? $is( $the)? ([^.])*\.)/i;
        # push @queryExpansion, qr/($keyTerm was [^.]*\.)/i;
        # push @queryExpansion, qr/((He|She) was [^.]*\.)/;
    }
    elsif( $query =~ /^what $is( $the)? (.*)\?/i) {
        $keyTerm = $4;
        @queryExpansion[0] = "boopy";
        @queryExpansion[1] = '"belch"';
        @queryExpansion[2] = "((($the )?$keyTerm)$tangent?( $is( $the)? ([^.])*\\.))";
        @queryExpansion[3] = '"$2$6"';
        @queryExpansion[4] = ".*$it $is( $the)? ([^.])*\\..*";
        @queryExpansion[5] = '"$1$5"';
    }
    elsif( $query =~ /^when (is|was)( the)? (.*)\?/ ) {
        $keyTerm = $3;
        push @queryExpansion, qr/(((the $keyTerm)|($keyTerm|it)) (is|was|are|were) ([^.])*\.)/i;
    }
    else {
        say "I am sorry I don't know the answer.";
        next;
    }

    # TODO
    say "KEYTERM: |$keyTerm|";

    # Get Wikipedia document.
    my $result = $wiki->search( $keyTerm );
    # Get text from document. If no document found, return a default response.
    my $wikiText = "";
    if( $result && $result->text() ) {
         $wikiText = $result->text();
    }
    else {
        say "I could not find any information on $keyTerm.";
        next;
    }
    # Remove newline characters from wikitext, since WWW::Wikipedia adds extras for aesthetics.
    $wikiText =~ s/\s+/ /g;
    # Remove parthentsized sections, so that we have a more raw text to use, that will be more likely to follow predicted grammatical structures.
    $wikiText =~ s/\([^()]*\)//g;
    # Remove weird characters.
    $wikiText =~ s/[{}'"]//g;
    # Make spacing equal.
    $wikiText =~ s/\s+/ /g;

    #TODO
    say "TEXT: |$wikiText|";

    # Stores the captured text, which matched the expansion.
    my $capture = "";

    # Search for each expansion. Return the first match.
    my $expansionLength = scalar @queryExpansion;
    for( my $i=0; $i<$expansionLength; $i=$i+2)  {
        my $rule = $queryExpansion[$i];
        my $sub = $queryExpansion[$i+1];
        say "Rule: |$rule|";
        say "Sub: |$sub|";
        if( $wikiText =~ /$rule/i ) {
            $capture = $1;
            $capture =~ s/$rule/$sub/eei;
            #TODO uncomment below
            # last;
            say "LOG ANSWER: $capture";
            say "MATCH: $_";
        }
    }
    say "ANSWER: $capture";
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

