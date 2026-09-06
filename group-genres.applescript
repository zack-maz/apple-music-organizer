#!/usr/bin/osascript
--
-- group-genres.applescript
--
-- Sorts the per-genre playlists inside the "genres" folder into parent folders.
-- Nothing is merged or renamed: every genre keeps its own playlist, it just
-- gains a parent. Moves are reversible (see --flatten).
--
-- Edit `groups` below to change the taxonomy, then re-run; it is idempotent
-- and reuses folders that already exist.
--
-- Usage:
--   ./group-genres.applescript [--dry-run] [--folder NAME] [--flatten]
--
--   --dry-run   Report the plan, including unmapped genres; change nothing.
--   --folder    Parent folder to work inside (default: genres).
--   --flatten   Undo: move every playlist back up to the top of the folder
--               and delete the now-empty parent folders.
--

use AppleScript version "2.4"
use scripting additions

property defaultFolderName : "genres"

property groups : {¬
	{"Hip-Hop & Rap", {"Hip-Hop/Rap", "Hip-Hop", "Rap", "Alternative Rap", "UK Hip-Hop", "Latin Rap", "Dirty South"}}, ¬
	{"Rock & Alternative", {"Alternative", "Rock", "Hard Rock", "Indie Rock", "Blues-Rock", "Punk", "Hardcore", "Metal", "Psychedelic", "Surf", "Rock y Alternativo"}}, ¬
	{"Electronic & Dance", {"Electronic", "Electronica", "Dance", "House", "Techno", "Trance", "Downtempo", "IDM/Experimental", "Jungle/Drum'n'bass"}}, ¬
	{"Pop", {"Pop", "Vocal Pop", "Indie Pop", "French Pop", "J-Pop", "Mandopop", "Vocal"}}, ¬
	{"R&B, Soul & Funk", {"R&B/Soul", "Soul", "Neo-Soul", "Motown", "Funk"}}, ¬
	{"Jazz & Blues", {"Jazz", "Crossover Jazz", "Latin Jazz", "Blues"}}, ¬
	{"Folk, Country & Songwriter", {"Country", "Honky Tonk", "Folk", "Alternative Folk", "Folk-Rock", "Singer/Songwriter"}}, ¬
	{"Reggae & Caribbean", {"Reggae", "Roots Reggae", "Dub", "Lovers Rock", "Modern Dancehall"}}, ¬
	{"Latin & Brazilian", {"Latin", "Pop Latino", "Urbano latino", "Música Mexicana", "Música tropical", "Brazilian", "MPB", "Samba", "Baile Funk"}}, ¬
	{"Global & World", {"African", "Afrobeats", "Afro House", "Amapiano", "Arabic Pop", "Maghreb Rai", "Farsi", "Indian", "Telugu", "Worldwide"}}, ¬
	{"Ambient & Instrumental", {"Ambient", "New Age", "Instrumental", "Easy Listening"}}, ¬
	{"Soundtracks & Screen", {"Soundtrack", "Original Score", "Anime"}}, ¬
	{"Other", {"Unknown Genre", "Christian", "Comedy", "Modern Era"}}}

