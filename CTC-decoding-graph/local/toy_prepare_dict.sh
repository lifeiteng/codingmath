#!/bin/bash

# Begin configuration.

data=data

# End configuration.

echo "$0 $@"  # Print the command line for logging

[ -f path.sh ] && . ./path.sh;
. parse_options.sh || exit 1;

set -e

if [ $# -ne 1 ]; then
    echo "$0 Argument should be the dict file."
    exit 1;
fi 

if [ ! -f $1 ]; then
    echo "$0 no dict file $file !!!"
    exit 1;
fi

dir=$data/local/dict
mkdir -p $dir

cat $1 | grep -v -w "<s>" | grep -v -w "</s>" | grep -v -w "<unk>" | \
    sort | uniq | sed 's= \+= =g' | sed 's:([0-9])::g' >$dir/lexicon_words.txt || exit 1;

grep -v -w SIL $dir/lexicon_words.txt | \
  awk '{for(n=2;n<=NF;n++) { phones[$n]=1; }} END{for(x in phones) {print x}}' | sort > $dir/nonsilence_phones.txt

echo SIL > $dir/silence_phones.txt
echo SIL > $dir/optional_silence.txt
echo -n  > $dir/extra_questions.txt # no extra questions, as we have no stress or tone markers.

(echo '!SIL SIL';) | cat - $dir/lexicon_words.txt | sort | uniq > $dir/lexicon.txt
(echo SIL;) > $dir/silence_phones.txt

# Check that the dict dir is okay!
utils/validate_dict_dir.pl $dir || exit 1

echo "$0 Dictionary preparation succeeded."
exit 0;
