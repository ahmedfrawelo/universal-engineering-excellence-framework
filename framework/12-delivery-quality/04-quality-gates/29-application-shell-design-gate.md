# Application Shell Design Gate

Release-blocking for shared sidebar, header, navigation, shell, route-transition, or global page-chrome work.

Pass only when the existing shell baseline is extracted, shared contracts are reused, navigation and permission behavior are explicit, page regions and route transitions are stable, motion is accessible and interruptible, responsive/input modes are tested, loading and reconciliation states are defined, and visual/performance evidence covers representative viewports.

Fail on feature-specific shell forks, route state based only on click history, hover-only navigation, stale transition queues, focus loss, inaccessible collapsed navigation, layout shift, duplicate global subscriptions, or screenshots that omit loading/error/RTL/reduced-motion states.
