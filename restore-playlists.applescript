#!/usr/bin/osascript
--
-- restore-playlists.applescript
--
-- Recreates playlists from a backup directory written by backup-playlists.applescript.
-- Each .tsv holds one playlist: persistentID <tab> title <tab> artist <tab> album.
-- Tracks are matched by persistent ID against the library.
--
-- Usage:
--   ./restore-playlists.applescript backups/playlists-YYYYMMDD-HHMMSS [PlaylistName ...]
--
-- With no playlist names, every .tsv in the directory is restored except the
-- Apple built-ins (Music, Music Videos, Favorite Songs), which are smart
-- playlists that Music manages itself.
--

use AppleScript version "2.4"
use framework "Foundation"
use scripting additions

property builtIns : {"Music", "Music Videos", "Favorite Songs"}

on run argv
	if (count of argv) < 1 then error "Usage: restore-playlists.applescript <backup-dir> [PlaylistName ...]"
	set backupDir to item 1 of argv
	set wanted to {}
	if (count of argv) > 1 then set wanted to items 2 thru -1 of argv

	set fm to current application's NSFileManager's defaultManager()
	set allFiles to (fm's contentsOfDirectoryAtPath:backupDir |error|:(missing value)) as list

	set restored to 0
	set totalAdded to 0
	set report to {}

	repeat with f in allFiles
		set fname to f as text
		if fname ends with ".tsv" and fname is not "MANIFEST.tsv" then
			set fpath to backupDir & "/" & fname
			set blob to (current application's NSString's stringWithContentsOfFile:fpath encoding:(current application's NSUTF8StringEncoding) |error|:(missing value)) as text
			set rows to paragraphs of blob

			-- first line is "# <original playlist name>"
			set plName to text 3 thru -1 of (item 1 of rows)
			set doIt to true
			if (count of wanted) > 0 then
				set doIt to (wanted contains plName)
			else if builtIns contains plName then
				set doIt to false
			end if

			if doIt then
				set ids to {}
				repeat with r in rows
					set rt to r as text
					if rt is not "" and rt does not start with "#" then
						set AppleScript's text item delimiters to tab
						set pid to text item 1 of rt
						set AppleScript's text item delimiters to ""
						if pid is not "" then set end of ids to pid
					end if
				end repeat

				tell application "Music"
					set p to make new user playlist with properties {name:plName}
					set added to 0
					repeat with pid in ids
						try
							duplicate (every track of library playlist 1 whose persistent ID is (pid as text)) to p
							set added to added + 1
						end try
					end repeat
				end tell
				set restored to restored + 1
				set totalAdded to totalAdded + added
				set end of report to "  " & plName & ": " & (added as text) & "/" & ((count of ids) as text)
				log "  " & plName & ": " & (added as text) & "/" & ((count of ids) as text)
			end if
		end if
	end repeat

	return "Restored " & (restored as text) & " playlists, " & (totalAdded as text) & " tracks matched."
end run
