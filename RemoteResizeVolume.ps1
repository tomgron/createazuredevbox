$disk = Get-Disk -Number 0
$partition = Get-Partition -Disk $disk | where DriveLetter -eq 'C'
$size = Get-PartitionSupportedSize -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber
Resize-Partition -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber -Size $size.SizeMax