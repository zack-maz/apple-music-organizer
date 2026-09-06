#!/usr/bin/osascript
--
-- download-genres.applescript
--
-- Walks the genre playlists one at a time, reports how many of each playlist's
-- tracks already have a local file, and asks Music to download the rest.
--
-- Music has no readable "is this downloaded" property on subscription tracks
-- (`downloaded` errors, and `whose downloaded is false` is unsupported), so
-- presence of `location` is used as the proxy: it raises an error when the
-- track has no local file.
--
-- `download` only queues -- it returns immediately and Music works through the
-- queue in the background. Re-run this later to see progress.
--
-- Usage:
--   ./download-genres.applescript [--dry-run] [--folder NAME]
--
--   --dry-run   Report per-playlist download state; queue nothing.
--

use AppleScript version "2.4"
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
			return "Usage: download-genres.applescript [--dry-run] [--folder NAME]"
		else
			error "Unknown option: " & a
		end if
		set i to i + 1
	end repeat

	tell application "Music"
		if it is not running then launch
	end tell

	-- capture targets by persistent ID; indexes shift as Music reorders
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

	set rowsOut to {}
	set grandHave to 0
	set grandMiss to 0
	set grandStuck to 0
	set queued to 0

	repeat with pid in targets
		set thisID to pid as text
		set idx to my findByID(thisID)
		if idx > 0 then
			tell application "Music"
				set plName to name of user playlist idx
				set howMany to count of tracks of user playlist idx
			end tell

			set haveN to 0
			set missN to 0
			set stuckN to 0
			tell application "Music"
				with timeout of 3600 seconds
					repeat with k from 1 to howMany
						set gotFile to true
						try
							get location of track k of user playlist idx
						on error
							set gotFile to false
						end try
						if gotFile then
							set haveN to haveN + 1
						else
							-- tracks pulled from the catalogue can never download
							set gone to false
							try
								if (cloud status of track k of user playlist idx) is no longer available then set gone to true
							end try
							if gone then
								set stuckN to stuckN + 1
							else
								set missN to missN + 1
							end if
						end if
					end repeat
				end timeout
			end tell

			set grandHave to grandHave + haveN
			set grandMiss to grandMiss + missN
			set grandStuck to grandStuck + stuckN

			set suffix to ""
			if stuckN > 0 then set suffix to "   (" & stuckN & " unavailable)"
			set rowsOut to rowsOut & {"  " & plName & ": " & haveN & "/" & howMany & suffix}

			if missN > 0 and not dryRun then
				try
					tell application "Music"
						with timeout of 600 seconds
							download user playlist idx
						end timeout
					end tell
					set queued to queued + 1
				on error e
					log "  could not queue " & plName & ": " & e
				end try
			end if
			log "  " & plName & ": " & haveN & "/" & howMany & suffix
		end if
	end repeat

	set rowsOut to rowsOut & {""}
	set rowsOut to rowsOut & {"Downloaded:  " & grandHave & " of " & (grandHave + grandMiss + grandStuck)}
	set rowsOut to rowsOut & {"Pending:     " & grandMiss}
	set rowsOut to rowsOut & {"Unavailable: " & grandStuck & "  (pulled from the catalogue - these can never download)"}
	if dryRun then
		set rowsOut to rowsOut & {"DRY RUN - nothing queued."}
	else
		set rowsOut to rowsOut & {"Queued " & queued & " playlists for download."}
	end if

	set AppleScript's text item delimiters to linefeed
	set outText to rowsOut as text
	set AppleScript's text item delimiters to ""
	return outText
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
