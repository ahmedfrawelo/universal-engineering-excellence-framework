# Skeleton Loading System

Use a skeleton when the user is waiting for a known content structure. The skeleton must be a structural counterpart of the final page or component: same major regions, row count policy, approximate text lengths, image ratios, controls, and spacing. Do not use a generic spinner as the only loading state for a page whose layout is known.

The loading contract is: `loading -> content | empty | error | partial`. The transition must preserve container dimensions and focus behavior. A skeleton is not content and must not be announced as content by assistive technology.
