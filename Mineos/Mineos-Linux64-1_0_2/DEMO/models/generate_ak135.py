# output ak135 model in a wanted format
#  awk '{if(NR>3)printf "%8f  %8f  %8f  %8f  %8f  %8f  %8f  %8f  %8f\n",(6371.0-$1)*1000,$2*1000,$3*1000,$4*1000,$5,$6,$3*1000,$4*1000,1.}' ak135.txt > temp
import sys
import string


i=0
list=[]
for line in open("ak135_nowater.txt"):
	i=i+1
	if (i<=3):
		continue
	list.append(line)

fout=open("ak135_iso_nowater.txt","w")
fout.write("ak135 spherical average structure, isotropic case\n1       1       1 # this is nonsence, I just want to match the format of PREM model\n147     25      71 # IMPORTANT CHANGE THIS\n")
N=len(list)
for i in range(N):
	l=list[N-i-1].rstrip().split()
	radius=6371000.-1000*float(l[0])	
	rho = float(l[1])*1000
	vp = float(l[2])*1000
	vs = float(l[3])*1000
	qp = float(l[4])
	qs = float(l[5])
	fout.write( "%8f  %8f  %8f  %8f  %8f  %8f  %8f  %8f  %8f\n"%(radius,rho,vp,vs,qp,qs,vp,vs,1.))
fout.close()	



