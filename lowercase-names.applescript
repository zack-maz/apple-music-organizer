#!/usr/bin/osascript
--
-- lowercase-names.applescript
--
-- Lowercases the names of the genre folder, its parent folders, and every
-- playlist inside it. Track metadata is never touched.
--
-- Uses Foundation's lowercaseString so non-ASCII names fold correctly
-- ("Música Mexicana" -> "música mexicana"); `tr` and friends do not.
--
-- Usage:
--   ./lowercase-names.applescript [--dry-run] [--folder NAME]
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
			return "Usage: lowercase-names.applescript [--dry-run] [--folder NAME]"
		else
			error "Unknown option: " & a
		end if
		set i to i + 1
	end repeat

	tell application "Music"
		if it is not running then launch
		if not (exists folder playlist folderName) then error "No folder playlist named \"" & folderName & "\"."
	end tell

	-- Collect targets by persistent ID first: renaming can reorder the
	-- collections, so indexes captured up front are not safe to reuse.
	set targets to {} -- {persistentID, currentName, isFolder}

	tell application "Music"
		repeat with fi from 1 to (count of folder playlists)
			set fn to name of folder playlist fi
			set inScope to (fn is folderName)
			if not inScope then
				try
					if (name of parent of folder playlist fi) is folderName then set inScope to true
				end try
			end if
			if inScope then set end of targets to {persistent ID of folder playlist fi, fn, true}
		end repeat

		repeat with pi from 1 to (count of user playlists)
			set inScope to false
			try
				set pn to name of parent of user playlist pi
				if pn is folderName then
					set inScope to true
				else
					try
						if (name of parent of parent of user playlist pi) is folderName then set inScope to true
					end try
				end if
			end try
			if inScope then set end of targets to {persistent ID of user playlist pi, name of user playlist pi, false}
		end repeat
	end tell

	-- Work out the new names and look for collisions before changing anything.
	set plan to {}
	set newNames to {}
	set collisions to {}
	repeat with t in targets
		set oldName to item 2 of t
		set newName to my lower(oldName)
		-- AppleScript compares strings case-insensitively unless told otherwise,
		-- so without this every name looks like it is already lowercase.
		considering case
			set needsChange to (newName is not oldName)
			set clash to (newNames contains newName)
		end considering
		if needsChange then
			if clash then set end of collisions to newName
			set end of newNames to newName
			set end of plan to {item 1 of t, oldName, newName, item 3 of t}
		end if
	end repeat

	set report to {}
	repeat with p in plan
		set tag to "playlist"
		if item 4 of p then set tag to "FOLDER  "
		set end of report to "  " & tag & "  " & (item 2 of p) & "   ->   " & (item 3 of p)
	end repeat

	if (count of collisions) > 0 then
		set end of report to ""
		set end of report to "COLLISIONS - these names would no longer be unique:"
		repeat with c in collisions
			set end of report to "    " & (c as text)
		end repeat
	end if

	if dryRun then
		set end of report to ""
		set end of report to "DRY RUN - would rename " & (count of plan) & " of " & (count of targets) & " names."
		return my joinLines(report)
	end if

	set renamed to 0
	repeat with p in plan
		set pid to item 1 of p
		set newName to item 3 of p
		set isFolder to item 4 of p
		try
			tell application "Music"
				if isFolder then
					repeat with fi from 1 to (count of folder playlists)
						if (persistent ID of folder playlist fi) is pid then
							set name of folder playlist fi to newName
							exit repeat
						end if
					end repeat
				else
					repeat with qi from 1 to (count of user playlists)
						if (persistent ID of user playlist qi) is pid then
							set name of user playlist qi to newName
							exit repeat
						end if
					end repeat
				end if
			end tell
			set renamed to renamed + 1
		on error e
			log "  could not rename " & (item 2 of p) & ": " & e
		end try
	end repeat

	set end of report to ""
	set end of report to "Renamed " & (renamed as text) & " of " & (count of plan) & " names (" & (count of targets) & " inspected)."
	return my joinLines(report)
end run

on lower(s)
	return ((current application's NSString's stringWithString:s)'s lowercaseString()) as text
end lower

on joinLines(lst)
	set AppleScript's text item delimiters to linefeed
	set out to lst as text
	set AppleScript's text item delimiters to ""
	return out
end joinLines
