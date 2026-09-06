#!/usr/bin/osascript
--
-- backup-playlists.applescript
--
-- Writes one TSV per playlist (persistentID, title, artist, album) plus a
-- MANIFEST.tsv, so playlists can be recreated later by restore-playlists.applescript.
-- Everything outside the "genres" folder is captured, including Apple's built-ins.
--
-- Usage:
--   ./backup-playlists.applescript [output-dir]
--
-- With no argument it creates backups/playlists-YYYYMMDD-HHMMSS next to this script.
--

on run argv
	if (count of argv) ≥ 1 then
		set outDir to item 1 of argv
	else
		set here to POSIX path of ((path to me as text) & "::")
		set stamp to do shell script "date +%Y%m%d-%H%M%S"
		set outDir to here & "backups/playlists-" & stamp
	end if
	do shell script "mkdir -p " & quoted form of outDir
	set manifest to {}
	tell application "Music"
		set total to count of user playlists
		repeat with i from 1 to total
			set nm to ""
			try
				set nm to name of user playlist i
			end try
			set isTop to true
			try
				get parent of user playlist i
				set isTop to false
			end try
			if isTop and nm is not "genres" and nm is not "" then
				set rowList to {}
				try
					set ts to every track of user playlist i
					repeat with t in ts
						set tn to ""
						set ta to ""
						set tl to ""
						set tp to ""
						try
							set tn to name of t
						end try
						try
							set ta to artist of t
						end try
						try
							set tl to album of t
						end try
						try
							set tp to persistent ID of t
						end try
						set end of rowList to tp & tab & tn & tab & ta & tab & tl
					end repeat
				on error trkErr
					log "  could not read tracks of " & nm & ": " & trkErr
				end try
				set AppleScript's text item delimiters to linefeed
				set body to rowList as text
				set AppleScript's text item delimiters to ""
				set safeName to my sanitize(nm)
				set fpath to outDir & "/" & safeName & ".tsv"
				my writeFile(fpath, "# " & nm & linefeed & "# persistentID" & tab & "title" & tab & "artist" & tab & "album" & linefeed & body & linefeed)
				set end of manifest to nm & tab & (count of rowList) & tab & safeName & ".tsv"
			end if
		end repeat
	end tell
	set AppleScript's text item delimiters to linefeed
	set m to manifest as text
	set AppleScript's text item delimiters to ""
	my writeFile(outDir & "/MANIFEST.tsv", "# playlist" & tab & "trackCount" & tab & "file" & linefeed & m & linefeed)
	return "Backed up " & (count of manifest) & " playlists to " & outDir
end run

on sanitize(s)
	set r to ""
	repeat with c in (characters of s)
		set cc to c as text
		if cc is "/" or cc is ":" then
			set r to r & "-"
		else
			set r to r & cc
		end if
	end repeat
	return r
end sanitize

on writeFile(p, txt)
	set f to open for access (POSIX file p) with write permission
	set eof f to 0
	write txt to f as «class utf8»
	close access f
end writeFile
