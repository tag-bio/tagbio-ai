# The `tagbio` plugin

Packages this repo's skills for `/plugin install`. The skills themselves live in `../../skills/` —
these are symlinks, so there is exactly one copy of each skill in the repo. Editing
`skills/<name>/` is all that a skill change requires.

Bump `version` in **both** `.claude-plugin/plugin.json` here and the matching entry in
`/.claude-plugin/marketplace.json` on every release, or installed users won't be offered the update.
`claude plugin tag` validates that the two agree and creates the release tag.
