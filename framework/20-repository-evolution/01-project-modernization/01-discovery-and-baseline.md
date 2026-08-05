# Discovery And Baseline

Start with `scripts/project-context-map.ps1` or its Unix equivalent, then inspect manifests, lockfiles, workspace definitions, module aliases, barrel exports, routes, registries, public APIs, service clients, stores, jobs, migrations, generated code, tests, CI, deployment, and runtime configuration.

Record:

- supported user and machine workflows;
- build, test, startup, deployment, and recovery commands;
- module and ownership boundaries;
- public and dynamic entrypoints;
- performance and reliability baselines;
- security and authorization boundaries;
- current runtime, framework, SDK, database, package-manager, and infrastructure versions;
- known debt with evidence rather than assumption.

Do not infer that an unreferenced symbol is dead until dynamic imports, reflection, templates, dependency injection, serialization, configuration, plugins, scripts, jobs, and generated consumers are checked.
