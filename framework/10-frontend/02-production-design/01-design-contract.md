# DESIGN.md Contract

`DESIGN.md` is the portable, human-readable source of durable design identity. Its YAML frontmatter carries tokens; its Markdown sections explain rationale and application. It must include `name`, `colors`, `typography`, `spacing`, and `rounded`, plus the required sections enforced by `scripts/validate-design-contract.mjs`.

Unknown sections may remain. Duplicate second-level headings are invalid. A `STYLESEED.md` lock may narrow composition for one task, but it must record the current `DESIGN.md` SHA-256 and must not override its tokens or invariants.

Start from `framework/21-framework-resources/01-templates/31-design-contract-template.md`; validate the repository contract with:

```powershell
node .\scripts\validate-design-contract.mjs --path .\DESIGN.md
```
