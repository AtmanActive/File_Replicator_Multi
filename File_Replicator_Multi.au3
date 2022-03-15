; File_Replicator_Multi.au3 by AtmanActive
; Created with ISN AutoIt Studio v. 1.14
;
; This program scans the selected source path for files, recursively, ignoring folders
; and then iterates for each found to search for the same named file in the destination path,
; and, if found, overwrites the destination file with the source file.
; If big source/dest trees are selected, the GUI will get unrensponsive until finished.
;
; https://github.com/AtmanActive/File_Replicator_Multi
;
; *****************************************

If not @Compiled then DllCall( "User32.dll", "bool", "SetProcessDPIAware" )

Opt( "GUIOnEventMode", 1 ) ;Enable OnEventMode
DllCall( "User32.dll", "bool", "SetProcessDPIAware" ) ;Set script high DPI aware


#include <DateTimeConstants.au3>
#include <File.au3>
#include <FileConstants.au3>
#include <GUIConstantsEx.au3>
#include <GuiButton.au3>
#include <Misc.au3>
#include <MsgBoxConstants.au3>
#include <Process.au3>
#include <WinAPIFiles.au3>
#include <WinAPIProc.au3>
#include <WindowsConstants.au3>

#include "File_Replicator_Multi_GUI.isf" ;This is the main GUI window. You can directly include an .isf into your script! No code copy/paste is needed! (NOTE: Every GUI is hidden by default!)



Global $sourceDir
Global $destinationDir
Global $isReady = 0
Global $Logfile = @WorkingDir & "\" & StringMid( @ScriptName, 1, ( StringLen( @ScriptName ) - 4 ) ) & ".log." & @YEAR & "-" & @MON & "-" & @MDAY & "-" & @HOUR & "-" & @MIN & "-" & @SEC & ".txt"

Global $do_overwrite = 1 ; SET THIS TO ZERO FOR TESTING PURPOSES



; SINGLE INSTANCE ONLY
If _Singleton( "File Replicator Multi", 1 ) = 0 Then
	Exit
EndIf



GUICtrlSetState( $button_go, $GUI_DISABLE )

GUISetState( @SW_SHOW, $File_Replicator_Multi_GUI )

GUICtrlSetState ( $input_path_source, $GUI_FOCUS )



_Main_Loop()


Exit





















































Func _BrowseForSourcePath()
	
	Local $sFileSelectFolder = FileSelectFolder( "Please choose source directory", "", 0, "", $File_Replicator_Multi_GUI )
	If @error Then
		$sourceDir = ""
		GUICtrlSetData ( $input_path_source, $sourceDir )
		GUICtrlSetState ( $input_path_source, $GUI_FOCUS )
	Else
		$sourceDir = $sFileSelectFolder
		GUICtrlSetData ( $input_path_source, $sourceDir )
		GUICtrlSetState ( $input_path_destination, $GUI_FOCUS )
	EndIf
	
EndFunc ;==>_BrowseForSourcePath()





Func _BrowseForDestinationPath()
	
	Local $sFileSelectFolder = FileSelectFolder( "Please choose destination directory", "", 0, "", $File_Replicator_Multi_GUI )
	If @error Then
		$destinationDir = ""
		GUICtrlSetData ( $input_path_destination, $destinationDir )
		GUICtrlSetState ( $input_path_destination, $GUI_FOCUS )
	Else
		$destinationDir = $sFileSelectFolder
		GUICtrlSetData ( $input_path_destination, $destinationDir )
	EndIf
	
EndFunc ;==>_BrowseForDestinationPath()














































