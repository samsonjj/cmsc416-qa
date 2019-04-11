
use warnings;
use strict;
use feature 'say';
use WWW::Wikipedia;

# Import wikipeida module.
my $wiki = WWW::Wikipedia->new( clean_html => 1 );

# Open log file.
my $logFilename = "logfile.txt";
open(my $logFh, '>', $logFilename)
    or die "Could not open log file '$1' $!.";

# Change error file to errorfile.txt, errors can be unavoidably caused during logging.
# For example, wikipedia can include some wide characters, which perl then reports when printing.
open(STDERR, '>', 'errorfile.log') or die "Can't open log";

# Counts the number of main loops, i.e. the number of questions asked so far.
my $questionCounter = 0;

# Print intro line.
say "\n*** This is a QA system by Jonathan Samson. It will try to answer questions that start with Who, What, When or Where. Enter \"exit\" to leave the program.";

# Main loop. Get query, expand query, search for queries, pick answer, parse answer, return answer.
while( 1 ) {

    say "\nQA: Ask me a question.";

    # Read query from standard input.
    print "USER: ";
    my $query = <STDIN>;
    $questionCounter++;

    # Remove endline character.
    chomp $query;
    $query = lc $query;

    # Remove trailing whitespace
    $query =~ s/^\s+|\s+$//g;

    # If the query equals "exit", quit the program.
    if( $query eq "exit" ) {
        last;
    }

    # If the question does not begin with who, what, when, or where, return a default response.
    if( $query !~ /^(who|what|when|where)/ ) {
        say "QA: Please ask a question that begins with who, what, when or where.";
        next;
    }

    # Store the query expansions here. They should be ordered by most precise to least precise.
    my @queryExpansion = ();
    # Store the answer expansions that correspond to the above query expansions.
    # my @answerExpansion = ();
    # Store the key term here, which we will search for in wikipedia.
    my $keyTerm;

    # Run a bunch of regex matches on the query. If matches, create query expansion.

    print $logFh "\nQUERY: |$query|\n";

    #Regex pieces.
    my $is = "(is|was|are|were)";
    my $the = "(a|the)";
    #my $tangent = "(,[^,.]*,|\([^.)]*\))";
    my $tangent = "([^.]*)";
    my $it = "(they|it)";
    my $he = "(he|she|they)";
    my $him = "(him|her|them)";
    my $word = "(\\w+)";
    my $happened = "(happens|occurs|takes place|happened|occured|took place)";
    my $when = "(when|during|after|before|between|on|at)";
    my $isAt = "(is located at|is found at|can be found at|is in|is at|was at|was in|is at the address)";

    if( $query =~ /^who $is( $the)? (.*)\?$/i ) {
        $keyTerm = $4;
        @queryExpansion[0] = "((($the )?$keyTerm)$tangent( $is( $the)? ([^.])*\\.))";
        @queryExpansion[1] = '"$2$6"';
        @queryExpansion[0] = "((($the )?$keyTerm)$tangent?(([^.])*\\.))";
        @queryExpansion[1] = '"$2$6"';
    }
    elsif( $query =~ /^who $word ($the )?(.*)\?$/i ) {
        $keyTerm = $4;
        my $actionVerb = $1;
        print $logFh "ACTION VERB: |$actionVerb|\n";
        @queryExpansion[0] = "((($word ){1,5})$actionVerb ($the )?$keyTerm)";
        @queryExpansion[1] = '"$1."';
        @queryExpansion[2] = "((($word ){1,5})$actionVerb($him|$it))";
        @queryExpansion[3] = '"$1."';
        @queryExpansion[4] = "($keyTerm was $actionVerb by ($word){1,5})";
        @queryExpansion[5] = '"$1."';
    }
    elsif( $query =~ /^what $is( $the)? (.*)\?/i) {
        $keyTerm = $4;
        @queryExpansion[0] = "((($the )?$keyTerm)$tangent?( $is( $the)? ([^.])*\\.))";
        @queryExpansion[1] = '"$2$6"';
        @queryExpansion[2] = "($it $is( $the)? ([^.])*\\.)";
        @queryExpansion[3] = '"$1"';
    }
    elsif( $query =~ /^when $is( $the)? (.*)\?/i ) {
        $keyTerm = $4;
        @queryExpansion[0] = "(($the )?$keyTerm $tangent($is |$happened )?($when)([^.]*)\\.)";
        @queryExpansion[1] = '"$1"';
        @queryExpansion[2] = "(($happened)([^.]*)\\.)";
        @queryExpansion[3] = $keyTerm.'" $1"';
    }
    elsif( $query =~ /^where $is( $the)? (.*)\?/i ) {
        $keyTerm = $4;
        @queryExpansion[0] = "(($the )?$keyTerm $tangent($isAt)([^.*)\\.)";
        @queryExpansion[1] = "$1";
    }
    else {
        say "I am sorry I don't know the answer.";
        next;
    }

    print $logFh "KEYTERM: |$keyTerm|\n";

    # Get Wikipedia document.
    my $result = $wiki->search( $keyTerm );
    # Get text from document. If no document found, return a default response.
    my $wikiText = "";
    if( $result && $result->text() ) {
         $wikiText = $result->text();
    }
    else {
        say "QA: I could not find any information on $keyTerm.";
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

    print $logFh "TEXT: |$wikiText|\n";

    # Stores the captured text, which matched the expansion.
    my $capture = "";

    # Store first answer found.
    my $firstAnswer = "";

    # Search for each expansion. Return the first match.
    my $expansionLength = scalar @queryExpansion;
    for( my $i=0; $i<$expansionLength; $i=$i+2)  {
        my $rule = $queryExpansion[$i];
        my $sub = $queryExpansion[$i+1];
        print $logFh "Rule: |$rule|\n";
        print $logFh "Sub: |$sub|\n";
        if( $wikiText =~ /$rule/i ) {
            $capture = $1;
            $capture =~ s/$rule/$sub/eei;
            #TODO uncomment below
            # last;
            if( $firstAnswer eq "") {
                $firstAnswer = $capture;
            }
            print $logFh "LOG ANSWER: $capture\n";
        }
    }
    if( $firstAnswer ne "" ) {
        say "QA: $firstAnswer";
    }
    else {
        say "QA: I do not know the answer.";
    }
}

close($logFh);

## search for 'perl' 
# my $result = $wiki->search( 'perl' );
 
## if the entry has some text print it out
# if ( $result->text() ) { 
#     say $result->text();
# }

# if ( $result->fulltext() ) {
#     say $result->fulltext();
# }

