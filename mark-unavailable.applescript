#!/usr/bin/osascript
--
-- mark-unavailable.applescript
--
-- Collects every track Apple has pulled from the catalogue (cloud status
-- `no longer available`) into one playlist. These can never download, so they
-- would otherwise sit in the library looking permanently un-downloaded and
-- defeat any "not downloaded means new" check.
--
-- The playlist is created at the top level, deliberately outside the genre
-- folder, so `organize-by-genre --replace` does not take it with the folder.
--
-- Rebuilds rather than repairs: the playlist is deleted and recreated, because
-- row-level edits to a synced playlist get reconciled against the server copy.
--
-- Usage:
--   ./mark-unavailable.applescript [--dry-run] [--name NAME]
--

use AppleScript version "2.4"
use scripting additions

property defaultName : "wont download"

on run argv
	set plName to defaultName
	set dryRun to false

	set i to 1
	repeat while i ≤ (count of argv)
		set a to item i of argv
		if a is "--dry-run" then
			set dryRun to true
		else if a is "--name" then
			set i to i + 1
			if i > (count of argv) then error "--name needs a value."
			set plName to item i of argv
		else if a is "-h" or a is "--help" then
			return "Usage: mark-unavailable.applescript [--dry-run] [--name NAME]"
		else
			error "Unknown option: " & a
		end if
		set i to i + 1
	end repeat

	tell application "Music"
		if it is not running then launch
		set lib to library playlist 1
		-- Each of these must re-state the `whose` clause. Storing the result in a
		-- variable turns it into a resolved list, and `name of <list>` fails with
		-- -1728 -- the same reference-vs-list rule that governs `duplicate`.
		with timeout of 1800 seconds
			set howMany to count of (every track of lib whose cloud status is no longer available)
			set titleList to name of (every track of lib whose cloud status is no longer available)
			set whoList to artist of (every track of lib whose cloud status is no longer available)
		end timeout
	end tell

	set rowsOut to {}
	repeat with k from 1 to howMany
		set rowsOut to rowsOut & {"  " & (item k of whoList) & " — " & (item k of titleList)}
	end repeat

	if dryRun then
		set rowsOut to rowsOut & {"", "DRY RUN - would put " & howMany & " tracks in \"" & plName & "\"."}
		return my joinUp(rowsOut)
	end if

	if howMany is 0 then
		tell application "Music"
			if exists user playlist plName then delete user playlist plName
		end tell
		return "No unavailable tracks. Nothing to mark."
	end if

	tell application "Music"
		if exists user playlist plName then delete user playlist plName
		set p to make new user playlist with properties {name:plName}
		with timeout of 1800 seconds
			duplicate (every track of lib whose cloud status is no longer available) to p
		end timeout
		set landed to count of tracks of p
	end tell

	set rowsOut to rowsOut & {"", "Put " & landed & " of " & howMany & " unavailable tracks in \"" & plName & "\"."}
	return my joinUp(rowsOut)
end run

on joinUp(lst)
	set AppleScript's text item delimiters to linefeed
	set outText to lst as text
	set AppleScript's text item delimiters to ""
	return outText
end joinUp
