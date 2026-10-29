# TurAIsta paper: datasets, approaches, results

Full paper: `paper/TurAIsta_AIETR_v2.docx` (13 pages). Every number traces to a notebook cell in `paper/claims_check.md`.

## Datasets

1. **FLEURS (test split)**: read speech, 100 utterances each for Tagalog and Cebuano. For speech recognition. No Ilocano.
2. **FLORES+ (devtest)**: 100 sentences per direction, 15 directions. For translatio    n.
3. **Farm-phrase check**: 5 English farm-tour questions translated into Tagalog, Cebuano and Ilocano. Checked by reading the outputs.
4. **Template-generated farm-tour messages**: 306 templates in en/tl/ko/ja/zh, giving 1,310 training and 250 test sentences. Split by template (20% test, seed 13). Framed as a test instrument for the study, not a released dataset.
5. **MASSIVE 1.1**: 300 extra OTHER examples (60 per language), training only.
6. **Hand-written test messages**: 22 (Taglish, typos, casual chat).

## Models

- MMS-1B-all (speech recognition), MMS-TTS (speech output)
- NLLB-200 distilled 600M (translation)
- Qwen2.5-0.5B-Instruct + LoRA (intent model), exported to GGUF q8_0 (507 MB), runs offline on the phone

## Approaches

| # | Approach | Data | Model / tool | Settings | Metric |
| --- | --- | --- | --- | --- | --- |
| 1 | Coverage audit | Released checkpoints and dataset configs | Hugging Face Hub | Loaded each model and test set per language | Supported or not |
| 2 | Speech recognition benchmark | FLEURS test, 100 utterances each, Tagalog and Cebuano | MMS-1B-all with language adapters | First 100 distinct sentences; lowercased, punctuation removed | Word error rate (WER) |
| 3 | Translation benchmark | FLORES+ devtest, 100 sentences per direction | NLLB-200 distilled 600M | Beam size 4; en/ko/ja/zh to tl/ceb/ilo, and tl/ceb/ilo to en (15 directions) | chrF++ |
| 4 | Farm-phrase safety check | 5 English farm-tour questions | NLLB-200 distilled 600M | Translated into tl, ceb, ilo | Key word kept or lost (read by hand) |
| 5 | Intent model fine-tuning | 1,610 training sentences (1,310 template + 300 MASSIVE) | Qwen2.5-0.5B-Instruct + LoRA | Rank 16, alpha 32, dropout 0.05; 3 epochs; batch 16; lr 2×10⁻⁴; loss on JSON answer only; 8.8M trainable params (1.75%) | Accuracy, safety recall, valid JSON, exact slots |
| 6 | Keyword safety rule | Same 250 test + 22 hand-written messages | Fixed keyword list (en, tl/Taglish, ko, ja, zh) | Any safety word forces DIETARY_SAFETY | Safety recall with vs. without the rule |
| 7 | App guardrails | Farm profile entered by the host | Flutter app, llama.cpp on phone CPU | Context 512, 4 threads, greedy decoding, JSON grammar; keywords decide alone if the model takes over 3 s | Unit tests (no field test yet) |

1. **Coverage audit.** We loaded each released model checkpoint and dataset configuration to check which of the seven languages each one supports (Tagalog, Cebuano, Ilocano, English, Korean, Japanese, Chinese).
2. **Speech recognition benchmark.** We ran MMS-1B-all with its Tagalog and Cebuano adapters on the first 100 distinct FLEURS test sentences per language. Word error rate was computed after lowercasing and removing punctuation.
3. **Translation benchmark.** We translated 100 FLORES+ devtest sentences per direction with NLLB-200 distilled 600M (beam size 4). The directions were each guest language (English, Korean, Japanese, Chinese) into each host language (Tagalog, Cebuano, Ilocano), plus each host language into English. Outputs were scored with chrF++.
4. **Farm-phrase safety check.** We translated five farm-tour questions from English into each host language and checked whether the key words survived. The questions covered booking, price, directions, an allergy and trail safety.
5. **Intent model fine-tuning.** We generated farm-tour messages from 306 templates in five languages and split them by template: 20% of templates went to the test set (seed 13), so test sentences come from templates the model never saw. We added 300 harmless OTHER examples from MASSIVE. We then fine-tuned Qwen2.5-0.5B-Instruct with LoRA (rank 16, 3 epochs) to output the intent and slots as JSON. The five intents were BOOKING, PRICE, DIRECTIONS, DIETARY_SAFETY and OTHER. The model was exported to GGUF q8_0 (507 MB) to run offline on the phone.
6. **Keyword safety rule.** A fixed list of allergen, diet, health, child, accessibility and weather words covers English, Tagalog/Taglish, Korean, Japanese and Chinese. Any match forces the intent to DIETARY_SAFETY, whatever the model predicts. We compared safety recall with and without the rule.
7. **App guardrails.** Replies are built only from the host's confirmed farm profile. DIETARY_SAFETY and OTHER messages never get a draft. A translated reply must keep the same numbers as the English draft, or the app falls back to English. The host approves and sends every reply.

## Results

| What | Result | Figure / table |
| --- | --- | --- |
| Coverage | All 7 languages have speech recognition and translation. Gaps: no Ilocano speech test; no Japanese or Chinese MMS speech output | Figure 2 |
| Speech recognition WER | Tagalog 13.1%, Cebuano 14.4% (about 1 word in 7 wrong) | Figure 3 |
| Translation from English (chrF++) | tl 57.5, ceb 55.8, ilo 52.4 | Figure 4 |
| Translation from Korean, Japanese, Chinese | 39.4 to 43.8 (12 to 15 points lower) | Figure 4 |
| Translation into English | tl 65.6, ceb 64.7, ilo 60.1 | text |
| Safety failures | "allergic to peanuts" became seeds (tl), apples (ceb), vegetables (ilo); "Is the trail safe?" became "happy" (ceb) | Table 3 |
| Intent accuracy, 250 test messages | 96.0% model only, 98.4% with keyword rule | Figure 5 |
| Safety recall | 87.8% model only (missed 6 of 49), 100% with keyword rule | Figure 5 |
| Valid JSON / exact slots | 100% / 75.6% | text |
| 22 hand-written messages | 100% (version 1 was 81.8%) | text |

Figure 1 is the flowchart of how the app handles one guest message.

## Main finding

Offline small AI works for guest messages, but translation fails on safety words. So safety is handled by fixed rules outside the model, and the host approves every reply.

## Still to check

- A native speaker should confirm the glosses: seeds, apples, vegetables, happy
- Final author list (is Sir Inovero included?)
- AIETR page limit
