---
name: research-paper
description: How to write, revise and fact-check the TurAIsta research paper so it is publication-ready and credible - where every result number lives in notebooks/, the claim and citation rules, the paper structure, honest limitations, and a pre-submission checklist. Use when writing or editing anything in paper/, answering reviewer comments, or checking a number or citation in the manuscript.
---

# Writing the TurAIsta paper

A paper is credible when a reviewer can check it. Every number points to an output, every
citation points to a page you opened, and every weakness is stated before a reviewer finds it.

## 1. Evidence map: where each result lives

Copy numbers from these outputs only. Cell ids are the notebook cell ids.

| Result | Value | Source |
| --- | --- | --- |
| MMS speech recognition coverage | all 7 languages | `notebooks/turaista-dataset-audit.ipynb`, cell `74048176` |
| MMS speech output coverage | no Japanese, no Chinese | same cell |
| NLLB-200 language support | all 7 | dataset-audit, cell `6f8b755f` |
| FLORES+ Tagalog | not under `tgl_Latn`; found by prefix lookup | dataset-audit `6f8b755f`; model-eval `4d4ecb7a` |
| FLEURS coverage and hours | no Ilocano; tl 7.71 h, ceb 12.17 h train | dataset-audit, cell `6b4b1f29` |
| Speech recognition WER (MMS-1B-all, FLEURS test, n = 100) | tl 13.1%, ceb 14.4% | `notebooks/turaista-model-eval.ipynb`, cells `8bd52046`, `79bdc21e` |
| Translation chrF++ (NLLB-200 600M, FLORES+ devtest, n = 100) | 15 directions | model-eval, cell `79bdc21e` |
| Farm-phrase translations (peanut, trail) | seeds / apples / vegetables; "Malipayon" | model-eval, cell `0f971a9d` |
| Speech output samples | 3 phrases, no scores | model-eval, cell `6696713c` |
| Intent training and test sizes | train 1,610; test 250; class counts | `notebooks/turaista-intent.ipynb`, cells `8` and `10` |
| Wild test messages | 22 | intent, cell `12` |
| LoRA settings and loss | r 16, 8.8M params, loss 0.0950 → 0.0013 | intent, cell `16` |
| Intent results | 96.0% → 98.4%; safety recall 0.878 → 1.0; slots 75.6% | intent, cell `18` |
| v1 results | 98.1% template, 81.8% wild | intent, cell `0` (markdown) |
| Example error | "Salamat po sa masarap na lunch!" → PRICE | intent, cell `20` |
| GGUF export | q8_0, 507 MB on disk | intent, cell `22`; `README.md` |
| App rules and runtime | guardrail, number check, ctx 512, 4 threads, 3 s fallback | `README.md`, `lib/core/`, `CLAUDE.md` |
| Detector recall, pivot vs direct, allergen preservation | **no saved outputs** | `notebooks/turaista-safety-layer.ipynb`: do not report |

Notebooks hide long outputs from the Read tool. Extract a cell's text output with:
`powershell: (Get-Content -Raw -Encoding utf8 <nb> | ConvertFrom-Json).cells[<index>].outputs`.

A number not in this table needs a new row here before it goes in the paper.

## 2. Claim rules

- **Every number** → a row in `paper/claims_check.md`: claim, value, source, status.
- **Every derived number** (a range, a difference, "missed 6 of 49") → show the
  arithmetic in `claims_check.md` (0.878 × 49 = 43, so 6 missed).
- **Every citation** → open the page (WebFetch) and confirm authors, year, title, venue and
  the specific finding you cite. A search snippet is not a source. Unopened →
  `[CITATION NEEDED]`.
- **Say what was measured, on what, with what n.** "chrF++ 57.5 on 100 FLORES+ devtest
  sentences", never "translation is good".
- **Match claim strength to evidence.** One run with no confidence interval → "scored",
  not "outperforms". Five phrases → "in our examples", not "NLLB fails on allergens".
- **Separate what the app does from what was tested.** The app translates with ML Kit and
  listens with Android speech; the notebooks tested NLLB-200 and MMS. The intent model was
  evaluated in fp16 before GGUF conversion. Say so wherever it matters.
- **No result from code that has no output.** If it is not printed in a notebook or a
  test log, it is not a result.

