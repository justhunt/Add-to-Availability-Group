###If the sqlserver powershell module isnt installed, this script won't run correctly. This checks for the install.
if (Get-Module -ListAvailable -Name sqlserver) {
    Import-Module sqlserver
  } 
else {
Install-Module sqlserver
Import-Module sqlserver
}
 
###Allows us to create the Windows form
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#The drop down list of servers, that also works as a text box, needs an array of options for the drop down box. Add servers to this inside of "double quotes".
$computerNames = @("<server-Name>")

function ServerName{
    ###Server Name###
    #Sets up the form for the server name
    $formServerName = New-Object System.Windows.Forms.Form
    $formServerName.Text = 'Server Name'
    $formServerName.Size = New-Object System.Drawing.Size(300,200)
    $formServerName.StartPosition = 'CenterScreen'

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(75,120)
    $okButton.Size = New-Object System.Drawing.Size(75,23)
    $okButton.Text = 'OK'
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $formServerName.AcceptButton = $okButton
    $formServerName.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(150,120)
    $cancelButton.Size = New-Object System.Drawing.Size(75,23)
    $cancelButton.Text = 'Cancel'
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $formServerName.CancelButton = $cancelButton
    $formServerName.Controls.Add($cancelButton)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10,20)
    $label.Size = New-Object System.Drawing.Size(280,30)
    $label.Text = 'Please enter the server name you are working on:'
    $formServerName.Controls.Add($label)

    $comboBox = New-Object System.Windows.Forms.ComboBox
    $comboBox.Location = New-Object System.Drawing.Point(10, 55)
    $comboBox.Size = New-Object System.Drawing.Size(265, 310)
    foreach($computer in $computerNames)
    {
        [void]$comboBox.Items.add($computer)
    }
    $formServerName.Controls.Add($comboBox)


    $formServerName.Topmost = $true

    $formServerName.Add_Shown({$comboBox.Select()})
    $result = $formServerName.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK)
    {
        #Set our ServerName variable equal to whatever server the user chose in the Windows Form for the entire script.
        $Script:ServerName = $comboBox.Text
        
        #If the server name entered is not in the array above, this adds it to the array
        if($computerNames -notcontains $ServerName) {
            $file = $PSCommandPath
            $file
            $original = (Get-Content -Path $file -Raw)
            
            #Match the end of the line that is the array
            $text = $original -match '(\$computerNames\ =\ @\(.+"\))'
            $text = $Matches.1
            $len = $text.Length - 1
            
            #Insert the "new" server name into the array
            $newtext = $text.Insert($len,",""$ServerName""")
            
            #Replace the file with the new text
            $final = $original.Replace($text, $newtext)
            $final | Set-Content -Path $file
        }
    }
    else{
        exit
    }
}
#Run the ServerName function above to get the server you are checking for databases not in AG's.
ServerName

