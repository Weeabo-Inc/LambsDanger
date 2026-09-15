# Acceptance tests

One folder per system, each a mission folder that can be copied to the game's `missions`
(or `mpmissions`) directory and opened in Eden or run on a dedicated server. Every mission
prints what the system believes to the RPT so a run can be read afterwards, and every test
lists the numbered checks from its system note in `docs/systems/`.

| Folder | System note | Checks |
|---|---|---|
| `knowledge.Stratis` | [knowledge.md](../docs/systems/knowledge.md) | 1 to 5 |
| `morale.Stratis` | [morale.md](../docs/systems/morale.md) | 1 to 5 |
| `contact.Stratis` | [tactics.md](../docs/systems/tactics.md) | 1 to 5 |
| `director.Stratis` | [director.md](../docs/systems/director.md) | 1 to 4 |
| `zeus.Stratis` | [zeus.md](../docs/systems/zeus.md) | 1 to 5 |
| `arms.Stratis` | [combined-arms.md](../docs/systems/combined-arms.md) | 1 to 5 |

How to run a test:

1. Copy the folder to `<profile>/missions/` (single player or hosted) or `mpmissions/` on the
   dedicated server, load it, and play as the one BLUFOR unit.
2. Set the `hostis_core_debugPicture` setting on to watch the pictures on the map.
3. Follow the steps in the folder's `README.md`; the RPT lines are prefixed `HOSTIS TEST`.
