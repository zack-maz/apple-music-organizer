#!/usr/bin/osascript
--
-- organize-by-genre.applescript
--
-- Dumps every song in your Apple Music library into a playlist named after its
-- genre, and puts all of those playlists inside a folder (default: "genres").
--
-- Usage:
--   ./organize-by-genre.applescript [options]
--   osascript organize-by-genre.applescript [options]
--
-- Options:
--   --dry-run            Show what would be created; touch nothing.
--   --replace            Delete an existing folder of the same name first.
--   --folder NAME        Folder name to create (default: "genres").
--   --min-tracks N       Skip genres with fewer than N tracks (default: 1).
--   --unknown NAME       Playlist name for tracks with no genre.
--   -h, --help           Show this help.
--

use AppleScript version "2.4"
use framework "Foundation"
use scripting additions

property defaultFolderName : "genres"
property defaultUnknownName : "Unknown Genre"

on run argv
	set folderName to defaultFolderName
	set unknownName to defaultUnknownName
	set dryRun to false
	set replaceExisting to false
	set minTracks to 1

	set argCount to count of argv
	set i to 1
	repeat while i ≤ argCount
		set a to item i of argv
		if a is "--dry-run" then
			set dryRun to true
		else if a is "--replace" then
			set replaceExisting to true
		else if a is "--folder" then
			set i to i + 1
			set folderName to my requireValue(argv, i, "--folder")
		else if a is "--unknown" then
			set i to i + 1
			set unknownName to my requireValue(argv, i, "--unknown")
		else if a is "--min-tracks" then
			set i to i + 1
			set minTracks to (my requireValue(argv, i, "--min-tracks")) as integer
		else if a is "-h" or a is "--help" then
			return my helpText()
		else
			error "Unknown option: " & a & linefeed & my helpText()
		end if
		set i to i + 1
	end repeat

	-- ---- read the whole library in one Apple event ------------------------
	log "Reading library..."
	tell application "Music"
		if it is not running then launch
		set lib to library playlist 1
		with timeout of 3600 seconds
			set rawGenres to genre of every track of lib
		end timeout
	end tell

	set trackCount to count of rawGenres
	if trackCount is 0 then return "No tracks found in the library."

	-- normalise: missing value -> empty string
	set cleanGenres to {}
	repeat with g in rawGenres
		set gv to contents of g
		if gv is missing value then
			set end of cleanGenres to ""
		else
			set end of cleanGenres to gv as text
		end if
	end repeat

	-- ---- unique + sorted genre list, and per-genre counts -----------------
	set uniqueSet to current application's NSOrderedSet's orderedSetWithArray:cleanGenres
	set sortedGenres to (uniqueSet's array()'s sortedArrayUsingSelector:"localizedStandardCompare:") as list
	set countedSet to current application's NSCountedSet's setWithArray:cleanGenres

	log ((count of sortedGenres) as text) & " genres across " & (trackCount as text) & " tracks."

	-- ---- dry run just reports --------------------------------------------
	if dryRun then
		set report to {"DRY RUN - nothing was created.", "Folder: " & folderName, ""}
		repeat with g in sortedGenres
			set gs to g as text
			set n to (countedSet's countForObject:gs) as integer
			if n ≥ minTracks then
				set end of report to my pad(n) & "  " & my playlistNameFor(gs, unknownName)
			end if
		end repeat
		set AppleScript's text item delimiters to linefeed
		set out to report as text
		set AppleScript's text item delimiters to ""
		return out
	end if

	-- ---- create (or replace) the folder ----------------------------------
	tell application "Music"
		if exists folder playlist folderName then
			if replaceExisting then
				log "Deleting existing folder \"" & folderName & "\"..."
				delete folder playlist folderName
			else
				error "A folder playlist named \"" & folderName & "\" already exists. Rerun with --replace to overwrite it, or use --folder NAME."
			end if
		end if
		set theFolder to make new folder playlist with properties {name:folderName}
	end tell

	-- ---- one playlist per genre ------------------------------------------
	set madeCount to 0
	set copiedCount to 0
	set skippedCount to 0

	repeat with g in sortedGenres
		set gs to g as text
		set expected to (countedSet's countForObject:gs) as integer
		if expected < minTracks then
			set skippedCount to skippedCount + 1
		else
			set plName to my playlistNameFor(gs, unknownName)
			log "  " & plName & " (" & (expected as text) & ")"

			tell application "Music"
				set thePlaylist to make new user playlist at theFolder with properties {name:plName}
			end tell

			-- Music only accepts a reference expression here, not a resolved list,
			-- so copy the whole genre in one event and fall back to track-by-track.
			set copied to 0
			try
				tell application "Music"
					with timeout of 3600 seconds
						duplicate (every track of lib whose genre is gs) to thePlaylist
					end timeout
				end tell
			on error bulkErr
				log "    bulk copy failed (" & bulkErr & "); falling back to one at a time"
				tell application "Music"
					with timeout of 3600 seconds
						set matches to (every track of lib whose genre is gs)
					end timeout
				end tell
				repeat with t in matches
					try
						tell application "Music" to duplicate (contents of t) to thePlaylist
					on error trackErr
						log "    skipped a track: " & trackErr
					end try
				end repeat
			end try

			tell application "Music" to set copied to (count of tracks of thePlaylist)
			if copied is 0 then
				tell application "Music" to delete thePlaylist
				set skippedCount to skippedCount + 1
			else
				set madeCount to madeCount + 1
				set copiedCount to copiedCount + copied
			end if
		end if
	end repeat

	return "Done. Created " & (madeCount as text) & " playlists in \"" & folderName & "\" holding " & (copiedCount as text) & " tracks (" & (skippedCount as text) & " genres skipped by --min-tracks)."
end run

on playlistNameFor(g, unknownName)
	if g is "" then return unknownName
	return g
end playlistNameFor

on requireValue(argv, i, flagName)
	if i > (count of argv) then error flagName & " needs a value."
	return item i of argv
end requireValue

on pad(n)
	set s to n as text
	repeat while (length of s) < 6
		set s to " " & s
	end repeat
	return s
end pad

on helpText()
	return "Usage: organize-by-genre.applescript [options]
  --dry-run        Show what would be created; change nothing.
  --replace        Delete an existing folder of the same name first.
  --folder NAME    Folder to create (default: genres).
  --min-tracks N   Skip genres with fewer than N tracks (default: 1).
  --unknown NAME   Playlist name for tracks with no genre (default: Unknown Genre).
  -h, --help       Show this help."
end helpText
