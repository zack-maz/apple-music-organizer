#!/usr/bin/osascript
--
-- whats-new.applescript
--
-- Answers "which songs have I added since the playlists were last built?"
--
-- It does NOT use download state. Music has no readable `downloaded` property
-- on subscription tracks, and tracks Apple has pulled from the catalogue stay
-- un-downloaded forever, so download state is unusable as a freshness signal.
--
-- Instead it compares the library against the genre tree directly: any track in
-- the library that is not in any genre playlist was added after the last
-- rebuild. That is exact, not a heuristic. `date added` is reported alongside
-- so the list reads chronologically.
--
-- Usage:
--   ./whats-new.applescript [--days N] [--folder NAME] [--all]
--
--   --days N     Also list everything added in the last N days (default: off).
--   --all        List every unorganized track (default caps the list at 40).
--   --folder     Genre folder to compare against (default: genres).
--

use AppleScript version "2.4"
use framework "Foundation"
use scripting additions

property defaultFolderName : "genres"

on run argv
	set folderName to defaultFolderName
	set dayWindow to 0
	set showAll to false
	set capAt to 40

	set i to 1
	repeat while i ≤ (count of argv)
		set a to item i of argv
		if a is "--all" then
			set showAll to true
		else if a is "--days" then
			set i to i + 1
			if i > (count of argv) then error "--days needs a value."
			set dayWindow to (item i of argv) as integer
		else if a is "--folder" then
			set i to i + 1
			if i > (count of argv) then error "--folder needs a value."
			set folderName to item i of argv
		else if a is "-h" or a is "--help" then
			return "Usage: whats-new.applescript [--days N] [--all] [--folder NAME]"
		else
			error "Unknown option: " & a
		end if
		set i to i + 1
	end repeat

	tell application "Music"
		if it is not running then launch
		set lib to library playlist 1
		with timeout of 3600 seconds
			set idList to persistent ID of every track of lib
			set titleList to name of every track of lib
			set whoList to artist of every track of lib
			set genreList to genre of every track of lib
			set addedList to date added of every track of lib
		end timeout
	end tell
	set libTotal to count of idList

	-- every persistent ID currently filed anywhere under the genre folder
	set filed to current application's NSMutableSet's alloc()'s init()
	set playlistCount to 0
	tell application "Music"
		repeat with pi from 1 to (count of user playlists)
			try
				set inScope to ((name of parent of user playlist pi) is folderName)
				if not inScope then
					try
						if (name of parent of parent of user playlist pi) is folderName then set inScope to true
					end try
				end if
				if inScope then
					set playlistCount to playlistCount + 1
					filed's addObjectsFromArray:(persistent ID of every track of user playlist pi)
				end if
			end try
		end repeat
	end tell

	-- library minus genre tree = added since the last rebuild
	set pending to {}
	set cutoff to (current date) - (dayWindow * 86400)
	set recent to {}

	repeat with k from 1 to libTotal
		set thisID to (item k of idList) as text
		set wasFiled to (filed's containsObject:thisID) as boolean
		set entry to my stampOf(item k of addedList) & "  " & (item k of whoList) & " — " & (item k of titleList) & "   [" & my genreOf(item k of genreList) & "]"
		if not wasFiled then set end of pending to entry
		if dayWindow > 0 and (item k of addedList) ≥ cutoff then set end of recent to entry
	end repeat

	set rowsOut to {}
	set rowsOut to rowsOut & {"Library:        " & libTotal & " tracks"}
	set rowsOut to rowsOut & {"Filed in \"" & folderName & "\": " & ((filed's |count|()) as integer) & " tracks across " & playlistCount & " playlists"}
	set rowsOut to rowsOut & {""}

	if (count of pending) is 0 then
		set rowsOut to rowsOut & {"Everything in the library is filed. Nothing new since the last rebuild."}
	else
		set rowsOut to rowsOut & {"UNORGANIZED - " & (count of pending) & " track(s) added since the last rebuild:"}
		set shown to my newestFirst(pending)
		set lim to count of shown
		if (not showAll) and lim > capAt then set lim to capAt
		repeat with k from 1 to lim
			set rowsOut to rowsOut & {"  " & (item k of shown)}
		end repeat
		if lim < (count of shown) then set rowsOut to rowsOut & {"  … and " & ((count of shown) - lim) & " more (pass --all)"}
		set rowsOut to rowsOut & {""}
		set rowsOut to rowsOut & {"Re-file them:  ./organize-by-genre.applescript --replace && ./group-genres.applescript && ./lowercase-names.applescript"}
	end if

	if dayWindow > 0 then
		set rowsOut to rowsOut & {""}
		set rowsOut to rowsOut & {"ADDED IN THE LAST " & dayWindow & " DAY(S) - " & (count of recent) & " track(s), filed or not:"}
		set shown2 to my newestFirst(recent)
		set lim2 to count of shown2
		if (not showAll) and lim2 > capAt then set lim2 to capAt
		repeat with k from 1 to lim2
			set rowsOut to rowsOut & {"  " & (item k of shown2)}
		end repeat
		if lim2 < (count of shown2) then set rowsOut to rowsOut & {"  … and " & ((count of shown2) - lim2) & " more (pass --all)"}
	end if

	set AppleScript's text item delimiters to linefeed
	set outText to rowsOut as text
	set AppleScript's text item delimiters to ""
	return outText
end run

on genreOf(g)
	if g is missing value then return "no genre"
	if (g as text) is "" then return "no genre"
	return g as text
end genreOf

-- sortable YYYY-MM-DD HH:MM prefix, so a plain string sort is chronological
on stampOf(d)
	if d is missing value then return "0000-00-00 00:00"
	set yr to year of d
	set mo to (month of d) as integer
	set dy to day of d
	set hr to hours of d
	set mnt to minutes of d
	return (yr as text) & "-" & my pad2(mo) & "-" & my pad2(dy) & " " & my pad2(hr) & ":" & my pad2(mnt)
end stampOf

on pad2(n)
	if n < 10 then return "0" & (n as text)
	return n as text
end pad2

on newestFirst(lst)
	if (count of lst) is 0 then return lst
	set sorted to ((current application's NSArray's arrayWithArray:lst)'s sortedArrayUsingSelector:"compare:") as list
	return reverse of sorted
end newestFirst
