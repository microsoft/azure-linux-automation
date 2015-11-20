#!/bin/bash
if [[ "`cat /var/lib/hyperv/.kvp_pool_0`" =~ "NdDriverVersion" ]]; then
    zypper --non-interactive --no-gpg-checks update kernel*
else
    echo NdDriverVersion_String_Not_Found
fi
