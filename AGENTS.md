# Repository instructions

## Phase completion and manual acceptance

- Use `PLAN.md` as the implementation and acceptance tracker. Complete phases in order.
- Before declaring a phase complete, finish its implementation, documentation, and applicable automated validation. Every checkbox remaining in that completed phase must be checked and supported by completed work or recorded evidence.
- As each phase completes, move all manual/in-game acceptance checks into `## Manual Acceptance` in `PLAN.md`, immediately before `## Definition of Done`. Group checks by their originating phase and retain links to detailed procedures and evidence.
- Run outstanding manual acceptance after all implementation phases are complete. Deferred checks remain unchecked until actually performed or explicitly confirmed by the user; moving a check does not make it pass. Preserve existing confirmed results.
- Split mixed implementation/manual items: finish and check the implementation in its phase, and retain the full live-verification obligation in Manual Acceptance. Track release metadata/documentation requiring live evidence with final manual release checks.
- Keep future implementation work in its owning future phase. Do not move unfinished implementation to Manual Acceptance or check it merely to close a phase. Future phases remain unchecked until their work is complete.
- Record validation performed and unavailable tooling honestly. Keep acceptance status references consistent in supporting documentation. Final Definition of Done and release readiness require outstanding manual checks and release finalization to pass.

## Validation

Run `python Tests/run_tests.py` (or `py Tests/run_tests.py` on Windows) with `lupa` available for all mocked Lua 5.1 suites, syntax checks, and manifest validation. Use `--package <output.zip>` when preparing a clean-install candidate. Automated checks do not replace live WoW acceptance.
