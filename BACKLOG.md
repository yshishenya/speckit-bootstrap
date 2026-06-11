# Backlog

## Remove temporary Linear cleanup

Status: planned

Bootstrap currently removes retired Linear integration files, generated
`speckit-linear*` skills, managed Linear instruction blocks, and Linear env keys
from existing projects.

Keep this cleanup in the current release line so old projects and worktrees can
self-clean on refresh.

In a later release, remove the Linear cleanup code once all active projects have
been refreshed and no installed Linear remnants remain.
