# Author: Jonathan Samson
# Date: 3/28/19
# Class: CMSC-416-001 VCU Spring 2019
# Project: Programming Assignment 5
# Title: qa-system.pl
#
#--------------------------------------------------------------------------
#   Problem Statement
#--------------------------------------------------------------------------
#
#   This program uses NLP techniques to provide a question answering system.
# A question answering system takes questions or queries from the user and
# returns an answer by searching through a collection of documents containing
# information. This program answers who, what, when, and where questions,
# using wikipedia as an information source.
# 
#--------------------------------------------------------------------------
#   Usage Instructions and Example Input/Output
#--------------------------------------------------------------------------
#
# This is a perl program, so some version of perl must be installed before executing the file.
# See: https://www.perl.org/get.html
#
# To run the program, type
#   perl qa-system.pl [log-file]
# Where log file is the name of the file you want the program to print logs to.
# The log file will contain debugging information, including the query (question provided by user),
# keyTerm (the term searched for on wikipedia), wikiText (The text pulled from wikipedia),
# each Rule ond Sub (Rule is the regex attempting to match against the text, Sub defines how
# to generate the answer from the match if found), and each possible answer found.
# 
#
# Type who, what, when, or where questions at the prompt, and press enter.
# The program will print an answer, or a default prompt. Addtionally, the program prints out a log file
# and error file.
# To exit, type 'exit'.
#
# Below is a sample run of the program.
#
#   *** This is a QA system by Jonathan Samson. It will try to answer questions that start with Who, What, When or Where. Enter "exit" to leave the program.
#
#   QA: Ask me a question.
#   USER: Who is George Washington?
#   QA: George Washington was an American political leader, military general, statesman, and Founding Father who also served as the first president of the United States from 1789 to 1797.
#
#   QA: Ask me a question.
#   USER: Who is Donald Trump?
#   QA: Donald J Trump is the 45th and current president of the United States.
#
#   QA: Ask me a question.
#   USER: Where is Budapest?
#   QA: Budapest is in Hungary, and the tenth-largest city in the European Union by population within city limits.
#
#   QA: Ask me a question.
#   USER: exit
#   QA: Thank you! Goodbye.
# 
# [Printed to log file]
#
# QUERY: |who is george washington?|
# KEYTERM: george washington
# WIKI TEXT: 
#
# {{Infobox officeholder
# | image = Gilbert Stuart Williamstown Portrait of George Washington.jpg office =
# | 1st President of the United States vicepresident = John Adams term_start =
# | April 30, 1789}} term_end = March 4, 1797 predecessor = Office established
# | successor = John Adams office1 = 7th Senior Officer of the United States Army
# | president1 = John Adams term_start1 = July 13, 1798 term_end1 = December 14,
# | 1799 predecessor1
#
# Rule: |((((a|an|the) )?george([\w+ ]*)washington)([^.]*)( (is|was|are|were|happens|occurs|takes place|happened|occured|took place)( (a|an|the))? ([^.])*\.))|
# Sub: |"$2$7"|
# LOG ANSWER: George Washington was an American political leader, military general, statesman, and Founding Father who also served as the first president of the United States from 1789 to 1797.
# Rule: |((((a|an|the) )?george([\w+ ]*)washington)([^.]*)?(([^.])*\.))|
# Sub: |"$2$6"|
# LOG ANSWER: George Washington
#
# QUERY: |who is donald trump?|
# KEYTERM: donald trump
# WIKI TEXT: 
# ...
#
#--------------------------------------------------------------------------
#   Algorithm
#--------------------------------------------------------------------------
#
# Below is a description of the algorithm used
#
# 1) Take in arguments and open log file for writing.
# 2) Loop the rest of the program, until user types exit.
# 3) Read user input, and match it against multiple regexes to determine question type
#    (who, what, when, or where). Also pull the keyTerm from the sentence, which defines the
#    wikipedia article to search for, from the question. If it matches no predicted question type,
#    return default reponse.
# 4) Depending on the type of question, generate a list of rules and substitutions, into the queryExpansions array.
# 5) Iterate through the array. If a match of a rule is found in the wikipedia text, use the corresponding subtitution
#    regex to generate an answer from the match. If not match is found, print default response.
# 6) Print the answer.

use warnings;
use strict;
use feature 'say';
use WWW::Wikipedia;

# Import wikipeida module.
my $wiki = WWW::Wikipedia->new( clean_html => 1 );

