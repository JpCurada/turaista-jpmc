# Claims check

Every number and factual claim in `manuscript.md`, with its source. Notebook cells are
given by cell id (model-eval, dataset-audit) or cell index (intent).

## Results from notebooks

| Claim | Value | Source | Status |
| --- | --- | --- | --- |
| MMS speech recognition covers all 7 languages | tl, ceb, ilo, en, ko, ja, zh | dataset-audit `74048176` | verified |
| MMS speech output missing for Japanese and Chinese | "not covered" | dataset-audit `74048176` | verified |
| NLLB-200 supports all 7 languages | True for all | dataset-audit `6f8b755f` | verified |
| FLORES+ covers Tagalog | found by prefix lookup; used for en/ko/ja/zh->tl scores | dataset-audit `6f8b755f` (tgl_Latn missing), model-eval `4d4ecb7a` | verified |
| FLEURS has no Ilocano | `ilo: None` | dataset-audit `6b4b1f29` | verified |
| WER Tagalog | 13.1% on 100 utterances | model-eval `8bd52046`, `79bdc21e` | verified |
| WER Cebuano | 14.4% on 100 utterances | model-eval `8bd52046`, `79bdc21e` | verified |
| "About one word in seven" | 13.1% to 14.4% ≈ 1/7.6 to 1/6.9 | derived | verified |
| WER normalization | lowercase, punctuation removed | model-eval `8bd52046` (`norm`) | verified |
| One utterance per sentence id | `seen` set | model-eval `8bd52046` | verified |
| chrF++ en->tl/ceb/ilo | 57.5 / 55.8 / 52.4 | model-eval `79bdc21e` | verified |
| chrF++ ko->tl/ceb/ilo | 42.7 / 41.3 / 40.1 | model-eval `79bdc21e` | verified |
| chrF++ ja->tl/ceb/ilo | 42.3 / 42.0 / 39.4 | model-eval `79bdc21e` | verified |
| chrF++ zh->tl/ceb/ilo | 42.8 / 43.8 / 40.8 | model-eval `79bdc21e` | verified |
| chrF++ tl/ceb/ilo->en | 65.6 / 64.7 / 60.1 | model-eval `79bdc21e` | verified |
| Abstract range from English | 52.4 to 57.5 | min/max of en row | verified |
| Abstract range from ko/ja/zh | 39.4 to 43.8 | min/max of those rows | verified |
| "12 to 15 points higher" | tl: 14.7 to 15.2; ceb: 12.0 to 14.5; ilo: 11.6 to 13.0 | derived; ilo low end is 11.6, rounds to 12 | verified (rounded) |
| Ilocano weakest target from every source | 52.4, 40.1, 39.4, 40.8 lowest in each row | model-eval `79bdc21e` | verified |
| Beam size 4, n = 100 aligned by id | `num_beams=4`, `ids[:N_MT]` | model-eval `4d4ecb7a` | verified |
| Peanut -> seeds (tl), apples (ceb), vegetables (ilo) | "buto", "mansanas", "natnateng" | model-eval `0f971a9d` output; meanings stated in intent cell 5 docstring | verified; glosses need native-speaker confirmation |
| Trail safe -> "Malipayon" (ceb) | output text | model-eval `0f971a9d` | output verified; "happy" gloss needs native-speaker confirmation |
| Key words survived in booking/price/directions | output text | model-eval `0f971a9d` | verified by reading outputs; native review advised |
| 306 templates | en 66, tl 66, ko 58, ja 58, zh 58 | intent cell 6 (`T`, `CASUAL`) | verified by count |
| Split by template, 20%, seed 13 | `split_ids(test_frac=0.2, seed=13)` | intent cell 6 | verified |
| ~half of training sentences get chat variant | `messy_frac=0.5` | intent cell 6 | verified |
| 1,310 template train, 250 test | printout | intent cell 8 | verified |
| 300 MASSIVE OTHER, 60 per language, 8 labels | `PER_LANG = 60`, `OTHER_OK` | intent cell 10 | verified |
| Training 1,610; test class counts | BOOKING 109, DIETARY_SAFETY 49, PRICE 40, DIRECTIONS 40, OTHER 12 | intent cell 10 | verified |
| Wild set 22, 4 or 5 per language | tl 5, en 5, ko 4, ja 4, zh 4 | intent cell 12 | verified |
| LoRA r 16, alpha 32, dropout 0.05, all projections | config | intent cell 16 | verified |
| 8.8M trainable, 1.75% | 8,798,208; 1.7497% | intent cell 16 | verified |
| 3 epochs, batch 16, lr 2e-4 one-cycle | `EPOCHS, BS, LR` | intent cell 16 | verified |
| Loss 0.0950 -> 0.0013 | epoch printouts | intent cell 16 | verified |
| Accuracy 96.0% -> 98.4% | report printout | intent cell 18 | verified |
| Safety recall 0.878 -> 1.0 | report printout | intent cell 18 | verified |
| Missed 6 of 49 | 49 × (1 - 0.878) = 5.98 | derived | verified |
| 12.2% missed | 6 / 49 = 12.24% | derived | verified |
| Valid JSON 100%, slots 75.6% | report printout | intent cell 18 | verified |
| Accuracy by language | en 100, ja 97.6, ko 100, tl 96.2, zh 100 | intent cell 18 | verified |
| Wild 100% model only and with rule | report printout | intent cell 18 | verified |
| v1: 98.1% template, 81.8% wild | markdown | intent cell 0 | verified (author's note, v1 run not saved) |
| v1 missed "Bawal po ako sa gatas"; casual -> OTHER | markdown | intent cell 0 | verified (author's note) |
| "Salamat po sa masarap na lunch!" -> PRICE | printout | intent cell 20 | verified |
| GGUF q8_0, 507 MB | `ls -lh` 507M | intent cell 22; README | verified |
| Kaggle T4 GPU | setup checklist | all notebooks | verified |
| Qwen2.5-0.5B-Instruct base | `BASE` | intent cell 14 | verified |

## Facts from the repository

| Claim | Source | Status |
| --- | --- | --- |
| Flutter app, ~3 GB RAM Android, offline after language download | README "The problem", "What TurAIsta does" | verified |
| Four stages and their behaviour, read-back "Tama po ba na PHP 350 bawat tao?" | README table | verified |
| Facts only from FarmProfile; dietarySafety and other never drafted | CLAUDE.md, README "Why hosts can trust it" | verified |
| Number check with English fallback | README "Why hosts can trust it" | verified |
| Either model or keywords can block; model cannot unlock | README "Why hosts can trust it" | verified |
| llama.cpp CPU, context 512, 4 threads, greedy, grammar JSON, 3 s fallback | README "Speed settings" | verified |
| ML Kit translation and Android offline speech in the shipped app | README "How it works", "Setting up the phone" | verified |
| Profile local, backup off, preferences asked | README "Why hosts can trust it" | verified |
| Repository URL | README "Downloads" | verified |

## Citations

| Claim | Source | Status |
| --- | --- | --- |
| DOT director: lack of foreign language skills, especially Chinese | Ignacio (2018), page opened | verified (speaker: Benjamin F. Santiago, DOT Region V) |
| Small AI definition | World Bank (2026) brief, page opened | verified |
| MT helps hospitality but does not replace language skills | Carvalho (2024), page opened | verified |
| GT accuracy 92% Spanish, 81% Chinese; some significant-harm errors | Khoong et al. (2019); bibliographic data from PubMed; figures from UCSF release (EurekAlert) | verified via press release and PubMed record; full text not opened |
| Backtranslation helps detect harmful errors QE misses | Mehandru et al. (2023), ACL Anthology abstract | verified |
| Numerical mistranslation is a general issue | Wang et al. (2021), PDF abstract | verified |
| NLLB-200: 200 languages | NLLB Team et al. (2022), arXiv abstract | verified |
| MMS: 1,107 languages | Pratap et al. (2023), arXiv abstract | verified |
| FilBench: 27 LLMs; GPT-4o about 72%; covers Filipino, Tagalog, Cebuano | Miranda et al. (2025), arXiv abstract and HTML | verified |
| MASSIVE: 51 languages | FitzGerald et al. (2022), arXiv abstract | verified; Tagalog inclusion verified by `tl-PH` load in intent cell 10 |
| Pezego-HITL: policy-grounded LLM for extension in Ghana; surveyed officers and farmers | Li et al. (2026), arXiv abstract | verified |
| Message-level vs sentence-level suggestions | Fu et al. (2023), arXiv abstract | verified; venue name inferred from the CHI '23 DOI shown on arXiv |
| LoRA | Hu et al. (2021), arXiv | verified |
| chrF++ | Popović (2017), ACL Anthology | verified |
| FLEURS | Conneau et al. (2022), arXiv | verified |
| Qwen2.5 | Yang et al. (2024), arXiv | verified |

## Still open

- Native-speaker confirmation of the glosses in Table 3 (seeds, apples, vegetables, happy).
- Confirm the author list (currently Curada and Zaragoza; Zaragoza is corresponding author).
- AIETR page limit and template.
