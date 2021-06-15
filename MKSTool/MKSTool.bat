@echo off
color 8a

:: Set up global variables
    set CurFolder = %CD%
    set MKSExePath = ""
    set OutputFile = ViewStatusOutput.csv
    set TempInputFile = %CurFolder%\tempInputFile.txt
    set TempFullPath = Temp_FullPath.txt
    set CONFIG_INI = config.ini

:: Check MKS connection
:: If MKS is openning, it will return a string. Otherwise, it will return an empty string
:MKS_CONNECTION
    cls
    set tempCheckMKSConnection = checkMKSConnection.txt
    si servers > %tempCheckMKSConnection%

    :: Get file's size
    Setlocal EnableDelayedExpansion
    for /f %%i in ("!tempCheckMKSConnection!") do 
    (
        set fileSize = %%~zi
    )

    if exist %tempCheckMKSConnection% del %tempCheckMKSConnection%
    if !fileSize! gtr 0
    (
        goto CHECK_INI_FILE
    )
    else
    (
        echo MKS is openning....
        %MKSExePath%
        @pause
        goto CHECK_INI_FILE
    )
    endlocal

:CHECK_INI_FILE
    cls
    if exist %CONFIG_INI%
    (
        call :READ_CONFIG_INI [SANDBOX]
        echo Your current sandbox location is !SandBox!
        @pause
        goto MENU
    )
    else
    (
        goto CHOOSE_SANDBOX
    )

:READ_CONFIG_INI
    set Params_Key = %1
    if exist %CONFIG_INI%
    (
        for /f "usebackq delims=" %%a in ("%CONFIG_INI") do
        (
            set ln = %%a
            for /f "tokens=1,2 delims==" %b in ("%ln%") do
            (
                set INI_Key = %%b
                if "!INI_Key!" == "!Params_Key!"
                (
                    set SandBox = %%c
                )
            )
        )
    )
    else
    (
        echo config.ini does not exist...
        @pause
    )
    exit /B

:WRITE_CONFIG_INI
    set Params_Key = %%1
    set Params_Value = %%2
    set Temp_INIFile = tempini.ini
    if exist %CONFIG_INI%
    (

    )
    else
    (
        echo !Params_Key!=!Params_Value! > %CONFIG_INI%
        @pause
    )
    exit /B

:: Main Section
:MENU
    echo ==================================================================
    echo =============================MENU=================================
    echo ==================================================================
    echo Please choose one of the below options:
    echo 1) View "Status" of a specific file with its revision info.
    echo 2) Find revision with a specific label
    echo 3) Set "State" for members.
    echo 4) View the keywords in all revision of a single file.
    echo 5) Exit

    set /p _option="Your choice is: "
    if %_option%==1     goto OPTION1
    if %_option%==2     goto OPTION2
    if %_option%==3     goto OPTION3
    if %_option%==4     goto OPTION4
    if %_option%==5     exit

:: OPTION1 - View "Status" of a specific file with its revision info.
:OPTION1
    cls
    :: Check whether the "OutputFile" is being openned
    2>nul (call;>>"%OutputFile%") && (
        echo %OutputFile% is free!
    ) || (
        echo %OutputFile% is being openned!
        echo Please close it then press any key to continue!
        @pause
        goto OPTION1
    )

    :: Prepare output file
    if exist %OutputFile%       del %OutputFile%

    echo sep=, > %OutputFile%
    echo FileName, Revision, State, Author, Year/Time >> %OutputFile%

    call :CHOOSE_INPUT
    call :REPLACE_SPACE
    call :CREATE_FULL_FILEPATH
    echo The output file is stored in %CurFolder%\%OutputFile%

    goto CONFIRM_EXIT

:: Get full input files' path
:CREATE_FULL_FILEPATH
    for /f "usebackq tokens=1-2 delims=," %%a in ("%TempInputFile%") do 
    (
        set FileName = %%a
        set Revision = %%b

        :: Catch error if the file is not found in this sandbox
        2>nul (dir.\!FileName! / >nul) && (
            call :GET_FULL_PATH
            call :GET_STATE
            call :GET_AUTHOR
            call :STORE_OUTPUT
            call :DELETE_TEMP_FILE
        ) || (
            set State = "File not found"
            call :STORE_OUTPUT
        )
    )
    exit /B

