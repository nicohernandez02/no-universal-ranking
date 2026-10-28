Optional self-test on synthetic data (no Gallup data needed, ~1 minute):
  1. Copy test/fake_main_pipeline.qmd to a scratch folder as no-universal-ranking.qmd
  2. Copy this whole revision folder next to it, as revision/
  3. In revision/: targets::tar_make()
If it finishes and writes test/out/revision/REVISION_SENTENCES.md, the setup works.
