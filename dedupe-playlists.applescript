#!/usr/bin/osascript
--
-- dedupe-playlists.applescript
--
-- Removes duplicate entries from the playlists inside the genre folder,
-- keeping the first occurrence of each track. Only playlist membership is
-- changed: `delete track k of <user playlist>` removes the row, never the
-- track from the library (verified).
--
-- Usage:
--   ./dedupe-playlists.applescript [--dry-run] [--folder NAME]
--

use AppleScript version "2.4"
use framework "Foundation"
use scripting additions

property defaultFolderName : "genres"

on run argv
	set folderName to defaultFolderName
	set dryRun to false

	set i to 1
	repeat while i ≤ (count of argv)
		set a to item i of argv
		if a is "--dry-run" then
			set dryRun to true
		else if a is "--folder" then
			set i to i + 1
			if i > (count of argv) then error "--folder needs a value."
			set folderName to item i of argv
		else if a is "-h" or a is "--help" then
			return "Usage: dedupe-playlists.applescript [--dry-run] [--folder NAME]"
		else
			error "Unknown option: " & a
		end if
		set i to i + 1
	end repeat

	tell application "Music"
		if it is not running then launch
		set libBefore to count of tracks of library playlist 1
	end tell

	-- Capture targets by persistent ID; indexes are not stable across edits.
	set targets to {}
	tell application "Music"
		repeat with pi from 1 to (count of user playlists)
			try
				set pn to name of parent of user playlist pi
				set inScope to (pn is folderName)
				if not inScope then
					try
						if (name of parent of parent of user playlist pi) is folderName then set inScope to true
					end try
				end if
				if inScope then set end of targets to persistent ID of user playlist pi
			end try
		end repeat
	end tell

	set report to {}
	set totalRemoved to 0
	set touched to 0

	repeat with pid in targets
		set thisID to pid as text
		set idx to my findByID(thisID)
		if idx > 0 then
			tell application "Music"
				set p to user playlist idx
				set plName to name of p
				set ids to persistent ID of every track of p
			end tell

			-- forward pass marks every repeat of an id already seen
			-- NSMutableSet's set() collides with AppleScript's `set` keyword; alloc/init avoids it
			set seen to current application's NSMutableSet's alloc()'s init()
			set toDelete to {}
			repeat with k from 1 to (count of ids)
				set idk to (item k of ids) as text
				set isDup to (seen's containsObject:idk) as boolean
				if isDup then
					set end of toDelete to k
				else
					seen's addObject:idk
				end if
			end repeat

			if (count of toDelete) > 0 then
				set touched to touched + 1
				set end of report to "  " & plName & ": " & (count of ids) & " -> " & ((count of ids) - (count of toDelete)) & "   (removing " & (count of toDelete) & ")"
				if not dryRun then
					-- delete high indexes first so lower ones stay valid
					tell application "Music"
						repeat with j from (count of toDelete) to 1 by -1
							try
								delete track (item j of toDelete) of user playlist idx
							on error e
								log "    row " & (item j of toDelete) & " of " & plName & ": " & e
							end try
						end repeat
					end tell
				end if
				set totalRemoved to totalRemoved + (count of toDelete)
			end if
		end if
	end repeat

	tell application "Music"
		set libAfter to count of tracks of library playlist 1
	end tell

	set end of report to ""
	if dryRun then
		set end of report to "DRY RUN - would remove " & (totalRemoved as text) & " duplicate rows from " & (touched as text) & " of " & (count of targets) & " playlists."
	else
		set end of report to "Removed " & (totalRemoved as text) & " duplicate rows from " & (touched as text) & " of " & (count of targets) & " playlists."
	end if
	set end of report to "Library tracks: " & (libBefore as text) & " before, " & (libAfter as text) & " after."

	set AppleScript's text item delimiters to linefeed
	set out to report as text
	set AppleScript's text item delimiters to ""
	return out
end run

on findByID(pid)
	tell application "Music"
		repeat with pi from 1 to (count of user playlists)
			try
				if (persistent ID of user playlist pi) is pid then return pi
			end try
		end repeat
	end tell
	return 0
end findByID
