<#
.SYNOPSIS

A Powershell clone of the classic TreeSize administrators tool. Works on local volumes or network shares.

Outputs the report to one or more interactive HTML files, and optionally zips them into a single zip file.

Requires Powershell 2. For Windows 2003 servers, install http://support.microsoft.com/kb/968930

Author: James Weakley (jameswillisweakley@gmail.com)

.DESCRIPTION

Recursively iterates a folder structure and reports on the space consumed below each individual folder. 
Outputs to a single HTML file which, with the help of a couple of third party javascript libraries,
displays in a web browser as an expandable tree, sorted by largest first.

.PARAMETER paths 

One or more comma separated locations to report on. 
A report on each of these locations will be output to a single HTML file per location, defined by htmlOutputFilenames

Pass in the value "ALL" to report on all fixed disks.

.PARAMETER reportOutputFolder

The folder location to output the HTML report(s) and zip file. This folder must exist already.

.PARAMETER htmlOutputFilenames

One or more comma separated filenames to output the HTML reports to. There must be one of these to correspond with each path specified.

If "ALL" is specified for paths, then this parameter is ignored and the reports use the filenames "C_Drive.html","D_Drive.html", and so on

.PARAMETER zipOutputFilename

Name of zip file to place all generated HTML reports in.

If this value is empty, HTML files are not zipped up.

.PARAMETER topFilesCountPerFolder

Setting this parameter filters the number of files shown at each level.

For example, setting it to 10 will mean that at each folder level, only the largest 10 files will be displayed in the report. 
The count and sum total size of all other files will be shown as one item.

The default value is 20. 

Setting the value to -1 disables filtering and always displays all files. Note that this may generate HTML files large enough to crash your web browser!

.PARAMETER folderSizeFilterDepthThreshold

Enables a folder size filter which, in conjunction with folderSizeFilterMinSize, excludes from the report sections of the tree that are smaller than a particular size.

This value determines how many subfolders deep to travel before applying the filter.

The default value is 8

Note that this filter does not affect the accuracy of the report. The total size of the filtered out branches are still displayed in the report, you just can't drill down any further.

Setting the value to -1 disables filtering and always displays all files. Note that this may generate HTML files large enough to crash your web browser!

.PARAMETER folderSizeFilterMinSize

Used in conjunction with folderSizeFilterDepthThreshold to excludes from the report sections of the tree that are smaller than a particular size.

This value is in bytes.

The default value is 104857600 (100MB)

.PARAMETER displayUnits

A string which must be one of "B","KB","MB","GB","TB". This is the units to display in the report.

The default value is MB

.EXAMPLE

TreeSizeHtml -paths "C:\" -reportOutputFolder "C:\temp" -htmlOutputFilenames "c_drive.html"

This will output a report on C:\ to C:\temp\c_drive.html using the default filter settings.


.EXAMPLE

TreeSizeHtml -paths "C:\,D:\" -reportOutputFolder "C:\temp" -htmlOutputFilenames "c_drive.html,d_drive.html" -zipOutputFilename "report.zip"

This will output two size reports: 
- A report on C:\ to C:\temp\c_drive.html
- A report on D:\ to C:\temp\d_drive.html

Both reports will be placed in a zip file at "C:\temp\report.zip"

.EXAMPLE 

TreeSizeHtml -paths "\\nas\ServerBackups" -reportOutputFolder "C:\temp" -htmlOutputFilenames "nas_server_backups.html" -topFilesCountPerFolder -1 -folderSizeFilterDepthThreshold -1

This will output a report on \\nas\ServerBackups to c:\temp\nas_server_backups.html

The report will include all files and folders, no matter how many or how small

.EXAMPLE 

TreeSizeHtml -paths "E:\" -reportOutputFolder "C:\temp" -htmlOutputFilenames "e_drive_summary.html" -folderSizeFilterDepthThreshold 0 -folderSizeFilterMinSize 1073741824

This will output a report on E:\ to c:\temp\e_drive_summary.html

As soon as a branch accounts for less than 1GB of space, it is excluded from the report.

.NOTES

