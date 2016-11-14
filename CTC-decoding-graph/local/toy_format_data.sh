#!/bin/bash

stage=0

data=data
lm_suffix="tg"
lang_suffix=""

# End configuration.

echo "$0 $@"  # Print the command line for logging

[ -f path.sh ] && . ./path.sh;
. parse_options.sh || exit 1;


# echo "Preparing decode ."
lmdir=$data/local/lm
tmpdir=$data/local/lm_tmp
mkdir -p $tmpdir
mkdir -p $lmdir

arpa=$1

if [ ! -f $arpa ];then
  echo "$f not exist!" && exit 1;
fi

# cp $arpa $lmdir/lm_${lm_suffix}.arpa

# Next, for each type of language model, create the corresponding FST
# and the corresponding lang_decode_* directory.

echo "Preparing language models for test"

suffix=$lm_suffix
test=$data/lang_${suffix}
mkdir -p $test
for f in phones.txt words.txt phones.txt L.fst L_disambig.fst \
   topo oov.int oov.txt; do
  cp $data/lang$lang_suffix/$f $test
done
cp -r $data/lang$lang_suffix/phones $test

lexicon=$data/local/dict/lexicon.txt
if [ ! -f $lexicon ];then
  awk '{$2=""; print $0;}' $data/lang$lang_suffix/phones/align_lexicon.txt >$tmpdir/lexicon.txt
  lexicon=$tmpdir/lexicon.txt
fi

if [ $stage -le 0 ];then
  cat $arpa | \
   utils/find_arpa_oovs.pl $test/words.txt  > $tmpdir/oovs_${suffix}.txt

  # grep -v '<s> <s>' because the LM seems to have some strange and useless
  # stuff in it with multiple <s>'s in the history.  Encountered some other similar
  # things in a LM from Geoff.  Removing all "illegal" combinations of <s> and </s>,
  # which are supposed to occur only at being/end of utt.  These can cause 
  # determinization failures of CLG [ends up being epsilon cycles].
  cat $arpa | \
    arpa2fst --disambig-symbol=#0 --read-symbol-table=$test/words.txt - $test/G.fst || exit 1;
fi

fstisstochastic $test/G.fst

# The output is like:
# 9.14233e-05 -0.259833
# we do expect the first of these 2 numbers to be close to zero (the second is
# nonzero because the backoff weights make the states sum to >1).
# Because of the <s> fiasco for these particular LMs, the first number is not
# as close to zero as it could be.

# Everything below is only for diagnostic.
# Checking that G has no cycles with empty words on them (e.g. <s>, </s>);
# this might cause determinization failure of CLG.
# #0 is treated as an empty word.
mkdir -p $tmpdir/g
awk '{if(NF==1){ printf("0 0 %s %s\n", $1,$1); }} END{print "0 0 #0 #0"; print "0";}' \
  < "$lexicon"  >$tmpdir/g/select_empty.fst.txt
fstcompile --isymbols=$test/words.txt --osymbols=$test/words.txt $tmpdir/g/select_empty.fst.txt | \
 fstarcsort --sort_type=olabel | fstcompose - $test/G.fst > $tmpdir/g/empty_words.fst
fstinfo $tmpdir/g/empty_words.fst | grep cyclic | grep -w 'y' && 
  echo "Language model has cycles with empty words" && exit 1
rm -r $tmpdir/g
utils/validate_lang.pl $test|| exit 1

echo "$0 Succeeded in formatting data."

exit 0

