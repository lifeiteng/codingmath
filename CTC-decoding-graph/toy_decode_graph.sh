
order=2
stage=0

. ./cmd.sh
. ./path.sh
. utils/parse_options.sh

if [ $stage -le 0 ];then
    mkdir -p data/lm
    mkdir -p data/local
    awk '{$1=""; print $0;}' data/train/text >data/local/text
    ngram-count -text data/local/text -order $order \
        -limit-vocab -vocab data/dict/toy.word \
        -unk -map-unk "<unk>" -lm data/lm/gram$order || exit 1;

    echo "========  format data ========"
    local/toy_format_data.sh --data data --lm-suffix "$order" data/lm/gram$order || exit 1
fi


if [ $stage -le 1 ];then
    rm -rf data/local/dict/
    local/toy_prepare_dict.sh --data data data/dict/toy.dict || exit 1;
    utils/prepare_lang.sh --share-silence-phones true \
        --position-dependent-phones false \
        --num-sil-states 1 --num-nonsil-states 1 \
        data/local/dict '!SIL' data/local/lang_tmp data/lang || exit 1;
fi


function drawpdf {
    isy=$1
    osy=$2
    dict=$3
    echo $isy $osy $dict
    fstdraw -isymbols=$isy -osymbols=$osy $dict.fst >$dict.dot; dot -Tps -Gsize=8,10.5 $dict.dot | ps2pdf - $dict.pdf
}

function drawpdfNoLabel {
    dict=$1
    echo $dict
    fstdraw $dict.fst >$dict.dot; dot -Tps -Gsize=8,10.5 $dict.dot | ps2pdf - $dict.pdf
}


if [ $stage -le 2 ];then
    echo "======== Lexicon PDF ========"
    drawpdf data/lang_$order/phones.txt data/lang_$order/words.txt data/lang_$order/L
    drawpdf data/lang_$order/phones.txt data/lang_$order/words.txt data/lang_$order/L_disambig
fi

if [ $stage -le 3 ];then
    echo "======== Grammar PDF ========"
    drawpdf data/lang_$order/words.txt data/lang_$order/words.txt data/lang_$order/G
fi

if [ $stage -le 4 ];then
    # echo "========  build one state tree ======== "
    # # Build a tree using our new topology.
    # steps/ctc/build_tree.sh --frame-subsampling-factor 1 --stage -10 --mono $mono \
    #     --leftmost-questions-truncate -1 \
    #     --cmd "$train_cmd" $TreeLeaves data/train $lang $ali_dir $treedir || exit 1;

    echo "======== CI/CD CTC decoding graph ========"
    dir=exp/mono_ctc_decoding_graph
    utils/mkgraph.sh --ctc --mono data/lang_$order exp/tree_mono $dir || exit 1

    drawpdf data/lang_$order/phones.txt data/lang_$order/words.txt data/lang_$order/tmp/LG
    drawpdfNoLabel $dir/HCLG
    drawpdfNoLabel $dir/CTC
fi

