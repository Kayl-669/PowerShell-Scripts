$pattern = Read-Host -Prompt 'Input search string'
$path = "C:\Users\james.holloway\Google Drive\diary"

Get-ChildItem -Path $path -Recurse -Filter *$pattern*

Read-Host -Prompt 'Press Enter to quit'