# Author: Jonathan Samson
# Date: 4/29/19
# Class: CMSC-416-001 VCU Spring 2019
# Project: Programming Assignment 6
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
# 4) Depending on the type of question, generate a list of rules and substitutions, into the queryReformulations array.
# 5) Iterate through the array. If a match of a rule is found in the wikipedia text, use the corresponding subtitution
#    regex to generate an answer from the match. If not match is found, print default response.
# 6) Print the answer.
#
#
# Assignment 6 Enhancements:
#
## Query Reformulation
### 1.1) Query for partial matches. We split the key phrase into all possible unigrams, bigrams, and trigrams. Then we add them to the list of patterns to search for.
### 1.2) We use WordNet to obtain synonyms of the words in the first (most precise) search query in our query reformulations. We then try all combinations of replacements
###    of each of the words which have synonyms, and add these to the query reformulations.
### 1.3) For each query reformulation, do not stop at first match (simple change, but important). Instead, consider all matches as candidate answers.
#
## Answer Composition
### 2.1) Answer tiling. We take pattern matches (candidate answers) and combine them if they have common trailing words. In other words, two patterns are matched
###      if they share a unigram in common at the edge of the sentence which allows them to be combined.
### 2.2) We take extra measures to attempt to make the chosen answer match the form of the question asked.
###      Expand any words appearing in the article title to the full name. i.e. if we search for George washington's birthday, and we find "Washington was born on ..."
###      expand this to "George Washington was born on...". End answers in a period. Begin answers with capital letter.
#
## Confidence Score
### 3.1) We generate a confidence score for each pattern match (candidate answer). This confidence score is higher for our more precise search patterns.
###      Tiled answers are scored best when they are a composite of two mediumly (.5) scored answers. This is to prevent the high scoring of tiles generated from
###      perfect answers (since perfect answers will be worse after tiling) and high scoring of tiles generated from two bad answers (which may just create a doubly bad answer).

use warnings;
use strict;
use feature 'say';

# Import wikipeida module.
use WWW::Wikipedia;
# Import WordNet module.
use WordNet::QueryData;