Func _RunTheReplicator()
	
	GUICtrlSetState( $button_go, $GUI_DISABLE )
	GUICtrlSetState( $button_browse_src, $GUI_DISABLE )
	GUICtrlSetState( $button_browse_dest, $GUI_DISABLE )
	GUICtrlSetState( $button_view_log, $GUI_DISABLE )
	GUICtrlSetState( $button_about, $GUI_DISABLE )
	GUICtrlSetState( $input_path_source, $GUI_DISABLE )
	GUICtrlSetState( $input_path_destination, $GUI_DISABLE )
	
	GUICtrlSetData ( $button_go, "RUNNING ..." )
	
	Local $validate_src = 0
	Local $validate_dst = 0
	Local $found_source_files = 0
	Local $overwrote_destination_files = 0
	Local $failed_destination_files = 0
	
	If $isReady = 1 Then
		
		If Not ( FileExists( $sourceDir ) ) Then
			MsgBox( 0, "Invalid Source Folder Selected", "The folder " & $sourceDir & " does not exist" )
		Else
			
			$validate_src = 1
			
			If Not ( FileExists( $destinationDir ) ) Then
				MsgBox( 0, "Invalid Destination Folder Selected", "The folder " & $destinationDir & " does not exist" )
			Else
				$validate_dst = 1
			EndIf
			
		EndIf
		
		
		If ( $validate_src = 1 And $validate_dst = 1 ) Then
			
			Local $found_files_array = _FileListToArrayRec( $sourceDir, "*", $FLTAR_FILES, $FLTAR_RECUR, $FLTAR_NOSORT, $FLTAR_FULLPATH )
			
			;;_ArrayDisplay( $found_files_array )
			
			if ( IsArray( $found_files_array ) And $found_files_array[0] > 0 ) Then
				
				ProgressOn ( "File Replicator Multi", "Running, please wait ... ", "Starting", -1, -1 )
				
				$found_source_files = $found_files_array[0]
				
				_WriteLog( "Found " & $found_files_array[0] & " files at path " & $sourceDir )
				
				For $i = 1 To UBound( $found_files_array ) - 1
					
					_WriteLog( $i & " of " & $found_files_array[0] & ": " & $found_files_array[ $i ] )
					
					GUICtrlSetData ( $button_go, "FILE " & $i & "/" & $found_source_files & " ..." )
					
					Dim $szDrive, $szDir, $szFName, $szExt
					Local $SplitPath = _PathSplit( $found_files_array[ $i ], $szDrive, $szDir, $szFName, $szExt )
					Local $find_this_file = $szFName & $szExt
					
					Local $source_file_mtime = FileGetTime( $found_files_array[ $i ], $FT_MODIFIED, $FT_STRING ) ;~ Returns Created Date in the format YYYYMMDDHHMMSS
					Local $source_file_size  = FileGetSize( $found_files_array[ $i ] )
					
					ProgressSet( ( ( 100 / $found_source_files ) * $i ), "File " & $i & " of " & $found_source_files & ": " & $find_this_file )
					
					_WriteLog( "Searching for " & $find_this_file & " in " & $destinationDir & " ... " )
					
					GUICtrlSetData ( $button_go, "FILE " & $i & "/" & $found_files_array[0] & " ..." )
					
					Local $found_dest_array = _FileListToArrayRec( $destinationDir, $find_this_file, $FLTAR_FILES, $FLTAR_RECUR, $FLTAR_NOSORT, $FLTAR_FULLPATH )
					
					If ( IsArray( $found_dest_array ) And $found_dest_array[0] > 0 ) Then
						
						For $j = 1 To UBound( $found_dest_array ) - 1
							
							Local $dest_file_mtime = FileGetTime( $found_dest_array[ $j ], $FT_MODIFIED, $FT_STRING ) ;~ Returns Created Date in the format YYYYMMDDHHMMSS
							Local $dest_file_size  = FileGetSize( $found_dest_array[ $j ] )
							
							_WriteLog( "Overwriting file " & $found_dest_array[ $j ] & ", source modified at " & $source_file_mtime & ", " & $source_file_size & " bytes, destination modified at " & $dest_file_mtime & ", " & $dest_file_size & " bytes" )
							
							
							Local $overwrite_ok
							
							If $do_overwrite = 1 Then
								$overwrite_ok = FileCopy ( $found_files_array[ $i ], $found_dest_array[ $j ], $FC_OVERWRITE )
							Else
								$overwrite_ok = 1
							EndIf
							
							if $overwrite_ok = 1 Then
								
								$overwrote_destination_files = $overwrote_destination_files + 1
								
								_WriteLog( "Overwrite OK" )
								
							Else
								
								$failed_destination_files = $failed_destination_files + 1
								
								_WriteLog( "Overwrite FAILED" )
								
							EndIf
							
						Next ;==> For $j = 1 To UBound( $found_dest_array ) - 1
						
					Else
						_WriteLog( "Found no files named " & $find_this_file & " at the destination path " & $destinationDir )
					EndIf
					
					_WriteLog( "--------------------------------------------------------------------------------" )
					
				Next ;==> For $i = 1 To UBound( $found_files_array ) - 1
				
				ProgressOff()
				
				MsgBox( 0, "Complete", "Found " & $found_source_files & " files, overwrote " & $overwrote_destination_files & " files, failed to overwrite " & $failed_destination_files & " files. " & @CRLF & "Details in the log file at " & $Logfile )
				
			Else
				
				MsgBox( 0, "No Files Found", "The folder " & $sourceDir & " appears to have no files" )
				
			EndIf ;==> if IsArray( $found_files_array ) Then
			
			
		EndIf ;==> If ( $validate_src = 1 And $validate_dst = 1 ) Then
		
	EndIf ;==> If $isReady = 1 Then
	
	GUICtrlSetData ( $button_go, "GO" )
	
	GUICtrlSetState( $button_go, $GUI_ENABLE )
	GUICtrlSetState( $button_browse_src, $GUI_ENABLE )
	GUICtrlSetState( $button_browse_dest, $GUI_ENABLE )
	GUICtrlSetState( $button_view_log, $GUI_ENABLE )
	GUICtrlSetState( $button_about, $GUI_ENABLE )
	GUICtrlSetState( $input_path_source, $GUI_ENABLE )
	GUICtrlSetState( $input_path_destination, $GUI_ENABLE )
	
