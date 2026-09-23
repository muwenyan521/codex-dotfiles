---
name: tldr
description: Append a one-line TLDR summary to the prior response. Use only when the user explicitly invokes `$tldr` or asks for a one-sentence TLDR of the previous answer.
---

Append exactly one line as a TLDR summary of the prior response for the user to fast-read the verdict.

Format strictly:
  📌 <verdict in under 20 words>

Rules:
  - Write the verdict in the same language as your previous response.
  - Lead with the key verdict / answer / decision — not a recap of topics.
  - One sentence, hard cap 20 words.
  - No new information, no caveats, no bullet list.
  - Output ONLY that single summary line. Nothing else.