:GET_STATE
    :: Catch error if revision is not valid or not exist
    2>nul (si revisioninfo --revision=!Revision! "!FullPath!\!FileName!" > nul) && (
        si revisioninfo --revision=!Revision! "!FullPath!\!FileName!" | findstr "State:" >  temp.txt
        for /f "tokens=2 delims=; " %%y in (temp.txt) do 
        (
            set State = %%y
        )
    ) || (
        set State = "Invalid revision"
    )
    exit /B

:GET_AUTHOR
    :: Catch error if the revision is not valid or not exist
    2>nul (si revisioninfo --revision=!Revision! "!FullPath!\!FileName!" > nul) && (
        si revisioninfo --revision=!Revision! "!FullPath!\!FileName!" | findstr "Created By:" >  temp.txt
        for /f "tokens=2 delims=; " %%y in (temp.txt) do 
        (
            set Author = %%y
        )
    ) || (
        set Author = "Invalid"
    )
    exit /B

:STORE_OUTPUT
    echo !FileName!, !Revision!, !State!, !Author! >> "!CurFolder!"\!OutputFile!
    exit /B

:: OPTION2 - Find revision with a specific label 
:OPTION2
    cls
    cd %SandBox%
    echo Please choose one of the below options:
    echo 1) With members
    echo 2) With sandbox
    echo 3) Back to main MENU

    set /p _option="Your choice is: "
    if %_option%==1     goto OPTION2_1
    if %_option%==2     goto OPTION2_2
    if %_option%==3     goto MENU

    :: OPTION 2_1: With members
    :OPTION2_1
        cls
        set /p FileName="Enter your file name here: "
        set /p Label="Enter the label here: "

        call :GET_FULL_PATH
        call :VIEW_MEMBER_REVISION_WITH_LABEL

        goto CONFIRM_EXIT

    :: Show the revision with label
    :VIEW_MEMBER_REVISION_WITH_LABEL
        si viewlabels %FullPath%\%FileName% | find "%Label%"
        exit /B

    :: OPTION 2_2: With sandbox
    :OPTION2_2
        cls
        set /p Label="Enter the label here: "
        call :VIEW_SANDBOX_REVISION_WITH_LABEL
        goto CONFIRM_EXIT

    :VIEW_SANDBOX_REVISION_WITH_LABEL
    si viewprojecthistory --field=Labels,revision -P <project>
    exit /B

:: OPTION 3 - Set State for members
:OPTION3
    cls
    call :CHOOSE_INPUT
    call :REPLACE_SPACE
    call :SET_STATE
    call :DELETE_TEMP_FILE

    goto CONFIRM_EXIT

    :: Set state for members
    :SET_STATE
        echo Please choose one of the below options:
        echo 1) ready_for_review
        echo 2) reviewed
        echo 3) release

        set /p _option="Your choice is: "
        if %_option% == 1   set userState = "ready_for_review"
        if %_option% == 2   set userState = "reviewed"
        if %_option% == 3   set userState = "release"

        for /f "usebackq tokens=1-2 delims=," %%a in ("%TempInputFile%") do 
        (
            set FileName = %%a
            set Revision = %%b

            :: Catch error if the file is not found in the sandbox
            2>nul (dir .\!FileName! /S >nul) && (
                echo Setting state...
                call :GET_FULL_PATH
                call :PROMOTE_STATE
            ) || (
                set ErrorStatus = "File not found"
                echo !FileName!, !Revision!, !ErrorStatus!
            )
        )

        exit /B

    :PROMOTE_STATE
        :: Catch error if revision is not valid or not exist
        2>nul (si revisioninfo --revision=!Revision! "!FullPath!\!FileName!" > nul) && (
            si promote --revision=!Revision! --state=!userState! "!FullPath!\!FileName!" 
        ) || (
            set ErrorStatus = "Invalid revision"
            echo !FileName!, !Revision!, !ErrorStatus!
        )
        exit /B

