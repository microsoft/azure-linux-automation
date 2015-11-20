#!/bin/bash
if [[ "`cat /var/lib/hyperv/.kvp_pool_0`" =~ NdDriverVersion.*142 ]]; then
    zypper --non-interactive --no-gpg-checks update kernel*
else
    echo NdDriverVersion_String_Not_Found
fi
