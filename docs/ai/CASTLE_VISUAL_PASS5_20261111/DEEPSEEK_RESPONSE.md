NON-BLOCKER

- Residual perf risk: courtyard run reached 188.32 ms vs prior max 187.92 ms (+0.40 ms, ~0.2%); likely noise but should remain monitored.
- Residual visual risk: darker/smaller 12-sided roofs and narrower five-tier pinnacles may alter silhouette/readability versus prior 20-sided roofs; screenshots passed, so no concrete blocker.
- Residual geometry risk: 4 cm vertical overlaps and alternating 0/45° stacks could produce minor z-fighting or shadow acne at distance; not evidenced by passed geometry/screenshot checks.
- Residual cascade risk: intentional architecture cascade count shift 62→66 must be treated as expected only for the seated-finial-with-selected-stack case; any other group-count drift would be a blocker.
- No blocker: counts remain 61886/343/1776/2207; no instances added; regression, pass2, single-brick, architecture cascade, and screenshot checks passed.