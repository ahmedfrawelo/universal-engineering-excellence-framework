# Dead And Obsolete Code

Use at least two evidence sources before deletion: compiler or linter reachability, repository references, dependency graph, coverage, route or registry inspection, build output, runtime telemetry, production traces, or owner confirmation.

Check hidden reachability through reflection, dependency injection, dynamic imports, templates, configuration names, scheduled jobs, message handlers, database conventions, plugin registries, command-line entrypoints, native bindings, serialization, and generated code.

Delete in bounded groups, remove associated tests/configuration/assets/exports, and rerun the closest consumer and deployment checks. Quarantine uncertain code behind explicit deprecation with owner, evidence gap, telemetry plan, and removal date; do not silently delete it or leave it indefinitely.
