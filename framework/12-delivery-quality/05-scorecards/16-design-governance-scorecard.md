# Design Governance Scorecard

Version: 1.2.0

Score applicable items from 0 to 4: 0 missing, 1 unsafe or inconsistent, 2 partial, 3 complete with evidence, 4 protected by automated regression checks.

| Domain | Criteria |
|---|---|
| Governance | Ownership; change control; source-of-truth traceability; exception expiry |
| Language | Visual hierarchy; interaction language; content density; state vocabulary |
| Tokens | Color; typography; iconography; spacing; sizing; radius; borders; shadows; elevation; motion; layers |
| Components | Contract; maturity; states; variants; accessibility; theme; responsive behavior; performance |
| Registry | Discoverability; owner; examples; adoption; deprecation and migration |
| Patterns | Forms; tables; cards; navigation; loading; empty; error; success; overlays; page templates |
| Reuse | Existing search; reuse decision; duplicate prevention; design drift remediation |
| Product quality | Theme; responsive; accessibility; interaction; performance; visual regression evidence |

Any critical token bypass, duplicate capability, missing accessibility, broken theme, or inconsistent overlay forces FAIL regardless of average. Otherwise, pass requires every applicable item at least 3 and 80 percent overall.
