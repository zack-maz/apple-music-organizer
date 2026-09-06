# STATE

Where this project actually stands. Update this file when the library state
changes; it is the first thing to read when picking the work back up.

**Last updated:** 2026-09-05, end of the first working session.

---

## Library right now

| | |
| --- | ---: |
| Tracks in library | 2,487 |
| Genre playlists | 84 |
| Parent folders | 13 (inside `genres`) |
| Tracks filed | 2,487 (rows = distinct, 0 duplicates) |
| Downloaded | ~1,112 of 2,487 |
| Can never download | 20 |

Everything is lowercase — the `genres` folder, all 13 parent folders, all 84
playlists. Nothing is loose at the root. `wont download` sits at the **top
level**, deliberately outside `genres` so `--replace` does not delete it.

Folder rollup: hip-hop & rap 961 · rock & alternative 584 · electronic & dance
303 · r&b, soul & funk 179 · pop 145 · reggae & caribbean 87 · global & world 58
· latin & brazilian 48 · jazz & blues 47 · folk, country & songwriter 34 ·
ambient & instrumental 25 · soundtracks & screen 12 · other 4.

## In progress

**Downloads are still running** in the background inside Music. Roughly 1,112 of
2,487 tracks had local files at last check, moving at ~84 files/hour, so
**~16 hours remained**. Music works the queue in library order, not by playlist,
so coverage is lumpy: `alternative` was 89% done while `pop` was at 3/123.

A queued download **cannot be cancelled from a script** and Music may refuse to
quit while one is running. Stopping it is a UI action.

## The one thing to re-check

The genre structure was verified clean immediately after being built, but
**earlier builds looked clean too and were reverted by iCloud sync within
hours.** Whether this build survives is the open question.

```sh
./whats-new.applescript                    # should say everything is filed
./dedupe-playlists.applescript --dry-run   # should find no duplicates
```

Also confirm **nesting and casing**, not just track counts — that is the gap
that made an earlier "verified clean" report wrong:

- playlists should be nested in parent folders, not loose at the root of `genres`
- all folder and playlist names should be lowercase

If it has reverted, rebuild rather than repair:
`./build-genres.applescript --replace`.

## Why the scripts are shaped the way they are

**iCloud Music Library reverts modifications to synced objects, but lets
creations stand.** Confirmed four times in one session:

| Change | Kind | Outcome |
| --- | --- | --- |
| Deleted 1,346 duplicate rows | modify | reverted |
| Renamed 97 playlists to lowercase | modify | reverted |
| Moved 84 playlists into parent folders | modify | reverted |
| Created folders + playlists + contents | create | **held** |

Each time, exactly the objects that had been edited reverted while untouched
ones survived. Track membership, which came from creation, held every time.

`build-genres.applescript` therefore issues **no `move` and no rename** — every
playlist is created directly inside its parent folder, already lowercase, then
filled. That is why it replaced the original three-step pipeline.

## Known limits

- **20 tracks can never download** (cloud status `no longer available` — pulled
  from the Apple Music catalogue). They are collected in `wont download`.
- **Download state is not scriptable.** `downloaded` errors on subscription
  tracks and `whose downloaded is false` is unsupported. Presence of `location`
  is the only proxy, at one Apple event per track.
- **"Not downloaded" cannot mean "new."** That was the original idea; it does not
  work, because the 20 unavailable tracks are permanently un-downloaded.
  `whats-new.applescript` answers the real question instead, by comparing the
  library against the genre tree — exact, not a heuristic.
- **Genres are not merged**, by explicit preference. `hip-hop`, `rap`,
  `hip-hop/rap` and `uk hip-hop` are four playlists sharing one parent. Only
  case is folded.

## Not established

- Whether the current build survives extended sync. **The open question.**
- What originally duplicated the playlists three times over. A sync write
  conflict fits every observation, but the trigger was never identified.
- Whether playlist track order survives a `move`.
- Behavior on a local-only (non-iCloud) library — everything here ran against an
  iCloud-synced library that is 99% subscription tracks.

## Safety notes

- `backups/` is **gitignored** — it contains the full contents of the music
  library (titles, artists, albums) and does not belong in a repo.
- Playlist deletion is permanent: no trash, no undo, and it syncs to other
  devices. Take a backup before anything destructive.
- A script's success message is not evidence. Verify against the library.

## Reference

The Music.app AppleScript behaviors these scripts depend on — which commands
work, which fail and with what error codes — are summarised at the end of
README.md under "Notes for editing these scripts".