## 3. Structure

| Section | What it must contain |
| --- | --- |
| Title | System name, what it does, who for, where. No claims of superiority. |
| Abstract | Problem, what was built, 3 to 5 key numbers with their test sets, the one lesson. 200 to 250 words. |
| 1. Introduction | The host's problem, why generic chatbots fail, research question with 3 sub-questions, contributions as a numbered list. Do not mention TurAIsmo. |
| 2. Related work | Four short themes: tourism language barriers; MT errors in high-stakes text; low-resource Philippine NLP; small AI with a human in the loop. End each with how TurAIsta differs. |
| 3. System | Four stages (table), message pipeline (numbered), rules enforced in code. |
| 4. Data and models | Datasets and models (table), templates, split by template, training settings, keyword rule. |
| 5. Results | One subsection per sub-question. Table caption above, one-sentence finding first. |
| 6. Discussion | Answers to each sub-question, then 2 to 3 design lessons. |
| 7. Limitations | Numbered, specific, each with its consequence. |
| 8. Conclusion | One paragraph: what holds, what does not, next step. No new numbers. |
| Data and code availability | Repo, notebooks, model file, licenses. |
| References | APA 7, alphabetical, DOI or URL. |

## 4. Limitations that must appear

1. Tagalog, Korean, Japanese and Chinese templates are not reviewed by native speakers.
2. The 22-message wild set was reused after v1 errors, so v2's 100% is a development score.
3. The same team wrote the safety templates and keyword list; over-blocking of harmless
   messages (children, seniors) was not measured.
4. Tested models differ from shipped components (ML Kit, Android speech, fp16 vs q8_0 GGUF).
5. 100 items per language or direction, one run, no confidence intervals; the
   allergen finding rests on 5 phrases.
6. No Ilocano speech test (FLEURS has none); no Japanese or Chinese MMS speech output.
7. No field study with hosts or guests; no on-phone latency or memory numbers.

Add a limitation when a new weakness is found. Never remove one to make the paper look stronger.

## 5. Credibility signals reviewers look for

- Test data never seen in training: say the split is by template, with seed 13.
- Baselines: report model-only vs model + keyword rule (already measured).
- Failure cases shown, not only successes (Table of mistranslations; the "lunch" error).
- Version history told honestly (v1 81.8% → v2 after targeted fixes).
- Ethics: no personal data collected; host profile stays on the phone; nothing is sent
  without host approval; preferences asked, not inferred.
- Reproducibility: name model ids, dataset versions, seeds, hardware (Kaggle T4), and where
  the notebooks and GGUF file are.

## 6. Figures

- Times New Roman in every figure, to match the body text.
- Process diagrams use standard flowchart symbols: terminator (rounded ends) for start and
  end, parallelogram for input, rectangle for a process step, diamond for a decision with
  labelled Yes/No exits, and arrows for flow. One accent colour marks the path the figure
  is about.
- Charts: title states the finding, axes labelled with units, bars start at zero, values
  printed on the marks, n stated.
- Regenerate with `paper/figures/make_figures.py`; never edit a PNG by hand.

## 7. Style

- Short sentences, one idea each. Active voice. Plain words.
- No em dashes. No hype: novel, groundbreaking, robust, seamless, state-of-the-art,
  revolutionize, leverage.
- Numbers with units and n. Percentages to one decimal, chrF++ to one decimal.
- Language names in full (Tagalog, not tl) in prose; codes only in tables if needed.
- Tables: caption above ("Table 3. ..."), every column has a unit.

## 8. Pre-submission checklist

- [ ] Every number in `manuscript.md` has a verified row in `claims_check.md`.
- [ ] No `[CITATION NEEDED]` or `[NUMBER NEEDED]` left, or each is removed with its claim.
- [ ] Every reference opened and checked; DOIs resolve.
- [ ] Abstract numbers match Results tables exactly.
- [ ] Every sub-question in the introduction is answered in the discussion.
- [ ] All seven limitations in section 4 are present.
- [ ] Authors, affiliations and emails confirmed by the user.
- [ ] Venue page limit and template checked (ask the user for the call for papers).
- [ ] Data and code availability statement written.
- [ ] Run `filipino-localization-reviewer` on any Tagalog, Cebuano or Ilocano text quoted
      in the paper.