EndFunc ;==>_RunTheReplicator()




















































Func _viewLog()
	
	If FileExists( $Logfile ) Then
		
		ShellExecute( $Logfile )
		
	Else
		
		MsgBox( 0, "Not yet", "The log file has not been generated yet" )
		
	EndIf
	
EndFunc ;==>_viewLog()



















































Func _openAboutURL()
	
	ShellExecute( "https://github.com/AtmanActive/File_Replicator_Multi" )
	
EndFunc ;==>_openAboutURL()



















































Func _are_inputs_ready()
	
	Local $current_input_source = GUICtrlRead( $input_path_source )
	Local $current_input_destination = GUICtrlRead( $input_path_destination )
	Local $nowReady
	
	If ( StringLen( $current_input_source ) > 2 And StringLen( $current_input_destination ) > 2 ) Then
		$nowReady = 1
	Else
		$nowReady = 0
	EndIf
	
	If $nowReady = 1 Then
		If $isReady = 0 Then
			GUICtrlSetState( $button_go, $GUI_ENABLE )
			$sourceDir = $current_input_source
			$destinationDir = $current_input_destination
			$isReady = 1
		EndIf
	Else
		If $isReady = 1 Then
			GUICtrlSetState( $button_go, $GUI_DISABLE )
			$isReady = 0
		EndIf
	EndIf
	
	
EndFunc ;==>_are_inputs_ready()




























































Func _WriteLog( $Message )
  Local $errorFile = $Logfile
  Local $LogTime = @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
  Local $hFileOpen = FileOpen( $errorFile, 9 )
  FileWriteLine( $hFileOpen, $LogTime & " " & $Message & @CRLF)
  FileClose( $hFileOpen )
EndFunc   ;==>_WriteLog
















Func _Exit()
	Exit
EndFunc   ;==>_Exit

















Func _Main_Loop()
	While 1
		
		 _are_inputs_ready()
		
		sleep ( 10 ) ; ~100Hz
		
	WEnd
EndFunc
