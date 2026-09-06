#!/usr/bin/osascript
--
-- build-genres.applescript
--
-- Builds the whole genre library in ONE creation pass: every playlist is made
-- directly inside its parent folder, already lowercase, already filled.
--
-- Why one pass: iCloud sync reverts modifications to existing synced objects
-- (renames, moves, row deletions) while letting creations stand, because new
-- objects carry new IDs and cannot conflict. Building the final shape up front
-- leaves sync nothing to undo. This replaces the old
-- organize-by-genre -> group-genres -> lowercase-names pipeline, whose last two
-- steps were exactly the post-hoc edits that kept getting reverted.
--
-- Genres are folded to lowercase and uniqued case-insensitively, so "Hip-Hop"
-- and "hip-hop" become one `hip-hop` playlist rather than two competing ones.
-- Nothing is merged beyond case: `hip-hop`, `rap` and `hip-hop/rap` stay
-- separate playlists that share a parent folder.
--
-- Usage:
--   ./build-genres.applescript [--dry-run] [--replace] [--folder NAME] [--min-tracks N]
--

use AppleScript version "2.4"
use framework "Foundation"
use scripting additions

property defaultFolderName : "genres"
property unknownName : "unknown genre"

-- {parent folder, {genres it holds}} -- all lowercase, matched case-insensitively
property groups : {¬
	{"hip-hop & rap", {"hip-hop/rap", "hip-hop", "rap", "alternative rap", "uk hip-hop", "latin rap", "dirty south"}}, ¬
	{"rock & alternative", {"alternative", "rock", "hard rock", "indie rock", "blues-rock", "punk", "hardcore", "metal", "psychedelic", "surf", "rock y alternativo"}}, ¬
	{"electronic & dance", {"electronic", "electronica", "dance", "house", "techno", "trance", "downtempo", "idm/experimental", "jungle/drum'n'bass"}}, ¬
	{"pop", {"pop", "vocal pop", "indie pop", "french pop", "j-pop", "mandopop", "vocal"}}, ¬
	{"r&b, soul & funk", {"r&b/soul", "soul", "neo-soul", "motown", "funk"}}, ¬
	{"jazz & blues", {"jazz", "crossover jazz", "latin jazz", "blues"}}, ¬
	{"folk, country & songwriter", {"country", "honky tonk", "folk", "alternative folk", "folk-rock", "singer/songwriter"}}, ¬
	{"reggae & caribbean", {"reggae", "roots reggae", "dub", "lovers rock", "modern dancehall"}}, ¬
	{"latin & brazilian", {"latin", "pop latino", "urbano latino", "música mexicana", "música tropical", "brazilian", "mpb", "samba", "baile funk"}}, ¬
	{"global & world", {"african", "afrobeats", "afro house", "amapiano", "arabic pop", "maghreb rai", "farsi", "indian", "telugu", "worldwide"}}, ¬
	{"ambient & instrumental", {"ambient", "new age", "instrumental", "easy listening"}}, ¬
	{"soundtracks & screen", {"soundtrack", "original score", "anime"}}, ¬
	{"other", {"unknown genre", "christian", "comedy", "modern era"}}}

