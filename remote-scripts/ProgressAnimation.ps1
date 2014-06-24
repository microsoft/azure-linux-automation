for($i = 1; $i -lt 50; $i++ )
{
    write-progress -Id 77 -activity "Executing Cycle :" -status 'In progress' -percentcomplete $i -CurrentOperation "Network-FTM"
    for($j = 1; $j -lt 50; $j++ )
    {
        write-progress -id 89 -activity "Executing Test : " -status 'In Progress' -percentcomplete $j -CurrentOperation "Network-IE-TCP-IPERF-PARALLEL"
        for($k = 1; $k -lt 100; $k++ )
        {
            write-progress -id 23 -activity "Executing Subtest for value : 4" -status 'In Progress' -percentcomplete $k -CurrentOperation "Deploying Virtual Machine.." ; sleep -Milliseconds 10
        }
    }
}