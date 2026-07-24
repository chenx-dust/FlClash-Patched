---
name: write-release-notes
description: Use when drafting English GitHub Release notes for FlClash, comparing adjacent versions, or identifying the FlClash and mihomo upstream bases for a release.
---

# Write Release Notes

Create concise, user-facing English release notes from verified Git history. Work
read-only unless the user explicitly asks to update a file.

## Workflow

1. Run the context collector with the previous and current release refs:

   ```bash
   .agents/skills/write-release-notes/scripts/collect_context.sh v0.8.101 v0.8.102
   ```

2. Trust the collector's comparison base instead of assuming adjacent tags are
   ancestors. FlClash release tags can come from parallel histories.
3. Inspect the commits and focused diffs in the reported range. Expand vague
   subjects such as `Minor UI tuning` or `Improve memory safety` from their
   actual changes before writing.
4. Include user-visible features, behavior changes, reliability improvements,
   and release-impacting build or packaging fixes.
5. Exclude version bumps, cache commits, tests, generated files, refactors with
   no observable impact, and changes already present in the previous release.
6. Draft the result in English and return it directly in the conversation.
   Do not edit `CHANGELOG.md` or another file unless requested.

## Required Format

Start with the upstream bases:

```markdown
## Upstream Base

- **FlClash:** [`<branch>` at `<short-sha>`](<upstream-commit-url>)
- **mihomo:** [`<tag-or-short-sha>` at `<short-sha>`](<mihomo-tag-or-commit-url>)
```

Then use only the categories needed:

```markdown
## What's Changed

### Added

- ...

### Improved

- ...

### Fixed

- ...
```

## Upstream Rules

- Report the FlClash remote branch and merge-base commit used by the release,
  normally `upstream/dev`.
- Resolve the release's `core/mihomo` submodule pointer internally, then
  report the nearest tagged mihomo upstream base. Use the tag and its commit
  when a tag exists; otherwise use the commit.
- Prefer full commit links and tag links from the canonical upstream
  repositories:
  - FlClash: `https://github.com/chen08209/FlClash`
  - mihomo: `https://github.com/MetaCubeX/mihomo`
- Do not add a GitHub compare link unless the two release refs have been
  verified as a linear range.

## Writing Style

- Use concise imperative past-tense release language: `Added`, `Improved`,
  `Fixed`.
- Describe outcomes, not implementation details.
- Combine tightly related changes without hiding distinct user-facing fixes.
- Avoid claims not supported by the inspected diff.
