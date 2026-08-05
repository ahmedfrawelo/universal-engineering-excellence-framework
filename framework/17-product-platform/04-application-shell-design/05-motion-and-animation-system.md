# Motion and Animation System

- Define a small motion vocabulary for shell reveal, sidebar collapse, menu open, page enter, overlay, list staging, and feedback states.
- Motion communicates hierarchy and state; it must not delay usable content or compete with data loading.
- Use transform/opacity where possible, avoid layout-thrashing animation, and respect reduced-motion preferences by removing travel and parallax while preserving state clarity.
- Define duration, easing, interruption, cancellation, and rapid-repeat behavior. A new navigation action must not queue stale transitions.
- Test animation at slow CPU, reduced motion, keyboard use, touch, and route cancellation.