on run argv
	set folderName to defaultFolderName
	set dryRun to false
	set doFlatten to false

	set i to 1
	repeat while i ≤ (count of argv)
		set a to item i of argv
		if a is "--dry-run" then
			set dryRun to true
		else if a is "--flatten" then
			set doFlatten to true
		else if a is "--folder" then
			set i to i + 1
			if i > (count of argv) then error "--folder needs a value."
			set folderName to item i of argv
		else if a is "-h" or a is "--help" then
			return my helpText()
		else
			error "Unknown option: " & a
		end if
		set i to i + 1
	end repeat

	tell application "Music"
		if it is not running then launch
		if not (exists folder playlist folderName) then error "No folder playlist named \"" & folderName & "\"."
		set rootFolder to folder playlist folderName
	end tell

	if doFlatten then return my flatten(folderName, rootFolder, dryRun)

	-- what currently sits directly inside the folder, excluding sub-folders
	set present to my childGenreNames(folderName)
	set mapped to {}
	set report to {}
	set movedCount to 0

	repeat with grp in groups
		set gname to item 1 of grp
		set members to item 2 of grp
		set hits to {}
		repeat with m in members
			set mn to m as text
			set end of mapped to mn
			if present contains mn then set end of hits to mn
		end repeat

		if (count of hits) > 0 then
			set end of report to gname & "  (" & (count of hits) & ")"
			repeat with h in hits
				set end of report to "    " & (h as text)
			end repeat
			if not dryRun then
				tell application "Music"
					if exists folder playlist gname then
						set sub to folder playlist gname
					else
						set sub to make new folder playlist at rootFolder with properties {name:gname}
					end if
					repeat with h in hits
						try
							move (my findChild((h as text), folderName)) to sub
							set movedCount to movedCount + 1
						on error e
							log "    could not move " & (h as text) & ": " & e
						end try
					end repeat
				end tell
			else
				set movedCount to movedCount + (count of hits)
			end if
		end if
	end repeat

	-- genres present but not named in the table
	set leftovers to {}
	repeat with p in present
		if mapped does not contain (p as text) then set end of leftovers to (p as text)
	end repeat
	if (count of leftovers) > 0 then
		set end of report to ""
		set end of report to "UNMAPPED - left at the top of \"" & folderName & "\" (" & (count of leftovers) & "):"
		repeat with l in leftovers
			set end of report to "    " & (l as text)
		end repeat
	end if

	set end of report to ""
	if dryRun then
		set end of report to "DRY RUN - would move " & (movedCount as text) & " playlists."
	else
		set end of report to "Moved " & (movedCount as text) & " playlists into parent folders."
	end if

	set AppleScript's text item delimiters to linefeed
	set out to report as text
	set AppleScript's text item delimiters to ""
	return out
end run

-- names of playlists sitting directly in the folder, skipping sub-folders
on childGenreNames(folderName)
	set found to {}
	tell application "Music"
		repeat with i from 1 to (count of user playlists)
			try
				if (name of parent of user playlist i) is folderName then
					if (class of user playlist i) is not folder playlist then
						set end of found to (name of user playlist i)
					end if
				end if
			end try
		end repeat
	end tell
	return found
end childGenreNames

on findChild(nm, folderName)
	tell application "Music"
		repeat with i from 1 to (count of user playlists)
			try
				if (name of user playlist i) is nm and (name of parent of user playlist i) is folderName then
					if (class of user playlist i) is not folder playlist then return user playlist i
				end if
			end try
		end repeat
	end tell
	error "not found directly inside " & folderName & ": " & nm
end findChild

on flatten(folderName, rootFolder, dryRun)
	set subs to {}
	tell application "Music"
		repeat with i from 1 to (count of user playlists)
			try
				if (name of parent of user playlist i) is folderName and (class of user playlist i) is folder playlist then
					set end of subs to (name of user playlist i)
				end if
			end try
		end repeat
	end tell
	if dryRun then return "DRY RUN - would flatten " & (count of subs) & " parent folders back into \"" & folderName & "\"."

	set moved to 0
	repeat with s in subs
		set sname to s as text
		repeat
			set didOne to false
			tell application "Music"
				repeat with i from 1 to (count of user playlists)
					try
						if (name of parent of user playlist i) is sname then
							move user playlist i to rootFolder
							set didOne to true
							exit repeat
						end if
					end try
				end repeat
			end tell
			if not didOne then exit repeat
			set moved to moved + 1
		end repeat
		tell application "Music"
			try
				delete folder playlist sname
			end try
		end tell
	end repeat
	return "Flattened: moved " & (moved as text) & " playlists back up and removed " & (count of subs) & " parent folders."
end flatten

on helpText()
	return "Usage: group-genres.applescript [options]
  --dry-run      Report the plan; change nothing.
  --folder NAME  Parent folder to work inside (default: genres).
  --flatten      Undo: move playlists back up and delete the parent folders.
  -h, --help     Show this help."
end helpText
