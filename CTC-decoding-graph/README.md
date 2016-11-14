# Toy example for building CTC-ASR decoding graph


## step 1: install [kaldi-ctc](https://github.com/lingochamp/kaldi-ctc)

inorder to use `ngram-count`, you should install srilm
`kaldi-ctc/tools/extras/install_srilm.sh`

edit path.sh, set `KALDI_ROOT=Your kaldi-ctc path`

## step 2: link steps utils
```
steps -> kaldi-ctc/egs/wsj/s5/steps
utils -> kaldi-ctc/egs/wsj/s5/utils
```

bash toy\_decode\_graph.sh

