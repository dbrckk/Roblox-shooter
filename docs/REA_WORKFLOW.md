# REA analysis workflow

This repo actually runs **REA: Reverse Engineer Anything** in an isolated GitHub Actions workflow.

- Tool: `morluto/rea` via `rea-agents@6.8.0`
- Legal reference: [fully-ai-arena-fps](https://github.com/Hazzad123/fully-ai-arena-fps/tree/920b123d67015d5e8151a4ebd6742d8015d538be), MIT code. Copyright © 2026 Ben Darling. Third-party art has separate CC0 terms and is **not imported**.
- Reference: 6 arenas, deathmatch, team modes, bots, rounds, network snapshots; these properties are sourced from its upstream README and still need verifying in the actual code.
- Run: [GitHub Actions / REA FPS reference analysis](../.github/workflows/rea-fps-analysis.yml) or Actions → REA FPS reference analysis → Run workflow.
- Artifacts: JSON Evidence from REA + condensed report; GitHub Actions summary shows the verified REA output.
- Security: checkout fixed revision, no running the FPS untrusted scripts or installing its dependencies; REA works on static files. Not supported for reverse-engineering proprietary Roblox place files.
- Primary Roblox gameplay target remains RIVALS, cited as visual/game-design inspiration only. The actual REA target is a public open source FPS with permission to study.