:: OPTION 4 - View the keywords in all revision of a single file.
:OPTION4
    cls
    set ViewKeywordsOutput = ViewKeywordsOutput.txt
    set FileOfRevision_Temp = revisionTemp.txt
    if exist %ViewKeywordsOutput%   del %ViewKeywordsOutput%

    :: Get file's full path
    set /p FileName="Enter your file name here: "
    cd %SandBox%
    call :GET_FULL_PATH
    cd %CurFolder%

    :: Enter number keywords that need to be searched
    set /P NumOfKey="How many keywords: "
    for /L %%i in (1,1,!NumOfKey!) do (
        set /P Key%%i="Key%%i:"
        set Keys=!Keys! !Key%%i!
    )

    :: Get all revision of the file.
    si viewhistory !FullPath!\!FileName! | findstr "develop ready_for_review bug reviewed tested release" | findstr /v "State changed: " | findstr /B /R ??

    :: Search keywords in each revision and store it into an output file
    Setlocal EnableDelayedExpansion
    for /f "tokens=1 delims=    " %%a in (%FileOfRevision_Temp%) do 
    (
        set Revision=%%a
        echo !Revision! >> %ViewKeywordsOutput%
        si viewrevision --revision=!Revision! !FullPath!\!FileName! | findstr "!Keys!" >> %ViewKeywordsOutput%
    )
    endlocal
    
    call :DELETE_TEMP_FILE
    if exist %FileOfRevision_Temp% del %FileOfRevision_Temp%
    echo The output file is store in %CurFolder%\%ViewKeywordsOutput%

    goto CONFIRM_EXIT

:: =============================================Global API==============================================

:: Choose root sandbox folder
:CHOOSE_SANDBOX
    echo Please choose your sandbox directory!

    set "psfolder=Add-Type -AssemblyName System.windows.form | Out-Null;"
    set "psfolder=%psfolder% $f=New-Object System.Windows.Forms.FolderBrowserDialog;"
    set "psfolder=%psfolder% $f.showHelp=$true;"
    set "psfolder=%psfolder% $f.ShowDialog() | Out-Null;"
    set "psfolder=%psfolder% $f.SelectedPath"

    for /f "delims=" %%I in ('powershell "%psfolder%"') do set "SandBox=%%I"

    echo Your sandbox path: !SandBox!
    call :WRITE_CONFIG_INI [SANDBOX] !SandBox!
    goto MENU

:: Get full path of the file
:GET_FULL_PATH
    :: Search for file in the sandbox directory, then choose the lines with contain full path
    :: In case of '.h' file, it might be existed in more than 2 places

    set Local_temp = localtemp.txt
    ( dir .\!FileName! /S | find "Directory of " | findstr /v "generated" | findstr /v "_out" | findstr /v "VectorCAST") > %Local_temp%

    for /f %%C in ('Find /V /C "" ^< %Local_temp%') do set NumofLine=%%c
    if %NumofLine% gtr 1 
    (
        findstr /v "rb_cl_CustLib"  %Local_temp% > %TempFullPath%
    )
    else
    (
        copy %Local_temp% %TempFullPath% >nul
    )
    :: The output of above command has form of "Directory of C:\....". 
    :: To get full path, need to delete words "Directory of"

    if exist localtemp.txt      del localtemp.txt

    for /f "tokens=3 delims= " %%x in (%TempFullPath%) do 
    (
        set FullPath=%%x
    )

    exit /B

:: Choose the input file, with format (filename, revision) (With/Without space is OK)
:CHOOSE_INPUT
    echo Please choose your input file, with format (filename, revision) (With/Without space is OK)

    set "psfolder=Add-Type -AssemblyName System.windows.form | Out-Null;"
    set "psfolder=%psfolder% $f=New-Object System.Windows.Forms.OpenFileDialog;"
    set "psfolder=%psfolder% $f.Filter='Model Files (*.txt)|*.txt|All files (*.*)|*.*';"
    set "psfolder=%psfolder% $f.showHelp=$true;"
    set "psfolder=%psfolder% $f.ShowDialog() | Out-Null;"
    set "psfolder=%psfolder% $f.FileName"

    for /f "delims=" %%I in ('powershell "%psfolder%"') do set "InputFile=%%I"

    if defined InputFile (
        echo Your input file is !InputFile!
    ) else (
        echo You didn't choose anything!
        goto CHOOSE_INPUT
    )

    exit /B

:: Replace <space(s)> in each line of the input file if exist
:REPLACE_SPACE
    Setlocal EnableDelayedExpansion
    for /f "tokens=*" %%a in (%InputFile%) do
    (
        set tLine=%%b
        set tLine=!tLine: =!
        echo !tLine! >> %TempInputFile% 
    )
    endlocal
    cd %SandBox%
    exit /B

:: Delete temporary files
:DELETE_TEMP_FILE
    if exist temp.txt           del temp.txt
    if exist %TempInputFile%    del %TempInputFile%
    if exist %TempFullPath%     del %TempFullPath%

    exit /B

:CONFIRM_EXIT
    set /p isExit="Do you want to continue (y/n)?"

    if /I "%isExit"=="y"        goto MENU
    if /I "%isExit"=="n"        exit

@pause    