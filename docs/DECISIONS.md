# DECISIONS

Autonomous decisions taken during development (what, why).

- **D001 (stage 0):** `docs/00_TASK_PROMPT.md` already existed and is byte-identical in size to `PROMPT_atomic_bombs.md` (32151 bytes); kept as is.
- **D002 (stage 1):** Research is run as a parallel multi-agent workflow (8 bomb groups + 1 techniques agent), each agent writes `docs/research_parts/*.md` and downloads 2-4 public-domain reference images into `docs/refs/NN_name/`. A merge agent consolidates into `docs/RESEARCH_NOTES.md` and corrects `docs/01_BOMBS_REFERENCE.md`. Development of the skeleton proceeds in parallel in the main thread to save wall-clock time.