on run argv
	set folderName to defaultFolderName
	set dryRun to false
	set replaceExisting to false
	set minTracks to 1

	set i to 1
	repeat while i ≤ (count of argv)
		set a to item i of argv
		if a is "--dry-run" then
			set dryRun to true
		else if a is "--replace" then
			set replaceExisting to true
		else if a is "--folder" then
			set i to i + 1
			if i > (count of argv) then error "--folder needs a value."
			set folderName to item i of argv
		else if a is "--min-tracks" then
			set i to i + 1
			if i > (count of argv) then error "--min-tracks needs a value."
			set minTracks to (item i of argv) as integer
		else if a is "-h" or a is "--help" then
			return "Usage: build-genres.applescript [--dry-run] [--replace] [--folder NAME] [--min-tracks N]"
		else
			error "Unknown option: " & a
		end if
		set i to i + 1
	end repeat

	log "Reading library..."
	tell application "Music"
		if it is not running then launch
		set lib to library playlist 1
		with timeout of 3600 seconds
			set rawGenres to genre of every track of lib
		end timeout
	end tell
	set libTotal to count of rawGenres
	if libTotal is 0 then return "No tracks in the library."

	-- fold to lowercase up front: the playlist name IS the lowercased genre,
	-- so there is never a rename step
	set folded to {}
	repeat with g in rawGenres
		set gv to contents of g
		if gv is missing value then
			set end of folded to unknownName
		else if (gv as text) is "" then
			set end of folded to unknownName
		else
			set end of folded to ((current application's NSString's stringWithString:(gv as text))'s lowercaseString()) as text
		end if
	end repeat

	set uniqueSet to current application's NSOrderedSet's orderedSetWithArray:folded
	set allGenres to (uniqueSet's array()'s sortedArrayUsingSelector:"localizedStandardCompare:") as list
	set tally to current application's NSCountedSet's setWithArray:folded
	log ((count of allGenres) as text) & " genres across " & (libTotal as text) & " tracks."

	-- assign each genre to a parent folder; anything unlisted is reported
	set claimed to {}
	repeat with grp in groups
		repeat with m in (item 2 of grp)
			set end of claimed to (m as text)
		end repeat
	end repeat
	set strays to {}
	repeat with g in allGenres
		set gs to g as text
		set isKnown to false
		repeat with c in claimed
			considering case
				if (c as text) is gs then set isKnown to true
			end considering
		end repeat
		if not isKnown then set end of strays to gs
	end repeat

	set report to {}
	set plannedFolders to 0
	set plannedLists to 0
	set plannedTracks to 0

	repeat with grp in groups
		set gname to item 1 of grp
		set present to {}
		repeat with m in (item 2 of grp)
			set ms to m as text
			set n to (tally's countForObject:ms) as integer
			if n ≥ minTracks and n > 0 then set end of present to {ms, n}
		end repeat
		if (count of present) > 0 then
			set plannedFolders to plannedFolders + 1
			set end of report to gname
			repeat with pr in present
				set plannedLists to plannedLists + 1
				set plannedTracks to plannedTracks + (item 2 of pr)
				set end of report to "    " & (item 1 of pr) & "  (" & (item 2 of pr) & ")"
			end repeat
		end if
	end repeat

	if (count of strays) > 0 then
		set end of report to ""
		set end of report to "UNMAPPED - will be created at the top of \"" & folderName & "\" (" & (count of strays) & "):"
		repeat with sgen in strays
			set sg to sgen as text
			set end of report to "    " & sg & "  (" & ((tally's countForObject:sg) as integer) & ")"
		end repeat
		set end of report to "  Add them to the `groups` table and re-run to file them."
	end if

	if dryRun then
		set end of report to ""
		set end of report to "DRY RUN - would create " & plannedFolders & " folders, " & plannedLists & " playlists, " & plannedTracks & " track entries."
		return my joinUp(report)
	end if

	-- create everything, in final form
	tell application "Music"
		if exists folder playlist folderName then
			if replaceExisting then
				log "Deleting existing \"" & folderName & "\"..."
				delete folder playlist folderName
			else
				error "A folder named \"" & folderName & "\" already exists. Re-run with --replace."
			end if
		end if
		set rootFolder to make new folder playlist with properties {name:folderName}
	end tell

	set madeLists to 0
	set copied to 0

	repeat with grp in groups
		set gname to item 1 of grp
		set present to {}
		repeat with m in (item 2 of grp)
			set ms to m as text
			set n to (tally's countForObject:ms) as integer
			if n ≥ minTracks and n > 0 then set end of present to ms
		end repeat

		if (count of present) > 0 then
			tell application "Music"
				set subFolder to make new folder playlist at rootFolder with properties {name:gname}
			end tell
			log "  " & gname
			repeat with gs in present
				set thisGenre to gs as text
				set got to my fillOne(thisGenre, subFolder, thisGenre)
				if got > 0 then set madeLists to madeLists + 1
				set copied to copied + got
			end repeat
		end if
	end repeat

	-- unmapped genres land at the root so they are visible, not buried
	repeat with sgen in strays
		set sg to sgen as text
		set n to (tally's countForObject:sg) as integer
		if n ≥ minTracks then
			set got to my fillOne(sg, rootFolder, sg)
			if got > 0 then set madeLists to madeLists + 1
			set copied to copied + got
			log "  (unmapped) " & sg
		end if
	end repeat

	set end of report to ""
	set end of report to "Created " & madeLists & " playlists holding " & copied & " tracks in \"" & folderName & "\"."
	return my joinUp(report)
end run

-- Makes the playlist inside `intoFolder`, already named, then fills it.
-- NB: do not name this parameter `container` -- that is a term in Music's
-- dictionary, and `at container` binds to the term, not the variable, failing
-- with -2710 "Can't make class user playlist".
on fillOne(genreName, intoFolder, plName)
	-- Tracks with no genre are *displayed* as "unknown genre" but must be
	-- *filtered* on the empty string -- no track carries the placeholder as its
	-- actual genre, so filtering on it matches nothing and the playlist is lost.
	set filterVal to genreName
	if genreName is unknownName then set filterVal to ""
	tell application "Music"
		set lib to library playlist 1
		set p to make new user playlist at intoFolder with properties {name:plName}
		with timeout of 3600 seconds
			try
				-- the `whose` clause must be restated inline; a stored result
				-- becomes a resolved list and duplicate rejects it
				duplicate (every track of lib whose genre is filterVal) to p
			on error e
				log "    could not fill " & plName & ": " & e
			end try
		end timeout
		set landed to count of tracks of p
		if landed is 0 then delete p
	end tell
	return landed
end fillOne

on joinUp(lst)
	set AppleScript's text item delimiters to linefeed
	set outText to lst as text
	set AppleScript's text item delimiters to ""
	return outText
end joinUp