# Open log file.
my $argsCount = scalar @ARGV;
if( $argsCount < 1 ) {
    die "Enter a single argument for the log file name.";
}
my $logFilename = $ARGV[0];
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
        say "QA: Thank you! Goodbye.";
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
    # Store the key term here, which we will search for in wikipedia.
    my $keyTerm;

    print $logFh "\nQUERY: |$query|\n";

    # These variables hold useful sets of words which can be used within regexes to cover more possible matches.
    my $is = "(is|was|are|were|happens|occurs|takes place|happened|occured|took place)";
    my $the = "(a|an|the)";
    my $tangent = "([^.]*)";
    my $it = "(they|it)";
    my $he = "(he|she|they)";
    my $him = "(him|her|them)";
    my $word = "(\\w+)";
    my $happened = "(happens|occurs|takes place|happened|occured|took place|begins|begin|beginning)";
    my $when = "(when|during|after|before|between|on|at)";
    my $isAt = "(is located at|is found at|can be found at|is in|is at|was at|was in|is at the address)";

    # Run a bunch of regex matches on the query. If matches, create query expansion.
    # Match who questions.
    if( $query =~ /^who $is( $the)? (.*)\?$/i ) {
        my $tempTerm = $4;
        $keyTerm = $4;
        $tempTerm =~ s/ /([\\w+ ]*)/i;
        # Generate query expansions.
        @queryExpansion[0] = "((($the )?$tempTerm)$tangent( $is( $the)? ([^.])*\\.))";
        @queryExpansion[1] = '"$2$7"';
        @queryExpansion[2] = "((($the )?$tempTerm)$tangent?(([^.])*\\.))";
        @queryExpansion[3] = '"$2$6"';
    }
    # Match who-verb questions, like "who built the pyramids?"
    elsif( $query =~ /^who $word ($the )?(.*)\?$/i ) {
        $keyTerm = $4;
        # Pull the verb from the question.
        my $actionVerb = $1;
        # Generate query expansions.
        @queryExpansion[0] = "((($word ){1,5})$actionVerb ($the )?$keyTerm)";
        @queryExpansion[1] = '"$1."';
        @queryExpansion[2] = "((($word ){1,5})$actionVerb($him|$it))";
        @queryExpansion[3] = '"$1."';
        @queryExpansion[4] = "($keyTerm was $actionVerb by ($word){1,5})";
        @queryExpansion[5] = '"$1."';
    }
    # Match what questions.
    elsif( $query =~ /^what $is( $the)? (.*)\?/i) {
        $keyTerm = $4;
        # Generate query expansions.
        @queryExpansion[0] = "((($the )?$keyTerm)$tangent?( $is( $the)? ([^.])*\\.))";
        @queryExpansion[1] = '"$2$6"';
        @queryExpansion[2] = "($it $is( $the)? ([^.])*\\.)";
        @queryExpansion[3] = '"$1"';
    }
    # Match when questions.
    elsif( $query =~ /^when $is( $the)? (.*)\?/i ) {
        $keyTerm = $4;
        # Generate query expansions.
        @queryExpansion[0] = "(($the )?$keyTerm$tangent $happened ($when )?([^.]*)\\.)";
        @queryExpansion[1] = '"$1"';
        @queryExpansion[2] = "(($happened)([^.]*)\\.)";
        @queryExpansion[3] = $keyTerm.'" $1"';
        @queryExpansion[4] = "(($keyTerm)[^.]*($is)[^.]*($when)( \\w+ \\d+(, \\d+)?))";
        @queryExpansion[5] = '"$2 $3 $5$7"';
        @queryExpansion[6] = "($keyTerm $is [^.]*)";
        @queryExpansion[7] = '"$1"';
    }
    # Match where questions.
    elsif( $query =~ /^where $is( $the)? (.*)\?/i ) {
        $keyTerm = $4;
        # Generate query expansions.
        @queryExpansion[0] = "(($the )?$keyTerm $tangent($isAt)([^.]*)\\.)";
        @queryExpansion[1] = '"$1"';
        @queryExpansion[2] = "(($keyTerm)([^.]*)is the capital([\\w ]*)of ([^.]*))";
        @queryExpansion[3] = '"$2 is in $5"';
        @queryExpansion[4] = "(($keyTerm)$tangent( $is [^.]*))";
        @queryExpansion[5] = '"$2$4"';
    }
    # No match found, so return default response, and go to next loop.
    else {
        say "I am sorry I don't know the answer.";
        next;
    }

    print $logFh "KEYTERM: $keyTerm\n";

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

    print $logFh "WIKI TEXT: $wikiText\n";

    # Remove newline characters from wikitext, since WWW::Wikipedia adds extras for aesthetics.
    $wikiText =~ s/\s+/ /g;
    # Remove parthentsized sections, so that we have a more raw text to use, that will be more likely to follow predicted grammatical structures.
    $wikiText =~ s/\([^()]*\)//g;
    $wikiText =~ s/\[([^\[\]]|(?0))*]//g;
    # Remove weird characters.
    $wikiText =~ s/[{}'"]//g;
    # Make spacing equal.
    $wikiText =~ s/\s+/ /g;
    # Remove junk 'Retrieved' sentences that are returned from wikipedia
    $wikiText =~ s/Retrieved[^.]*\.//g;
    $wikiText =~ s/\.[ \d\-]*\.//g;

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

        # Post process the answer.
        # Remove trailling whitespace.
        $firstAnswer =~ s/^\s+|\s+$//g;

        # Make sure it ends in a period.
        if( $firstAnswer !~ /\.$/ ) {
            $firstAnswer = $firstAnswer.".";
        }

        say "QA: $firstAnswer";
    }
    else {
        say "QA: I do not know the answer.";
    }
}

close($logFh);
