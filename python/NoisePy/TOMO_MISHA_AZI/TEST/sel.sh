#!/bin/tcsh
awk '{if(($2 < 40) && ($2 > 35) && ($4 < 40) && ($4 > 35) && \
($3 < -115) && ($3 > -120) && ($5 < -115) && ($5 > -120)) print $0}' $1 > $2
exit