function DatabaseName{
    ###Database Name###
    #Sets up the form for the databases that aren't in an AG
    $formDatabaseName = New-Object System.Windows.Forms.Form -Property @{
        Text = 'Database Name'
        Size = New-Object System.Drawing.Size(400,700)
        StartPosition = 'CenterScreen'
    }

    $DatabaseNameCancelButton = New-Object System.Windows.Forms.Button -Property @{
        Location = New-Object System.Drawing.Point(($formDatabaseName.Width/2),($formDatabaseName.Height-100))
        Size = New-Object System.Drawing.Size(75,23)
        Text = 'Cancel'
        Anchor = (
        [System.Windows.Forms.AnchorStyles]::Bottom -bor
        [System.Windows.Forms.AnchorStyles]::Right
        )
        DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    }
    $formDatabaseName.CancelButton = $DatabaseNameCancelButton
    $formDatabaseName.Controls.Add($DatabaseNameCancelButton)

    $okButton = New-Object System.Windows.Forms.Button -Property @{
        Location = New-Object System.Drawing.Point(($DatabaseNameCancelButton.Location.X-75),($DatabaseNameCancelButton.Location.Y))
        Size = New-Object System.Drawing.Size(75,23)
        Text = 'OK'
        Anchor = (
        [System.Windows.Forms.AnchorStyles]::Bottom -bor
        [System.Windows.Forms.AnchorStyles]::Right
        )
        DialogResult = [System.Windows.Forms.DialogResult]::OK
    }
    $formDatabaseName.AcceptButton = $okButton
    $formDatabaseName.Controls.Add($okButton)

    $label = New-Object System.Windows.Forms.Label -Property @{
        Location = New-Object System.Drawing.Point((($formDatabaseName.Left) + 10),(($formDatabaseName.Top) + 40))
        Size = New-Object System.Drawing.Size(400,40)
        Text = "Please choose each database you want to add to AG on $ServerName`:"
        Font = New-Object System.Drawing.Font("Arial", 10.5)
    }
    $formDatabaseName.Controls.Add($label)

    $DatabaseNameslistBox = New-Object System.Windows.Forms.Listbox -Property @{
        Location = New-Object System.Drawing.Point((($formDatabaseName.Left) + 40),(($formDatabaseName.Top) + 90))
        Size = New-Object System.Drawing.Size(($formDatabaseName.Width - 100), ($formDatabaseName.Height - 230))
        Font = New-Object System.Drawing.Font("Arial", 10.5)
        Anchor = (
        [System.Windows.Forms.AnchorStyles]::Bottom -bor
        [System.Windows.Forms.AnchorStyles]::Left -bor
        [System.Windows.Forms.AnchorStyles]::Right -bor
        [System.Windows.Forms.AnchorStyles]::Top
        )
        AutoSize = $false
        Sorted = $true
        SelectionMode = 'MultiExtended'
    }
    $formDatabaseName.Controls.Add($DatabaseNameslistBox)
    $formDatabaseName.Topmost = $true

    #This is the sql query we use on the server specified in the ServerName function. It will select all db's not in an AG
    $DatabaseNamesQuery = "select DISTINCT sd.name
    from sys.databases as sd
    left outer join sys.dm_hadr_database_replica_states  as hdrs on hdrs.database_id = sd.database_id
    left outer join sys.dm_hadr_name_id_map as grp on grp.ag_id = hdrs.group_id
    where grp.ag_name is null
    and sd.name not in ('master','model','msdb','tempdb')"
    
    #Get the databases using the tsql above on the ServerName chosen in the ServerName function
    $DatabaseNames = @(Invoke-Sqlcmd -ServerInstance $ServerName -Query $DatabaseNamesQuery | Select-Object name)
    
    #For each database found, add it to our Windows Form for the user to select
    foreach($DatabaseName in $DatabaseNames.Name){
        [void] $DatabaseNameslistBox.Items.Add($DatabaseName)
    }

    $result = $formDatabaseName.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK){
        $Script:DatabaseNames = $DatabaseNameslistBox.SelectedItems
    }
    else{
        exit
    }
}
#Run the DatabaseName function above
DatabaseName

#Set up the tsql variable we will be saving to a file at the end of the program
$agdbAddTsql = ""

#For each database the user select in the DatabaseName function
foreach($DatabaseName in $DatabaseNames){
    ###Get server replica
    $ServerReplicaQuery = "SELECT DISTINCT replica_server_name
    FROM sys.availability_replicas
    WHERE replica_server_name not in(SELECT @@SERVERNAME)"
    $MachineReplica = @(Invoke-SQLCmd -ServerInstance $ServerName -query $ServerReplicaQuery) | Select-Object replica_server_name
    $MachineReplica = $MachineReplica.replica_server_name
    $ServerReplicaName = $MachineReplica + ".services.ads.tamu.edu"
    
    ###Get any AG. Can specify in a where clause for this tsql
    $agquery = "SELECT TOP 1
    Groups.[Name] AS AGname
    FROM master.sys.availability_groups Groups
    INNER JOIN sys.availability_databases_cluster AGDatabases ON Groups.group_id = AGDatabases.group_id"

    #Get the AG name in a variable
    $agdb = @(Invoke-Sqlcmd -ServerInstance $ServerName -Query $agquery) | Select-Object AGname
    $agdb = $agdb.AGname
    
    #This adds the databases to the AG on both servers. By adding to the secondary replica AG this way, the database is being created on the secondary server as well.
    $agdbAddTsql = $agdbAddTsql + "------ Add $DatabaseName to both the primary and secondary replica AG's.`n" +
    "PRINT CHAR(13)+CHAR(10) + '*********' + CHAR(13)+CHAR(10) + 'Adding $DatabaseName to Availability Group' + CHAR(13)+CHAR(10) + '*********' + CHAR(13)+CHAR(10) + CHAR(13)+CHAR(10)`nGO`n" +
    ":Connect $ServerName
    USE [master]
    GO

    ALTER AVAILABILITY GROUP [$agdb]
    MODIFY REPLICA ON N'$MachineReplica' WITH (SEEDING_MODE = AUTOMATIC)
    GO

    USE [master]
    GO

    ALTER AVAILABILITY GROUP [$agdb]
    ADD DATABASE [$DatabaseName];
    GO`n" + 
    ":Connect $ServerReplicaName

    ALTER AVAILABILITY GROUP [$agdb] GRANT CREATE ANY DATABASE;
    GO`n`n"   
}
#Save the tsql to a the same folder as this script
$agdbAddTsql | Out-File "$PSScriptRoot\Add_to_AG.sql"

