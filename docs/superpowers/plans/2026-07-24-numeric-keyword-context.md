# Numeric Keyword Context Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent pure numeric keywords from blocking a substring inside a long numeric sequence while retaining short country-code prefixes and existing literal keyword behavior.

**Architecture:** Keep ordinary keywords in the existing Aho-Corasick matchers. Group numeric keywords by byte length in exact lookup tables so a shorter numeric prefix cannot mask a longer keyword at the same position. A small helper evaluates surrounding ASCII-digit context with the approved thresholds before accepting a numeric match.

**Tech Stack:** OpenResty LuaJIT, existing `ahocorasick` C module, `resty` unit runner, Docker Compose integration tests.

## Global Constraints

- Apply context filtering only to keywords matching `^%d+$`.
- Skip when `(relaxed_left >= 2 and relaxed_right >= 2) or contiguous_left >= 4 or contiguous_right >= 3`.
- Relaxed scans may skip at most one ASCII space; contiguous scans may not skip whitespace.
- Continue searching after a skipped numeric candidate.
- Preserve all non-numeric keyword matching behavior.

---

### Task 1: Numeric Context Helper

**Files:**
- Create: `openresty/lua/filter/numeric_keyword_context.lua`
- Create: `tests/test_numeric_keyword_context.lua`

**Interfaces:**
- Produces: `should_skip(data, begin_offset, end_offset) -> boolean`, where offsets are zero-based and inclusive.

- [ ] Write table-driven tests for no context, one-to-three digit prefixes, two-sided space-separated digits, four contiguous leading digits, and three contiguous trailing digits.
- [ ] Run `resty -I openresty/lua tests/test_numeric_keyword_context.lua` and verify failure because the module is absent.
- [ ] Implement byte-oriented ASCII digit scans and the approved predicate.
- [ ] Re-run the unit test and verify it passes.

### Task 2: Keyword Loader Integration

**Files:**
- Modify: `openresty/lua/filter/keyword_loader.lua`
- Create: `tests/test_numeric_keyword_context.sh`

**Interfaces:**
- Consumes: `numeric_keyword_context.should_skip(data, begin_offset, end_offset)`.
- Produces: `keyword_loader.find_match(data)` that ignores only numeric matches rejected by the helper.

- [ ] Add an integration test with numeric keywords `123` and `123456`; assert approved matches block, long-number contexts pass through, and a valid longer keyword still blocks after a skipped short prefix.
- [ ] Run the integration test and verify it fails before loader changes.
- [ ] Split numeric keyword construction by byte length, inspect only the positions that can satisfy the contiguous thresholds, and retain existing non-numeric matcher behavior.
- [ ] Re-run the integration test and verify it passes.

### Task 3: Regression Verification

**Files:**
- Modify: `README.md`

- [ ] Document the numeric context behavior and fixed thresholds in the keyword configuration section.
- [ ] Run `resty -I openresty/lua tests/test_numeric_keyword_context.lua`.
- [ ] Run `bash tests/test_numeric_keyword_context.sh`.
- [ ] Run `bash tests/test_keyword_chunked_loading.sh` and `bash tests/test_anchored_regex_rules.sh`.
