# Reuse And Update Policy

Search shared loading primitives, component contracts, page templates, and pattern-library entries before creating a skeleton. Reuse an existing skeleton when semantic structure and states match. Extend it when one shared variant can serve multiple real consumers. Create a new variant only with an owner, name, supported states, responsive limits, token mapping, and tests.

Never create a second skeleton for the same page region. When an existing component changes, update its skeleton in the same change and record the affected consumers.

Reusable skeleton behavior must live in the existing design-system or shared UI owner and be exported through its public API. Register primitives and composed recipes in the component registry with ownership, supported states, token mapping, accessibility behavior, and migration status. Feature code may compose domain-specific structure from shared primitives, but it must not redefine animation, timing, color, radius, accessibility, or base geometry locally.

Promote a recipe after two proven consumers or a clear cross-product contract. Architecture checks must reject a page-local primitive or recipe when an equivalent registered capability already exists. Tests must cover the shared contract and at least one real consumer.