# Create wikipedia object.
my $wiki = WWW::Wikipedia->new( clean_html => 1 );
# Create wordnet object.
my $wn = WordNet::QueryData->new( noload => 1);

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

    # Store the query Reformulations here. They should be ordered by most precise to least precise.
    my @queryReformulation = ();
    # Store the answer Reformulations that correspond to the above query Reformulations.
    # Store the key term here, which we will search for in wikipedia.
    my $keyTerm;

    print $logFh "\nQUERY: |$query|\n";

    # These variables hold useful sets of words which can be used within regexes to cover more possible matches.
    my $is = "(is|was|are|were|happens|occurs|takes place|happened|occured|took place|did)";
    my $the = "(a|an|the)";
    my $tangent = "([^.]*)";
    my $it = "(they|it)";
    my $he = "(he|she|they)";
    my $him = "(him|her|them)";
    my $word = "(\\w+)";
    my $happened = "(happens|occurs|takes place|happened|occured|took place|begins|begin|beginning)";
    my $when = "(when|during|after|before|between|on|at)";
    my $isAt = "(is located at|is found at|can be found at|is in|is at|was at|was in|is at the address)";

    # Run a bunch of regex matches on the query. If matches, create query Reformulation.
    # Match who questions.
    if( $query =~ /^who $is( $the)? (.*)\?$/i ) {
        my $tempTerm = $4;
        $keyTerm = $4;
        $tempTerm =~ s/ /([\\w+ ]*)/i;
        # Generate query Reformulations.
        @queryReformulation[0] = "((($the )?$tempTerm)$tangent( $is( $the)? ([^.])*\\.))";
        @queryReformulation[1] = '"$2$7"';
        @queryReformulation[2] = "((($the )?$tempTerm)$tangent?(([^.])*\\.))";
        @queryReformulation[3] = '"$2$6"';
    }
    # Match who-verb questions, like "who built the pyramids?"
    elsif( $query =~ /^who $word ($the )?(.*)\?$/i ) {
        $keyTerm = $4;
        # Pull the verb from the question.
        my $actionVerb = $1;
        # Generate query Reformulations.
        @queryReformulation[0] = "((($word ){1,5})$actionVerb ($the )?$keyTerm)";
        @queryReformulation[1] = '"$1."';
        @queryReformulation[2] = "((($word ){1,5})$actionVerb($him|$it))";
        @queryReformulation[3] = '"$1."';
        @queryReformulation[4] = "($keyTerm was $actionVerb by ($word){1,5})";
        @queryReformulation[5] = '"$1."';
    }
    # Match what questions.
    elsif( $query =~ /^what $is( $the)? (.*)\?/i) {
        $keyTerm = $4;
        # Generate query Reformulations.
        @queryReformulation[0] = "((($the )?$keyTerm)$tangent?( $is( $the)? ([^.])*\\.))";
        @queryReformulation[1] = '"$2$6"';
        @queryReformulation[2] = "($it $is( $the)? ([^.])*\\.)";
        @queryReformulation[3] = '"$1"';
    }
    # Match when questions.
    elsif( $query =~ /^when $is( $the)? (.*)\?/i ) {
        $keyTerm = $4;
        # Generate query Reformulations.
        @queryReformulation[0] = "(($the )?$keyTerm$tangent $happened ($when )?([^.]*)\\.)";
        @queryReformulation[1] = '"$1"';
        @queryReformulation[2] = "(($happened)([^.]*)\\.)";
        @queryReformulation[3] = $keyTerm.'" $1"';
        @queryReformulation[4] = "(($keyTerm)[^.]*($is)[^.]*($when)( \\w+ \\d+(, \\d+)?))";
        @queryReformulation[5] = '"$2 $3 $5$7"';
        @queryReformulation[6] = "($keyTerm $is [^.]*)";
        @queryReformulation[7] = '"$1"';

    }
    # Match where questions.
    elsif( $query =~ /^where $is( $the)? (.*)\?/i ) {
        $keyTerm = $4;
        # Generate query Reformulations.
        @queryReformulation[0] = "(($the )?$keyTerm $tangent($isAt)([^.]*)\\.)";
        @queryReformulation[1] = '"$1"';
        @queryReformulation[2] = "(($keyTerm)([^.]*)is the capital([\\w ]*)of ([^.]*))";
        @queryReformulation[3] = '"$2 is in $5"';
        @queryReformulation[4] = "(($keyTerm)$tangent( $is [^.]*))";
        @queryReformulation[5] = '"$2$4"';

    }
    # No match found, so return default response, and go to next loop.
    else {
        say "I am sorry I don't know the answer.";
        next;
    }

    ### BEGIN [Enhancement 1.2] Use WordNet to create extra query reformulations

    # Iterate through each word in the keyTerm.
    my @keyWords = split(" ", $keyTerm);
    my $numWords = scalar @keyWords;
    for(my $j=0; $j<$numWords; $j++) {
        my $word = $keyWords[$j];
        # Get senses of the word.
        my @senses = $wn->querySense($word);
        # For each sense, obtain all synonyms, and add them to query reformulations.
        for my $sense (@senses) {
            my @synonymSenses = $wn->querySense($sense, "syns");
            for my $synonym (@synonymSenses) {
                $synonym =~ s/^([^#])#/$1/;
                my $queryReformulationLength = scalar @queryReformulation;
                $queryReformulation[$queryReformulationLength] = "[^.]*".$synonym."[^.]*\\.";
                $queryReformulation[$queryReformulationLength+1] = '"$1"';
            }
        }
    }
    ### END [Enhancement 1.2]

    ### BEGIN [Enhancement 1.1] Search for partial matches
    # Remove commas and quotes from key term.
    $keyTerm =~ s/[,'"]*//g;
    # Split key term into individual words.
    my @partialArray = split(' ', $keyTerm);

    # For each triple, double, and single word combo, add the pattern to the queryReformulations.
    my $queryReformulationLength = scalar @queryReformulation;
    my $partialArrayLength = scalar @partialArray;
    for( my $k=0; $k<3; $k++ ) {
        for( my $i=0; $i<$partialArrayLength-$k; $i++ ) {
            my $Reformulation = "";
            for( my $j=0; $j<$k; $j++ ) {
                my $word = $partialArray[$i+$j];
                $Reformulation = $Reformulation + " $word";
            }
            $Reformulation =~ s/^\s+|\s+$//g;
            $queryReformulation[$queryReformulationLength] = "$Reformulation";
            $queryReformulation[$queryReformulationLength+1] = '"$1"';
            $queryReformulationLength += 2;
        }
    }
    ### END [Enhancement 1.1] Search for partial matches

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
    # Remove parethesized sections, so that we have a more raw text to use, that will be more likely to follow predicted grammatical structures.
    $wikiText =~ s/\([^()]*\)//g;
    $wikiText =~ s/\[([^\[\]]|(?0))*]//g;
    # Remove weird characters.
    $wikiText =~ s/[{}'"]//g;
    # Make spacing equal.
    $wikiText =~ s/\s+/ /g;
    # Remove junk 'Retrieved' sentences that are returned from wikipedia
    $wikiText =~ s/Retrieved[^.]*\.//g;
    $wikiText =~ s/\.[ \d\-]*\.//g;

    # Stores the captured text, which matched the Reformulation.
    my $capture = "";

    ### BEGIN [Enhancement 3.1] Storing all matches and partial matches in an array, and assigning scores in the loop below.

    # Store answers in array
    my %answers = ();

    # Search for each Reformulation. Return the first match.
    my $ReformulationLength = scalar @queryReformulation;
    for( my $i=0; $i<$ReformulationLength; $i=$i+2)  {
        my $rule = $queryReformulation[$i];
        my $sub = $queryReformulation[$i+1];
        print $logFh "Rule: |$rule|\n";
        print $logFh "Sub: |$sub|\n";

        # [Enhancement 1.3] Match all matches in text.
        while( $wikiText =~ /$rule/ig ) {
            $capture = $1;
            $capture =~ s/$rule/$sub/eei;
            $capture =~ s/^\s+|\s+$//g;

            # Store the answer in the answer hash, along with its score
            my $answersSize = scalar keys %answers;
            my $score = 1 / ($i + 1);
            @answers{$answersSize} = [$capture, $score];
            print $logFh "ANSWER (score = $score): $capture\n";
        }
    }
    ### END [Enhancement 3.1]

    if( exists $answers{0} ) {
        my @answer = @{ $answers{0} };
        my $answerText = $answer[0];
        my $answerScore = $answer[1];
        
        # If the top answer has a score of 1, we don't need to perform any other modifications. Just return that answer.
        if( $answerScore == 1 ) {
            # Make sure it ends in a period.
            if( $answerText !~ /\.$/ ) {
                $answerText = $answerText.".";
            }
            say "QA: $answerText";
        }
        else {

            ### BEGIN [Enhancement 2.1] Tiling. For each combination of possible answers, compare first and last words. If they match, perform tiling, and add new answer with new score.
            my %wordArrays = ();

            # For each combination of possible answers, compare first and last words. If they match, perform tiling, and add new answer with
            ## new score.
            my @answerKeys = keys %answers;
            for my $answerKey1 (@answerKeys) {
                for my $answerKey2 (@answerKeys) {
                    # Only perform if we are comparing two DIFFERENT answers
                    if($answerKey1 == $answerKey2) {
                        next;
                    }
                    my @answer1 = @{ $answers{$answerKey1} };  
                    my @answer2 = @{ $answers{$answerKey2} };  
                    my $answerText1 = $answer1[0];
                    my $answerText2 = $answer2[0];
                    my $answerScore1 = $answer1[1];
                    my $answerScore2 = $answer2[2];

                    # Obtain last word of first answer.
                    my $last1 = $answerText1 =~ /[^ ]*$/i;
                    $last1 =~ s/[."',?!]//g;
                    # Obtain first word of second answer.
                    my $first2 = $answerText2 =~ /^[^ ]*/i;
                    # If they match, perform tiling.
                    if( $last1 eq $first2) {
                        my $restAnswerText2 = $answerText2 =~ s/$first2//ee;
                        $restAnswerText2 =~ s/^\s+|\s+$//g;
                        my $newAnswerText = $answerText1.$restAnswerText2;
                        # The new score takes into account the scores of the two answers which have been tiled together.
                        # It is a product of 2 factors.
                        # Factor 1: (2 - $answerScore1 - $answerScore2) / 2)
                        ## Value between 0 and 1 which represents how bad the previous scores were.
                        ## We want good scoring answers to produce badly scored tiled answers (since the previous answers were likely better).
                        # Factor 2: (( $answerScore1 + $answerScore2) / 2)
                        ## Value between 0 and 1 which represents how good the previous scores were.
                        ## We want bad scoring answers to retain some of the value for how bad they were before (two very bad answers should not make a good answer);
                        my $newAnswerScore = ((2 - $answerScore1 - $answerScore2) / 2) * (( $answerScore1 + $answerScore2) / 2);
                        my $answersLength = scalar keys %answers;
                        $answers{$answersLength} = [$newAnswerText, $newAnswerScore];
                    }
                }
            }

            ### END [Enhancement 2.1] Tiling.

            my $maxScore = 0;
            my $maxAnswer = "";
            for my $answerKey (keys %answers) {
                my @answer = @{ $answers{0} };
                my $answerText = $answer[0];
                my $answerScore = $answer[1];
                if( $answerScore > $maxScore ) {
                    $maxAnswer = $answerText;
                    $maxScore = $answerScore;
                }
            }

            ### BEGIN [Enhancement 2.2] Answer compositions improvment.
            
            my $done = 0;

            # If the answer does not currently contain the whole keyTerm, attempt to fill in the rest of it.
            if($maxAnswer !~ /$keyTerm/i) {
                # Split key term into words.
                my @keyWords = split " ", $keyTerm;

                # Search through answer for n-grams of the keyTerm. If found, fill in the rest and continue.
                # Start with n-grams of size (n-1), where n is the number of words in the keyTerm.
                my $keyWordsLength = scalar @keyWords;
                for( my $n=$keyWordsLength-1; $n>0; $n--) {
                    # Iterate through all ngrams.
                    for( my $i=0; $i <= $keyWordsLength-$n; $i++) {
                        
                        # Get each of the n words into a string.
                        my $ngram = "";
                        for( my $j=0; $j<$n; $j++) {
                            $ngram = $ngram." ".$keyWords[$i+$j];
                        }

                        # if we find a match, substitute the ngram with the whole keyTerm, and continue.
                        if( $maxAnswer =~ s/$ngram/$keyTerm/iee ) {
                            $done = 1;
                            last;
                        }
                    }
                    if($done == 1) {
                        last;
                    }
                }
            }

            ### END [Enhancement 2.2]

            # Add capital letter to begin answer.
            $maxAnswer = ucfirst $maxAnswer;

            # Add period if necessary.
            if( $maxAnswer !~ /\.$/ ) {
                $maxAnswer = $maxAnswer.".";
            }
            say "QA: $maxAnswer";
        }
    }
    else {
        say "QA: I do not know the answer.";
    }

    

    print $logFh "QUERY ReformulationS: \n";
    $queryReformulationLength = scalar @queryReformulation;
    for( my $i=0; $i<$queryReformulationLength; $i+=2) {
        print $logFh "    $queryReformulation[$i]\n";
    }
}

close($logFh);