You need to run this function as a user with permission to traverse the tree, otherwise you'll have sections of the tree labeled 'Permission Denied'

#>
#requires -version 2

param (
       [Parameter(Mandatory=$true)][String] $paths,
       [Parameter(Mandatory=$true)][String] $reportOutputFolder,
       [Parameter(Mandatory=$false)][String] $htmlOutputFilenames = $null,
       [Parameter(Mandatory=$false)][String] $zipOutputFilename = $null,
       [Parameter(Mandatory=$false)][int] $topFilesCountPerFolder = 10,
       [Parameter(Mandatory=$false)][int] $folderSizeFilterDepthThreshold = 2,
       [Parameter(Mandatory=$false)][long] $folderSizeFilterMinSize = 104857600,
       [Parameter(Mandatory=$false)][String] $displayUnits = "MB"
    )


function TreeSizeHtml { 
    
    $ErrorActionPreference = "Stop"
    
    $pathsArray = @();
    $htmlFilenamesArray = @();
    

    # check output folder exists
    if (!($reportOutputFolder.EndsWith("\")))
    {
        $reportOutputFolder = $reportOutputFolder + "\"
    }

    $reportOutputFolderInfo = New-Object System.IO.DirectoryInfo $reportOutputFolder
    if (!$reportOutputFolderInfo.Exists)
    {
        Throw "Report output folder $reportOutputFolder does not exist"
    }
    

    # passing in "ALL" means that all fixed disks are to be included in the report
    if ($paths -eq "ALL")
    {
        gwmi win32_logicaldisk -filter "drivetype = 3" | % {
            $pathsArray += $_.DeviceID+"\"
            $htmlFilenamesArray += $_.DeviceID.replace(":","_Drive.html");
        }
        
    }
    else
    {
        if ($htmlOutputFilenames -eq $null -or $htmlOutputFilenames -eq '')
        {
            throw "paths was not 'ALL', but htmlOutputFilenames was not defined. If paths are defined, then the same number of htmlOutputFileNames must be specified."
        }
        # split up the paths and htmlOutputFilenames parameters by comma
        $pathsArray = $paths.split(",");
        $htmlFilenamesArray = $htmlOutputFilenames.split(",");
        if (!($pathsArray.Length -eq $htmlFilenamesArray.Length))
        {
            Throw "$($pathsArray.Length) paths were specified but $($htmlFilenamesArray.Length) htmlOutputFilenames. The number of HTML output filenames must be the same as the number of paths specified"
        }
    }
    for ($i=0;$i -lt $htmlFilenamesArray.Length; $i++)
    {
        $htmlFilenamesArray[$i] = ($reportOutputFolderInfo.FullName)+$htmlFilenamesArray[$i]
    }
    if (!($zipOutputFilename -eq $null -or $zipOutputFilename -eq ''))
    {
        $zipOutputFilename = ($reportOutputFolderInfo.FullName)+$zipOutputFilename
    }
    
    write-host "Report Parameters"
    write-host "-----------------"
    write-host "Locations to include:"
    for ($i=0;$i -lt $pathsArray.Length;$i++)
    {
        write-host "- $($pathsArray[$i]) to $($htmlFilenamesArray[$i])"        
    }
    if ($zipOutputFilename -eq $null -or $zipOutputFilename -eq '')
    {
        write-host "Skipping zip file creation"
    }
    else
    {
        write-host "Report HTML files to be zipped to $zipOutputFilename"
    }
    
    write-host
    write-host "Filters:"
    if ($topFilesCountPerFolder -eq -1)
    {
        write-host "- Display all files"
    }
    else
    {
        write-host "- Displaying largest $topFilesCountPerFolder files per folder"
    }
    
    if ($folderSizeFilterDepthThreshold -eq -1)
    {
        write-host "- Displaying entire folder structure"
    }
    else
    {
        write-host "- After a depth of $folderSizeFilterDepthThreshold folders, branches with a total size less than $folderSizeFilterMinSize bytes are excluded"
    }    
        
    write-host
    
    for ($i=0;$i -lt $pathsArray.Length; $i++){
    
        $_ = $pathsArray[$i];
        # get the Directory info for the root directory
        $dirInfo = New-Object System.IO.DirectoryInfo $_
        # test that it exists, throw error if it doesn't
        if (!$dirInfo.Exists)
        {
            Throw "Path $dirInfo does not exist"
        }
        
        
        write-host "Building object tree for path $_"
        # traverse the folder structure and build an in-memory tree of objects
        $treeStructureObj = @{}
        buildDirectoryTree_Recursive $treeStructureObj $_
        $treeStructureObj.Name = $dirInfo.FullName; #.replace("\","\\");
        
        
        write-host "Building HTML output"
        
        # initialise a StringBuffer. The HTML will be written to here
        $sb = New-Object -TypeName "System.Text.StringBuilder";
        
        # output the HTML and javascript for the report page to the StringBuffer
        # below here are mostly comments for the javascript code, which  
        # runs in the browser of the user viewing this report
        sbAppend "<!DOCTYPE html>"
        sbAppend "<html>"
        sbAppend "<head>"
        # jquery javascript src (from web)
        sbAppend "<link rel=`"stylesheet`" href=`"http://jquery.bassistance.de/treeview/jquery.treeview.css`" />"
        sbAppend "<script src='http://static.jstree.com/v.1.0pre/jquery.js' type='text/javascript'></script>"
        # jstree javascript src (from web)
        sbAppend "<script src='http://jquery.bassistance.de/treeview/jquery.treeview.js' type='text/javascript'></script>"
        sbAppend "<script type='text/javascript'>"
        # check that jquery and jstree loaded in the browser, display error messages if they aren't
        sbAppend "function checkjQuery()"
        sbAppend "{"
        sbAppend "  if (typeof jQuery=='undefined' || typeof `$('#tree').treeview=='undefined')"
        sbAppend "  {"
        sbAppend "     var errorMsg = 'Error: Internet access is required to view this report, as the jQuery and JsTree javascript libraries are loaded from web sources.<br/><br/>';"
        sbAppend "     if (typeof jQuery=='undefined')"
        sbAppend "     {"
        sbAppend "       errorMsg+='Unable to load jQuery from http://static.jstree.com/v.1.0pre/jquery.js<br/>';"
        sbAppend "     }"
        sbAppend "     if (typeof `$('#tree').treeview=='undefined')"
        sbAppend "     {"
        sbAppend "       errorMsg+='Unable to load treeview from http://jquery.bassistance.de/treeview/jquery.treeview.js<br/>';"
        sbAppend "     }"
        sbAppend "     "
        sbAppend "     document.getElementById('error').innerHTML=errorMsg;"
        sbAppend "  }"
        sbAppend "  else"
        sbAppend "  {"
        # initialise treeview
        sbAppend "  `$(function () {"
        sbAppend "    `$('#tree').treeview({"
        sbAppend "            collapsed: true,"
		sbAppend "    		animated: 'medium',"
		sbAppend "    		persist: `"location`""
        sbAppend "         });"
        sbAppend "     })"
        sbAppend "  }"
        sbAppend "}"
        sbAppend "window.onload = checkjQuery; "
        sbAppend "</script>"
        sbAppend "</head>"
        sbAppend "<body>"
        sbAppend "<div id='header'>"
        sbAppend "<h1>Disk utilisation report</h1>"
        sbAppend "<h3>Root Directory: ($($dirInfo.FullName))</h3>"
        $machine = hostname
        sbAppend "<h3>Generated on machine: $machine</h3>"
        sbAppend "<h3>Report Filters</h3>"
        sbAppend "<ul>"
        
        if ($topFilesCountPerFolder -eq -1)
        {
            sbAppend "<li>Displaying all files</li>"
        }
        else
        {
            sbAppend "<li>Displaying largest $topFilesCountPerFolder files per folder</li>"
        }
        
        if ($folderSizeFilterDepthThreshold -eq -1)
        {
            sbAppend "<li>Displaying entire folder structure</li>"
        }
        else
        {
            sbAppend "<li>After a depth of $folderSizeFilterDepthThreshold folders, branches with a total size less than $folderSizeFilterMinSize bytes are excluded</li>"
        }    
        
        sbAppend "</ul>"
        sbAppend "</div>"
        sbAppend "<div id='error'/>"
        sbAppend "<div id='report''>"
        sbAppend "<ul id='tree' class='filetree'>"
        
        $size = bytesFormatter $treeStructureObj.SizeBytes $displayUnits
        $name = $treeStructureObj.Name.replace("'","\'")        
        # output the name and total size of the root folder
        sbAppend "   <li><span class='folder'>$name ($size)</span>"
        sbAppend "     <ul>"
        # recursively build the javascript object in the format that jsTree uses
        outputNode_Recursive $treeStructureObj $sb $topFilesCountPerFolder $folderSizeFilterDepthThreshold $folderSizeFilterMinSize 1;
        sbAppend "     </ul>"
        sbAppend "   </li>"
        sbAppend "</ul>"
        sbAppend "</div>"
        
        
        
        # include a loading message and spinny icon while jsTree initialises
        #sbAppend "<div id='tree'>Loading...<img src='http://static.jstree.com/v.1.0pre/themes/default/throbber.gif'/></div>"
        sbAppend "</body>"
        sbAppend "</html>"
        
        
        # finally, output the contents of the StringBuffer to the filesystem
        $outputFileName = $htmlFilenamesArray[$i]
        write-host "Writing HTML to file $outputFileName"
        
        Out-file -InputObject $sb.ToString() $outputFileName -encoding "UTF8"
    }
    
    if ($zipOutputFilename -eq $null -or $zipOutputFilename -eq '')
    {
        write-host "Skipping zip file creation"
    }
    else
    {
        # create zip file
    	set-content $zipOutputFilename ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
    	(dir $zipOutputFilename).IsReadOnly = $false
        
        for ($i=0;$i -lt $htmlFilenamesArray.Length; $i++){
            
            write-host "Copying $($htmlFilenamesArray[$i]) to zip file $zipOutputFilename"
            $shellApplication = new-object -com shell.application
        	$zipPackage = $shellApplication.NameSpace($zipOutputFilename)
            
        	$zipPackage.CopyHere($htmlFilenamesArray[$i])
            
            # the zip is asynchronous, so we have to wait and keep checking (ugly)
            # use a DirectoryInfo object to retrieve just the file name within the path, 
            # this is what we check for every second
            $fileInfo = New-Object System.IO.DirectoryInfo $htmlFilenamesArray[$i]
            
            $size = $zipPackage.Items().Item($fileInfo.Name).Size
            while($zipPackage.Items().Item($fileInfo.Name) -Eq $null)
            {
                start-sleep -seconds 1
                write-host "." -nonewline
            }
        }
        $inheritance = get-acl $zipOutputFilename
        $inheritance.SetAccessRuleProtection($false,$false)
        set-acl $zipOutputFilename -AclObject $inheritance
    }
    
} 
<#
.SYNOPSIS

Used internally by the TreeSizeHtml function. 

Used to perform Depth-First (http://en.wikipedia.org/wiki/Depth-first_search) search of the entire folder structure. 
This allows the cumulative total of space used to be added up during backtracking.

.PARAMETER currentNode 

The current node object, a temporary custom object which represents the current folder in the tree.

.PARAMETER currentPath

The path to the current folder in the tree

#>
function buildDirectoryTree_Recursive {  
        param (  
            [Parameter(Mandatory=$true)][Object] $currentParentDirInfo,  
            [Parameter(Mandatory=$true)][String] $currentDirInfo 
        )  
    $substDriveLetter = $null
    # Get the directory info of the current path

    # if the current directory length is too long, try to work around the feeble Windows size limit by using the subst command
    if ($currentDirInfo.Length -gt 248)
    {
    	if ($currentDirInfo.Contains("`$Recycle.Bin"))
        {
            write-host "Skipping path under `$Recycle.Bin folder that is too long";
            return;
        }
        Write-Host "$currentDirInfo has a length of $($currentDirInfo.Length), greater than the maximum 248, invoking workaround"
        $substDriveLetter = ls function:[d-z]: -n | ?{ !(test-path $_) } | select -First 1
        $parentFolder = ($currentDirInfo.Substring(0,$currentDirInfo.LastIndexOf("\")))
        $relative = $substDriveLetter+($currentDirInfo.Substring($currentDirInfo.LastIndexOf("\")))
        write-host "Mapping $substDriveLetter to $parentFolder for access via $relative"
        subst $substDriveLetter $parentFolder


        $dirInfo = New-Object System.IO.DirectoryInfo $relative

    }
    else
    {
        $dirInfo = New-Object System.IO.DirectoryInfo $currentDirInfo 
    }

    # add its details to the currentParentDirInfo object
    $currentParentDirInfo.Files = @()
    $currentParentDirInfo.Folders = @()
    $currentParentDirInfo.SizeBytes = 0;
    $currentParentDirInfo.Name = $dirInfo.Name;
    $currentParentDirInfo.Type = "Folder";
    
    

    # iterate all subdirectories
    try
    {
    	#don't include reparse points
        $dirs = $dirInfo.GetDirectories() | where {!$_.Attributes.ToString().Contains("ReparsePoint")};
        $files = $dirInfo.GetFiles();
        # remove any drive mappings created via subst above
        if (!($substDriveLetter -eq $null))
        {
            write-host "removing substitute drive $substDriveLetter"
            subst $substDriveLetter /D
            $substDriveLetter = $null
        }

        $dirs | % { 
            # create a new object for the subfolder to pass in
            $subFolder = @{}
            # call this function in the subfolder. It will return after the entire branch from here down is traversed
            buildDirectoryTree_Recursive $subFolder ($currentDirInfo + "\" + $_.Name);
            # add the subfolder object to the list of folders at this level
            $currentParentDirInfo.Folders += $subFolder;
            # the total size consumed from the subfolder down is now available. 
            # Add it to the running total for the current folder
            $currentParentDirInfo.SizeBytes= $currentParentDirInfo.SizeBytes + $subFolder.SizeBytes;
            
        }
        # iterate all files
        $files | % { 
            # create a custom object for each file, containing the name and size
            $htmlFileObj = @{};
            $htmlFileObj.Type = "File";
            $htmlFileObj.Name = $_.Name;
            $htmlFileObj.SizeBytes = $_.Length
            # add the file object to the list of files at this level
            $currentParentDirInfo.Files += $htmlFileObj;
            # add the file's size to the running total for the current folder
            $currentParentDirInfo.SizeBytes= $currentParentDirInfo.SizeBytes + $_.Length
        }
    }
    catch [Exception]
    {
        if ($_.Exception.Message.StartsWith('Access to the path'))
        {
            $currentParentDirInfo.Name = $currentParentDirInfo.Name + " (Access Denied to this location)"
        }
        else
        {
            Write-Host $_.Exception.ToString()
        }
    }
} 
<#
.SYNOPSIS

Used internally by the TreeSizeHtml function. 

Takes a number in bytes, and a string which must be one of B,KB,MB,GB,TB and returns a nicely formatted converted string.

.EXAMPLE 

bytesFormatter -bytes 102534233454 -notation "MB"
returns "97,784 MB"
#>
function bytesFormatter{param (
        [Parameter(Mandatory=$true)][decimal][AllowNull()] $bytes,
        [Parameter(Mandatory=$true)][String] $notation
    )
    if ($bytes -eq $null)
    {
        return "unknown size";
    }
    $notation = $notation.ToUpper();
    if ($notation -eq 'B')
    {
        return ($bytes.ToString())+" B";
    }
    if ($notation -eq 'KB')
    {
        return (roundOffAndAddCommas($bytes/1024)).ToString() + " KB"
    }
    if ($notation -eq 'MB')
    {
        return (roundOffAndAddCommas($bytes/1048576)).ToString() + " MB"
    }
    if ($notation -eq 'GB')
    {
        return (roundOffAndAddCommas($bytes/1073741824)).ToString() + " GB"
    }
    if ($notation -eq 'TB')
    {
        return (roundOffAndAddCommas($bytes/1099511627776)).ToString() + " TB"
    }
    Throw "Unrecognised notation: $notation. Must be one of B,KB,MB,GB,TB"
}

<#
.SYNOPSIS

Used internally by the TreeSizeHtml function. 

Takes a number and returns it as a string with commas as thousand separators, rounded to 2dp 
#>
function roundOffAndAddCommas{param(
    [Parameter(Mandatory=$true)][decimal] $number)
    $value = "{0:N2}" -f $number;
    return $value.ToString();
}

function sbAppend{param(
    [Parameter(Mandatory=$true)][string] $stringToAppend)
    $sb.Append($stringToAppend) | out-null;
}

<#
.SYNOPSIS

Used internally by the TreeSizeHtml function. 

Used to output the folder tree to a StringBuffer in the format of an HTML unordered list which the TreeView library can display.

.PARAMETER node 

The current node object, a temporary custom object which represents the current folder in the tree.

#>
function outputNode_Recursive{
    param (
        [Parameter(Mandatory=$true)][Object] $node,
        [Parameter(Mandatory=$true)][System.Text.StringBuilder] $sb,
        [Parameter(Mandatory=$true)][int] $topFilesCountPerFolder,
        [Parameter(Mandatory=$true)][int] $folderSizeFilterDepthThreshold,
        [Parameter(Mandatory=$true)][long] $folderSizeFilterMinSize,
        [Parameter(Mandatory=$true)][int] $CurrentDepth
    )
    
    # If there is more than one subfolder from this level, sort by size, largest first
    if ($node.Folders.Length -gt 1)
    {
        $folders = $node.Folders | Sort -Descending {$_.SizeBytes}
    }
    else
    {
        $folders = $node.Folders
    }
    # iterate each subfolder
    for ($i = 0; $i -lt $node.Folders.Length; $i++)
    {
        $_ = $folders[$i];
        # append to the string buffer a HTML List Item which represents the properties of this folder
        
        $size = bytesFormatter $_.SizeBytes $displayUnits
        $name = $_.Name.replace("'","\'")
        sbAppend "<li><span class='folder'>$name ($size)</span>"
        sbAppend "<ul>"
        
        if ($name -eq "winsxs")
        {
            sbAppend "<li><span class='folder'>Contents of folder hidden as <a href='http://support.microsoft.com/kb/2592038'>winsxs</a> commonly contains tens of thousands of files</span></li>"
        }
        elseif ($folderSizeFilterDepthThreshold -le $CurrentDepth -and $_.SizeBytes -lt $folderSizeFilterMinSize)
        {
            sbAppend "<li><span class='folder'>Contents of folder hidden via size filter</span></li>"
        }
        else
        {
            # call this function in the subfolder. It will return after the entire branch from here down is output to the string buffer
            outputNode_Recursive $_ $sb $topFilesCountPerFolder $folderSizeFilterDepthThreshold $folderSizeFilterMinSize ($CurrentDepth+1);
        }
        
        sbAppend "</ul>"        
        sbAppend "</li>"
        
    } 
    # If there is more than one file on level, sort by size, largest first
    if ($node.Files.Length -gt 1)
    {
        $files = $node.Files | Sort -Descending {$_.SizeBytes}
    }
    else
    {
        $files = $node.Files
    }
    # iterate each file
    for ($i = 0; $i -lt $node.Files.Length; $i++)
    {
        if ($i -lt $topFilesCountPerFolder)
        {
            $_ = $files[$i];
            # append to the string buffer a HTML List Item which represents the properties of this file
            $size = bytesFormatter $_.SizeBytes $displayUnits
            $name = $_.Name.replace("'","\'")
            sbAppend "<li><span class='file'>$name ($size)</span></li>"
        }
        else
        {
            $remainingFilesSize = 0;
            while ($i -lt $node.Files.Length)
            {
                $remainingFilesSize += $files[$i].SizeBytes
                $i++;
            }
            $size = bytesFormatter $_.SizeBytes $displayUnits
            $name = "..."+($node.Files.Length-$topFilesCountPerFolder)+" more files"
            sbAppend "<li><span class='file'>$name ($size)</span></li>"
        }
    } 
}
TreeSizeHtml
