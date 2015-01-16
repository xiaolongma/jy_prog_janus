        program hspec96
c---------------------------------------------------------------------c
c                                                                     c
c      COMPUTER PROGRAMS IN SEISMOLOGY                                c
c      VOLUME VI                                                      c
c                                                                     c
c      PROGRAM: HSPEC96                                               c
c                                                                     c
c      COPYRIGHT 1996                                                 c
c      R. B. Herrmann                                                 c
c      Department of Earth and Atmospheric Sciences                   c
c      Saint Louis University                                         c
c      221 North Grand Boulevard                                      c
c      St. Louis, Missouri 63013                                      c
c      U. S. A.                                                       c
c                                                                     c
c---------------------------------------------------------------------c
c       CHANGES
c       11 SEP 2000 - build in P, SV and SH first arrival times
c       14 JAN 2001 - put in A, C, F, L and N constants into
c           trace header
c       18 MAR 2001 - new formalism from Herrmann (2001) 
c           Seismic Waves in Layered Media
c       18 JUL 2001 - fixed specification for KSRC when source and
c           receiver are in fluids. 
c       09 APR 2002 - another hack at fixing the 
c           JSRC when fluids are involved.
c           commented out lines in gethsp which was not correct, 
c           modified output loop 
c       29 OCT 2002 - Fixed evalg and evalh for fluid layers
c       18 APR 2005 - put in simple minded earth flattening 
c           for J. Ritsema
c       16 JUN 2005 - travel time for P and S work for spherical
c       04 AUG 2006 - corrected error in first arrival pick that
c               falsely gave the refraction time instead of the
c               direct time because the refraction arrival was
c               unphysical
c       15 DEC 2007 - introduced an earth flattening correction
c               that uses a different density mapping for the SH and
c               P-SV problems 
c               The sphericity correction invoked for a spherical model
c               is as follows
c               
c               Spherical              Flat
c                   r                  x=ln(a/r)   where a is radius of sphere
c               velocity               velocity*(a/r)
c               density                density*(r/a)**POWER
c                                        POWER=5 for SH
c                                        POWER=2.275 for P-SV
c       14 JAN 2008 - put Radius of Earth into common/earth/radius for
c               generality
c               correct layer insertion for spherical earth
c               NOTE refdep handled correctly for a spherical earth
c       22 JAN 2008 - rearranged routines, put in new common
c                     isotropic travel time routines from time96
c       25 JAN 2008 - put Radius of Earth into common/earth/radius for
c                      generality
c                   -  define a separate common block for the
c                      SH velocity and density
c                   -  have sphericity correction
c                      work on common blocks instead of procedure call
c                   -  create a default adomod  to fill the SH for a flat model
c                      note the separation of SH is important for wavenumber
c                      integration code
c                      NOTE - the separation into qsh bsh is incomplete 
c                        since the current mapping requires only a 
c                        different density mapping for
c                        SH - we would have to create a varsh 
c                        routine to be consistent,
c                        but that would increase computational time slightly
c       08 FEB 2008 -  subtle change in fstarr for source receiver in same layer -
c                      spherical mapping was not done
c       18 FEB 2009 -  took care to add common/depref/refdep in frstar
c       24 MAR 2012 -  corrected code to output pressure field in a fluid
c       01 JUN 2013 -  Modified subroutine to prevent NaN for direct ray by replacing
c                      pnew = 0.999d+00 * pupper to
c                      pnew = 0.99d+00 * pupper
c                      also modified subroutine frstar to have the dogeom argument.
c                      We do not want to compute teleseismic geometrical spreading
c       09 OCT 2013 -  Corrected code at line 452 - this C syntax works with
c                      gfortran but not with Solaris f77 - sorry
c-----
        parameter(LER=0, LIN=5, LOT=6)
        parameter(NL=200)
        parameter(NSOURCE=100,NRECEIVER=100,NSR=100)
        common/source/depths(NSOURCE),lmaxs(NSOURCE),mdpths
        common/receiv/depthr(NRECEIVER),lmaxr(NRECEIVER),mdpthr
        common/sourcesv/depthssv(NSOURCE)
        common/receivsv/depthrsv(NRECEIVER)
        real*4 depths, depthr
        integer lmaxs, lmaxr, mdpths, mdpthr
        common/bound/vmin,vamin,vamax,vbmin,vbmax
        common/damp/alpha,ieqex
        common/modctl/iflsph
        common/isomod/d(NL),a(NL),b(NL),rho(NL),
     1      qa(NL),qb(NL),etap(NL),etas(NL), 
     2      frefp(NL), frefs(NL)
        common/shwave/bsh(NL), rhosh(NL), qbsh(NL)
        real bsh, rhosh, qbsh
        common/modlly/mmax
        common/modelt/dt(NL),at(NL),bt(NL),rhot(NL),
     1      mmaxt,qat(NL),qbt(NL),etapt(NL),etast(NL),
     1      frefpt(NL),frefst(NL),bsht(NL),rhosht(NL),qbsht(NL)
        common/jout/jsrc(21) , jbdrys, jbdryh
c-----
c       matrix components in layers and boundaries saved
c-----
        complex*16 har(NL,4,4), dar(NL,5,5), hsr(2,5), gbr(2,5), 
     1      hal(NL,2,2), hsl(2,2), gbl(2,2)
        real*8 hex(NL), lex(NL), dex(NL), hexw(NL)
        common/hamat/har
        common/damat/dar
        common/hsrfr/hsr
        common/gbrfr/gbr
        common/hlmat/hal
        common/hsrfl/hsl
        common/gbrfl/gbl
        common/hexex/hex
        common/hexexw/hexw
        common/dexex/dex
        common/lexex/lex 
        common/water/iwater(NL),iwats(2),iwatb(2)
        common/updnsm/equalu(NL), equald(NL)
        logical equalu, equald
        common/lyrctl/lyrins
        logical lyrins
        common/rlimit/rlim
        real*4 rlim
c-----c
        character*3 istat3
        logical ixst3
        real*4 ffreq(8)
        parameter(NDST=500)
        real*4 r(NDST), tshift(NDST), vred(NDST)
        complex smm(NSR,21)
        complex ztmp, zdata
        common/c/cmax,c1,c2,cmin
        common/frlim/fl,fu,df,fwhich
        common/cntrl/ishank,hnkarg,dstcor,dokjar,docausal
c-----
c       ishank  L   - .true. use Hankel function and not Bessel
c                    note that asymptotic tricks are not used
c       hnkarg  R*4 - (default 6.0) For kr > hnkarg use the Hankel
c                   function, otherwise the Bessel
c       isfref  L   - .true. reference frequency uis not the 
c                   default of 1.0 Hz
c       fref    R*4 - reference frequency for Causal Q
c       dstcor  I*4 - 0 first time sample is tshift + r/vred
c                 1 first time sample is tshift + z/vred where
c                   z = abs (source depth - receiver depth)
c                 2 first time sample is tshift + 
c                   sqrt(z*z + r*r) /vred
c       dokjar  L   - .false. use Futterman causal Q
c       docausal L  - .true. Use causal Q
c                 .true.  use Kjartansson Causal Q
c-----
        integer*4 dstcor
        real*4 hnkarg
        logical ishank,dokjar,docausal
        common/ctlrud/rpup,rpdn,rsup,rsdn,dorud
        logical rpup, rpdn, rsup, rsdn, dorud
        common/ctlsud/spup,spdn,ssup,ssdn,dosud
        logical spup, spdn, ssup, ssdn, dosud

        logical ext
        character mname*80, title*80

        common/lwater/lfluid
        logical lfluid

        common/depref/refdep
        real refdep

        common/earth/radius
        real radius

        real tp, tsv, tsh, vra, vrb, vsa, vsb, vsr, rayp, geom, tstar
c-----
c       ksrc = temporary array for jsrc for output
c       here jsrc != 0 reflects source information
c       if receiver is not in a fluid DO NOT output pressure field
c-----
        integer ksrc(21)
c-----
c       lsrc maps jsrc to output Green s functions. e.g., if
c       jsrc(8) = radial explosion term, but in final output it
c       occupies position 10, or jsrc(lsrc(10)) = computed
c-----
        integer*4 lsrc(21)
        data lsrc/1,2,3,4,13,5,6,14,7,8,9,10,11,12,15,16,17,18,19,20,21/
        fwhich = -1.0
c-----
c       call machine dependent initialization
c-----
        call mchdep()
c-----
c       initialize
c-----
        radius = 6371.
c-----
c       parse command line arguments
c-----
        call gcmdln()
        if(ishank)write(LOT,2042)hnkarg
c-----
c       set up tolerances
c           rlim is the distance which is effectively zero
c-----
            rlim = 1.0e-07
c-----
c       See if the file hspec96.dat exists, if it does
c       open it for all control information
c-----
        inquire(file='hspec96.dat',exist=ext)
        if(.not. ext)then
                write(LER,*)'Control file ',
     1          'hspec96.dat does not exist'
                go to 9999
        endif
        open(3,file='hspec96.dat',access='sequential',
     1      form='formatted',status='unknown')
        rewind 3
        call gethsp(3,mname,fl,fu,delt,n,n1,n2,xleng,xfac,
     1      ndist,r,tshift,vred)
        close (3)
c-----
c       process
c-----
        df = 1./(n*delt)
        nyq = n/2 + 1
        nyq2 = 2*nyq
        write(LOT,2)  fl,fu,df,n1,n2,n,
     2      vmin,vamin,vamax
        if(.not.lfluid)write(LOT,21)vbmin,vbmax
c-----
c       UNIX output - no carriage control
c-----
    2   format('fl =',f10.5,5x,'fu =',f10.5,5x,'df =',f10.5,/
     1      4x,'n1 =',i4,5x,'n2 =',i4,5x, ' n =',i5/
     2  'vmin  =',f10.5,' vamin =',f10.5,' vamax =',f10.5)
   21   format(
     1  '       ',10x  ,' vbmin =',f10.5,' vbmax =',f10.5)
 2021   format('depths =',f20.6,' (',f20.6,')')
 2031   format('depthr =',f14.6,' (',f20.6,')')
 2041   format('     r =',f14.6,' tshift=',f10.2,' vred=',f10.2)
    3   format(8f10.5)
    4   format('frequencies for which response computed     ')
    5   format('alpha =',f10.5,5x,'dt =',f10.3)
 2042   format('Hankel function used for kr >=',f10.2)
c-----
c       MSDOS MICROSOFT FORTRAN OUTPUT
c-----
c    2   format(1x,'fl =',f10.5,5x,'fu =',f10.5,5x,'df =',f10.5,/
c     1          1x,4x,'n1 =',i4,5x,'n2 =',i4,5x, ' n =',i5/
c     2  1x,'vmin  =',f10.5,' vamin =',f10.5,' vamax =',f10.5)
c   21  format(
c     1 1x,'       ',10x  ,' vbmin =',f10.5,' vbmax =',f10.5)
c 2021   format(1x,'depths =',f20.6)
c 2031   format(1x,'depthr =',f14.6)
c 2041   format(1x,'     r =',f14.6,' tshift=',f10.2,' vred=',f10.2)
c    3   format(1x,8f10.5)
c    4   format(1x,'frequencies for which response computed     ')
c    5   format(1x,'alpha =',f10.5,5x,'dt =',f10.3)
c 2042  format(1x, 'Hankel function used for kr >=',f10.2)
c-----

        write(LOT,*)'SOURCE DEPTH IN WORKING AND ORIGINAL MODEL (',
     1       mdpths,')'
        do 2020 i=1,mdpths
            write(LOT,2021)depths(i), depthssv(i) - refdep
 2020   continue
        write(LOT,*)'RECEIVER DEPTH IN WORKING AND ORIGINAL MODEL ('
     1       ,mdpthr,')'
        do 2030 i=1,mdpthr
            write(LOT,2031)depthr(i), depthrsv(i) - refdep
 2030   continue
        write(LOT,*)'RECEIVER DISTANCES (',ndist,')'
        do 2040 i=1,ndist
            write(LOT,2041)r(i), tshift(i), vred(i)
 2040   continue
        write(LOT,5)alpha,delt
        if(docausal)then
            if(dokjar)then
            write(LOT,*)'Kjartansson Constant Q operator used'
            endif
        else
            write(LOT,*)'Non-causal Q operator used'
        endif
        if(dosud)then
            write(LOT,*)'Wavefield separation at Source'
            write(LOT,*)'    Upward P-wave  ',spup
            write(LOT,*)'    Upward S-wave  ',ssup
            write(LOT,*)'    Downward P-wave',spdn
            write(LOT,*)'    Downward S-wave',ssdn
        endif
        if(dorud)then
            write(LOT,*)'Wavefield separation at Receiver'
            write(LOT,*)'    Upward P-wave  ',rpup
            write(LOT,*)'    Upward S-wave  ',rsup
            write(LOT,*)'    Downward P-wave',rpdn
            write(LOT,*)'    Downward S-wave',rsdn
        endif
        write(LOT,4)
c-----
c     open output file for hspec96
c-----
      open(unit=2,file='hspec96.tmp',status='unknown',form=
     1            'unformatted',access='sequential')
      rewind 2
c-----
c     open temporary distance multiplexed file which
c     will be examined in case it exists already for
c     work already done
c-----
      inquire(file='hspec96.bin',exist=ixst3)
      if(ixst3)then
            istat3 = 'old'
      else
            istat3 = 'new'
      endif
      open(unit=3,file='hspec96.bin',status=istat3,form=
     1            'unformatted',access='sequential')
      rewind 3
      ifreq = 0
      if(ixst3)then
            call reset3(ifreq,jsrc,lsrc,ndist,n1,n2)
            write(LER,*)'Partial processing - starting at',
     1          ifreq, ' in range [',n1,'-' ,n2,']'
      endif
c-----
c       process the frequencies
c-----
        do 101 i=1,8
            ffreq(i)=-1.0
  101   continue
        n11 = n1
        if(ifreq.gt.n1)n11 = ifreq + 1
        do 100 ii = n11,n2
            freq=(ii-1)*df
            if(freq.lt.df) freq = 0.01*df
            call excit(freq,xleng,xfac,dk,nk,omega)
            do 200 jd=1,ndist
                call setup(r(jd))
                call wvint(r(jd),smm,dk,nk)
                k = 0
                do 303 is=1,mdpths
                    do 304 ir=1,mdpthr
                        call gett0(t0,r(jd),depthssv(is),
     1                      depthrsv(ir),tshift(jd),
     2                      vred(jd),dstcor)
                        fac = 6.2831853*freq*t0
                        ztmp = cmplx(cos(fac), sin(fac) )
                        k = k + 1
                        do 301 jj=1,21
                            zdata = ztmp*smm(k,jj)
                            if(jsrc(lsrc(jj)).eq.1)then
                            datar= real(zdata)
                            datai=aimag(zdata)
                            write(3)datar,datai
                            endif
  301                   continue
  304               continue
  303           continue
  200       continue
            index=mod(ii,8)
            if(index.eq.0)index=8
            ffreq(index)=freq
            if (index.eq.8) then
                    write(LOT,3)ffreq
                    do 102 ij=1,8
                        ffreq(ij)=-1.
  102               continue
            endif
  100   continue
        write(LOT,3)ffreq
        write(LOT,*)'Transition to non-asymptotic at',fwhich
c-----
c       output the final spectrum as a function of distance
c-----
        open(unit=4,file='hspec96.grn',status='unknown',
     1      form='unformatted',access='sequential')
        rewind 4
c-----
c       iprog   1 hspec96
c           2 hspec96p
c           3 hwhole96
c-----
        iprog = 1
        write(4)iprog
        write(4) alpha,fl,fu,delt,n,n1,n2,df,nyq2
        write(4)mname
c-----
c       now output the spectrum for each distance
c
c       The order in the temporary file 'hspec96.bin' is
c           FREQ
c               DIST
c                   SOURCE_DEPTH
c                       RECEIVER_DEPTH
c       This must be rearranged to form
c           DIST
c               SOURCE_DEPTH
c                   RECEIVER_DEPTH
c                       FREQ
c
c-----
        write(LOT,'(a,a)')
     1  '     r(km)   t0(sec)    hs(km)    hr(km)    Tp(sec)   Tsv(sec)'
     2  ,'   Tsh(sec)'
        do 5000 jd=1,ndist
        if (iflsph.eq.0)then
                gfac = 1.0
        else
                if(r(jd).eq.0.0)then
                        gfac = 1.0
                else
                        gfac = (r(jd)/radius)/sin(r(jd)/radius)
                        gfac = sqrt(gfac)
                endif
        endif
        k = 0
        do 5005 js=1,mdpths
        do 5010 jr=1,mdpthr
            k = k + 1
            rewind 3
            call gett0(t0,r(jd),depthssv(js),
     1          depthrsv(jr),tshift(jd),vred(jd),dstcor)
c-----
c       to get first arrivals, we must account for the fact that
c       there may be a a difference reference depth which is
c       indicated by the consistent use of negative layer thicknesses
c       in the upper part of the model. The getmod() subroutine
c       notes this and converts to a model that has a surface reference
c       depth. This program adds this reference depth to all
c       source ande receiver depths input. This in calling FRSTAR,
c       which rereads the model file, we use the adjusted source
c       depths. When we output the results, 
c          we convert back to the actual
c       physical depths
c-----
            CALL FRSTAR(R(JD),DEPTHSSV(JS)-refdep,DEPTHRSV(JR)-refdep,
     1          MNAME,1,TP ,VRA, VRB, den,
     1          VSA, VSB, VSR, rayp, geom, tstar, .false. ,.false.)
            CALL FRSTAR(R(JD),DEPTHSSV(JS)-refdep,DEPTHRSV(JR)-refdep,
     1          MNAME,2,TSV,VRA, VRB, den,
     1          VSA, VSB, VSR, rayp, geom, tstar, .false. ,.false.)
            CALL FRSTAR(R(JD),DEPTHSSV(JS)-refdep,DEPTHRSV(JR)-refdep,
     1          MNAME,3,TSH,VRA, VRB, den,
     1          VSA, VSB, VSR, rayp, geom, tstar, .false. ,.false.)
c-----
c      Fix 24 MARCH 2012 - when there is a fluid, the TSH will be
c      a large number. Use the Sac not defined as the value
c-----
C BAD            if(TSH > 1.0e+29)TSH=-12345.
            if(TSH .gt. 1.0e+29)TSH=-12345.
c-----
c       define TI constants
c-----
            SR = VSR
            SL = VSR*VSB*VSB
            SN = VSR*VSB*VSB
            SA = VSR*VSA*VSA
            SC = VSR*VSA*VSA
            SF = SA - 2.0*SN
            write(4)r(jd),t0,depthssv(js)-refdep,
     1              depthrsv(jr)-refdep,
     2              TP,TSV,TSH, 
     3              SA, SC, SF, SL, SN, SR
c-----
c       Dislocations and forces must act in a solid source region
c       if the receiver is in a fluid, then permit pressure field output
c-----
            do 5011 i=1,21
                ksrc(i) = jsrc(lsrc(i))
                if(ksrc(i).gt.0)then
                if(i.ge.1.and.i.le.8)then
                    if(VSB .le. 0.0001*VSA)then
                        ksrc(i) = 0
                    endif
                else if(i.ge.11.and.i.le.15)then
                    if(VSB .le. 0.0001*VSA)then
                        ksrc(i) = 0
                    endif
                elseif(i.eq.16)then
                    if(VRB .lt. 0.0001*VRA)then
                        ksrc(i) = 1
                    else
                        ksrc(i) = 0
                    endif
                else if(i.ge.17)then
                    if(VRB .lt. 0.0001*VRA.and.VSB.gt.0.0)then
                        ksrc(i) = 1
                    else
                        ksrc(i) = 0
                    endif
                endif
                endif
 5011       continue
            write(4)ksrc
            write(LOT,'(4f10.3,3f11.3)')
     1          r(jd),t0,depthssv(js)-refdep,depthrsv(jr)-refdep,
     2          TP,TSV,TSH
c-----
c       search through the Green s functions and output
c       only is permitted by ksrc. 
c           Note pressure only output for fluid receiver      
c-----
            do 5200 i=n1,n2
                do 5300 jjd=1,ndist
                kk = 0
                do 5301 jjs=1,mdpths
                do 5302 jjr=1,mdpthr
                    kk = kk + 1
                    do 5400 jj=1,21
                        if(jsrc(lsrc(jj)).eq.1)then
                        read(3)datar,datai
                        if(jjd.eq.jd .and. k.eq.kk.and.
     1                      ksrc(jj).ne.0)then
                            write(4)datar*gfac,datai*gfac
                        endif
                        endif
 5400               continue
 5302           continue
 5301           continue
 5300           continue
 5200       continue
 5010   continue
 5005   continue
 5000   continue
        rr = -1.0
        tt0 = 0.0
        write(4)rr,tt0
        close (4)
        close(2,status='delete')
        close(3,status='delete')
 9999   continue
        end

        subroutine gethsp(lun,mname,fl,fu,delt,n,n1,n2,xleng,xfac,
     1      ndist,r,tshift,vred)
c-----
c       read in data file of hspec8 commands
c-----
        parameter(LER=0, LIN=5, LOT=6)
        parameter(NL=200)
        parameter(NSOURCE=100,NRECEIVER=100,NSR=100)
        common/source/depths(NSOURCE),lmaxs(NSOURCE),mdpths
        common/receiv/depthr(NRECEIVER),lmaxr(NRECEIVER),mdpthr
        real*4 depths, depthr
        common/sourcesv/depthssv(NSOURCE)
        common/receivsv/depthrsv(NRECEIVER)
        real*4 depthssv, depthrsv
        integer lmaxs, lmaxr, mdpths, mdpthr
        common/bound/vmin,vamin,vamax,vbmin,vbmax
        common/damp/alpha,ieqex
        common/modctl/iflsph
        common/isomod/d(NL),a(NL),b(NL),rho(NL),
     1      qa(NL),qb(NL),etap(NL),etas(NL), 
     2      frefp(NL), frefs(NL)
        common/shwave/bsh(NL), rhosh(NL), qbsh(NL)
        real bsh, rhosh, qbsh
        common/modlly/mmax
        common/jout/jsrc(21) , jbdrys, jbdryh
        parameter(NDST=500)
        real*4 r(NDST), tshift(NDST), vred(NDST)
        common/c/cmax,c1,c2,cmin
        character ostr*80
        character mname*80, title*80
        common/lyrctl/lyrins
        logical lyrins
        logical ext

        common/cntrl/ishank,hnkarg,dstcor,dokjar,docausal
        integer*4 dstcor
        real*4 hnkarg
        logical ishank,dokjar,docausal

        common/depref/refdep
        real refdep
        common/earth/radius
        real radius
c-----
c       UNIX FORTRAN - NO CARRIAGE CONTROL
c-----
   21   format(11i5)
   22   format(6e11.4)
   24   format('XLENG=',e15.7,' XFAC=',e15.7)
   30   format(2e15.7/1x,3i10)
 4012       format('WAVENUMBER FILTERING bounded in phase velocites'/
     1          '[cmax,c1,c2,cmin]=','[', f10.3, ',', 
     2          f10.3, ',', f10.3, ',', f10.3,']' /
     3          '( -1.0 means 0.0 for cmin and infinity for cmax)')
 4013   format('WAVENUMBER FILTERING NOT DONE')
c-----
c       MSDOS MICROSOFT FORTRAN OUTPUT - CARRIAGE CONTROL
c-----
c   21  format(1x,11i5)
c   22  format(1x,6e11.4)
c   24  format(1x,'XLENG=',e15.7,' XFAC=',e15.7)
c   30  format(1x,2e15.7/1x,3i10)
c 4012      format(1x,'WAVENUMBER FILTERING bounded in phase velocites'/
c     1         1x,'[cmax,c1,c2,cmin]=',
c     2         1x,'[', f10.3, ',', f10.3, ',', f10.3, ',', f10.3,']' /
c     3         1x,'( -1.0 means 0.0 for cmin and infinity for cmax)')
c 4013  format(1x,'WAVENUMBER FILTERING NOT DONE')
c-----
c       read in distance correction
c-----
        read(lun,*)idcor
        if(idcor.ge.0 .and. idcor.le.2)then
            dstcor = idcor
        else
            dstcor = 0
        endif
c-----
c       read in time domain damping, sampling interval
c-----
        read(lun,*)alphat,delt
c-----
c       read in number of time samples, frequency limits
c-----
        read(lun,*)n,n1,n2  
        alpha = alphat/(n*delt)
        write(LOT,30) alpha,delt,n,n1,n2
        df = 1.0/(n*delt)
        fl = (n1-1)*df
        fu = (n2-1)*df
c-----
c       Specify desired output Green's functions
c-----
        read(lun,*)ieqex
        if(ieqex.gt.6 .or. ieqex.lt.0)ieqex = 2
        if(ieqex .eq. 0)then
            write(LOT,*)'ieqex= ',ieqex,' EARTHQUAKE + EXPLOSION'
        else if(ieqex.eq.1)then
            write(LOT,*)'ieqex= ',ieqex,' POINT FORCES + EXPLOSION'
        else if(ieqex.eq.2)then
            write(LOT,*)'ieqex= ',ieqex,' ALL GREEN'
        else if(ieqex.eq.3)then
            write(LOT,*)'ieqex= ',ieqex,' EXPLOSION ONLY'
        else if(ieqex.eq.4)then
            write(LOT,*)'ieqex= ',ieqex,' EARTHQUAKE ONLY'
        else if(ieqex.eq.5)then
            write(LOT,*)'ieqex= ',ieqex,' POINT FORCES ONLY'
        else if(ieqex.eq.6)then
            write(LOT,*)'ieqex= ',ieqex,' SH ONLY'
        endif
c-----
c       provide names for output Green's functions in order of output
c-----
        if(ieqex.eq.0)then
c-----
c           EARTHQUAKE + EXPLOSION
c-----
            do 1234 i=1,21
                if(i.le.8)then
                    jsrc(i) = 1
                else
                    jsrc(i) = 0
                endif
 1234       continue
            jsrc(13) = 1
            jsrc(14) = 1
            jsrc(16) = 1
            jsrc(17) = 1
            jsrc(18) = 1
            jsrc(19) = 1
            jsrc(20) = 0
            jsrc(21) = 0
        else if(ieqex.eq.1)then
c-----
c           POINT FORCES + EXPLOSION
c-----
            do 1235 i=1,21
                if(i.ge.7)then
                    jsrc(i) = 1
                else
                    jsrc(i) = 0
                endif
 1235       continue
            jsrc(13) = 0
            jsrc(14) = 0
            jsrc(17) = 0
            jsrc(18) = 0
            jsrc(19) = 0
        else if(ieqex.eq.2)then
c-----
c           ALL
c-----
            do 1236 i=1,21
                jsrc(i) = 1
 1236       continue
        else if(ieqex.eq.3)then
c-----
c           EXPLOSION ONLY
c-----
            do 1237 i=1,21
                if(i.eq.7 .or. i.eq.8 .or. i.eq.16)then
                    jsrc(i) = 1
                else
                    jsrc(i) = 0
                endif
 1237       continue
        else if(ieqex.eq.4)then
c-----
c           EARTHQUAKE ONLY
c-----
            do 1238 i=1,21
                if(i.le.6 .or. i.eq.13 .or. i.eq.14)then
                    jsrc(i) = 1
                else
                    jsrc(i) = 0
                endif
 1238       continue
            jsrc(17) = 1
            jsrc(18) = 1
            jsrc(10) = 1

        else if(ieqex.eq.5)then
c-----
c           POINT FORCES ONLY
c-----
            do 1239 i=1,21
                if(i.ge.9)then
                    jsrc(i) = 1
                else
                    jsrc(i) = 0
                endif
 1239       continue
            jsrc(13) = 0
            jsrc(14) = 0
            jsrc(16) = 0
        else if(ieqex.eq.6)then
c-----
c           SH ONLY
c-----
            do 1240 i=1,21
                if(i.eq.13 .or. i.eq.14 .or. i.eq.15)then
                    jsrc(i) = 1
                else
                    jsrc(i) = 0
                endif
 1240       continue
        endif
c-----
c       jsrc - array giving Green's functions to be evaluated
c           this controls computations, gives far field terms
c           or course true solution for radial may involve transverse
c       jsrc(lsrc) maps into Green,s functions, e.g.,
c           For REP=10, lsrc(10) = 8, and if jsrc(8) = 1
c           P-SV contribution to explosion radial time 
c           history is computed
c
c       ieqex = 0 
c       Earthquake + Explosion
c       1-ZDD   2-RDD   3-ZDS   4-RDS   5-TDS   6-ZSS
c       7-RSS   8-TSS   9-ZEP   10-REP
c
c       ieqex = 1 
c       Point Forces + Explosion
c       11-ZVF  12-RVF  13-ZHF  14-RHF  15-THF  16-PEP
c       9-ZEP   10-REP (others have no meaning)
c
c       ieqex = 2
c       All Green's functions
c       1-ZDD   2-RDD   3-ZDS   4-RDS   5-TDS   6-ZSS
c       7-RSS   8-TSS   9-ZEP   10-REP
c       11-ZVF  12-RVF  13-ZHF  14-RHF  15-THF  16-PEP
c
c       ieqex = 3
c       Explosion Only
c       9-ZEP   10-REP
c
c       ieqex = 4 
c       Earthquake
c       1-ZDD   2-RDD   3-ZDS   4-RDS   5-TDS   6-ZSS
c       7-RSS   8-TSS
c
c       ieqex = 5 
c       Point Forces Only
c       11-ZVF  12-RVF  13-ZHF  14-RHF  15-THF  
c
c       ieqex = 6
c       SH Solution Only
c       5-TDS 8-TSS 15-THF
c
c       If fluid layer for receiver, 16 is forced to be fluid 
c           stress due to explosion
c-----
c       input jbdry = 10*surface + halfspace
c       surface   = 0 - elastic halfspace   = 0 - elastic
c                   1 - free              1 - free 
c                   2 - rigid             2 - rigid
c-----
        read(lun,*)jbdry
        write(LOT,21) jbdry
        if(jbdry.lt.0)jbdry = 0
        ibdrys = jbdry / 10
        if(ibdrys.eq.0)then
            jbdrys = 0
        else if(ibdrys.eq.1)then
            jbdrys = 1
        else if(ibdrys.eq.2)then
            jbdrys = -1
        else
            jbdrys = 0
        endif
        ibdryh = mod(jbdry,10)
        if(ibdryh.eq.0)then
            jbdryh = 0
        else if(ibdryh.eq.1)then
            jbdryh = 1
        else if(ibdryh.eq.2)then
            jbdryh = -1
        else
            jbdryh = 0
        endif
c-----
c       jbdrys  =  surface boundary condition
c           = -1 top surface is rigid
c           =  0 really a halfspace with parameters of top layer    
c           =  1 free surface
c       jbdryh  = halfspace boundary condition
c           = -1  RIGID
c           =  0  ELASTIC
c           = +1  FREE SURFACE
c-----
        if(jbdrys.eq.1)then
            write(LOT,*)' TOP  OF MODEL IS FREE SURFACE  '
        else if(jbdrys.eq.0)then
            write(LOT,*)' TOP  OF MODEL IS HALFSPACE WITH',
     1          ' PROPERTIES OF FIRST LAYER'
        else if(jbdrys.eq.-1)then
            write(LOT,*)' TOP  OF MODEL IS RIGID'
        endif
        if(jbdryh.eq.0)then
            write(LOT,*)' BASE OF MODEL IS HALFSPACE WITH',
     1          ' PROPERTIES OF BOTTOM LAYER'
        else if(jbdryh.eq.-1)then
            write(LOT,*)' BASE OF MODEL IS RIGID'
        else if(jbdryh.eq.1)then
            write(LOT,*)' BASE OF MODEL IS FREE'
        endif


c-----
c       read in the earth model name
c-----
        read(lun,'(a)')mname
        lmnm = lgstr(mname)
        write(LOT,*)mname(1:lmnm)
c-----
c       read in the earth model in model96 format
c-----
        inquire(file=mname,exist=ext)
        if(.not. ext)then
            write(LER,*)'Model file not located'
            stop
        endif
        call getmod(1,mname,mmax,title,iunit,iiso,iflsph,
     1      idimen,icnvel,ierr,.true.)
c-----
c       check the appropriateness of the model file
c-----
c               - -1 file does not exist
c               - -2 file is not a model file
c                 -3 error in the model file
        if(ierr.eq. -1)then
            call usage('Model file does not exist')
        else if(ierr.eq. -2)then
            call usage('Model file given is not a model96 file')
        else if(ierr.eq. -3)then
            call usage('Error in model file')
        endif
        call adomod()
c-----
c       error checking
c-----
        if(idimen.ne.1)then
            call usage('1-D velocity model required')
        endif
        if(icnvel.ne.0)then
            call usage('Constant velocity model required')
        endif
        if(iiso.ne.0)then
            call usage('Isotropic velocity model required')
        endif
c-----
c       transform the spherical model to a flat model
c-----
        if(iflsph.ne.0)then
            call adosph()
        endif
c-----
c       do not permit Q < 1 If qa or qb is entered > 1 
c       invert to form q inverse
c-----
        do 3007 i=1,mmax
            if(qa(i).lt.0.0)qa(i) = 0.0
            if(qb(i).lt.0.0)qb(i) = 0.0
            if(qa(i) .gt. 1.0)qa(i) = 1.0/qa(i)
            if(qb(i) .gt. 1.0)qb(i) = 1.0/qb(i)
            if(frefp(i) .le. 0.0)frefp(i) = 1.0
            if(frefs(i) .le. 0.0)frefs(i) = 1.0
 3007   continue
        call modcpy(.true.)
        call velbnd()
c-----
c       check model for inconsistencies
c-----
        call chkmod()
c-----
c       read in controls for wavenumber integration
c-----
        read(lun,*) xleng, xfac
        write(LOT,24)xleng, xfac
c-----
c       read in the  source depth
c-----
        read(lun,*)mdpths
        mtmp = NSOURCE
        if(mdpths .gt. NSOURCE)then
            write(ostr,3008)mdpths,mtmp
 3008   format(' NUMBER OF SOURCE DEPTHS',i5,' EXCEEDS DIMENSION ',i5)
            call werror(ostr)
        endif
c-----
c       get maximum source or receiver depth
c-----
        do 2008 i=1,mdpths
            read(lun,*)depths(i)
            depths(i) = depths(i) + refdep
 2008   continue
c-----
c       read in the receiver depth
c-----
        read(lun,*)mdpthr
        mtmp = NRECEIVER
        if(mdpthr .gt. NRECEIVER)then
            write(ostr,3009)mdpthr,mtmp
 3009   format(' NUMBER OF RECEIVER DEPTHS',i5,' EXCEEDS DIMENSION ',i5)
            call werror(ostr)
        endif
        do 2009 i=1,mdpthr
            read(lun,*)depthr(i)
            depthr(i) = depthr(i) + refdep
 2009   continue
c-----
c       check for filling the final depth array
c-----
        mtmp = mdpths * mdpthr
        ntmp = NSR
        if(mtmp .gt. ntmp)then
            write(ostr,3011)mtmp,ntmp
 3011   format(' NUMBER SOURCE-RECEIVER COMB',
     1      i5,' EXCEEDS DIMENSION ',i5)
            call werror(ostr)
        endif
c-----
c       transform all spherical source depths to the equivalent depths
c       in flat model - but do not change flat model depths
c-----
        do 1191 i=1,mdpths
            depthssv(i) = depths(i)
            if(iflsph.ne.0)then
                depths(i) = radius*alog(radius/(radius-depths(i)))
            endif
 1191       continue
            do 1192 i=1,mdpthr
            depthrsv(i) = depthr(i)
            if(iflsph.ne.0)then
                depthr(i) = radius*alog(radius/(radius-depthr(i)))
            endif
 1192       continue
c-----
c       read in the distances
c-----
        read(lun,*)ndist
        mtmp = NDST
        if(mdpthr .gt. NDST)then
            write(ostr,3010)ndist,mtmp
 3010   format(' NUMBER OF DISTANCES',i5,' EXCEEDS DIMENSION ',i5)
            call werror(ostr)
        endif
        do 2010 i=1,ndist
            read(lun,*)rr,tshf,vr
            r(i)=rr
            tshift(i) = tshf
            vred(i) = vr
 2010   continue
c-----
c       read in phase velocity limits for wavenumber filtering
c       Wavenumber filtering will consist of following
c
c       |*ZERO*|-COSINE TAPER-|*ALL PASS*|-COSINE TAPER-|*ZERO
c       |      |              |          |              |
c            omega          omega      omega          omega
c k =   0    -----          -----      -----          -----   infinity
c            cmax            c1         c2             cmin
c-----
c       If c2 or cmin <= 0, then upper wavenumber limit is infinite
c       If c1 or cmax <= 0, then lower wavenumber limit is zero
c-----
        read(lun,*,end=4010,err=4010)cmax,c1,c2,cmin
            if(c1.le.0.0)cmax = -1.0
            if(c2.le.0.0)cmin = -1.0
            write(LOT,4012)cmax,c1,c2,cmin
        goto 4011
 4010   continue
            cmax = -1.0
            c1 = -1.0
            c2 = -1.0
            cmin = -1.0
        write(LOT,4013)
 4011   continue
c-----
c       For reasons of efficiency, decide whether to
c       add all layers at once, to the model
c       or to evaluate each layer source-receiver
c       combination separately. 
c
c       Roughly if the number of unique source and receiver depths
c       are mdpths+mdpthr if we insert layers, then we
c       end up with roughly mmax+mdpths+mdpthr layers, and
c       hence layer multiplication of this many matrices
c       for each source-receiver combination. Of course, for
c       equally spaced depth points, some economy arises
c       in avoiding matrix recomputation.
c
c       So if mdpths+mdpthr > 2*mmax we do not make a big model
c       other wise we do
c-----
c       adjust the model so that additional layers are added
c       to permit source and receiver at top of a give layer
c-----
        if(mdpths+mdpthr .gt. 2*mmax )then
            lyrins = .false.
            write(LOT,*)' LAYER INSERTION NOT DONE'
        else
            lyrins = .true. 
            write(LOT,*)' LAYER INSERTION DONE'
            do 2108 i=1,mdpths
                call insert(depths(i))
 2108       continue
            do 2109 i=1,mdpthr
                call insert(depthr(i))
 2109       continue
            call dezero()
c-----
c           check whether neighboring layers are identical
c           to avoid redundant evaluation
c----
            call equlck()
        endif
c-----
c       verify the new model parameters
c-----
        write(LOT,*)'mmax=',mmax
        write(LOT,22)(d(i),a(i),b(i),rho(i),qa(i),qb(i),i=1,mmax)
C-----
C removed 01 APR 2002 since messes up a mixed fluid/solid modium       
Cc-----
Cc      Guarantee that no time wasted if any source is in the water
Cc      since there can only be a center of expansion source
Cc-----
C       do 2019 i=1,mdpths
C           call srclay(depths(i), lmaxs(i), dphs)
C           if(b(lmaxs(i)).le.1.0e-04)then
C               do 2091 ii=1,21
C                   if(ii.ne.7 .and. ii.ne.8 .and. ii.ne.16)then
C                       jsrc(ii) = 0
C                   endif
C 2091          continue
C           endif
C 2019  continue
c-----
c       determine position of source and receiver in new layers
c-----
        if(lyrins)then
            do 2020 i=1,mdpths
                call srclyr(depths(i), lmaxs(i), dphs)
 2020       continue
            do 2021 i=1,mdpthr
                call srclyr(depthr(i), lmaxr(i), dphs)
 2021       continue
        endif
        return
        end

        subroutine excit(freq,xleng,xfac,dk,nk,omega)
c-----
c     sample response for all wavenumbers at a given frequency
c     using Bouchon equal wavenumber sampling = dk
c     with offset of 0.218dk
c-----
        parameter(LER=0,LIN=5,LOT=6)
        parameter(NL=200)
        parameter(NSOURCE=100,NRECEIVER=100,NSR=100)
        common/source/depths(NSOURCE),lmaxs(NSOURCE),mdpths
        common/receiv/depthr(NRECEIVER),lmaxr(NRECEIVER),mdpthr
        real*4 depths, depthr
        integer lmaxs, lmaxr, mdpths, mdpthr
        common/bound/vmin,vamin,vamax,vbmin,vbmax
        common/isomod/d(NL),a(NL),b(NL),rho(NL),
     1      qa(NL),qb(NL),etap(NL),etas(NL), 
     2      frefp(NL), frefs(NL)
        common/shwave/bsh(NL), rhosh(NL), qbsh(NL)
        real bsh, rhosh, qbsh
        common/modlly/mmax
        common/jout/jsrc(21) , jbdrys, jbdryh
        common/damp/alpha,ieqex
c-----
c       set up common blocks for wavenumber sampling at
c       suitable depths. This is necessary since the matrix
c       evaluation is done here for all source-receiver pairs
c       The source-receiver distance is important for the
c       wavenumber sampling at low frequencies
c-----
        common/kint1/gasymp
            logical gasymp(NSR)
        common/kint2/mkup
            integer mkup(NSR)
        common/kint3/wave
            real*4 wave(NSR,2)
        common/kint4/aa,bb,cc
            complex aa(NSR,21),bb(NSR,21),cc(NSR,21)

        complex*16 wvn,om, wvn2, om2
        complex gg(21)
c-----
c       matrix components in layers and boundaries saved
c-----
        complex*16 har(NL,4,4), dar(NL,5,5), hsr(2,5), gbr(2,5), 
     1      hal(NL,2,2), hsl(2,2), gbl(2,2)
        real*8 hex(NL), lex(NL), dex(NL), hexw(NL)
        common/hamat/har
        common/damat/dar
        common/hsrfr/hsr
        common/gbrfr/gbr
        common/hlmat/hal
        common/hsrfl/hsl
        common/gbrfl/gbl
        common/hexex/hex
        common/hexexw/hexw
        common/dexex/dex
        common/lexex/lex 
        common/water/iwater(NL),iwats(2),iwatb(2)
        common/lyrctl/lyrins
        logical lyrins
        common/wvflt/wvmn,wvc1,wvc2,wvmx
        common/c/cmax,c1,c2,cmin

c-----
c       define angular frequency
c-----
        omega=6.2831853*freq
        om=dcmplx(dble(omega),-dble(alpha))
        om2 = om * om
c-----
c       define wavenumber tapering limits
c-----
        wvmn=omega/cmax
        wvc1=omega/c1
        wvc2=omega/c2
        wvmx=omega/cmin
c-----
c       evaluate wavenumber integration limits
c       and asymptotic coefficients
c-----
        call wvlimit(nk,omega,dk,xfac,xleng)
        rewind 2
c-----
c       output wavenumber in reverse order
c-----
        call bufini(1,ierr)
        do 3998 ii=nk,1,-1
            wv = (ii-1)*dk + 0.218*dk
            call wvfilt(wvmn,wvc1,wvc2,wvmx,wv,fact0)
            wvn=dcmplx(dble(wv),0.0d+00)
            wvn2 = wvn*wvn
c-----
c       evaluate matrices first
c-----
            if(lyrins)then
                call evlmat(om,wvn,jbdrys,jbdryh,wvn2,om2)
            endif
c-----
c       now evaluate for a specific source, receiver position
c-----
            call bufwr(wv)
            k = 0
            do 4000 js=1,mdpths
                do 4010 jr=1,mdpthr
                    k = k + 1
                    if(.not.lyrins)then
c-----
c                   evaluate matrices first
c                   for currently defined layering
c-----
                    call modcpy(.false.)
                    call insert(depths(js))
                    call insert(depthr(jr))
                    call srclyr(depths(js), 
     1                  lmaxs(js), dphs)
                    call srclyr(depthr(jr), 
     1                  lmaxr(jr), dphr)
                    call dezero()
                    call equlck()
                    call evlmat(om,wvn,jbdrys,jbdryh,wvn2,om2)
                    endif
                    if(ii.le.mkup(k))then
                    call rshof(gg,om,wvn,lmaxs(js),
     1                  lmaxr(jr),wvn2,om2)
c-----
c                   adjust 12 and 15 to get avoid asymptotic problems
c-----
                    gg(12) = gg(12) * dreal(wvn)
                    gg(15) = gg(15) * dreal(wvn)
c-----
c       if asymptotic is invoked, modify the integrand here
c-----
                        if(gasymp(k))then
                        depth = abs(depths(js)-depthr(jr))
                        call gasym(gg,k,wv,depth,jsrc)
                        endif
                    else
                        do 3997 j=1,21
                            gg(j) = cmplx(0.0,0.0)
 3997                   continue
                    endif
                    do 3999 j=1,21
                        if(jsrc(j).eq.1)then
                            gg(j) = gg(j)*fact0
                            call bufwr(real(gg(j)))
                            call bufwr(aimag(gg(j)))
                        endif
 3999               continue
 4010           continue
 4000       continue
 3998   continue
        call buflsh()
        return
        end

        subroutine gcmdln()
c-----
c       parse command line arguments
c       requires subroutine mgtarg() and function mnmarg()
c-----
c       ishank  L   - .true. use Hankel function and not Bessel
c                    note that asymptotic tricks are not used
c       hnkarg  R*4 - (default 6.0) For kr > hnkarg use the Hankel
c                   function, otherwise the Bessel
c       dokjar  L   - .false. use Futterman causal Q
c                 .true.  use Kjartansson Causal Q
c                 .true.  use Kjartansson Causal Q
c       docausal L  - .true. Use causal Q
c-----
        common/cntrl/ishank,hnkarg,dstcor,dokjar,docausal
        integer*4 dstcor
        real*4 hnkarg
        logical ishank,dokjar,docausal
        common/ctlrud/rpup,rpdn,rsup,rsdn,dorud
        logical rpup, rpdn, rsup, rsdn, dorud
        common/ctlsud/spup,spdn,ssup,ssdn,dosud
        logical spup, spdn, ssup, ssdn, dosud

        integer*4 mnmarg
        character*50 name


        ishank = .false.
        hnkarg = 6.0
        dokjar = .false.
        docausal = .true.
        dosud = .false.
        spup = .false.
        spdn = .false.
        ssup = .false.
        ssdn = .false.
        dorud = .false.
        rpup = .false.
        rpdn = .false.
        rsup = .false.
        rsdn = .false.
        nmarg=mnmarg()
        i = 0
   11   i = i + 1
            if(i.gt.nmarg)goto 13
            call mgtarg(i,name)
            if(name(1:2).eq.'-H')then
                ishank = .true.
            else if(name(1:2).eq.'-A')then
                i=i+1
                call mgtarg(i,name)
                read(name,'(bn,f10.0)')hnkarg
            else if(name(1:2).eq.'-R' .and. name(1:3).ne.'-RD'
     1              .and. name(1:3).ne.'-RU'
     2              .and. name(1:3).ne.'-RP'
     3              .and. name(1:3).ne.'-RS')then
                dstcor = 2
            else if(name(1:3).eq.'-SU')then
                spup = .true.
                ssup = .true.
                ssdn = .false.
                spdn = .false.
                dosud = .true.
            else if(name(1:3).eq.'-SD')then
                spup = .false.
                ssup = .false.
                ssdn = .true.
                spdn = .true.
                dosud = .true.
            else if(name(1:5).eq.'-SPUP')then
                spup = .true.
                dosud = .true.
            else if(name(1:5).eq.'-SSUP')then
                ssup = .true.
                dosud = .true.
            else if(name(1:5).eq.'-SPDN')then
                spdn = .true.
                dosud = .true.
            else if(name(1:5).eq.'-SSDN')then
                ssdn = .true.
                dosud = .true.
            else if(name(1:5).eq.'-RPUP')then
                rpup = .true.
                dorud = .true.
            else if(name(1:5).eq.'-RSUP')then
                rsup = .true.
                dorud = .true.
            else if(name(1:5).eq.'-RPDN')then
                rpdn = .true.
                dorud = .true.
            else if(name(1:5).eq.'-RSDN')then
                rsdn = .true.
                dorud = .true.
            else if(name(1:3).eq.'-RD')then
                rpup = .false.
                rsup = .false.
                rsdn = .true.
                rpdn = .true.
                dorud = .true.
            else if(name(1:3).eq.'-RU')then
                rpup = .true.
                rsup = .true.
                rsdn = .false.
                rpdn = .false.
                dorud = .true.
            else if(name(1:2).eq.'-K')then
                dokjar = .true.
            else if(name(1:2).eq.'-N')then
                docausal = .false.
            else if(name(1:2).eq.'-?')then
                call usage(' ')
            else if(name(1:2).eq.'-h')then
                call usage(' ')
            endif
        goto 11
   13   continue
c-----
c       safety check
c-----
        if(hnkarg.lt.3.0)hnkarg=3.0
        return
        end

        subroutine usage(ostr)
c------
c       write out program syntax
c-----
        character ostr*(*)
        integer LER,LOT,LIN
        parameter(LER=0, LIN=5, LOT=6)
        if(ostr.ne. ' ' )then
            lostr = lgstr(ostr)
            write(LER,*)ostr(1:lostr)
        endif
        write(LER,*)'USAGE: ',
     1  'hspec96 [-H] [-A arg] [-K] [-N]',
     2      '[-SU] [-SD] [-SPUP] [-SSUP] [-SPDN] [-SSDN] ',
     3      '[-RU] [-RD] [-RPUP] [-RSUP] [-RPDN] [-RSDN] [-?] [-h]'
        write(LER,*)
     1  '-H (default false)   Use Hankel function not Bessel'
        write(LER,*)
     1  '-A arg (default arg=3.0) value of kr where Hn(kr) replaces'
        write(LER,*)
     1  '            Jn(kr) in integration - only used when -H is used'
        write(LER,*)
     1  '-K      (default Futterman) use Kjartansson Causal Q'
        write(LER,*)
     1  '-N      (default causal) use non-causal Q'
        write(LER,*)
     1  'The following govern wavefield at source. The default is',
     2  ' the entire wavefield'
        write(LER,*)
     1  '-SU      (default whole wavefield) Compute only upgoing ',
     2  '               wavefield from the source'
        write(LER,*)
     1  '-SD      (default whole wavefield) Compute only downgoing ',
     2  '               wavefield from the source'
        write(LER,*)
     1  ' -SPUP  Include upward P at source'
        write(LER,*)
     1  ' -SSUP  Include upward S at source'
        write(LER,*)
     1  ' -SPDN  Include downward P at source'
        write(LER,*)
     1  ' -SSDN  Include downward S at source'
        write(LER,*)
     1  'The following govern wavefield at receiver. The default is',
     2  ' the entire wavefield'
        write(LER,*)
     1  ' -RD    Only downgoing waves at receiver'
        write(LER,*)
     1  ' -RU    Only upgoing waves at receiver'
        write(LER,*)
     1  ' -RPUP  Include upward P at receiver'
        write(LER,*)
     1  ' -RSUP  Include upward S at receiver'
        write(LER,*)
     1  ' -RPDN  Include downward P at receiver'
        write(LER,*)
     1  ' -RSDN  Include downward S at receiver'
        write(LER,*)
     1  '-?                   Display this usage message'
        write(LER,*)
     1  '-h                   Display this usage message'
        stop 
        end

        subroutine rshof(gg,om,wvno, lmaxs, lmaxr, wvno2, om2) 
        parameter(NL=200)
        common/isomod/d(NL),a(NL),b(NL),rho(NL),
     1      qa(NL),qb(NL),etap(NL),etas(NL), 
     2      frefp(NL), frefs(NL)
        common/shwave/bsh(NL), rhosh(NL), qbsh(NL)
        real bsh, rhosh, qbsh
        common/modlly/mmax
        common/bound/vmin,vamin,vamax,vbmin,vbmax
        common/damp/alpha,ieqex
c-----
c       gus - surface displacements or potentials or top of layer
c-----
        complex*16 gus(21)
        complex*16 wvno,wvno2
        complex*16 cd(5),da(4,4),fr,y(4,4)
        complex gg(21) 
        complex*16 om,fourpo,ka2,kb2 , om2, ka, kb
        complex*16 d11,d12,fl 
        complex*16 s21,s32,s14,s34,s32e,s34e 
        complex*16 s24,s33
        complex*16 atna,atnb 
        complex*16 wv4pi
        complex*16 zero
        real *8 fact,exe,exl,exel,exll,elj
        real *8 exwu
        common/cntrl/ishank,hnkarg,dstcor,dokjar,docausal
        integer*4 dstcor
        real*4 hnkarg
        logical ishank,dokjar,docausal
        common/ctlsud/spup,spdn,ssup,ssdn,dosud
        logical spup, spdn, ssup, ssdn, dosud
        complex*16 ra,rb,gam,gamm1,h
        complex*16 sdd(4), sds(4), sss(4), sep(4), svf(4), shf(4)
        complex*16 zone
        common/jout/jsrc(21) , jbdrys, jbdryh
        complex*16 haa(4,4), saa(2,2)
        real*8 fourpi
        real*8 CDABS
        complex*16 CDSQRT
        real*8 DREAL



c-----
c       Initialization
c-----
        fourpi=12.5663706d+00
        fourpo=12.5663706d+00*om*om
        zero  = dcmplx(0.0d+00,0.0d+00)
        zone  = dcmplx(1.0d+00,0.0d+00)
c-----
c       do not evaluate for wvno = 0.0
c-----
        if(CDABS(wvno).eq.0.0d+00) then
            do 102 i=1,21
                gg(i) = cmplx(0.0,0.0)
  102       continue
        else
c-----
c       process for this wavenumber and frequency
c-----
            do 101 i = 1,21
                gus(i) = zero
  101       continue
            wv4pi = 2.0d+00 * wvno / fourpi
            call aten(om,qa(lmaxs),qb(lmaxs),ka ,kb ,alpha,
     1          a(lmaxs),b(lmaxs),atna,atnb,iwats,
     2          frefp(lmaxs),frefs(lmaxs)) 
            gam=dble(b(lmaxs))*(wvno/om)
            gam = gam * atnb
            gam = dcmplx(2.0d+00,0.0d+00)*gam*gam
            gamm1 = gam - zone
            ka2=ka *ka  
            kb2=kb *kb  
            ra=CDSQRT(wvno2-ka2)
            rb=CDSQRT(wvno2-kb2)
            if(b(lmaxr).eq.0.0)then
                iwatr = 1
            else
                iwatr = 0
            endif
            if(dosud)then
                call hsupdn(haa,saa,wvno2,om,om2,wvno,lmaxs,
     1              lmaxr,lmaxs,1)
            endif
c-----
c           this follows Wang and Herrmann (1980), 
c               A numerical study of P-, SV-, and SH-wave 
c               generation in a plane layerd medium,
c               Bull. Seism. Soc. Am. 70, 1015-1036.
c           For p-SV we use equation (8). Note below in "do 60" 
c               that the Z component (odd index) is reversed 
c               from (8) so that +z is up
c
c       using the trick of reducing the 6x6 compound matrices to 5x5, 
c           the
c       following correspondence between what is given here 
c       and that in Wang
c       and Herrmann is in effect
c-----
c       Compound Matrix (6x6)   Here (5x5)
c
c       X|12/12 ==      cd(1)
c       X|12/13 ==      cd(2)
c       X|12/14 ==      cd(3)
c       X|12/23 ==      -cd(3)
c       X|12/24 ==      cd(4)
c       X|12/34 ==      cd(5)
c       X|12/21 = -X|12/12
c       X|12/ij = -X|12/ji
c
c       where
c
c        |12
c       X|  = X|12/ij
c        |ij
c-----
            call scoef(cd,da,fr,om,exe,exl,exwu,wvno,
     1          fl,d11,d12,exel,exll,lmaxs,lmaxr,wvno2,om2) 
c-----
c       Form X|12/ij x Zj2 in Equation 8 of Wang and Herrmann
c----
c KLUDGE to CHANGE ORDER AND ALSO GET UR CORRECT FOR WATER LAYER
            do 50 k=1,2
c-----
c       k =1 UR     k=2 UZ
c       jj=1 = UZ, jj=2 = UR
c-----
                if(k.eq.1)then
                    jj = 2
                else if(k.eq.2)then
                    jj = 1
                endif
                if(iwatr.eq.1 .and. jj.eq.2)then
c-----
c       compute Tz and then get Ur from UZ
c-----
c-----
                    j = 3
                else
                    j = k
                endif
                y(1,jj)= cd(1)*da(2,j) + cd(2)*da(3,j) 
     1              + cd(3)*da(4,j)
                y(2,jj)= -cd(1)*da(1,j) - cd(3)*da(3,j) 
     1              + cd(4)*da(4,j)
                y(3,jj)=-cd(2)*da(1,j) + cd(3)*da(2,j) 
     1              + cd(5)*da(4,j)
                y(4,jj)= -cd(3)*da(1,j) - cd(4)*da(2,j) 
     1              - cd(5)*da(3,j)
   50       continue
            if(iwatr.eq.1)then
                y(1,2) = - wvno*y(1,2)/(rho(lmaxr)*om*om)
                y(2,2) = - wvno*y(2,2)/(rho(lmaxr)*om*om)
                y(3,2) = - wvno*y(3,2)/(rho(lmaxr)*om*om)
                y(4,2) = - wvno*y(4,2)/(rho(lmaxr)*om*om)
            endif
c-----
c           evaluate different Green's functions
c           apply source terms
c----- 
c-----
c           START OF P-SV
c-----
c           First compute the DELTA displacement-stress source terms
c           for inverted model, the UZ, TR elements change, These will
c           be only those required for dipoles and forces
c           
c           Stress-displacement discontinuities for Green's functions
c           Green   dUr dUz dTz dTr
c           DD      s32     s34
c           DS  s21
c           SS              s14
c           EX      s32e        s34e
c           VF          s33
c           HF              s24
c-----
            if(iwats.eq.1)then
                s14  = zero
                s21  = zero
                s24  = zero
                s32  = zero
                s33  = zero
                s34  = zero
                s34e = zero
            else
                s14  = -wv4pi
                s21  = 2.0d+00*kb2/(dble(rho(lmaxs))*fourpo)
                s24  = -2.0d+00/fourpi
                s32  = 4.*ka2/(dble(rho(lmaxs))*fourpo)
                s33  = dcmplx(-2.0d+00/fourpi, 0.0)
                s34  = wv4pi*( (4.*ka2/kb2) - 3.0d+00)
                s34e = 2.0d+00*wv4pi*(ka2/kb2)
            endif
            s32e=2.0d+00*ka2/(dble(rho(lmaxs))*fourpo) 
c-----
c           receiver beneath the source
c-----
            if(lmaxr .gt. lmaxs)then
                s14  = - s14
                s24  = - s24
                s32  = - s32
                s32e = - s32e
                s34  = - s34
                s34e = - s34e
            endif
c-----
c           For complete wavefield computation do not
c           waste cycles computing W matrix elements
c-----
            if(.not. dosud)then
                do 61 j=1,2
c       DD
                    gus(j   )=s32 *y(2,j)+ s34*y(4,j)
c       DS
                    gus(j+ 2)=s21 *y(1,j)             
c       SS
                    gus(j+ 4)=             s14*y(4,j)
c       EX
                    gus(j+ 6)=s32e*y(2,j)+s34e*y(4,j)
c       VF
                    gus(j+ 8)=s33 *y(3,j)
c       HF
                    gus(j+10)=s24 *y(4,j)
   61           continue
            ELSE
                sdd(1) = zero
                sdd(2) = s32
                sdd(3) = zero
                sdd(4) = s34
                sds(1) = s21
                sds(2) = zero
                sds(3) = zero
                sds(4) = zero
                sss(1) = zero
                sss(2) = zero
                sss(3) = zero
                sss(4) = s14
                sep(1) = zero
                sep(2) = s32e
                sep(3) = zero
                sep(4) = s34e
                svf(1) = zero
                svf(2) = zero
                svf(3) = s33
                svf(4) = zero
                shf(1) = zero
                shf(2) = zero
                shf(3) = zero
                shf(4) = s24
c-----
c               Change the source vector for up/down going wavefields
c-----

                call svupdn(sdd,haa)
                call svupdn(sds,haa)
                call svupdn(sss,haa)
                call svupdn(sep,haa)
                call svupdn(svf,haa)
                call svupdn(shf,haa)
c-----
c           compute the response
c-----
                do 64 j=1,2
                    gus(j   ) = sdd(1)*y(1,j) + sdd(2)*y(2,j) 
     1                  + sdd(3)*y(3,j) + sdd(4)*y(4,j)
                    gus(j+ 2) = sds(1)*y(1,j) + sds(2)*y(2,j) 
     1                  + sds(3)*y(3,j) + sds(4)*y(4,j)
                    gus(j+ 4) = sss(1)*y(1,j) + sss(2)*y(2,j) 
     1                  + sss(3)*y(3,j) + sss(4)*y(4,j)
                    gus(j+ 6) = sep(1)*y(1,j) + sep(2)*y(2,j) 
     1                  + sep(3)*y(3,j) + sep(4)*y(4,j)
                    gus(j+ 8) = svf(1)*y(1,j) + svf(2)*y(2,j) 
     1                  + svf(3)*y(3,j) + svf(4)*y(4,j)
                    gus(j+10) = shf(1)*y(1,j) + shf(2)*y(2,j) 
     1                  + shf(3)*y(3,j) + shf(4)*y(4,j)
   64           continue
            ENDIF
c-----
c       invert the vertical
c-----
            do 62 j=1,12,1
                gus(j) = -gus(j)
   62       continue
c-----
c           if receiver beneath the source unflip radial
c-----
            if(lmaxr .gt. lmaxs)then
                do 63 j=2,12,2
                    gus(j) = - gus(j)
   63           continue
            endif
c-----
c           If the receiver is in the water and the source 
c           is an explosion generate pressure time history at receiver
c           Also in water layer radial time history 
c           is generated differently
c-----
            if(iwatr.eq.1)then
                gus(16) =  dble(rho(lmaxr))*gus(8) /wvno
                gus(17) =  dble(rho(lmaxr))*gus(2) /wvno
                gus(18) =  dble(rho(lmaxr))*gus(4) /wvno
                gus(19) =  dble(rho(lmaxr))*gus(6) /wvno
                gus(20) =  dble(rho(lmaxr))*gus(10) /wvno
                gus(21) =  dble(rho(lmaxr))*gus(12) /wvno
            endif
c-----
c           END OF P-SV
c-----
c           START OF SH
c-----
            if(iwats.eq.0 .and. iwatr.eq.0)then
                sds(1) = - 2.0d+00/(rhosh(lmaxs)*
     1              12.5663706d+00*
     1              bsh(lmaxs)*bsh(lmaxs)*atnb*atnb)
                sds(2) = zero
                sss(1) = zero
                sss(2) =  2.0d+00*wvno/12.5663706d+00
                shf(1) = zero
                shf(2) =  2.0d+00/12.5663706d+00
                if(.not. dosud )then
                    gus(13) = - ( d11*sds(1)           )
                    gus(14) = - (            d12*sss(2))
                    gus(15) = - (            d12*shf(2))
                ELSE
                    call shupdn(sds,saa)
                    call shupdn(sss,saa)
                    call shupdn(shf,saa)
                    gus(13) = - ( d11*sds(1) + d12*sds(2))
                    gus(14) = - ( d11*sss(1) + d12*sss(2))
                    gus(15) = - ( d11*shf(1) + d12*shf(2))
                ENDIF
                if(lmaxr .gt. lmaxs)then
                    gus(13) = - gus(13)
                endif
            endif
c-----
c           END OF SH
c-----
c-----
c           do final scaling for exponential
c-----
c-----
c           SV
c-----
c           fix for radial derived from vertical for fluid
c-----
            do 71 k=1,2
                elj = -exe + exl 
                fact = 0.0D+00
                if(elj.gt.-55.) fact=dexp(elj)
                do 72 i=0,10,2
                    j = i + k
                    gg(j) = ( gus(j) * fact/fr)
c-----
c           flip UZ to make vertical positive up
c-----
                    if(k.eq.1)then
                        gg(j) = -gg(j)
                    endif
   72           continue
c----
c           do pressure field
c----
                if(k.eq.1)then
                    gg(16) = - (gus(16)*fact/fr)
                    gg(17) = - (gus(17)*fact/fr)
                    gg(18) = - (gus(18)*fact/fr)
                    gg(19) = - (gus(19)*fact/fr)
                    gg(20) = - (gus(20)*fact/fr)
                    gg(21) = - (gus(21)*fact/fr)
                endif
   71       continue
c-----
c           SH
c-----
            elj=-exel+exll
            if(iwats.eq.0)then
                if(elj.gt.-55.) then
                    fact = dexp(elj)
                    gg(13)=(gus(13)*fact)/(fl)
                    gg(14)=(gus(14)*fact)/(fl)
                    gg(15)=(gus(15)*fact)/(fl)
                else
                    gg(13) = cmplx(0.0,0.0)
                    gg(14) = cmplx(0.0,0.0)
                    gg(15) = cmplx(0.0,0.0)
                endif
            else
                gg(13) = cmplx(0.0,0.0)
                gg(14) = cmplx(0.0,0.0)
                gg(15) = cmplx(0.0,0.0)
            endif
        endif
        return
        end

        subroutine reset3(ifreq,jsrc,lsrc,ndist,n1,n2)
c-----
c       routine to reset temporary output file on unit 3
c       if it already exists due to an aborted run
c
c       the file is read until an error is found, which
c       indicates the total number of correct frequencies on the
c       output file. The file is rewound and the correct frequencies
c       are read in to reposition the output file. The
c       parameter ifreq indicates the number of complete frequency sets
c-----
        integer*4 lsrc(*), jsrc(21)
        parameter(NSOURCE=100,NRECEIVER=100,NSR=100)
        common/source/depths(NSOURCE),lmaxs(NSOURCE),mdpths
        common/receiv/depthr(NRECEIVER),lmaxr(NRECEIVER),mdpthr
        real*4 depths, depthr
        integer lmaxs, lmaxr, mdpths, mdpthr
c-----
c       find the correct number by duplicating the 
c       writes of the main program
c-----
        ifreq = 0
        rewind 3
        do 2000 i = n1, n2
            do 2100 jd=1,ndist
            k = 0
            do 1000 js=1,mdpths
            do 1010 jr=1,mdpthr
                k = k + 1
                do 2200 jj=1,21
                if(jsrc(lsrc(jj)).eq.1)then
                    read(3,err=9998,end=9999)xx,yy
                endif
 2200           continue
 1010       continue
 1000       continue
 2100       continue
            ifreq = ifreq + 1
 2000   continue
 9998   continue
 9999   continue
c-----
c       there are now ifreq known data sets out there
c       position write pointer on the output file
c-----
        rewind 3
        do 5000 i = 1,ifreq
            do 5100 jd=1,ndist
            k = 0
            do 4000 js=1,mdpths
            do 4010 jr=1,mdpthr
                k = k + 1
                do 5200 jj=1,21
                if(jsrc(lsrc(jj)).eq.1)then
                    read(3,err=9998,end=9999)xx,yy
                endif
 5200           continue
 4010       continue
 4000       continue
 5100       continue
 5000   continue
        ifreq = ifreq -1 + n1
        return
        end

        subroutine wvint(r,smm,dk,nk)
c-----
c       to work with potentially large disk files, we cannot read in
c       all wavenumbers at once. We only work with neighboring
c       points at any time. The first two are for the DC correction,
c       followed by wavenumbers in decreasing order
c-----
        parameter(NSOURCE=100,NRECEIVER=100,NSR=100)
        common/source/depths(NSOURCE),lmaxs(NSOURCE),mdpths
        common/receiv/depthr(NRECEIVER),lmaxr(NRECEIVER),mdpthr
        real*4 depths, depthr
        integer lmaxs, lmaxr, mdpths, mdpthr
        common/jout/jsrc(21) , jbdrys, jbdryh
        common/asym/j0k0(NSR),j0k1(NSR),j0k2(NSR),j0k3(NSR),
     1      j1k0(NSR),j1k1(NSR),j1k2(NSR),j1k3(NSR),
     2      j2k0(NSR),j2k1(NSR),j2k2(NSR),j2k3(NSR),
     3      j1k0r(NSR),j1k1r(NSR),j1k2r(NSR),j1k3r(NSR),
     4      j1km1r(NSR)
        real*4 j0k0,j0k1,j0k2,j0k3,
     1      j1k0,j1k1,j1k2,j1k3,
     2      j2k0,j2k1,j2k2,j2k3,
     3      j1k0r,j1k1r,j1k2r,j1k3r,
     4      j1km1r
        common/kint4/aa,bb,cc
            complex aa(NSR,21),bb(NSR,21),cc(NSR,21)
        complex gg1(NSR),sumc(NSR)
        complex g(NSR,21)
        complex smm(NSR,21)
        complex sumd(NSR)
        real*4 wvn
        complex h0, h1

        common/cntrl/ishank,hnkarg,dstcor,dokjar,docausal
        integer*4 dstcor
        real*4 hnkarg
        logical ishank,dokjar,docausal
c-----
c       process
c-----
        rewind 2
        call bufini(0,ierr)
c-----
c       initialize integral
c-----
        call intini(smm,r)
c-----
c       we now can procede with integration
c-----
c       in the variables below the t0,j0,j1,sum refer to upper limit
c       of integration and t01,j01,j11 and sum1 refer 
c       to the lower limit
c-----
        do 200 ik = nk,1,-1
            call getgk(g,jsrc,wvn)
            t01 = wvn * r
            dkk = dk
            call hank(t01,h0,h1)
            if(ishank .and. t01 .le. hnkarg)then
                h0 = cmplx(0.0,0.0)
                h1 = cmplx(0.0,0.0)
            endif
c-----
c       perform windowing in wavenumber domain to pass
c       certain ranges of phase velocity
c-----
            if(jsrc(1).eq.1)then
c-----
c       ZDD
c-----
                call fmake(1,0,wvn,1,g,gg1)
                call wint(sumd,gg1,h0,h1,t01,0,dkk,r,wvn)
                call smmadd(1,smm,sumd)
            endif
            if(jsrc(2).eq.1)then
c-----
c       RDD
c-----
                call fmake(2,0,wvn,1,g,gg1)
                call wint(sumd,gg1,h0,h1,t01,1,dkk,r,wvn)
                call smmadd(2,smm,sumd)
            endif
            if(jsrc(3).eq.1)then
c-----
c       ZDS
c-----
                call fmake(3,0,wvn,1,g,gg1)
                call wint(sumd,gg1,h0,h1,t01,1,dkk,r,wvn)
                call smmadd(3,smm,sumd)
            endif
            call smmzer(sumc)
c-----
c           only include near field term if both SH and P-SV
c           computed
c-----
            if(jsrc(4).eq.1.and.jsrc(13).eq.1)then
                call fmake(4,13,wvn,0,g,gg1)
                call wint(sumc,gg1,h0,h1,t01,10,dkk,r,wvn)
            endif
            if(jsrc(4).eq.1)then
c-----
c       RDS
c-----
                call fmake(4,0,wvn,1,g,gg1)
                call wint(sumd,gg1,h0,h1,t01,0,dkk,r,wvn)
                call smmadd(4,smm,sumd)
                call smmadd(4,smm,sumc)
            endif
            if(jsrc(13).eq.1)then
c-----
c       TDS
c-----
                call fmake(13,0,wvn,1,g,gg1)
                call wint(sumd,gg1,h0,h1,t01,0,dkk,r,wvn)
                call smmadd(5,smm,sumd)
                call smmadd(5,smm,sumc)
            endif
            if(jsrc(5).eq.1)then
c-----
c       ZSS
c-----
                call fmake(5,0,wvn,1,g,gg1)
                call wint(sumd,gg1,h0,h1,t01,2,dkk,r,wvn)
                call smmadd(6,smm,sumd)
            endif
            call smmzer(sumc)
c-----
c           only include near field term if both SH and P-SV
c           computed
c-----
            if(jsrc(6).eq.1.and.jsrc(14).eq.1)then
                call fmake(6,14,wvn,0,g,gg1)
                call wint(sumc,gg1,h0,h1,t01,20,dkk,r,wvn)
            endif
            if(jsrc(6).eq.1)then
c-----
c       RSS
c-----
                call fmake(6,0,wvn,1,g,gg1)
                call wint(sumd,gg1,h0,h1,t01,1,dkk,r,wvn)
                call smmadd(7,smm,sumd)
                call smmadd(7,smm,sumc)
            endif
            if(jsrc(14).eq.1)then
c-----
c       TSS
c-----
                call fmake(14,0,wvn,1,g,gg1)
                call wint(sumd,gg1,h0,h1,t01,1,dkk,r,wvn)
                call smmadd(8,smm,sumd)
                call smmadd(8,smm,sumc)
            endif
            if(jsrc(7).eq.1)then
c-----
c       ZEX
c-----
                call fmake(7,0,wvn,1,g,gg1)
                call wint(sumd,gg1,h0,h1,t01,0,dkk,r,wvn)
                call smmadd(9,smm,sumd)
            endif
            if(jsrc(8).eq.1)then
c-----
c       REX
c-----
                call fmake(8,0,wvn,1,g,gg1)
                call wint(sumd,gg1,h0,h1,t01,1,dkk,r,wvn)
                call smmadd(10,smm,sumd)
            endif
            if(jsrc(9).eq.1)then
c-----
c       ZVF
c-----
                call fmake( 9,0,wvn,1,g,gg1)
                call wint(sumd,gg1,h0,h1,t01,0,dkk,r,wvn)
                call smmadd(11,smm,sumd)
            endif
            if(jsrc(10).eq.1)then
c-----
c       RVF
c-----
                call fmake(10,0,wvn,1,g,gg1)
                call wint(sumd,gg1,h0,h1,t01,1,dkk,r,wvn)
                call smmadd(12,smm,sumd)
            endif
            if(jsrc(11).eq.1)then
c-----
c       ZHF
c-----
                call fmake(11,0,wvn,1,g,gg1)
                call wint(sumd,gg1,h0,h1,t01,1,dkk,r,wvn)
                call smmadd(13,smm,sumd)
            endif
            call smmzer(sumc)
c-----
c           include near field term only if both SH and P-SV
c           computed
c-----
            if(jsrc(12).eq.1.and.jsrc(15).eq.1)then
                call fmake(12,15,wvn,0,g,gg1)
                call wint(sumc,gg1,h0,h1,t01,-10,dkk,r,wvn)
            endif
            if(jsrc(12).eq.1)then
c-----
c       RHF
c-----
                call fmake(12,0,wvn,0,g,gg1)
                call wint(sumd,gg1,h0,h1,t01,0,dkk,r,wvn)
                call smmadd(14,smm,sumd)
                call smmadd(14,smm,sumc)
            endif
            if(jsrc(15).eq.1)then
c-----
c       THF
c-----
                call fmake(15,0,wvn,0,g,gg1)
                call wint(sumd,gg1,h0,h1,t01,0,dkk,r,wvn)
                call smmadd(15,smm,sumd)
                call smmadd(15,smm,sumc)
            endif
            if(jsrc(16).eq.1)then
c-----
c       PEX
c-----
                call fmake(16,0,wvn,1,g,gg1)
                call wint(sumd,gg1,h0,h1,t01,0,dkk,r,wvn)
                call smmadd(16,smm,sumd)
            endif
            if(jsrc(17).eq.1)then
c-----
c       PDD
c-----
                call fmake(17,0,wvn,1,g,gg1)
                call wint(sumd,gg1,h0,h1,t01,0,dkk,r,wvn)
                call smmadd(17,smm,sumd)
            endif
            if(jsrc(18).eq.1)then
c-----
c       PDS
c-----
                call fmake(18,0,wvn,1,g,gg1)
                call wint(sumd,gg1,h0,h1,t01,1,dkk,r,wvn)
                call smmadd(18,smm,sumd)
            endif
            if(jsrc(19).eq.1)then
c-----
c       PSS
c-----
                call fmake(19,0,wvn,1,g,gg1)
                call wint(sumd,gg1,h0,h1,t01,2,dkk,r,wvn)
                call smmadd(19,smm,sumd)
            endif
            if(jsrc(20).eq.1)then
c-----
c       PVF
c-----
                call fmake(20,0,wvn,1,g,gg1)
                call wint(sumd,gg1,h0,h1,t01,0,dkk,r,wvn)
                call smmadd(20,smm,sumd)
            endif
            if(jsrc(21).eq.1)then
c-----
c       PHF
c-----
                call fmake(21,0,wvn,1,g,gg1)
                call wint(sumd,gg1,h0,h1,t01,1,dkk,r,wvn)
                call smmadd(21,smm,sumd)
            endif
  200   continue
c-----
c       sign change due to k j(-1)
c-----
        call smmflp(smm)
        return
        end

        subroutine wint(smm,g1,h0,h1,t01,n,dkk,r,wvn)
c-----
c       perform the wavenumber integration for the particular
c       integrand
c-----
        parameter(NSOURCE=100,NRECEIVER=100,NSR=100)
        common/source/depths(NSOURCE),lmaxs(NSOURCE),mdpths
        common/receiv/depthr(NRECEIVER),lmaxr(NRECEIVER),mdpthr
        real*4 depths, depthr
        integer lmaxs, lmaxr, mdpths, mdpthr
        complex smm(NSR),g1(NSR)
        complex h0, h1
        k = 0
        do 1000 js=1,mdpths
        do 1010 jr=1,mdpthr
            k = k + 1
            call wwint(smm(k),g1(k),h0,h1,t01,n,dkk,r,wvn)
 1010   continue
 1000   continue
        return
        end

        subroutine wwint(smm,g1,h0,h1,t01,n,dkk,r,wvn)
        complex smm,g1
        complex h0, h1
        complex h2
        real j21
        common/rlimit/rlim
        real*4 rlim
        common/cntrl/ishank,hnkarg,dstcor,dokjar,docausal
        integer*4 dstcor
        real*4 hnkarg
        logical ishank,dokjar,docausal
c-----
c       test for Hankel Function
c-----
        if(ishank)then
c-----
c           rectangular rule
c-----
            if(n.eq.0)then
c-----
c           integral (c + d z) * j0(z) dz
c-----
                smm =  (g1 * (h0 * dkk))
            elseif(n.eq.1)then
c-----
c           integral (c + d z) j1(z) dz
c-----
                smm =  (g1 * (h1 * dkk))
c-----
c           integral (c + d z) j2(z) dz
c-----
            elseif(n.eq.2)then
                if(t01.eq.0.0)then
                    h2 = (0.0,0.0)
                else
                    h2 = 2.*h1/t01 - h0
                endif
                smm =  (g1 * (h2 * dkk))
c-----
c            - integral (c + d z) j1(kr) dk / r
c-----
            elseif(n.eq.10)then
                if(r.le.rlim)then
                    smm =  (g1 * (0.5 * dkk)) * wvn
                else
                    smm =  (g1 * (h1 * dkk))/r
                endif
                smm = - smm
        SMM =  CMPLX(0.0,0.0)
c-----
c            - integral (c + d z) j1(kr) dk / kr
c-----
            elseif(n.eq.-10)then
                if(r.le.rlim)then
                    smm =  (g1 * (0.5 * dkk)) 
                else
                    smm =  (g1 * (h1 * dkk))/(r*wvn)
                endif
                smm = - smm
        SMM =  CMPLX(0.0,0.0)
c-----
c            - 2 integral (c + d z) j2(kr) dk / r
c-----
            elseif(n.eq.20)then
                if(t01.eq.0.0)then
                    h2 = (0.0,0.0)
                else
                    h2 = 2.*h1/t01 - h0
                endif
                if(r.le.rlim)then
                    smm = (0.0,0.0)
                else
                    smm =  (g1 * (h2 * dkk)) / r
                endif
                smm = -2.0*smm
        SMM =  CMPLX(0.0,0.0)
            endif
        else
c-----
c           rectangular rule
c-----
            if(n.eq.0)then
c-----
c           integral (c + d z) * j0(z) dz
c-----
                smm =  (g1 * (real(h0) * dkk))
            elseif(n.eq.1)then
c-----
c           integral (c + d z) j1(z) dz
c-----
                smm =  (g1 * (real(h1) * dkk))
c-----
c           integral (c + d z) j2(z) dz
c-----
            elseif(n.eq.2)then
                if(t01.eq.0.0)then
                    j21 = (0.0,0.0)
                else
                    j21 = 2.*real(h1)/t01 - real(h0)
                endif
                smm =  (g1 * (j21 * dkk))
c-----
c            - integral (c + d z) j1(kr) dk / r
c-----
            elseif(n.eq.10)then
                if(r.le.rlim)then
                    smm =  (g1 * (0.5 * dkk)) * wvn
                else
                    smm =  (g1 * (real(h1) * dkk))/r
                endif
                smm = - smm
c-----
c            - integral (c + d z) j1(kr) dk / kr
c-----
            elseif(n.eq.-10)then
                if(r.le.rlim)then
                    smm =  (g1 * (0.5 * dkk)) 
                else
                    smm =  (g1 * (real(h1) * dkk))/(r*wvn)
                endif
                smm = - smm
c-----
c            - 2 integral (c + d z) j2(kr) dk / r
c-----
            elseif(n.eq.20)then
                if(t01.eq.0.0)then
                    j21 = (0.0,0.0)
                else
                    j21 = 2.*real(h1)/t01 - real(h0)
                endif
                if(r.le.rlim)then
                    smm = (0.0,0.0)
                else
                    smm =  (g1 * (j21 * dkk)) / r
                endif
                smm = -2.0*smm
            endif
        endif
        return
        end

        subroutine hank(z,h0,h1)
c-----
c       evaluate Bessel functions using Abromiwitz and Stegun
c-----
        complex h0, h1
        real z
        real j0, j1
        real j1z
        common/cntrl/ishank,hnkarg,dstcor,dokjar,docausal
        integer*4 dstcor
        real*4 hnkarg
        logical ishank,dokjar,docausal
c-----
        h0 = cmplx(0.0,0.0)
        h1 = cmplx(0.0,0.0)
        if(z.eq.0.0)then
            h0 = cmplx(1.0,0.0)
        elseif(z.gt.0.0 .and. z.le.3.0)then
            x = (z/3.)*(z/3.)
            j0 = 1.-x*(2.2499997-x*(1.2656208-x*(.3163866-x*(
     1            .0444479-x*(.0039444-x*(.0002100))))))
            j1z = 0.5-x*(.56249985-x*(.21093573-x*(.03954289-x*(
     1      .00443319-x*(.00031761-x*(.00001109))))))
            j1 = z * j1z
            h0 = cmplx(j0,0.0)
            h1 = cmplx(j1,0.0)
        else
            x = 3./z
            fac = 1./sqrt(z)
            f0 = .79788456+x*(-.00000077 + x*(-.00552740 + x*(
     1      -.00009512+x*(.00137237+x*(-.00072805+x*(.00014476))))
     2            ))
            t0 = z - .78539816+x*(-.04166397+x*(-.00003954+x*(
     1      .00262573+x*(-.00054125+x*(-.00029333+x*(.00013558))))
     2            ))
            f1 = .79788456+x*(.00000156+x*(.01659667+x*(.00017105+
     1            x*(-.00249511+x*(.00113653+x*(-.00020033))))))
            t1 = z-2.35619449+x*(.12499612+x*(.00005650+x*(
     1       -.00637879+x*(.00074348+x*(.00079824+x*(-.00029166)))
     2            )))
            if(ishank .and. z .ge. hnkarg)then
                h0 = 0.5 * fac * f0 * cmplx(cos(t0), -sin(t0))
                h1 = 0.5 * fac * f1 * cmplx(cos(t1), -sin(t1))
            else
                h0 =       fac * f0 * cmplx(cos(t0),0.0)
                h1 =       fac * f1 * cmplx(cos(t1),0.0)
            endif
        endif
        return
        end

        subroutine solu(y1,y2,x1,x2,h,j,a,b,c)
c-----
c       Using two data points, determine the coefficients of
c       a function
c       y(k) = [ a + bk + ck^2 ] exp [ -kh]
c
c       Given only two data points, we will constrain one of the a,b,c
c       to be zero, depending on the nature of the 
c       elastic wave integrand
c-----
c       we do not solve for a,b,c together, only two at most
c       thus we only need two values of wavenumber, x1 and x2
c
c
c       Since the program permits consideration of more than a
c       single depth, we must check for overflow here and 
c       underflow in gasym
c-----
        complex y1,y2,a,b,c
        integer imap(21)
C       data imap/3,2,3,2,3,2,3,2,3,2,3,3,2,2,3,3,3,3,3,3,3/
        data imap/2,2,3,2,3,3,2,3,2,2,2,3,2,2,3,2,2,2,2,2,2/
        a=cmplx(0.0,0.0)
        b=cmplx(0.0,0.0)
        c=cmplx(0.0,0.0)
        wfac = x1*h
c       if(wfac.gt.10.0)return
        ii = imap(j)
        if(ii.eq.1)then
c-----
c       a exp(-kh)
c-----
            b=cmplx(0.0,0.0)
            a=y1*exp(x1*h)
        else if(ii.eq.2)then
c-----
c       [ a + b k  ]exp(-kh)
c-----
            u1=x1*h
            u2=x2*h
            det=x2-x1
            a= x2*(y1*exp(u1))-x1*(y2*exp(u2))
            a=a/det
            b= y2*exp(u2) - y1*exp(u1)
            b=b/det
        else if(ii.eq.3)then
c-----
c       [ b + c k  ]  k exp(-kh)
c-----
            u1=x1*h
            u2=x2*h
            det=x2-x1
            a = cmplx(0.0,0.0)
            b = x2*(y1*exp(u1))/x1 - x1*(y2*exp(u2))/x2
            b = b/det
            c= y2*exp(u2)/x2 - y1*exp(u1)/x1
            c = c/det
        else if(ii.eq.4)then
c-----
c       [ c k*k ] exp(-kh)
c-----
            a = cmplx(0.0,0.0)
            b = cmplx(0.0,0.0)
            c = y1 * exp(x1*h)/(x1)**2
        else if(ii.eq.5)then
c-----
c       [ b k ] exp(-kh)
c-----
            a = cmplx(0.0,0.0)
            b = y1 * exp(x1*h)/ x1
        endif
        return
        end

        subroutine setup(rr) 
c---------------------------------------------------------- 
c 
c       jnkm =  integral exp(-kh) krsup m j sub n (kr) dk 
c
c       This is used in the fit of low frequency information
c
c       integral f(k) Jn(kr) dk = 
c           integral [ f(k) - (a+bk+ck^2)e^{-kh} ] Jn(kr) dk
c           +integral [  (a+bk+ck^2)e^{-kh} ] Jn(kr) dk
c
c       The last integral is obtained analytically
c
c       Special care is taken when r=0, especially for a near field
c       TDS, RDS term
c       j1kmr = lim r->0 integral exp(-kh) k rsup m j sub 1 (kr) dk
c
c       Herrmann, R. B., and C. Y. Wang (1985).
c       A comparison of synthetic seismograms,
c       Bull. Seism. Soc. Am. 75, 41-56.
c 
c---------------------------------------------------------- 
        implicit double precision (a-h,o-z)
        parameter(NSOURCE=100,NRECEIVER=100,NSR=100)
        common/source/depths(NSOURCE),lmaxs(NSOURCE),mdpths
        common/receiv/depthr(NRECEIVER),lmaxr(NRECEIVER),mdpthr
        real*4 depths, depthr
        integer lmaxs, lmaxr, mdpths, mdpthr
        real*4 rr,zz
        common/rlimit/rlim
        real*4 rlim
        common/asym/j0k0(NSR),j0k1(NSR),j0k2(NSR),j0k3(NSR),
     1      j1k0(NSR),j1k1(NSR),j1k2(NSR),j1k3(NSR),
     2      j2k0(NSR),j2k1(NSR),j2k2(NSR),j2k3(NSR),
     3      j1k0r(NSR),j1k1r(NSR),j1k2r(NSR),j1k3r(NSR),
     4      j1km1r(NSR)
        real*4 j0k0,j0k1,j0k2,j0k3,
     1      j1k0,j1k1,j1k2,j1k3,
     2      j2k0,j2k1,j2k2,j2k3,
     3      j1k0r,j1k1r,j1k2r,j1k3r,
     4      j1km1r
        k = 0
        do 2500 i=1,mdpths
            do 2600 j=1,mdpthr
                zz = abs(depths(i) - depthr(j))
                k = k + 1
                    r = dble(rr)
                    z = dble(zz)
                    dist=dsqrt(r*r + z*z) 
c-----
c       if distance == 0 , force small answers
c-----
                if(dist.le.rlim)dist=rlim
                    dist3=dist**3 
                    dist5=dist**5 
                    dist7=dist**7 
                zdist = z + dist
                    rz=r*z 
                    z2=z*z 
                    r2=r*r 
                    r3=r*r2 
                    z3=z*z2 
                    rz2=r*z2 
                    rz3=r*z3 
                    zor = z/dist
                    zor2= zor*zor
                    zor3= zor*zor2
                    j0k0(k) = sngl( 1.0/dist   )
                    j0k1(k) = sngl( z/dist3   )
                    j0k2(k) = sngl( (2.0*z2 - r2)/dist5   )
                    j0k3(k) = sngl( (6.0*z3 - 9.0*z*r2)/dist7   )
                if(rr.le.rlim)then
                    j1k0(k) = 0.0
                    j1k1(k) = 0.0
                    j1k2(k) = 0.0
                    j1k3(k) = 0.0
                    if(zz .le.rlim)then
                        j1km1r(k)=sngl(1.0d+00/zdist)
                        j1k0r(k) = sngl(0.5/(dist*dist))
                    else
                        j1km1r(k) = sngl(0.5/z)
                        j1k0r(k) = sngl(0.5/z2)
                    endif
                    j1k1r(k) = sngl(1.0/dist3)
                        j1k2r(k) = sngl( 3.0*z/dist5   )
                        j1k3r(k) = sngl( 12.0*z2 /dist7   )
                    
                else
c                       j1k0(k) = sngl(( 1.0 -z/dist   )/r       )
                        j1k0(k) = sngl((r/(dist*zdist) )      )
                        j1k1(k) = sngl( r/dist3                  )
                        j1k2(k) = sngl( 3.0*z*r/dist5            )
                        j1k3(k) = sngl( 3.0*r*(4.0*z2 - r2)/dist7)
                    j1km1r(k)=sngl(1.0d+00/(zdist)          )
c                   j1k0r(k) = j1k0(k)/rr
                        j1k0r(k) = sngl(1.0d+00/(dist*zdist))
                    j1k1r(k) = j1k1(k)/rr
                    j1k2r(k) = j1k2(k)/rr
                    j1k3r(k) = j1k3(k)/rr
                endif
                if(rr.le.rlim)then
                        j2k0(k) = 0.0
                        j2k1(k) = 0.0
                else
                        j2k0(k)=sngl((1.0 -zor)*(1.0-zor)*(dist/r2))
c                       j2k0(k)=sngl(((r/zdist)**2)/dist)
                        j2k1(k)=sngl((1.0-zor)*(1.0-zor)*(2.0+zor)/r2)
c                       j2k1(k)=j2k0(k)*sngl( (zdist+dist)/dist3)
                endif
                    j2k2(k) = sngl( 3.0*r2/dist5   )
                    j2k3(k) = sngl( 15.0*z*r2/dist7   )
 2600       continue
 2500   continue
        return 
        end 

        subroutine fmake(j,k,wvn,l,g,gg1)
c-----
c       make the proper integrand
c-----
        parameter(NSOURCE=100,NRECEIVER=100,NSR=100)
        common/source/depths(NSOURCE),lmaxs(NSOURCE),mdpths
        common/receiv/depthr(NRECEIVER),lmaxr(NRECEIVER),mdpthr
        real*4 depths, depthr
        integer lmaxs, lmaxr, mdpths, mdpthr
        real*4 wvn
        complex g(NSR,21)
        complex gg1(NSR)
        kk = 0
        do 1000 js=1,mdpths
        do 1010 jr=1,mdpthr
            kk = kk + 1
            gg1(kk)= g(kk,j)
            if(k.gt.0)then
                    gg1(kk)=gg1(kk) + g(kk,k)
            endif
            if(l.gt.0)then
                    gg1(kk)=gg1(kk) * wvn
            endif
 1010   continue
 1000   continue
        return
        end

        subroutine getgk(g,jsrc,wvno)
c-----
c       read input to obtain elements of g(21,j) array
c-----
        parameter(NSOURCE=100,NRECEIVER=100,NSRC=100)
        common/source/depths(NSOURCE),lmaxs(NSOURCE),mdpths
        common/receiv/depthr(NRECEIVER),lmaxr(NRECEIVER),mdpthr
        real*4 depths, depthr
        integer lmaxs, lmaxr, mdpths, mdpthr
        complex g(NSRC,21)
        dimension jsrc(21)
        call bufrd(wvno,ierr)
        k = 0
        do 1000 js=1,mdpths
        do 1010 jr=1,mdpthr
            k = k + 1
            do 101 i=1,21
                if(jsrc(i).eq.1)then
                    call bufrd(xr,ierr)
                    call bufrd(xi,ierr)
                    g(k,i)=cmplx(xr,xi)
                endif
  101       continue
 1010   continue
 1000   continue
        return
        end

        subroutine intini(smm,r)
        parameter(NSOURCE=100,NRECEIVER=100,NSR=100)
        common/source/depths(NSOURCE),lmaxs(NSOURCE),mdpths
        common/receiv/depthr(NRECEIVER),lmaxr(NRECEIVER),mdpthr
        real*4 depths, depthr
        integer lmaxs, lmaxr, mdpths, mdpthr
        common/jout/jsrc(21) , jbdrys, jbdryh
        common/asym/j0k0(NSR),j0k1(NSR),j0k2(NSR),j0k3(NSR),
     1      j1k0(NSR),j1k1(NSR),j1k2(NSR),j1k3(NSR),
     2      j2k0(NSR),j2k1(NSR),j2k2(NSR),j2k3(NSR),
     3      j1k0r(NSR),j1k1r(NSR),j1k2r(NSR),j1k3r(NSR),
     4      j1km1r(NSR)
        real*4 j0k0,j0k1,j0k2,j0k3,
     1      j1k0,j1k1,j1k2,j1k3,
     2      j2k0,j2k1,j2k2,j2k3,
     3      j1k0r,j1k1r,j1k2r,j1k3r,
     4      j1km1r
        common/kint4/aa,bb,cc
            complex aa(NSR,21),bb(NSR,21),cc(NSR,21)
        complex smm(NSR,21),sumd
        common/kint1/gasymp
            logical gasymp(NSR)
        common/rlimit/rlim
        real*4 rlim
        k = 0
        do 1000 js=1,mdpths
        do 1010 jr=1,mdpthr
            k = k + 1
            if(gasymp(k))then
c-----
c       set up sum arrays, but put in asymptotic value now
c       of setting to zero and then resetting
c-----
                smm(k,1)=         aa(k,1)*j0k1(k) 
     1                  + bb(k,1)*j0k2(k) 
     2                  + cc(k,1)*j0k3(k)
                smm(k,2)=         aa(k,2)*j1k1(k) 
     1                  + bb(k,2)*j1k2(k) 
     2                  + cc(k,2)*j1k3(k)
                smm(k,3)=         aa(k,3)*j1k1(k) 
     1                  + bb(k,3)*j1k2(k) 
     2                  + cc(k,3)*j1k3(k)
                if(jsrc(4).eq.1 .and. jsrc(13).eq.1)then
                    sumd  = (aa(k,4)+aa(k,13))*j1k0r(k) 
     1                  + (bb(k,4)+bb(k,13))*j1k1r(k) 
     2                  + (cc(k,4)+cc(k,13))*j1k2r(k)
                    sumd = - sumd
                else
                    sumd = cmplx(0.0,0.0)
                endif
                smm(k,4)= sumd  + aa(k,4) *j0k1(k) 
     1                  + bb(k,4) *j0k2(k) 
     2                  + cc(k,4) *j0k3(k)
                smm(k,5)= sumd  + aa(k,13)*j0k1(k) 
     1                  + bb(k,13)*j0k2(k) 
     2                  + cc(k,13)*j0k3(k)
                smm(k,6)=     aa(k,5)*j2k1(k) 
     1                  + bb(k,5)*j2k2(k) 
     2                  + cc(k,5)*j2k3(k)
                if(jsrc(6).eq.1 .and. jsrc(14).eq.1 .and.
     1              r.gt.rlim)then
                    sumd= (aa(k,6)+aa(k,14))*j2k0(k) 
     1                  + (bb(k,6)+bb(k,14))*j2k1(k) 
     2                  + (cc(k,6)+cc(k,14))*j2k2(k)
                    sumd = -2.*sumd/r
                else
                    sumd = cmplx(0.0,0.0)
                endif
                smm(k,7)= sumd  + aa(k,6) *j1k1(k) 
     1                  + bb(k,6) *j1k2(k) 
     2                  + cc(k,6) *j1k3(k)
                smm(k,8)= sumd  + aa(k,14)*j1k1(k)
     1                  + bb(k,14)*j1k2(k)
     2                  + cc(k,14)*j1k3(k)
                smm(k,9)=         aa(k,7) *j0k1(k)        
     1                  + bb(k,7) *j0k2(k) 
     2                  + cc(k,7) *j0k3(k)
                smm(k,10)=        aa(k,8) *j1k1(k) 
     1                  + bb(k,8) *j1k2(k) 
     2                  + cc(k,8) *j1k3(k)
                smm(k,11)=        aa(k,9) *j0k1(k) 
     1                  + bb(k,9) *j0k2(k) 
     2                  + cc(k,9) *j0k3(k)
                smm(k,12)=        aa(k,10)*j1k1(k) 
     1                  + bb(k,10)*j1k2(k) 
     2                  + cc(k,10)*j1k3(k)
                smm(k,13)=        aa(k,11)*j1k1(k) 
     1                  + bb(k,11)*j1k2(k) 
     2                  + cc(k,11)*j1k3(k)
                if(jsrc(12).eq.1 .and. jsrc(15).eq.1)then
                    sumd  = (aa(k,12)+aa(k,15))*j1km1r(k) 
     1                  + (bb(k,12)+bb(k,15))*j1k0r(k) 
     2                  + (cc(k,12)+cc(k,15))*j1k1r(k)
                    sumd = - sumd
                else
                    sumd = cmplx(0.0,0.0)
                endif
                smm(k,14)= sumd + aa(k,12)*j0k0(k) 
     1                  + bb(k,12)*j0k1(k) 
     2                  + cc(k,12)*j0k2(k)
                smm(k,15)= sumd + aa(k,15)*j0k0(k) 
     1                  + bb(k,15)*j0k1(k) 
     2                  + cc(k,15)*j0k2(k)
                smm(k,16)=        aa(k,16)*j0k1(k) 
     1                  + bb(k,16)*j0k2(k) 
     2                  + cc(k,16)*j0k3(k)
                smm(k,17)=        aa(k,17)*j0k1(k) 
     1                  + bb(k,17)*j0k2(k) 
     2                  + cc(k,17)*j0k3(k)
                smm(k,18)=        aa(k,18)*j1k1(k) 
     1                  + bb(k,18)*j1k2(k) 
     2                  + cc(k,18)*j1k3(k)
                smm(k,19)=        aa(k,19)*j2k1(k) 
     1                  + bb(k,19)*j2k2(k) 
     2                  + cc(k,19)*j2k3(k)
                smm(k,20)=        aa(k,20)*j0k1(k) 
     1                  + bb(k,20)*j0k2(k) 
     2                  + cc(k,20)*j0k3(k)
                smm(k,21)=        aa(k,21)*j1k1(k) 
     1                  + bb(k,21)*j1k2(k) 
     2                  + cc(k,21)*j1k3(k)
            else
                do 100 i=1,21
                    smm(k,i)=cmplx(0.0,0.0)
  100           continue
            endif
 1010   continue
 1000   continue
        return
        end

        subroutine wvfilt(wvmn,wvc1,wvc2,wvmx,wvno,fact)
        common/c/cmax,c1,c2,cmin
c-----
c       apply a cosine taper wavenumber filter
c-----
        pi = 3.1415927
c-----
c       test if no filtering is to be done
c-----
        if(cmin .le. 0.0 .and. cmax.le.0.0)then
            fact = 1.0
c-----
c       test if high pass in wavenumber (low phase velocity)
c-----
        else if(cmin .le. 0.0)then
            if(wvno.ge.wvc1)then
                fact=1.0
            else if(wvno.ge.wvmn.and.wvno.lt.wvc1)then
                fact=(1.-cos(pi*(wvno-wvmn)/ (wvc1-wvmn)))/2.
            else if(wvno.lt.wvmn)then
                fact = 0.0
            endif
c-----
c       test if low pass in wavenumber (high phase velocity)
c-----
        else if(cmax .le. 0.0)then
            if(wvno.le.wvc2)then
                fact = 1.0 
            else if(wvno.gt.wvc2.and.wvno.le.wvmx)then
                fact=(1.-cos(pi*(wvno-wvmx)/ (wvc2-wvmx)))/2.
            else
                fact = 0.0
            endif
c-----
c       test if band pass in wavenumber
c-----
        else
            if(wvno.ge.wvc1.and.wvno.le.wvc2)then
                fact=1.0
            elseif(wvno.ge.wvmn.and.wvno.lt.wvc1)then
                fact=(1.-cos(pi*(wvno-wvmn)/ (wvc1-wvmn)))/2.
            elseif(wvno.gt.wvc2.and.wvno.le.wvmx)then
                fact=(1.-cos(pi*(wvno-wvmx)/ (wvc2-wvmx)))/2.
            else
                fact = 0.0
            endif
        endif
        return
        end

        subroutine smmadd(i,smm,sumd)
        parameter(NSOURCE=100,NRECEIVER=100,NSR=100)
        common/source/depths(NSOURCE),lmaxs(NSOURCE),mdpths
        common/receiv/depthr(NRECEIVER),lmaxr(NRECEIVER),mdpthr
        real*4 depths, depthr
        integer lmaxs, lmaxr, mdpths, mdpthr
        complex smm(NSR,21), sumd(NSR)
c-----
c       add sumd vector to the particular entry of smm
c-----
        k = 0
        do 1000 js=1,mdpths
            do 1010 jr=1,mdpthr
                k = k + 1
                smm(k,i) = smm(k,i) +  sumd(k)
 1010       continue
 1000   continue
        return
        end

        subroutine smmzer(sumc)
c-----
c       zero an array for all depths
c-----
        parameter(NSOURCE=100,NRECEIVER=100,NSR=100)
        common/source/depths(NSOURCE),lmaxs(NSOURCE),mdpths
        common/receiv/depthr(NRECEIVER),lmaxr(NRECEIVER),mdpthr
        real*4 depths, depthr
        integer lmaxs, lmaxr, mdpths, mdpthr
        complex sumc(NSR)
c-----
c       zero a vector over all depths
c-----
        k = 0
        do 1000 js=1,mdpths
            do 1010 jr=1,mdpthr
                k = k + 1
                sumc(k) = cmplx(0.0,0.0)
 1010       continue
 1000   continue
        return
        end

        subroutine smmscl(sumc,scl)
c-----
c       scale an array for all depths
c-----
        parameter(NSOURCE=100,NRECEIVER=100,NSR=100)
        common/source/depths(NSOURCE),lmaxs(NSOURCE),mdpths
        common/receiv/depthr(NRECEIVER),lmaxr(NRECEIVER),mdpthr
        real*4 depths, depthr
        integer lmaxs, lmaxr, mdpths, mdpthr
        complex sumc(NSR)
        real*4 scl
c-----
c       add sumd vector to the particular entry of smm
c-----
        k = 0
        do 1000 js=1,mdpths
            do 1010 jr=1,mdpthr
                k = k + 1
                sumc(k) = sumc(k) * scl
 1010       continue
 1000   continue
        return
        end

        subroutine smmflp(smm)
c-----
c       flip the -1 Bessel function values
c-----
        parameter(NSOURCE=100,NRECEIVER=100,NSR=100)
        common/source/depths(NSOURCE),lmaxs(NSOURCE),mdpths
        common/receiv/depthr(NRECEIVER),lmaxr(NRECEIVER),mdpthr
        real*4 depths, depthr
        integer lmaxs, lmaxr, mdpths, mdpthr
        complex smm(NSR,21)
        k = 0
        do 1000 js=1,mdpths
            do 1010 jr=1,mdpthr
                k = k + 1
                smm(k,2)  = -smm(k,2)
                smm(k,10) = -smm(k,10)
                smm(k,12) = -smm(k,12)
 1010       continue
 1000   continue
        return
        end

        subroutine gett0(t0,r,depths,depthr,tshift,vred,dstcor)
        real*4 t0, depths, depthr, tshift, vred
        integer*4 dstcor
c-----
c       compute time of first sample of the time series
c-----
            if(dstcor.eq.0)then
                rr = r
            else if(dstcor.eq.1)then
                rr = abs(depthr - depths)
            else if(dstcor.eq.2)then
                rr = sqrt(r*r + (depthr-depths)*(depthr-depths))
            endif
            if(vred.eq.0.0)then
                t0 = tshift 
            else
                t0 = tshift + rr/vred
            endif
        return
        end

        subroutine wvlimit(nk,omega,dk,xfac,xleng)
        parameter(NL=200)
        common/isomod/d(NL),a(NL),b(NL),rho(NL),
     1      qa(NL),qb(NL),etap(NL),etas(NL), 
     2      frefp(NL), frefs(NL)
        common/shwave/bsh(NL), rhosh(NL), qbsh(NL)
        real bsh, rhosh, qbsh
        common/modlly/mmax
        common/jout/jsrc(21) , jbdrys, jbdryh
        parameter(NSOURCE=100,NRECEIVER=100,NSR=100)
        common/source/depths(NSOURCE),lmaxs(NSOURCE),mdpths
        common/receiv/depthr(NRECEIVER),lmaxr(NRECEIVER),mdpthr
        common/frlim/fl,fu,df,fwhich
        real*4 depths, depthr
        integer lmaxs, lmaxr, mdpths, mdpthr
        common/bound/vmin,vamin,vamax,vbmin,vbmax
        common/damp/alpha,ieqex
        common/lyrctl/lyrins
        logical lyrins
        common/wvflt/wvmn,wvc1,wvc2,wvmx
        common/c/cmax,c1,c2,cmin
c-----
c       set up common blocks for wavenumber sampling at
c       suitable depths. This is necessary since the matrix
c       evaluation is done here for all source-receiver pairs
c       The source-receiver distance is important for the
c       wavenumber sampling at low frequencies
c-----
c       If wavenumber filtering is used and if 
c          the upper wavenumber limit
c       is not defined, then asymptotic may be permissible
c-----
        common/kint1/gasymp
            logical gasymp(NSR)
        common/kint2/mkup
            integer mkup(NSR)
        common/kint3/wave
            real*4 wave(NSR,2)
        common/kint4/aa,bb,cc
            complex aa(NSR,21),bb(NSR,21),cc(NSR,21)
        complex*16 wvn,om, wvn2, om2
        complex g1(21), g2(21)
c-----
c       command line arguments
c-----
        common/cntrl/ishank,hnkarg,dstcor,dokjar,docausal
        integer*4 dstcor
        real*4 hnkarg
        logical ishank,dokjar,docausal

c-----
c       get average  layer thickness
c-----
        deep = 0.0
        do 10 i=mmax,1,-1
            deep = deep + d(i)
   10   continue
        deep = deep/mmax
        k = 0
        nk = 0
        wvfu = 6.2831853*fu/vmin
        wvbm = omega/vmin
        dk = 6.2831853/xleng
        om=dcmplx(dble(omega),-dble(alpha))
        do 1000 js=1,mdpths
            do 1010 jr=1,mdpthr
                k = k + 1
                depth = abs(depths(js) - depthr(jr))
                if(depth.lt. deep)then
                    dpth = deep
                else
                    dpth = depth
                endif
c-----
c       check for wavenumber filtering. If done, do not use asymptotic
c-----
                if(cmin .le. 0.0)then
c-----
c       new logic for asymptotic as of 083192
c       If kh never gets large enough, the asymptotic
c       must be forced. Also the integration must at least go beyond
c       4 wvbm. Note that below we actually integrate in this case
c       over a square region in the omega-k plane rather than
c       the triangular when kh gets large 
c-----
                    wvmm = (5.0/dpth) + xfac*wvbm
                    wvzmx = wvmm * depth
                    if(wvzmx.gt.5.0)then
                        wave(k,1) = 6.0/depth
                        wave(k,2) = 2.5/depth
                        mk = wvmm / dk
                    else
                        wave(k,1)=20.0*wvfu
                        wave(k,2)=5.0*wvfu
                        if(wave(k,1)*depth .gt. 5.0)then
                            wave(k,1) = 6.0/depth
                            wave(k,2) = 
     1                      (5.0/dpth)+4.0*wvbm
                        endif
                        mk = wave(k,2) / dk
                    endif
                    if(mk .lt.1)mk = 1
                    wv = (mk-1)*dk + 0.218*dk
                    if(wv.gt.wave(k,1))then
                        gasymp(k) = .false.
                        if(fwhich.lt.0.0)then
                        fwhich=omega/6.2831853
                        endif
                    else
                        gasymp(k) = .true.
                    endif
                else
                    mk = wvmx /dk
                    gasymp(k) = .false.
                    if(fwhich.lt.0.0)then
                        fwhich=omega/6.2831853
                    endif
                endif
                if(ishank)gasymp(k) = .false.
c-----
c       define upper index of wavenumber
c-----
                mkup(k) = mk
                if(mk.gt.nk)nk = mk
c-----
c       now evaluate asymptotic coefficients, if appropriate
c-----
                if(gasymp(k))then
                    if(.not. lyrins)then
                        call modcpy(.false.)
                        call insert(depths(js))
                        call insert(depthr(jr))
                        call srclyr(depths(js),
     1                      lmaxs(js), dphs)
                        call srclyr(depthr(jr),
     1                      lmaxr(jr), dphr)
                        call dezero()
                        call equlck()
                    endif

                    om2 = om*om
                    wvn=dcmplx(dble(wave(k,1)),0.0d+00)
                    wvn2 = wvn*wvn
                    call evlmat(om,wvn,jbdrys,jbdryh,wvn2,om2)
                    call rshof(g1,om,wvn,lmaxs(js),lmaxr(jr),wvn2,om2)
c-----
c                   adjust 12 and 15 to get avoid asymptotic problems
c-----
                    g1(12) = g1(12) * dreal(wvn)
                    g1(15) = g1(15) * dreal(wvn)

                    wvn=dcmplx(dble(wave(k,2)),0.0d+00)
                    wvn2 = wvn*wvn
                    call evlmat(om,wvn,jbdrys,jbdryh,wvn2,om2)
                    call rshof(g2,om,wvn,lmaxs(js),lmaxr(jr),wvn2,om2)
c-----
c                   adjust 12 and 15 to get avoid asymptotic problems
c-----
                    g2(12) = g2(12) * dreal(wvn)
                    g2(15) = g2(15) * dreal(wvn)
c-----
c                    find asymptotic coefficients using these values
c-----
                    do 102 j=1,21
                            call solu(g1(j),g2(j),wave(k,1),
     1                  wave(k,2),depth,j,
     2                      aa(k,j),bb(k,j),cc(k,j) )
  102               continue
c-----
                else
                    do 1101 i=1,21
                        aa(k,i) = cmplx(0.0,0.0)
                        bb(k,i) = cmplx(0.0,0.0)
                        cc(k,i) = cmplx(0.0,0.0)
 1101               continue
                endif
 1010       continue
 1000   continue
        return
        end

        subroutine gasym(g,k,wvno,depth,jsrc)
c-----
c       remove asymptotic trend from integrands
c-----
        parameter(NSOURCE=100,NRECEIVER=100,NSR=100)
        common/kint4/aa,bb,cc
            complex aa(NSR,21),bb(NSR,21),cc(NSR,21)
        complex g(21)
        dimension jsrc(21)
        ex = exp(-wvno*depth)
        do 1000 j=1,21
            if(jsrc(j).eq.1)then
c           if(j.eq.12 .or. j.eq.15)then
c               g(j)=g(j) - ex*(aa(k,j)/wvno +bb(k,j))
c           else
                g(j)=g(j) - ex*(aa(k,j)+wvno*(bb(k,j)+
     1              wvno*(cc(k,j))))
c           endif
            endif
 1000   continue
c----
c       the fix for j=12, the P-SV horizontal force was made 8/26/92
c       this is OK since we never use k=0. Also, note that the
c       integrands involve J1 or a kJ0
c-----
        return
        end

        subroutine equlck()
        parameter(NL=200)
        common/isomod/d(NL),a(NL),b(NL),rho(NL),
     1      qa(NL),qb(NL),etap(NL),etas(NL), 
     2      frefp(NL), frefs(NL)
        common/shwave/bsh(NL), rhosh(NL), qbsh(NL)
        real bsh, rhosh, qbsh
        common/modlly/mmax
        common/updnsm/equalu(NL), equald(NL)
        logical equalu, equald
c-----
c       To avoid repeated computation, 
c       check to see if neighboring layers
c       are identical, once for going up and another for going down
c-----
c       First check top down
c-----
        do 100 m=1,mmax
            if(m.eq.1)then
                equald(m) = .false.
            else if(m.gt.1
     1          .and. a(m).eq.a(m-1) 
     2          .and. b(m).eq.b(m-1)
     3          .and. d(m).eq.d(m-1) 
     4          .and. rho(m).eq.rho(m-1)
     5          .and. qa(m).eq.qa(m-1)
     6          .and. qb(m).eq.qb(m-1) 
     2          .and. bsh(m).eq.bsh(m-1)
     4          .and. rhosh(m).eq.rhosh(m-1)
     5          .and. qbsh(m).eq.qbsh(m-1))then
                equald(m) = .true.
            else
                equald(m) = .false.
            endif
  100   continue
c-----
c       check bottom up
c-----
        do 200 m=1,mmax
            if(m.eq.mmax)then
                equalu(m) = .false.
            else if(m.lt.mmax
     1          .and. a(m).eq.a(m+1) 
     2          .and. b(m).eq.b(m+1)
     3          .and. d(m).eq.d(m+1) 
     4          .and. rho(m).eq.rho(m+1)
     5          .and. qa(m).eq.qa(m+1)
     6          .and. qb(m).eq.qb(m+1) 
     2          .and. bsh(m).eq.bsh(m+1)
     4          .and. rhosh(m).eq.rhosh(m+1)
     5          .and. qbsh(m).eq.qbsh(m+1) )then
                equalu(m) = .true.
            else
                equalu(m) = .false.
            endif
  200   continue
        return
        end

        subroutine dezero()
        parameter (LER=0, LIN=5, LOT=6)
        parameter(NL=200)
        common/isomod/d(NL),a(NL),b(NL),rho(NL),
     1      qa(NL),qb(NL),etap(NL),etas(NL), 
     2      frefp(NL), frefs(NL)
        common/shwave/bsh(NL), rhosh(NL), qbsh(NL)
        real bsh, rhosh, qbsh
        common/modlly/mmax
c-----
c       ultimately get rid of zero thickness layers - this
c       will require readjusting the model from top down, and
c       also readjusting the source and receiver indices.
c----
c       Here just guarantee that the halfspace is not of zero thickness
c-----
        dmin = 1.0e+30
        do 100 i=1,mmax-1
            if(d(i) .lt. dmin .and. d(i).gt.0.0)dmin = d(i)
  100   continue
c       if(d(mmax).le.0.0)then
c           d(mmax) = 0.1*dmin
c       endif
        return
        end

        subroutine srclay(depth,lmax,dph)
        parameter (LER=0, LIN=5, LOT=6)
        parameter(NL=200)
        common/isomod/d(NL),a(NL),b(NL),rho(NL),
     1      qa(NL),qb(NL),etap(NL),etas(NL), 
     2      frefp(NL), frefs(NL)
        common/shwave/bsh(NL), rhosh(NL), qbsh(NL)
        real bsh, rhosh, qbsh
        common/modlly/mmax
        common/lyrctl/lyrins
        logical lyrins
        if(.not.lyrins)then
            call modcpy(.false.)
            call insert(depth)
        endif
        call srclyr(depth,lmax,dph)
        return
        end

        subroutine velbnd() 
        parameter (LER=0, LIN=5, LOT=6)
c-----
c       get bounds on earth model 
c-----
        parameter(NL=200)
        common/isomod/d(NL),a(NL),b(NL),rho(NL),
     1      qa(NL),qb(NL),etap(NL),etas(NL), 
     2      frefp(NL), frefs(NL)
        common/shwave/bsh(NL), rhosh(NL), qbsh(NL)
        real bsh, rhosh, qbsh
        common/modlly/mmax
        common/bound/vmin,vamin,vamax,vbmin,vbmax
c-----
c       initialize bound search
c-----
        vamin = 1.0e+38
        vbmin = 1.0e+38
        vmin  = 1.0e+38
        vamax = 0.0
        vbmax = 0.0
        write(LOT,2) 
    2   format(' Working model'/
     1      ' ',7x,'d',9x,'a',9x,'b',9x,'rho',6x,'1/qa',6x,'1/qb',
     2      7x,'bsh',4x,'1/qbsh')
    3   format(' ',4f10.3,2f10.6,2f10.3) 
        do 20 i = 1,mmax 
            if(a(i).gt.vamax)vamax=a(i)
            if(b(i).gt.vbmax)vbmax=b(i)
            if(a(i).lt.vamin)vamin=a(i)
            if(b(i).lt.vbmin .and. b(i).gt.0.0)vbmin=b(i)
            if(b(i).gt.0.1)then
                if(b(i).lt.vmin)vmin=b(i)
            else
                if(a(i).lt.vmin)vmin=a(i)
            endif
            if(i.lt.mmax)then
            write(LOT,3)d(i),a(i),b(i),rho(i),qa(i),qb(i),
     1          bsh(i),rhosh(i)
            endif
   20   continue 
    5   format(' ',10x,3f10.3,2f10.6,2f10.3/' ') 
        write(LOT,5)a(mmax),b(mmax),rho(mmax),qa(mmax),qb(mmax) ,
     1          bsh(mmax),rhosh(mmax)
c-----
c     obtain extreme velocity limits
c-----
      return 
      end 

        subroutine aten(om,qa,qb,xka,xkb,alpha,a,b,atna,atnb,iwat,
     2      frefp,frefs)
c-----
c       make velocities complex, using Futterman causality operator
c-----
        real*4 qa,qb,alpha,a,b
        complex*16 om,at,atna,atnb,xka,xkb
        real*8 pi, om1p, om1s, oml, fac, pi2
        common/cntrl/ishank,hnkarg,dstcor,dokjar,docausal
        integer*4 dstcor
        real*4 hnkarg
        logical ishank,dokjar,docausal
        real*8 CDABS
        complex*16 CDLOG
c-----
c       reference frequency is fref hz
c-----
        om1p=6.2831853*frefp
        om1s=6.2831853*frefs
        pi2 = 1.5707963
        pi=3.1415927d+00
        if(dokjar)then
c-----
c       Kjartansson Constant Q, causal Q operator
c       Kjartansson, E. (1979). 
c       Constant Q-wave propagation and attenuation,
c       J. Geophys. Res. 84, 4737-4748.
c-----
            gama = atan(qa)/pi
            gamb = atan(qb)/pi
            if(gama.le.0.0)then
                atna = cmplx(1.0,0.0)
            else
                fac = pi2*gama
                rfac = sin(fac)/cos(fac)
                atna = dcmplx(1.0d+00,0.0d+00)/
     1              (( (om/om1p)**dble(-gama) ) *
     2               dcmplx(1.0d+00,-dble(rfac)))
            endif
            if(b.gt.1.0e-04*a)then
                if(gamb.le.0.0)then
                    atnb = cmplx(1.0,0.0)
                else
                    fac = pi2*gamb
                    rfac = sin(fac)/cos(fac)
                    atnb = dcmplx(1.0d+00,0.0d+00)/
     1              (( (om/om1s)**dble(-gamb) ) *
     2               dcmplx(1.0d+00,-dble(rfac)))
                endif
            endif
        else
c-----
c       Futterman Causal Q
c-----
c           low frequency cutoff is 0.01 hz
c-----
            oml=0.062831853d+00
            atna=dcmplx(1.0d+00,0.0d+00)
            atnb=dcmplx(1.0d+00,0.0d+00)
            if(qa.gt.0.0)then
              at=dcmplx(0.0d+00,0.0d+00)
              if(CDABS(om).gt.oml) at=CDLOG(om/om1p)/pi
              if(CDABS(om).le.oml) then
                fac=dsqrt(oml*oml + dble(alpha*alpha))/oml
              at=CDLOG(dcmplx(dble(oml),-dble(alpha))/(om1p*fac))/pi
              endif
              atna=(1.+dble(qa)*at+dcmplx(0.0d+00,dble(qa/2.)))
            endif
            if(qb.gt.0.0)then
              at=dcmplx(0.0d+00,0.0d+00)
              if(CDABS(om).gt.oml) at=CDLOG(om/om1s)/pi
              if(CDABS(om).le.oml) then
                fac=dsqrt(oml*oml + dble(alpha*alpha))/oml
              at=CDLOG(dcmplx(dble(oml),-dble(alpha))/(om1s*fac))/pi
              endif
               atnb=(1.+dble(qb)*at+dcmplx(0.0d+00,dble(qb/2.)))
            endif
        endif
        if(.not.docausal)then
            atna=(1.+dcmplx(0.0d+00,dble(qa/2.)))
            atnb=(1.+dcmplx(0.0d+00,dble(qb/2.)))
        endif
        xka=om/(dble(a)*atna)
        if(b.le.1.0e-04*a)then
            iwat = 1
            xkb = dcmplx(0.0d+00,0.0d+00)
        else
            iwat = 0
            xkb=om/(dble(b)*atnb)
        endif
        return
        end

        subroutine cmult(e,ca,exa,exe)
        common/lwater/lfluid
        logical lfluid
c-----
c       FORM EC where e(1x5) c(5x5)
        complex*16 ca(5,5)
        real*8 exa,exe,eval
        real *8 xnorm
        complex*16 e(5)
        complex*16 c, ee(5)

        if(lfluid)then
            IUP = 2
        else
            IUP = 5
        endif
        do 1350 i=1,IUP
            c = dcmplx(0.0d+00,0.0d+00)
            do 1349 j=1,IUP
                c=c+ e(j) * ca(j,i)
 1349       continue
            ee(i)=c
 1350   continue
        exe = exe + exa
        call normc(ee,eval,xnorm)
        do 1351 i=1,IUP
            e(i) = ee(i)*xnorm
 1351   continue
        exe = exe + eval
        return
        end

        subroutine rcmult(y,c,exa,exe)
        common/lwater/lfluid
        logical lfluid
c-----
c       FORM YC where y(5x5) c(5x5) RETURN Y
c-----
        complex*16 c(5,5)
        real*8 exa,exe,eval
        real *8 xnorm
        complex*16 y(5,5)
        complex*16 ztmp, ee(5,5)
        if(lfluid)then
            IUP = 2
        else
            IUP = 5
        endif
        do 1350 i=1,IUP
            do 1351 j=1,IUP
                ztmp = dcmplx(0.0d+00,0.0d+00)
                do 1349 k=1,IUP
                    ztmp=ztmp+ y(i,k) * c(k,j)
 1349           continue
                ee(i,j)=ztmp
 1351       continue
 1350   continue
        exe = exe + exa
        call rnormc(ee,eval,xnorm)
        do 1353 j=1,IUP
            do 1352 i=1,IUP
                y(i,j) = ee(i,j)*xnorm
 1352       continue
 1353   continue
        exe = exe + eval
        return
        end

        subroutine dmult(da,aa)
c-----
c       propagator up
c       FORM D = DA
c-----
        complex*16 aa(4,4)
        complex*16 sumd,ea(4,4),da(4,4)
        do 1360 i=1,4
            do 1361 j=1,4
                sumd = dcmplx(0.0d+00,0.0d+00)
                do 1362 jj=1,4
                    sumd=sumd+da(i,jj) * aa(jj,j)
 1362           continue
                ea(i,j)=sumd
 1361       continue
 1360   continue
        do 1363 j=1,4
            do 1364 i=1,4
                da(i,j)=ea(i,j)
 1364       continue
 1363   continue
        return
        end

        subroutine dnka(ca,wvno,wvno2,om2,gam,rho,iwat,w,x,cosp,ex)
        complex*16 ca(5,5)
        complex*16 wvno, wvno2, om2
        real*4 rho
        complex*16 gam
        complex*16 w,x,cosp
        real*8 ex
        common/ ovrflw / a0,cpcq,cpy,cpz,cqw,cqx,xy,xz,wy,wz
        real *8 a0
        complex*16 cpcq,cpy,cpz,cqw,cqx,xy,xz,wy,wz

        complex*16 gam2,gamm1,gamm2,a0c,xz2,wy2,temp
        real*8 dfac
        complex*16 cqww2, cqxw2, g1wy2, gxz2, g2wy2, g2xz2
        complex*16 gg1, a0cgg1
        complex*16 zrho, zrho2
c-----
c        A11     A12     A13    -A13     A15     A16
c        A21     A22     A23    -A23     A25     A15
c        A31     A32     A33    1-A33   -A23    -A13
c       -A31    -A32    1-A33    A33     A23     A13
c        A51     A52    -A32     A32     A22     A12
c        A61     A51    -A31     A31     A21     A11
c-----
c       this will be multipled on the left by the G matrix
c
c       [ G11   G12 G13 -G13    G15 G16 ]
c
c-----
c       or on the right by
c
c       [ H11   H21 H31 -H31    H51 H61  ] ^T
c-----
c       the number of multiplications can be reduced from 36 to 25 
c       if we define a new matrices
c       related to the original matrices by
c-----
c         A11     A12     A13         A15     A16
c         A21     A22     A23         A25     A15
c        2 A31   2 A32   2 A33 -1   -2 A23  -2 A13
c         A51     A52    -A32         A22     A12
c         A61     A51    -A31         A21     A11
c-----
c
c       [ G11   G12  G13    G15 G16  ]
c       [ H11   H21 2 H31   H51 H61  ] ^T
c
c-----
c       this means that some of the original definitions of the 
c       Aij elements must be changed for the
c       definition of the modified 5x5 compount A matrix
c
c       old 6x6                 new 5x5
c       A11 = 1 - A33 + A22     1 - (1/2)(new A33 + 1) + new A2)
c       A53 = -A32              A43 = - (1/2) new A32
c       A63 = -A31              A53 = - (1/2) new A31
c-----
c       To recover the needed elements, 
c          we note that the old G14 = -old G14 = new G13
c-----
c-----
        zrho = dcmplx(dble(rho),0.0d+00)
        if(iwat.eq.1)then
c-----
c       fluid layer
c-----
            do 100 j=1,5
                do 101 i=1,5
                    ca(i,j) = dcmplx(0.0d+00, 0.0d+00)
  101           continue
  100       continue
            if(ex.gt.35.0d+00)then
                dfac = 0.0d+00
            else
                dfac = dexp(-ex)
            endif
            ca(3,3) = dfac
            ca(1,1) = cosp
            ca(5,5) = cosp
            ca(1,2) = - x/(zrho*om2)
            ca(2,1) = - zrho*w*om2
            ca(2,2) = cosp
            ca(4,4) = cosp
            ca(4,5) = ca(1,2)
            ca(5,4) = ca(2,1)
        else
c-----
c       elastic layer
c-----
            zrho2= dcmplx(dble(rho*rho),0.0d+00)
            gam2  = gam*gam
            gamm1 = gam-1.
            gamm2 = gamm1*gamm1
            cqww2 = cqw * wvno2
            cqxw2 = cqx / wvno2
            gg1 = gam*gamm1
            a0c  = dcmplx(2.0d+00,0.0d+00)*
     1          (dcmplx(a0,0.0d+00)-cpcq)
            xz2  = xz/wvno2
            gxz2 = gam*xz2
            g2xz2 = gam2 * xz2
            a0cgg1 = a0c*(gam+gamm1)
            wy2  = wy*wvno2
            g2wy2 = gamm2 * wy2
            g1wy2 = gamm1 * wy2

c-----
c       OK by symmetry
c----
            temp = a0c*gg1 + g2xz2 + g2wy2
            ca(3,3) = a0 + temp + temp
            ca(1,1) = cpcq-temp
            ca(1,2) = (-cqx + wvno2*cpy)/(zrho*om2)
            temp = dcmplx(0.5d+00,0.0d+00)*a0cgg1 + gxz2 + g1wy2
            ca(1,3) = wvno*temp/(zrho*om2)

            ca(1,4) = (-cqww2+cpz)/(zrho*om2)
            temp = wvno2*(a0c + wy2) + xz
            ca(1,5) = -temp/(zrho2*om2*om2)

            ca(2,1) = (-gamm2*cqw + gam2*cpz/wvno2)*zrho*om2
            ca(2,2) = cpcq
            ca(2,3) = (gamm1*cqww2 - gam*cpz)/wvno
            ca(2,4) = -wz
            ca(2,5)=ca(1,4)


            temp =dcmplx(0.5d+00,0.0d+00)*a0cgg1*gg1 
     1          + gam2*gxz2 + gamm2*g1wy2
            ca(3,1) = -dcmplx(2.0d+00,0.0d+00)*temp*zrho*om2/wvno
            ca(3,2) = -wvno*(gam*cqxw2 - gamm1*cpy)*
     1          dcmplx(2.0d+00,0.0d+00)

            ca(3,4)=-dcmplx(2.0d+00,00d+00)*ca(2,3)
            ca(3,5)=-dcmplx(2.0d+00,00d+00)*ca(1,3)

            ca(4,1) = (-gam2*cqxw2 + gamm2*cpy)*zrho*om2
            ca(4,2) = -xy
            ca(4,3)= -ca(3,2)/(dcmplx(2.0d+00,00d+00))
            ca(4,4)=ca(2,2)
            ca(4,5)=ca(1,2)

            temp = gamm2*(a0c*gam2 + g2wy2) + gam2*g2xz2
            ca(5,1) = -zrho2*om2*om2*temp/wvno2
            ca(5,2)=ca(4,1)
            ca(5,3)=-ca(3,1)/(dcmplx(2.0d+00,00d+00))
            ca(5,4)=ca(2,1)
            ca(5,5)=ca(1,1)
        endif
        return
        end

        subroutine hska(aa,w,x,y,z,cosp,cosq,wvno,wvno2,gam,gamm1,rho,
     1      iwat,ex,om2)
        complex*16 wvno,wvno2
        complex*16 aa(4,4),w,x,y,z,cosp,cosq,gam,gamm1
        complex*16 cpq, gcpq, zw2, gzw2, g1w, g1y, gx
        complex*16 zrho
        real*8 ex, dfac
        complex*16 om2
        zrho = dcmplx(dble(rho),0.0d+00)
        if(iwat.eq.1)then
c-----
c       fluid layer
c-----
            do 100 j=1,4
                do 101 i=1,4
                    aa(i,j) = dcmplx(0.0d+00,0.0d+00)
  101           continue
  100       continue
            if(ex.gt.35.0d+00)then
                dfac = 0.0d+00
            else
                dfac = dexp(-ex)
            endif
            aa(1,1) = dfac
            aa(4,4) = dfac
            aa(2,2) = cosp
            aa(3,3) = cosp
            aa(2,3) = -x/(zrho*om2)
            aa(3,2) = - zrho*w*om2
        else
c-----
c       elastic layer
c-----
            cpq = cosp-cosq
            gcpq = gam*cpq
            zw2 = z/wvno2
            gzw2 = gam*zw2
            g1w = gamm1*w
            g1y = gamm1*y
            gx = gam*x
            aa(1,1)=   gcpq + cosq
                aa(1,3)= - wvno * cpq/(zrho*om2)
            aa(1,2)=   wvno*(-g1w+gzw2)
            aa(1,4)=   (wvno2*w-z)/(zrho*om2)
            aa(2,1)=   (gx - wvno2*g1y)/wvno
            aa(2,2)= - gcpq + cosp
            aa(2,3)=   (-x+wvno2*y)/(zrho*om2)
            aa(2,4)= - aa(1,3)
            aa(3,1)=   zrho*om2*gamm1*gcpq/wvno
            aa(3,2)=   zrho*om2*((-gamm1*g1w)+(gam*gzw2))
            aa(3,3)=   aa(2,2)
            aa(3,4)= - aa(1,2)
            aa(4,1)=   zrho*om2*(((gam*gx)/wvno2) - (gamm1*g1y))
            aa(4,2)= - aa(3,1)
            aa(4,3)= - aa(2,1)
            aa(4,4)=   aa(1,1)
        endif
        return
        end

        subroutine hskl(hl,cosql,yl,zl,h,iwat)
        complex*16 hl(2,2)
        complex*16 cosql,yl,zl,h
        integer iwat
c-----
c       cosql = cosh ( nu d )
c       zl    = nu sinh ( nu d )
c       yl    = sinh ( nu d ) / nu
c       h     = rho beta ^ 2
c-----
        if(iwat.eq.0)then   
            hl(1,1) = cosql
            hl(2,1) = zl*h
            hl(1,2) = yl/h
            hl(2,2) = cosql
        else
            hl(1,1) = dcmplx(1.0d+00,0.0d+00)
            hl(1,2) = dcmplx(0.0d+00,0.0d+00)
            hl(2,1) = dcmplx(0.0d+00,0.0d+00)
            hl(2,2) = dcmplx(1.0d+00,0.0d+00)
        endif
        return
        end 

        subroutine lmult(d11,d12,d21,d22,hl,iwat,exel,exb,icomp)
c-----
c       multiply SH matrix by a row vector on left
c-----
        complex*16 d11,d12,d21,d22,hl(2,2),e1,e2
        real*8 exel, exb
        logical icomp
c-----
c       fluid layer do nothing, just return, 
c       equivalent to multiplying by
c       identity matrix
c-----
        if(iwat.eq.0)then
c-----
c       elastic layer
c-----
            e1=d11
            e2=d12
c-----
c           a11 = cosql
c           a12 = yl
c           a21 = zl
c           a22 = cosql
c-----
            d11=e1*hl(1,1) + e2*hl(2,1)
            d12=e1*hl(1,2) + e2*hl(2,2)
            exel = exel + exb
            if(icomp)then
                e1=d21
                e2=d22
                d21=e1*hl(1,1) + e2*hl(2,1)
                d22=e1*hl(1,2) + e2*hl(2,2)
            endif
        endif
        return
        end

        subroutine normc(e,ex,xnorm)
        common/lwater/lfluid
        logical lfluid
        real*8 ex
        real *8 test,testt,x,y,fac,xnorm
        real*8 DREAL
        complex*16 e(*)
        test = 0.0D+00
        testt = 0.0D+00
        if(lfluid)then
            IUP = 2
        else
            IUP = 5
        endif
        do 2 i = 1,IUP
            if(dabs(dreal(e(i))).gt.testt) testt =dabs(dreal(e(i)))
            if(dabs(dimag(e(i))).gt.testt) testt =dabs(dimag(e(i)))
    2   continue
        if(testt.lt.1.0e-30)testt=1.0
        do 1 i =1,IUP
            x=dreal(e(i))/testt
            y=dimag(e(i))/testt
            fac = x*x + y*y
            if(test.lt.fac) test = fac
    1   continue
        test = testt*dsqrt(test)
        if(test.lt.1.0d-30) test=1.0
        xnorm = 1./test
        ex =-dlog(xnorm)
        return
        end

        subroutine rnormc(e,ex,xnorm)
        common/lwater/lfluid
        logical lfluid
        real*8 ex
        real*8 DREAL
        real *8 test,testt,x,y,fac,xnorm
        complex*16 e(5,5)
        test = 0.0D+00
        testt = 0.0D+00
        if(lfluid)then
            IUP = 2
        else
            IUP = 5
        endif
        do 3 j=1,IUP
            do 2 i = 1,IUP
            if(dabs(dreal(e(i,j))).gt.testt) testt =dabs(dreal(e(i,j)))
            if(dabs(dimag(e(i,j))).gt.testt) testt =dabs(dimag(e(i,j)))
    2       continue
    3   continue
        if(testt.lt.1.0e-30)testt=1.0
        do 4 j=1,IUP
            do 1 i =1,IUP
                x=dreal(e(i,j))/testt
                y=dimag(e(i,j))/testt
                fac = x*x + y*y
                if(test.lt.fac) test = fac
    1       continue
    4   continue
        test = testt*dsqrt(test)
        if(test.lt.1.0d-30) test=1.0
        xnorm = 1./test
        ex =-dlog(xnorm)
        return
        end

        subroutine svupdn(s,haa)
        complex*16 s(4), haa(4,4)
        complex*16 t(4), tmp
        do 100 i=1,4
            tmp = dcmplx(0.0d+00,0.0d+00)
            do 101 j=1,4
                tmp = tmp + haa(i,j)*s(j)
  101       continue
            t(i) = tmp
  100   continue
        do 200 i=1,4
            s(i) = t(i)
  200   continue
        return
        end
        
        subroutine shupdn(s,saa)
        complex*16 s(2), saa(2,2)
        complex*16 tmp
            tmp = saa(1,1)*s(1) + saa(1,2)*s(2)
            s(2) = saa(2,1)*s(1) + saa(2,2)*s(2)
            s(1) = tmp
        return
        end

        subroutine evlmat(om,wvno,jbdrys,jbdryh,wvno2,om2)
        parameter(NL=200)
        common/isomod/d(NL),a(NL),b(NL),rho(NL),
     1      qa(NL),qb(NL),etap(NL),etas(NL), 
     2      frefp(NL), frefs(NL)
        common/shwave/bsh(NL), rhosh(NL), qbsh(NL)
        real bsh, rhosh, qbsh
        common/modlly/mmax
        parameter(NSOURCE=100,NRECEIVER=100,NSR=100)
        common/source/depths(NSOURCE),lmaxs(NSOURCE),mdpths
        common/receiv/depthr(NRECEIVER),lmaxr(NRECEIVER),mdpthr
        real*4 depths, depthr
        integer lmaxs, lmaxr, mdpths, mdpthr
        common/damp/alpha,ieqex
        complex*16 om,xka,xkb,ra,rb,gam,gamm1,p,q,w,x,y
        complex*16 cosq,z,cosp
        complex*16  ca(5,5), hl(2,2)
        complex*16 atna,atnb
        complex*16 yl,zl,cosql
        real *8 ex,exa,exb
        complex*16 wvno,wvno2,om2
        complex*16 h
        complex*16 aa(4,4)
        complex*16 zone
c-----
c       matrix components in layers and boundaries saved
c-----
        complex*16 har(NL,4,4), dar(NL,5,5), hsr(2,5), gbr(2,5), 
     1      hal(NL,2,2), hsl(2,2), gbl(2,2)
        real*8 hex(NL), lex(NL), dex(NL), hexw(NL)
        common/hamat/har
        common/damat/dar
        common/hsrfr/hsr
        common/gbrfr/gbr
        common/hlmat/hal
        common/hsrfl/hsl
        common/gbrfl/gbl
        common/hexex/hex
        common/hexexw/hexw
        common/dexex/dex
        common/lexex/lex 
        common/water/iwater(NL),iwats(2),iwatb(2)
        common/updnsm/equalu(NL), equald(NL)
        logical equalu, equald
        logical compute
        complex*16 CDSQRT


        zone  = dcmplx(1.0d+00,0.0d+00)
c-----
c       evaluate the G matrix 
c           gbr(1,x) is for normal stack
c           gbr(2,x) is for inverted stack
c-----
        call evalg(jbdryh,mmax,mmax-1,gbr,gbl,1,wvno,om,om2,wvno2)
        call evalg(jbdrys,1,   2,     gbr,gbl,2,wvno,om,om2,wvno2)
c-----
c       evaluate the H matrix
c           hsr(1,x) is for normal stack
c           hsr(2,x) is for inverted stack
c-----
        call evalh(jbdrys,1,   2,     hsr,hsl,1,wvno,om,om2,wvno2)
        call evalh(jbdryh,mmax,mmax-1,hsr,hsl,2,wvno,om,om2,wvno2)
c-----

c-----
c       matrix multiplication from bottom layer upward
c-----
        do 1340 m = 1,mmax,1
c-----
c       first check to see if computations already done
c-----
            if(equald(m))then
                compute = .false.
            else
                compute = .true.
            endif
            if(compute)then
                call aten(om,qa(m),qb(m),xka,xkb,
     1              alpha,a(m),b(m),atna,atnb,iwat,
     2              frefp(m),frefs(m))
                gam=dble(b(m))*(wvno/om)
                gam = gam * atnb
                gam = dcmplx(2.0d+00,0.0d+00)*gam*gam
                gamm1 = gam - zone
                ra=CDSQRT(wvno2-xka*xka)
                rb=CDSQRT(wvno2-xkb*xkb)
                p=ra*dble(d(m))
                q=rb*dble(d(m))
                call var(p,q,ra,rb,w,x,y,z,cosp,cosq,
     1              ex,exa,exb,yl,zl,cosql,iwat)
                call dnka(ca,wvno, wvno2, om2,gam,rho(m),iwat,
     1              w,x,cosp,ex)
                call hska(aa,w,x,y,z,cosp,cosq,wvno,wvno2,gam,
     1              gamm1,rho(m),
     1              iwat,ex,om2)
                h =(dble(rhosh(m)*bsh(m)*bsh(m))*atnb*atnb)
                call hskl(hl,cosql,yl,zl,h,iwat)
            endif
            iwater(m) = iwat
            call copy5(ca,dar,m,0,dex,exa)
            call copy4(aa,har,m,0,hex,ex)
            call copy2(hl,hal,m,0,lex,exb)
 1340   continue
        return
        end

        subroutine copy5(ca,dar,m,itofrm,dex,exa)
        parameter (NL=200)
        complex*16 dar(NL,5,5)
        complex*16 ca(5,5)
        integer itofrm
        real*8 dex(NL)
        real*8 exa
c-----
c       copy from ca to dar
c-----
        if(itofrm.eq.0)then
            do 100 j=1,5
                do 110 i=1,5
                    dar(m,i,j) = ca(i,j)
  110           continue
                dex(m) = exa
  100       continue
c-----
c       copy from dar to ca
c-----
        else
            do 200 j=1,5
                do 210 i=1,5
                    ca(i,j) = dar(m,i,j)
  210           continue
                exa = dex(m)
  200       continue
        endif
        return
        end

        subroutine copy4(aa,har,m,itofrm,hex,ex)
c-----
c       copy between aa and har arrays for m'th layer
c
c       aa  R   - 4x4 Haskell matrix array
c       har R   - NLx4x4 storage array
c       m   I   - layer index
c       itofrm  I   - 0 copy aa to har, ex to hex
c                 !=0 copy from har to aa, hex to ex
c       hex R   - NL array - storage for exponent
c       ex  R   - exponent value
c-----
        parameter (NL=200)
        complex*16 har(NL,4,4)
        complex*16 aa(4,4)
        integer itofrm
        real*8 hex(NL)
        real*8 ex
c-----
c       copy from aa to har
c-----
        if(itofrm.eq.0)then
            do 100 j=1,4
                do 110 i=1,4
                    har(m,i,j) = aa(i,j)
  110           continue
                hex(m) = ex
  100       continue
c-----
c       copy from har to aa
c-----
        else
            do 200 j=1,4
                do 210 i=1,4
                    aa(i,j) = har(m,i,j)
  210           continue
                ex = hex(m)
  200       continue
        endif
        return
        end

        subroutine copy2(hl,hal,m,itofrm,lex,exb)
        parameter (NL=200)
        complex*16 hal(NL,2,2)
        complex*16 hl(2,2)
        integer itofrm
        real*8 lex(NL)
        real*8 exb
c-----
c       copy from hl to hal
c-----
        if(itofrm.eq.0)then
            do 100 j=1,2
                do 110 i=1,2
                    hal(m,i,j) = hl(i,j)
  110           continue
                lex(m) = exb
  100       continue
c-----
c       copy from hal to hl
c-----
        else
            do 200 j=1,2
                do 210 i=1,2
                    hl(i,j) = hal(m,i,j)
  210           continue
                exb = lex(m)
  200       continue
        endif
        return
        end

        subroutine evalg(jbdry,m,m1,gbr,gbl,in,
     1      wvno,om,om2,wvno2)
        complex*16 gbr(2,5), gbl(2,2)
        parameter(NL=200)
        common/isomod/d(NL),a(NL),b(NL),rho(NL),
     1      qa(NL),qb(NL),etap(NL),etas(NL), 
     2      frefp(NL), frefs(NL)
        common/shwave/bsh(NL), rhosh(NL), qbsh(NL)
        real bsh, rhosh, qbsh
        common/modlly/mmax
        common/damp/alpha,ieqex
        complex*16 om,xka,xkb,ra,rb,gam,gamm1
        complex*16 atna,atnb
        complex*16 wvno,wvno2,om2
        common/lwater/lfluid
        logical lfluid
        complex*16 CDSQRT
c-----
c       set up halfspace conditions
c-----
        call aten(om,qa(m),qb(m),xka,xkb,alpha,a(m),
     1      b(m),atna,atnb,iwat,
     2      frefp(m),frefs(m))
        ra=CDSQRT(wvno2-xka*xka)
        rb=CDSQRT(wvno2-xkb*xkb)
        gam = dble(b(m))*wvno/om
        gam = gam * atnb
        gam = 2.0d+00 * (gam * gam)
        gamm1 = gam - dcmplx(1.0d+00,0.0d+00)
c-----
c       set up halfspace boundary conditions
c
c       jbdry   = -1  RIGID
c           =  0  ELASTIC
c           = +1  FREE SURFACE
c
c-----
        if(jbdry.lt.0)then
c-----
c       RIGID - check properties of layer above
c-----
            if(b(m) .gt. 0.0)then
c-----
c               ELASTIC ABOVE - RIGID
c-----
                gbr(in,1) = dcmplx(1.0d+00,0.0d+00)
                gbr(in,2) = dcmplx(0.0d+00,0.0d+00)
                gbr(in,3) = dcmplx(0.0d+00,0.0d+00)
                gbr(in,4) = dcmplx(0.0d+00,0.0d+00)
                gbr(in,5) = dcmplx(0.0d+00,0.0d+00)
                gbl(in,1) = dcmplx(1.0d+00,0.0d+00)
                gbl(in,2) = dcmplx(0.0d+00,0.0d+00)
            else
c-----
c               FLUID ABOVE - RIGID
c-----
                gbr(in,1) = dcmplx(0.0d+00,0.0d+00)
                gbr(in,2) = dcmplx(0.0d+00,0.0d+00)
                gbr(in,3) = dcmplx(0.0d+00,0.0d+00)
                gbr(in,4) = dcmplx(0.0d+00,0.0d+00)
                gbr(in,5) = dcmplx(0.0d+00,0.0d+00)
                if(lfluid)then
                    gbr(in,1) = dcmplx(1.0d+00,0.0d+00)
                else
                    gbr(in,4) = dcmplx(1.0d+00,0.0d+00)
                endif
c-----
c               (pseudo SH)
c-----
                gbl(in,1) = dcmplx(1.0d+00,0.0d+00)
                gbl(in,2) = dcmplx(0.0d+00,0.0d+00)
            endif
        else if(jbdry.eq.0)then
c-----
c       HALFSPACE
c-----
            if(iwat.eq.0)then
c-----
c               ELASTIC HALFSPACE
c-----
c       multiply G of Herrmann 2001 by - rho^2 om^4 k^2 ra rb
c       should have no effect since it is in both numerator and
c       denominator -- however will not give the correct potential
c       coefficient -- so rethink?
c-----



                gbr(in,1)=dble(rho(m)*rho(m))*om2*om2*
     1              (-gam*gam*ra*rb+wvno2*gamm1*gamm1)
                gbr(in,2)=-dble(rho(m))*(wvno2*ra)*om2
                gbr(in,3)=-dble(rho(m))*(-gam*ra*rb+wvno2*gamm1)
     1              *om2*wvno
                gbr(in,4)=dble(rho(m))*(wvno2*rb)*om2
                gbr(in,5)=wvno2*(wvno2-ra*rb)
        gbr(in,1) = 0.25*gbr(in,1)/(-rho(m)*rho(m)*om2*om2*wvno2*ra*rb)
        gbr(in,2) = 0.25*gbr(in,2)/(-rho(m)*rho(m)*om2*om2*wvno2*ra*rb)
        gbr(in,3) = 0.25*gbr(in,3)/(-rho(m)*rho(m)*om2*om2*wvno2*ra*rb)
        gbr(in,4) = 0.25*gbr(in,4)/(-rho(m)*rho(m)*om2*om2*wvno2*ra*rb)
        gbr(in,5) = 0.25*gbr(in,5)/(-rho(m)*rho(m)*om2*om2*wvno2*ra*rb)

                gbl(in,1) =  dble(rhosh(m))*(dble(bsh(m)*bsh(m))
     1                  *atnb*atnb)*rb
                gbl(in,2) =  dcmplx(1.0d+00,0.0d+00)
            else if(iwat.eq.1)then
c-----
c               FLUID HALFSPACE
c-----
                if(lfluid)then
                    gbr(in,1) = dble(0.5) / ra
                    gbr(in,2) = dcmplx(0.5d+00,0.0d+00)/
     1                  (-dble(rho(m))*om2)
                    gbr(in,3) = dcmplx(0.0d+00,0.0d+00)
                    gbr(in,4) = dcmplx(0.0d+00,0.0d+00)
                    gbr(in,5) = dcmplx(0.0d+00,0.0d+00)
                else
                    gbr(in,1) = dcmplx(0.0d+00,0.0d+00)
                    gbr(in,2) = dcmplx(0.0d+00,0.0d+00)
                    gbr(in,3) = dcmplx(0.0d+00,0.0d+00)
                    gbr(in,4) = dble(0.5*rho(m)*om2) / ra
                    gbr(in,5) = dcmplx(-0.5d+00,0.0d+00)
                endif
                gbl(in,1) = dcmplx(0.0d+00,0.0d+00)
                gbl(in,2) = dcmplx(1.0d+00,0.0d+00)
            endif
        else if(jbdry.eq.1)then
c-----
c       FREE - check properties of layer above
c-----
            if(b(m) .gt. 0.0)then
                gbr(in,1) = dcmplx(0.0d+00,0.0d+00)
                gbr(in,2) = dcmplx(0.0d+00,0.0d+00)
                gbr(in,3) = dcmplx(0.0d+00,0.0d+00)
                gbr(in,4) = dcmplx(0.0d+00,0.0d+00)
                gbr(in,5) = dcmplx(1.0d+00,0.0d+00)
                gbl(in,1) = dcmplx(0.0d+00,0.0d+00)
                gbl(in,2) = dcmplx(1.0d+00,0.0d+00)
                
            else
                gbr(in,1) = dcmplx(0.0d+00,0.0d+00)
                gbr(in,2) = dcmplx(0.0d+00,0.0d+00)
                gbr(in,3) = dcmplx(0.0d+00,0.0d+00)
                gbr(in,4) = dcmplx(0.0d+00,0.0d+00)
                gbr(in,5) = dcmplx(0.0d+00,0.0d+00)
                if(lfluid)then
                    gbr(in,2) = dcmplx(1.0d+00,0.0d+00)
                else
                    gbr(in,5) = dcmplx(1.0d+00,0.0d+00)
                endif
                gbl(in,1) = dcmplx(0.0d+00,0.0d+00)
                gbl(in,2) = dcmplx(1.0d+00,0.0d+00)
            endif
        endif
        return
        end

        subroutine evalh(jbdry,m,m1,hsr,hsl,in,wvno,om,om2,wvno2)
        complex*16 hsr(2,5), hsl(2,2)
        parameter(NL=200)
        common/isomod/d(NL),a(NL),b(NL),rho(NL),
     1      qa(NL),qb(NL),etap(NL),etas(NL), 
     2      frefp(NL), frefs(NL)
        common/shwave/bsh(NL), rhosh(NL), qbsh(NL)
        real bsh, rhosh, qbsh
        common/modlly/mmax
        common/damp/alpha,ieqex
        complex*16 om,xka,xkb,ra,rb,gam,gamm1
        complex*16 atna,atnb
        complex*16 wvno,wvno2,om2
        complex*16 h
        complex*16 CDSQRT
c-----
c       set up surface conditions
c-----
        call aten(om,qa(m),qb(m),xka,xkb,alpha,a(m),
     1      b(m),atna,atnb,iwat,
     2      frefp(m),frefs(m))
        ra=CDSQRT(wvno2-xka*xka)
        rb=CDSQRT(wvno2-xkb*xkb)
        gam = dble(b(m))*wvno/om
        gam = gam * atnb
        gam = 2.0d+00 * (gam * gam)
        gamm1 = gam - dcmplx(1.0d+00,0.0d+00)
        h =(dble(rhosh(m)*bsh(m)*bsh(m))*atnb*atnb)
c-----
c       do top surface condition
c
c           = -1  RIGID
c           =  0  ELASTIC
c           = +1  FREE SURFACE
c-----
        if(iwat.eq.0)then
            if(jbdry.eq.0)then
c-----
c           ELASTIC ABOVE SOLID
c-----
                hsr(in,1) = (wvno2 - ra*rb)
                hsr(in,2) = dble(rho(m))*om2*rb
                hsr(in,3) = 2.0d+00*
     1              wvno*dble(rho(m))*om2*
     1              ( gamm1 - gam*ra*rb/wvno2)
                hsr(in,4) = -dble(rho(m))*om2*ra
                hsr(in,5) = dble(rho(m)*rho(m))*om2*om2
     1              *(gamm1*gamm1 - 
     1              gam*gam*ra*rb/wvno2)
                hsl(in,1) = dcmplx(0.5d+00,0.0d+00)
                hsl(in,2) = 0.5d+00*h*rb
            else if(jbdry.eq.-1)then
c-----
c           RIGID ABOVE SOLID
c-----
                hsr(in,1) = dcmplx(0.0d+00,0.0d+00)
                hsr(in,2) = dcmplx(0.0d+00,0.0d+00)
                hsr(in,3) = dcmplx(0.0d+00,0.0d+00)
                hsr(in,4) = dcmplx(0.0d+00,0.0d+00)
                hsr(in,5) = dcmplx(1.0d+00,0.0d+00)
                hsl(in,1) = dcmplx(0.0d+00,0.00d+00)
                hsl(in,2) = dcmplx(1.0d+00,0.00d+00)
            else if(jbdry.eq.1)then
c-----
c           FREE ABOVE SOLID
c-----
                hsr(in,1) = dcmplx(1.0d+00,0.0d+00)
                hsr(in,2) = dcmplx(0.0d+00,0.0d+00)
                hsr(in,3) = dcmplx(0.0d+00,0.0d+00)
                hsr(in,4) = dcmplx(0.0d+00,0.0d+00)
                hsr(in,5) = dcmplx(0.0d+00,0.0d+00)
                hsl(in,1) = dcmplx(1.0d+00,0.00d+00)
                hsl(in,2) = dcmplx(0.0d+00,0.00d+00)
            endif
        else if(iwat.gt.0)then
            if(jbdry.eq.0)then
c-----
c           HALFSPACE ABOVE FLUID
c-----
                hsr(in,1) = ra
                hsr(in,2) = -dble(rho(m))*om2
                hsr(in,3) = dcmplx(0.0d+00,0.0d+00)
                hsr(in,4) = dcmplx(0.0d+00,0.0d+00)
                hsr(in,5) = dcmplx(0.0d+00,0.0d+00)
                hsl(in,1) = dcmplx(1.0d+00,0.00d+00)
                hsl(in,2) = dcmplx(0.0d+00,0.00d+00)
            else if(jbdry.eq.-1)then
c-----
c           RIGID ABOVE FLUID
c-----
                hsr(in,1) = dcmplx(0.0d+00,0.0d+00)
                hsr(in,2) = dcmplx(1.0d+00,0.0d+00)
                hsr(in,3) = dcmplx(0.0d+00,0.0d+00)
                hsr(in,4) = dcmplx(0.0d+00,0.0d+00)
                hsr(in,5) = dcmplx(0.0d+00,0.0d+00)
                hsl(in,1) = dcmplx(1.0d+00,0.00d+00)
                hsl(in,2) = dcmplx(0.0d+00,0.00d+00)
            else if(jbdry.eq.1)then
c-----
c           FREE ABOVE FLUID
c-----
                hsr(in,1) = dcmplx(1.0d+00,0.0d+00)
                hsr(in,2) = dcmplx(0.0d+00,0.0d+00)
                hsr(in,3) = dcmplx(0.0d+00,0.0d+00)
                hsr(in,4) = dcmplx(0.0d+00,0.0d+00)
                hsr(in,5) = dcmplx(0.0d+00,0.0d+00)
                hsl(in,1) = dcmplx(1.0d+00,0.00d+00)
                hsl(in,2) = dcmplx(0.0d+00,0.00d+00)
            endif
        endif
        return
        end

        subroutine scoef(cd,da,fr,om,exe,exl,exwu,wvno,
     1      fl,d11,d12,exel,exll,llmaxs,llmaxr,wvno2, om2)
c-----
c       llmaxs  I*4 - source layer index in original model
c       llmaxr  I*4 - receiver layer index in original model
c-----
        parameter(NL=200)
        common/isomod/d(NL),a(NL),b(NL),rho(NL),
     1      qa(NL),qb(NL),etap(NL),etas(NL), 
     2      frefp(NL), frefs(NL)
        common/shwave/bsh(NL), rhosh(NL), qbsh(NL)
        real bsh, rhosh, qbsh
        common/modlly/mmax
        common/damp/alpha,ieqex
        complex*16 om, om2
        complex*16  da(4,4),ca(5,5)
        complex*16   cd(5),e(5),fr
        complex*16 d11,d12,e1,e2,e21, e22, fl
        real *8 exe,exl,exel,exll,ex,exa,exb,exwu
        real*8 dzero
        complex*16 wvno2, wvno
        complex*16 zdum
        complex*16 aa(4,4)
        complex*16 cy(5,5)
        complex*16 zero, zone
        complex*16 y11, y12, y21, y22, sd11, sd21
        complex*16 hl(2,2)
c-----
c       matrix components in layers and boundaries saved
c-----
        complex*16 har(NL,4,4), dar(NL,5,5), hsr(2,5), gbr(2,5), 
     1      hal(NL,2,2), hsl(2,2), gbl(2,2)
        real*8 hex(NL), lex(NL), dex(NL), hexw(NL)
        common/hamat/har
        common/damat/dar
        common/hsrfr/hsr
        common/gbrfr/gbr
        common/hlmat/hal
        common/hsrfl/hsl
        common/gbrfl/gbl
        common/hexex/hex
        common/hexexw/hexw
        common/dexex/dex
        common/lexex/lex 
        common/water/iwater(NL),iwats(2),iwatb(2)
        common/updnsm/equalu(NL), equald(NL)
        logical equalu, equald
        logical retrieve
c-----
c       check for decomposition at wavefield at receiver
c-----
        common/ctlrud/rpup,rpdn,rsup,rsdn,dorud
        logical rpup, rpdn, rsup, rsdn, dorud
        common/ctlsud/spup,spdn,ssup,ssdn,dosud
        logical spup, spdn, ssup, ssdn, dosud
        complex*16 haa(4,4), saa(2,2)


c-----
c       this routine computes the layer response. 
c       To simplify the mathematics
c       of the case of receiver above or beneath the source, the
c       layer is internally flipped.
c
c       llmaxs  I*4 - source layer index in original model
c       llmaxr  I*4 - receiver layer index in original model
c       mm  I*4 - pointer to layer in original model
c
c       lmaxs   I*4 - source layer index in current model
c       lmaxr   I*4 - receiver layer index in current model
c       mm  I*4 - pointer to layer in current model
c
c       in  I*4 - 1 use current model (source beneath receiver)
c               - 2 use inverted model (receiver beneath source)
c-----
c       initialize matrices
c-----
        zero = dcmplx(0.0d+00,0.0d+00)
        zone  = dcmplx(1.0d+00,0.0d+00)
        dzero = 0.0d+00
        exe=0.0
        exl=0.0
        exwu = 0.0
        do 2 j = 1,4
            do 3 i = 1,4
                da(i,j)=zero
    3       continue
            da(j,j) = zone
    2   continue
        do 12 j=1,5
            do 13 i=1,5
                cy(i,j) = zero
   13       continue
            cy(j,j) = zone
   12   continue
        y11 = zone
        y12 = zero
        y21 = zero
        y22 = zone
        exel = 0.0
        exll = 0.0
c-----
c     set up halfspace conditions
c-----
        if(llmaxs .ge. llmaxr)then
            in = 1
        else
            in = 2
        endif
        do 100 i=1,5
            e(i) = gbr(in,i)
  100   continue
        e1 = gbl(in,1)
        e2 = gbl(in,2)
        do 11 i=1,5
            cd(i)=e(i)
   11   continue
        d11=e1
        d12=e2
c-----
c       set up limits on the layer stacking
c-----
        if(llmaxs .ge. llmaxr)then
            lmaxs = llmaxs
            lmaxr = llmaxr
        else
            lmaxs = mmax - llmaxs + 2
            lmaxr = mmax - llmaxr + 2
        endif
c-----
c       matrix multiplication from bottom layer upward
c-----
        do 1340 mm = mmax,1,-1
            if(llmaxs .ge. llmaxr)then
                m = mm
                if(equalu(m))then
                    retrieve = .false.
                else
                    retrieve = .true.
                endif
            else
                m = mmax + 1 - mm
                if(equald(m))then
                    retrieve = .false.
                else
                    retrieve = .true.
                endif
            endif
            iwat = iwater(m)
            if(retrieve)then
                call copy5(ca,dar,m,1,dex,exa)
                call copy2(hl,hal,m,1,lex,exb)
                call copy4(aa,har,m,1,hex,ex)
            endif
            call cmult(e,ca,exa,exe)
            call lmult(e1,e2,e21,e22,hl,iwat,exel,exb,.false.)
            if(mm.lt.lmaxr)then
                call rcmult(cy,ca,exa,exl)
                call lmult(y11,y12,y21,y22,hl,iwat,
     1              exll,exb,.true.)
            else if(mm.ge.lmaxr .and. mm.lt.lmaxs) then
                call dmult(da,aa)
                    exl = exl + ex
c-----
c       save values at top of source layer
c-----
            else if(mm.eq.lmaxs) then
                    do 1352 i=1,5
                    cd(i)=e(i)
 1352           continue
                exl=exe
                exll = exel
                d11=e1
                d12=e2
            endif
            if(mm.eq.1)then
                do 200 i=1,5
                    ca(i,1) = hsr(in,i)
  200           continue
                sd11 = hsl(in,1)
                sd21 = hsl(in,2)
                zdum = e1
                e1 = zdum*sd11 + e2*sd21
c               e2 = zdum*sd11 - e2*sd21
                zdum = y11
                y11 = zdum*sd11 + y12*sd21
                zdum = y21
                y21 = zdum*sd11 + y22*sd21
                zdum = dcmplx(0.0,0.0)
                do 1402 i=1,5
                    zdum = zdum + e(i)*ca(i,1)
 1402           continue
                e(1) = zdum
                call rcmult(cy,ca,dzero,exl)
            endif
 1340 continue
c-----
c       get final matrices
c-----
c-SH
        fl=e1
c-P-SV
c       form x(l,m)y(ij|12)
c-----take care of x(i,j) y(1j|12) and replace the da
            aa(1,1) =   zero
            aa(2,1) =   cy(1,1)
            aa(3,1) =   cy(2,1)
            aa(4,1) =   cy(3,1) /(2.0d+00 )
c change sign 0430 1200
            aa(1,2) = - aa(2,1)
            aa(2,2) =   zero
            aa(3,2) = - aa(4,1)
            aa(4,2) =   cy(4,1)
            aa(1,3) = - aa(3,1)
            aa(2,3) = - aa(3,2)
            aa(3,3) =   zero
            aa(4,3) =   cy(5,1)
            aa(1,4) = - aa(4,1)
            aa(2,4) = - aa(4,2)
            aa(3,4) = - aa(4,3)
            aa(4,4) =   zero
            call dmult(da,aa)
        fr=e(1)
c-----
c       if decomposion of wavefield at receiver modify the
c       returned matrices
c-----
        if(dorud)then
            
            call hsupdn(haa,saa,wvno2,om,om2,wvno,llmaxr, 
     1          llmaxr,llmaxs,0)
c-----
c           SH
c           B = SAA B
c-----
            d11 = d11*(saa(1,1)*y11 + saa(1,2)*y21)
            d12 = d12*(saa(1,1)*y11 + saa(1,2)*y21)
c-----
c           SV
c           BT = ST CD X HAAT
c           Form X HAAT
c-----
            call trans4(haa)
            call dmult(da,haa)
        else
            d11 = y11*d11
            d12 = y11*d12
        endif
        return
        end

        subroutine var(p,q,ra,rb,w,x,y,z,cosp,cosq,ex,
     1      exa,exl,yl,zl,cosql,iwat)
c     not modified for negative p,q
c     this assumes that real p and real q have same signs
        common/ovrflw/a0,cpcq,cpy,cpz,cqw,cqx,xy,xz,wy,wz
        complex*16 cpcq,cpy,cpz,cqw,cqx,xy,xz,wy,wz
        complex*16 p,q,ra,rb,w,x,y,z,cosp,cosq
        complex*16 yl,zl,cosql
        complex*16 eqp,eqm,epp,epm,sinp,sinq
        real *8 a0,pr,pi,qr,qi,fac,qmp,ex,exa,exl
c-----
c       form terms such as cos(p), sin(p), cos(q), sin(q)
c       and cos(p)*cos(q)
c
c       Introduce a factorization of exponentials to
c       make a pseudo floating point system
c
c       ex is the exponent in cosp
c       exl is the exponent in cosq for SH
c       exa is the exponent in cosp*cosq
c-----
        real*8 DREAL
      ex=0.0d+00
      exl = 0.0d+00
      a0=0.0d+00
      pr=dreal(p)
      pi=dimag(p)
      epp=dcmplx(dcos(pi),dsin(pi))/2.
      epm=dconjg(epp)
      ex=pr
      fac=0.0
      if(pr.lt.15.) fac=dexp(-2.*pr)
      cosp=epp + fac*epm
      sinp=epp - fac*epm
      w=sinp/ra
      x=ra*sinp
        if(iwat.eq.1)then
c-----
c       fluid layer
c-----
            a0 = 1.0d+00
            exa = ex
            cosq = 1.0d+00
            y = 0.0d+00
            z = 0.0d+00
            cosql = 1.0d+00
            yl = 0.0d+00
            zl = 0.0d+00
            exl = 0.0d+00
        else
c-----
c       elastic layer
c-----
            qr=dreal(q)
            qi=dimag(q)
            eqp=dcmplx(dcos(qi),dsin(qi))/2.
            eqm=dconjg(eqp)
            exl=qr
            fac=0.0d+00
            if(qr.lt.15.) fac=dexp(-2.*qr)
            cosql=eqp + fac*eqm
            sinq=eqp - fac*eqm
            yl=sinq/rb
            zl=rb*sinq
c-----
c       form factors for compound P-SV matrix
c-----
            exa=pr + qr
            cpcq=cosp*cosql
            cpy=cosp*yl
            cpz=cosp*zl
            cqw=cosql*w
            cqx=cosql*x
            xy=x*yl
            xz=x*zl
            wy=w*yl
            wz=w*zl
            fac=0.0d+00
            qmp=qr-pr
            if(qmp.gt.-40.) fac=dexp(qmp)
            cosq=cosql*fac
            y=fac*yl
            z=fac*zl
            fac=0.0d+00
            if(exa.lt.60.) a0=dexp(-exa)
        endif
        return
        end

        subroutine bufini(irdwr,ierr)
c-----
c       initialize buffer pointer
c       irdwr = 0 read initialize
c       irdwr = 1 write initialize
c-----
        implicit none
        integer irdwr, ierr
        integer BUFMAX
        parameter(BUFMAX=8192*64)
        common/buf/iptr,mxbuf,buffer(BUFMAX)
        integer iptr, mxbuf
        real buffer
        iptr = 1
        if(irdwr.eq.0)call getbuf(ierr)
        return
        end

        subroutine buflsh()
c-----
c       flush output buffer
c-----
        implicit none
        integer BUFMAX
        parameter(BUFMAX=8192*64)
        common/buf/iptr,mxbuf,buffer(BUFMAX)
        integer iptr, mxbuf
        real buffer
        integer ipt, i
        ipt = iptr -1
        if(ipt.gt.0)write(2)ipt,(buffer(i),i=1,ipt)
        iptr = 1
        return
        end

        subroutine bufwr(x)
c-----
c       fill buffer with floating point variable x,
c       flush buffer as necessary
c-----
        implicit none
        real x
        integer BUFMAX
        parameter(BUFMAX=8192*64)
        common/buf/iptr,mxbuf,buffer(BUFMAX)
        integer iptr, mxbuf
        real buffer
        buffer(iptr) = x
        iptr = iptr + 1
        if(iptr.gt.BUFMAX)call buflsh()
        return
        end

        subroutine getbuf(ierr)
c-----
c       read in file contents into buffer, taking care not to
c       read beyond the contents of the file
c-----
        implicit none
        integer ierr
        integer BUFMAX
        parameter(BUFMAX=8192*64)
        common/buf/iptr,mxbuf,buffer(BUFMAX)
        integer iptr, mxbuf
        real buffer
        integer i
c-----
c       ierr = 0 successful read
c            = 1 read error
c            = 2 end of file
c-----
        read(2,err=1000,end=2000)mxbuf,(buffer(i),i=1,mxbuf)
        iptr = 1
        ierr = 0
        return
 1000   ierr = 1
        return
 2000   ierr = 2
        return
        end

        subroutine bufrd(x,ierr)
c-----
c       retrieve a value from buffer array, red in new array
c       as necessary
c       iptr is here the next array element to be read
c       it is always >= 1. We do not worry the upper limit
c       since the calling program must worry about this
c       because read always follows a complete write
c-----
        implicit none
        real x
        integer ierr
        integer BUFMAX
        parameter(BUFMAX=8192*64)
        common/buf/iptr,mxbuf,buffer(BUFMAX)
        integer iptr, mxbuf
        real buffer
c-----
c       only yank in new data if actually required
c-----
        if(iptr.gt.mxbuf)call getbuf(ierr)
        x = buffer(iptr)
        iptr = iptr + 1
        return
        end

        subroutine werror(ostr)
c-----
c       output error message and terminate program
c-----
        parameter(LER=0, LIN=5, LOT=6)
        character ostr*(*)
        write(LER,*)'PROGRAM TERMINATION'
        write(LER,*)ostr
        stop
        end

        subroutine modcpy(totmp) 
        logical totmp
c-----
c       copy model to temporary array
c-----
        parameter(NL=200)
        common/isomod/d(NL),a(NL),b(NL),rho(NL),
     1      qa(NL),qb(NL),etap(NL),etas(NL), 
     2      frefp(NL), frefs(NL)
        common/shwave/bsh(NL), rhosh(NL), qbsh(NL)
        real bsh, rhosh, qbsh
        common/modlly/mmax
        common/modelt/dt(NL),at(NL),bt(NL),rhot(NL),
     1      mmaxt,qat(NL),qbt(NL),etapt(NL),etast(NL),
     1      frefpt(NL),frefst(NL),bsht(NL),rhosht(NL),qbsht(NL)
c-----
c       copy to temporary array
c-----
        if(totmp)then
            do 20 i = 1,mmax 
                dt(i) = d(i)
                at(i) = a(i)
                bt(i) = b(i)
                rhot(i) = rho(i)
                qat(i) = qa(i)
                qbt(i) = qb(i)
                etapt(i) = etap(i)
                etast(i) = etas(i)
                frefpt(i) = frefp(i)
                frefst(i) = frefs(i)
                bsht(i) = bsh(i)
                rhosht(i) = rhosh(i)
                qbsht(i) = qbsh(i)
   20       continue 
            mmaxt = mmax
        else
            do 30 i = 1,mmaxt 
                d(i) = dt(i)
                a(i) = at(i)
                b(i) = bt(i)
                rho(i) = rhot(i)
                qa(i) = qat(i)
                qb(i) = qbt(i)
                etap(i) = etapt(i)
                etas(i) = etast(i)
                frefp(i) = frefpt(i)
                frefs(i) = frefst(i)
                bsh(i) = bsht(i)
                rhosh(i) = rhosht(i)
                qbsh(i) = qbsht(i)
   30       continue 
            mmax = mmaxt
        endif
        return 
        end 

        subroutine chkmod()
        parameter(NL=200)
        common/isomod/d(NL),a(NL),b(NL),rho(NL),
     1      qa(NL),qb(NL),etap(NL),etas(NL), 
     2      frefp(NL), frefs(NL)
        common/shwave/bsh(NL), rhosh(NL), qbsh(NL)
        real bsh, rhosh, qbsh
        common/modlly/mmax
        common/jout/jsrc(21) , jbdrys, jbdryh
        common/lwater/lfluid
        logical lfluid
c-----
c       check model for inconsistencies
c-----
c-----
c       Model cannot consist entirely of water layers
c       Also determine first solid layer from top
c-----
        iw = 0  
        isoldd = 0
        do 100 i=1,mmax
            if(b(i).eq.0.0)then
                iw = iw + 1
            else
                if(isoldd .eq.0)isoldd=i
            endif
  100   continue
        if(iw .eq. mmax)then
            lfluid = .true.
C           call werror('MODEL CONSISTS ONLY OF LIQUID LAYERS')
        else
            lfluid = .false.
        endif
c-----
c       Determine first solid layer from bottom
c-----
        iw = 0  
        isoldu = 0
        do 101 i=mmax,1,-1
            if(b(i).eq.0.0)then
                iw = iw + 1
            else
                if(isoldu .eq.0)isoldu=i
            endif
  101   continue
c-----
c       Check for interior water layer
c-----
        if(iw.gt.0 .and. .not. lfluid)then
            do 102 i=isoldd,isoldu
                if(b(i).eq.0.0)then
                call werror('MODEL HAS INTERIOR  FLUID LAYERS')
                endif
  102       continue
        endif
c-----
c       If boundary condition is rigid, and the adjacent layer is
c       fluid, terminate 
c-----
C       if(b(1).le.1.0e-04 .and. jbdrys.eq.-1 .and. lfluid)then
C           call werror('TOP LAYER IS FLUID AND RIGID BOUNDARY')
C       endif
C       if(b(mmax).le.1.0e-04 .and. jbdryh.eq.-1 .and. lfluid)then
C           call werror('BOTTOM LAYER IS FLUID AND RIGID BOUNDARY')
C       endif
        return
        end

        subroutine hsupdn(aa,saa,wvno2,om,om2,wvno,m,
     1      lmaxr,lmaxs,isr)
c-----
c       aa  C*16    P-SV matrix
c       saa C*16    SH matrix
c       wvno2   C*16    wavenumber squared
c       om  C*16    complex angular frequency
c       wvno    C*16    wavenumber 
c       m   I   layer index for matrix computation
c               (perform wavefield separation in this layer)
c       lmaxr   I   index of receiver layer
c       lmaxs   I   index of source layer
c               (used for definition of up/down)
c       isr I   0 - compete for receiver layer
c               1 - compute for source
c-----
        complex*16 aa(4,4), saa(2,2), wvno2, om, wvno,om2
        parameter(NL=200)
        common/isomod/d(NL),a(NL),b(NL),rho(NL),
     1      qa(NL),qb(NL),etap(NL),etas(NL), 
     2      frefp(NL), frefs(NL)
        common/shwave/bsh(NL), rhosh(NL), qbsh(NL)
        real bsh, rhosh, qbsh
        common/modlly/mmax
        common/damp/alpha,ieqex
        common/ctlrud/rpup,rpdn,rsup,rsdn,dorud
        logical rpup, rpdn, rsup, rsdn, dorud
        common/ctlsud/spup,spdn,ssup,ssdn,dosud
        logical spup, spdn, ssup, ssdn, dosud
        complex*16 h, gam, gamm1, ra, rb, atna, atnb, xka, xkb
        complex*16 zero, zone 
        logical pup, pdn, sup, sdn, doud
        real*8 drho
        complex*16 CDSQRT

c-----
c       define necessary constants
c-----
        zero = dcmplx(0.0d+00,0.0d+00)
        zone = dcmplx(1.0d+00,0.0d+00)
        drho = dble(rho(m))
c-----
c       if receiver is beneath source, it is necessary to redefine
c       local concept of up/down
c-----
        if(isr.eq.0)then
            if(lmaxs .gt. lmaxr)then
                pup = rpup
                pdn = rpdn
                sup = rsup
                sdn = rsdn
            else
                pup = rpdn
                pdn = rpup
                sup = rsdn
                sdn = rsup
            endif
            doud = dorud
        else
            if(lmaxs .gt. lmaxr)then
                pup = spup
                pdn = spdn
                sup = ssup
                sdn = ssdn
            else
                pup = spdn
                pdn = spup
                sup = ssdn
                sdn = ssup
            endif
            doud = dosud
        endif
        call aten(om,qa(m),qb(m),xka,xkb,
     1      alpha,a(m),b(m),atna,atnb,iwat,
     2      frefp(m),frefs(m))
        h =(dble(rhosh(m)*bsh(m)*bsh(m))*atnb*atnb)
        gam=dble(b(m))*(wvno/om)
        gam = gam * atnb
        gam = dcmplx(2.0d+00,0.0d+00)*gam*gam
        gamm1 = gam - zone
        ra=CDSQRT(wvno2-xka*xka)
        rb=CDSQRT(wvno2-xkb*xkb)
        do 100 j=1,4
            do 101 i = 1,4
                aa(i,j) = zero
  101       continue
  100   continue
        saa(1,1) = zero
        saa(1,2) = zero
        saa(2,1) = zero
        saa(2,2) = zero
c-----
c       now test wave field conditions
c-----
        if(pup .and. pdn .and. sup .and. sdn)then
            aa(1,1)  = zone
            aa(2,2)  = zone
            aa(3,3)  = zone
            aa(4,4)  = zone
            saa(1,1) = zone
            saa(2,2) = zone
        else
c-----
c           water layer
c-----
            if(iwat.ne.0)then
c-----
c               coefficients of exp(nua*h)
c-----
                if(pup)then
                    aa(2,2) = aa(2,2) + 0.5d+00*zone
                    aa(2,3) = aa(2,3) - 
     1                  ra/(dble(2.0*rho(m))*om2)
                    aa(3,2) = aa(3,2) - 
     1                  drho*om2/(2.0d+00*ra)
                    aa(3,3) = aa(3,3) + 0.5d+00*zone
                endif
c-----
c               coefficients of exp(-nua*h)
c-----
                if(pdn)then
                    aa(2,2) = aa(2,2) + 0.5d+00*zone
                    aa(2,3) = aa(2,3) + 
     1                  ra/(dble(2.0*rho(m))*om2)
                    aa(3,2) = aa(3,2) + 
     1                  drho*om2/(2.0d+00*ra)
                    aa(3,3) = aa(3,3) + 0.5d+00*zone
                endif

c-----
c           elastic layer
c-----
            else
c-----
c               coefficients of exp(nua*h)
c-----
                if(pup)then
                    aa(1,1) = aa(1,1) + gam
                    aa(1,2) = aa(1,2) - wvno*gamm1/ra
                    aa(1,3) = aa(1,3) - wvno/(drho*om2)
                    aa(1,4) = aa(1,4) + 
     1                  wvno2/(drho*ra*om2)
                    aa(2,1) = aa(2,1) + gam*ra/wvno
                    aa(2,2) = aa(2,2) - gamm1
                    aa(2,3) = aa(2,3) - ra/(drho*om2)
                    aa(3,1) = aa(3,1) + 
     1                  drho*gam*gamm1*om2/wvno
                    aa(3,2) = aa(3,2) - drho*om2*
     1                  gamm1*gamm1/ra
                    aa(4,1) = aa(4,1) + drho*om2*
     1                  gam*gam*ra/wvno2
                endif
c-----
c               coefficients of exp(-nua*h)
c-----
                if(pdn)then
                    aa(1,1) = aa(1,1) + gam
                    aa(1,2) = aa(1,2) + wvno*gamm1/ra
                    aa(1,3) = aa(1,3) - wvno/(drho*om2)
                    aa(1,4) = aa(1,4) - 
     1                  wvno2/(drho*ra*om2)
                    aa(2,1) = aa(2,1) - gam*ra/wvno
                    aa(2,2) = aa(2,2) - gamm1
                    aa(2,3) = aa(2,3) + ra/(drho*om2)
                    aa(3,1) = aa(3,1) + 
     1                  drho*gam*gamm1*om2/wvno
                    aa(3,2) = aa(3,2) + drho*om2*
     1                  gamm1*gamm1/ra
                    aa(4,1) = aa(4,1) - drho*om2*
     1                  gam*gam*ra/wvno2
                endif
c-----
c               coefficients of exp(nub*h)
c-----
                if(sup)then
                    aa(1,1) = aa(1,1) - gamm1
                    aa(1,2) = aa(1,2) + gam*rb/wvno
                    aa(1,3) = aa(1,3) + wvno/(drho*om2)
                    aa(1,4) = aa(1,4) - rb/(drho*om2)
                    aa(2,1) = aa(2,1) - wvno*gamm1/rb
                    aa(2,2) = aa(2,2) + gam
                    aa(2,3) = aa(2,3) + 
     1                  wvno2/(drho*rb*om2)
                    aa(3,1) = aa(3,1) - 
     1                  drho*gam*gamm1*om2/wvno
                    aa(3,2) = aa(3,2) + 
     1                  drho*om2*gam*gam*rb/wvno2
                    aa(4,1) = aa(4,1) - drho*om2*
     1                  gamm1*gamm1/rb
                    saa(1,1) = saa(1,1) + zone
                    saa(1,2) = saa(1,2) + zone/(h*rb)
                    saa(2,1) = saa(2,1) + (h*rb)
                    saa(2,2) = saa(2,2) + zone
                endif
c-----
c               coefficients of exp(-nub*h)
c-----
                if(sdn)then
                    aa(1,1) = aa(1,1) - gamm1
                    aa(1,2) = aa(1,2) - gam*rb/wvno
                    aa(1,3) = aa(1,3) + wvno/(drho*om2)
                    aa(1,4) = aa(1,4) + rb/(drho*om2)
                    aa(2,1) = aa(2,1) + wvno*gamm1/rb
                    aa(2,2) = aa(2,2) + gam
                    aa(2,3) = aa(2,3) - 
     1                  wvno2/(drho*rb*om2)
                    aa(3,1) = aa(3,1) - 
     1                  drho*gam*gamm1*om2/wvno
                    aa(3,2) = aa(3,2) - 
     1                  drho*om2*gam*gam*rb/wvno2
                    aa(4,1) = aa(4,1) + drho*om2*
     1                  gamm1*gamm1/rb
                    saa(1,1) = saa(1,1) + zone
                    saa(1,2) = saa(1,2) - zone/(h*rb)
                    saa(2,1) = saa(2,1) - (h*rb)
                    saa(2,2) = saa(2,2) + zone
                endif
                aa(2,4) = -aa(1,3)
                aa(3,3) =  aa(2,2)
                aa(3,4) = -aa(1,2)
                aa(4,2) = -aa(3,1)
                aa(4,3) = -aa(2,1)
                aa(4,4) =  aa(1,1)
c-----
c       special case clean up
c-----
                if(pup.and.sup .or. pdn.and.sdn)then
                    aa(1,1) = zone
                    aa(2,2) = zone
                    aa(3,3) = zone
                    aa(4,4) = zone
                    aa(1,3) = zero
                    aa(2,4) = zero
                    aa(3,1) = zero
                    aa(4,2) = zero
                endif
                do 200 j=1,4
                    do 201 i = 1,4
                        aa(i,j) = aa(i,j)/dble(2.0)
  201               continue
  200           continue
                saa(1,1) = saa(1,1) / dble(2.0)
                saa(1,2) = saa(1,2) / dble(2.0)
                saa(2,1) = saa(2,1) / dble(2.0)
                saa(2,2) = saa(2,2) / dble(2.0)
            endif
        endif
        return
        end

        subroutine trans4(a)
c-----
c       from a transpose 
c-----
        complex*16 a(4,4), zdum
        do 100 i=1,4
            do 101 j=i,4
                zdum = a(i,j)
                a(i,j) = a(j,i)
                a(j,i) = zdum
  101       continue
  100   continue
        return
        end

        subroutine insert(dph)
        implicit none
        real dph
        integer LER, LIN, LOT
        parameter (LER=0, LIN=5, LOT=6)
        integer NL
        parameter(NL=200)
        common/isomod/d(NL),a(NL),b(NL),rho(NL),
     1      qa(NL),qb(NL),etap(NL),etas(NL),
     2      frefp(NL), frefs(NL)
        real d, a, b, rho, qa, qb, etap, etas, frefp, frefs
        common/modlly/mmax
        integer mmax
        common/shwave/bsh(NL), rhosh(NL), qbsh(NL)
        real bsh, rhosh, qbsh

        real dp, dphh, hsave, dep
        integer m, ls
c-----
c       Insert a depth point into the model by splitting a layer
c       so that the point appears at the top boundary of the layer
c       dph = depth of interest
c-----
c       determine the layer in which the depth dph lies.
c       if necessary, adjust  layer thickness at the base
c-----
c       Here determine layer corresponding to specific depth dph
c       If the bottom layer is not thick enough, extend it
c
c       dep - depth to bottom of layer
c       dphh    - height of specific depth above bottom of the layer
c-----
        if(dph.le.0)then
            d(1) = d(1) - dph
            return
        else if(dph.ge.0)then
            dep = 0.0 
            dp = 0.0 
            dphh = -1.0
            do 100 m = 1,mmax 
                dp = dp + d(m) 
                dphh = dp - dph 
                if(m.eq.mmax)then
                    if(d(mmax).le.0.0 .or. dphh.lt.0.0)then
                        d(mmax) = (dph - dp)
                    endif
                endif
                dep = dep + d(m) 
                dphh = dep - dph 
                ls = m 
                if(dphh.ge.0.0) go to 101 
  100       continue 
  101       continue 
        endif
c-----
c       In the current model, the depth point is in the ls layer
c       with a distance dphh to the bottom of the layer
c
c       Do not create unnecessary layers, e.g., 
c           at surface and internally
c       However do put in a zero thickness layer 
c           at the base if necessary
c-----
        if(dphh .eq. 0.0 .and. ls.ne.mmax)then
            return
        else
c-----
c           adjust layering
c-----
             do 102 m = mmax,ls,-1
                d(m+1) = d(m)
                a(m+1) = a(m)
                b(m+1) = b(m)
                rho(m+1) = rho(m)
                qa(m+1) = qa(m)
                qb(m+1) = qb(m)
                etap(m+1) = etap(m)
                etas(m+1) = etas(m)
                frefp(m+1) = frefp(m)
                frefs(m+1) = frefs(m)
                bsh(m+1) = bsh(m)
                qbsh(m+1) = qbsh(m)
                rhosh(m+1) = rhosh(m)
  102       continue
            hsave = d(ls)
            d(ls) = hsave - dphh
            d(ls+1) = dphh
            ls = ls + 1
            mmax = mmax + 1
            if(d(mmax).lt.0.0)d(mmax)=0.0
        endif
        return
        end

        subroutine frstar(r,hs,hr,mname,ipsvsh,time,pvel,svel,den,
     1      vsa, vsb, vsr, rayp, geom, tstar, dolock, dogeom)
c-----
c       r   R   Epicentral distance
c       hs  R   Source depth
c       hr  R   Receiver depth
c       mname   Ch*(*)  Name of model file
c       ipsvsh  I*4 1 - get P time
c               2 - get SV time
c               3 - get SH time
c               4 - get pP time
c               5 - get sP time
c       time    R   First arrival time
c       pvel    R   Velocity of P wave at receiver
c       svel    R   Velocity of S wave at receiver
c       den     R   Density at receiver
c       vsa R   P-wave velocity at source
c       vsb R   S-wave velocity at source
c       vsr R   Density at source
c       rayp R   Ray parameter in sec/km
c       geom R   geometrical spreading factor
c       tstar R   geometrical spreading factor
c       dolock L .true. apply locked mode which means to ignore the
c                bottom layer
c       dogeom L .true. compute geometrical spreading. Only do this for
c                teleseisms
c-----
        real r, hs, hr, time, pvel, svel, vsa, vsb, vsr
        real rayp, geom, tstar
	logical dolock, dogeom
        character mname*(*)
        integer ipsvsh
c-----
c-----
c       internal variables
c-----
        real depths, depthr
        real dphs, dphr, dphref
        integer lmaxs, lmaxr, lmaxref
        real tm, rp(2),ts
        real dpdx, deginrad, sinis, sinir, cosir, cosis, sindeg
        real vs, vr, rs, rr

        
        common/earth/radius
        real radius

        common/depref/refdep
        real refdep
c-----
c       compute the travel time
c-----
        call fstarr(r,time,lmaxs, lmaxr, lmaxref,
     1      hs, hr, ipsvsh,iflsph, rayp,
     2      tstar, dolock,
     3      mname, varec, vbrec, rhorec,
     4      vasrc, vbsrc, rhosrc)

        svel = vbrec
        pvel = varec
        den  = rhorec
        vsa  = vasrc
        vsb  = vbsrc
        vsr  = rhosrc
c-----
C       compute the geometrical spreading
C
C       since a flat earth is always used, we use the flat layered
C       geometrical spreading from Officer
C       The geometrical spreading is dimensionless and gives the decrease in amplitude from
C       a distance of 1 km from the source to the receiver
C                        2                            2
C            ( rhos vs  a sin Is Vs                  d T      )
C       sqrt |  -------------------------------     -----     |
C            |                                         2      |
C            ( rhor vr sin DEG  cos Ir Rs Cos Is     dx       )
C
C       where p (sec/km) = dT/dx
C       a = radius of sphere about source - we use 1.0 km
C       Is= incident angle at source
C       Ir= incident angle at receiver
C       Rs= distance from center of Earth to source
C       Rr= distance from center of Earth to receiver
C       DEG=epicental distance in degrees
C       rhos and vs are the density and wave velocity at the source depth
c       rhor and vr are the density and wave velocity at the receiver depth
c
c       To get the dp/dx, we determine p at different distances, and then form
c       an interpolating polynomial
c
        if(dogeom)then
              call fstarr(r-500,tm,lmaxs, lmaxr, lmaxref,
     1            hs, hr, ipsvsh,iflsph, rp(1),
     2            ts, dolock,
     3            mname, varec, vbrec, rhorec,
     4            vasrc, vbsrc, rhosrc)

              call fstarr(r+500,tm,lmaxs, lmaxr, lmaxref,
     1            hs, hr, ipsvsh,iflsph, rp(2),
     2            ts, dolock,
     3            mname, varec, vbrec, rhorec,
     4            vasrc, vbsrc, rhosrc)


              dpdx = abs(rp(1) - rp(2))/(500.0 - ( - 500.0))
              deginrad = r/radius
              sindeg = sin(deginrad)
  
              if(ipsvsh.eq.1)then
                  vs = vsa
                  vr = pvel
                  rs = vsr
                  rr = den
              else if(ipsvsh.eq.2)then
                  vs = vsb
                  vr = svel
                  rs = vsr
                  rr = den
              else if(ipsvsh.eq.3)then
                  vs = vsb
                  vr = svel
                  rs = vsr
                  rr = den
              else if(ipsvsh.eq.4)then
                  vs = vsa
                  vr = pvel
                  rs = vsr
                  rr = den
              else if(ipsvsh.eq.5)then
                  vs = vsb
                  vr = pvel
                  rs = vsr
                  rr = den
              endif
              sinis = rayp*vs
              cosis = sqrt(1.0-sinis*sinis)
              sinir = rayp*vr
              cosir = sqrt(1.0-sinir*sinir)

              fac = (rs*vs*sinis*vs*dpdx)/
     1           (rr*vr*sindeg*cosir*(radius-hs)*cosis)
              geom = sqrt(abs(fac))
      else
c-----
c     default to have a defined return value
c-----
              geom = 1.0
      endif
              

c-----
        return
        end

        subroutine fstarr(dist,tfirst,lmaxs,lmaxr,lmaxref,
     1      hs,hr,ipsvsh,iflsph, rayp,
     2      tstar, dolock,
     3      mname, varec, vbrec, rhorec,
     4      vasrc, vbsrc, rhosrc)
c-----
c       given a distance, the source depth, receiver depth,
c       get time of first arrival of P
c-----
c       dist    R   - distance
c       tfirst  R   - first arrival time
c       mmax    I*4 - number of layers in model
c       lmaxs   I*4 - layer index for source
c       lmaxr   I*4 - layer index for receiver
c       lmaxref I*4 - layer index for reference depth,
c                     used only for pP and sS
c       hs      R   - depth of source
c       hs      R   - depth of receiver
c       ipsvsh  I*4 1 - get P time
c               2 - get SV time
c               3 - get SH time
c               4 - get pP time
c               5 - get sP time
c       iflsph  I*4 - 0 flat earth model
c                 1 spherical earth model
c       rayp    R   - ray parameter in sec/km
c       tstar   R   T* operator
c       dolock L .true. apply locked mode which means to ignore the
c                bottom layer
c       mname   Ch* - name of the velocity model
c       varec   R - P velocity at receiver (untransformed)
c       vbrec   R - S velocity at receiver (untransformed)
c       rhorec  R - Density at receiver (untransformed)
c       vasrc   R - P velocity at source (untransformed)
c       vbsrc   R - S velocity at source (untransformed)
c       rhosrc  R - Density at source (untransformed)
c-----
c       since this routine is to be used for omega-k,
c       we will approximate the direct arrival
c
c       18 JAN 2008 - everything is straightforward. The addition of
c          the request for pP and sP changes the logic in that
c          the direct arrival is ignored, and that the upgoing refraction 
c          from the source is ignored. We handle this by just setting
c          a very large tfirst before trying to do the modified 
c          downward path refraction to avoid another level of
c          if/then/else/endif
c       24 MAR 2008 - modified to place the model read into this
c          routine instead of in frstar
c-----
        real dist, tfirst, dphs, dphr, hs, hr, depths, depthr
        real rayp, tstar
        real varec, vbrec, rhorec
        real vasrc, vbsrc, rhosrc
        logical dolock
        integer lmaxs, lmaxr, lmaxref
        character mname*(*)

        integer NL
        parameter (NL=200)
        common/isomod/d(NL),a(NL),b(NL),rho(NL),
     1      qa(NL),qb(NL),etap(NL),etas(NL), 
     2      frefp(NL), frefs(NL)
        common/modlly/mmmax
        integer mmmax
        common/depref/refdep
        real refdep
        common/shwave/bsh(NL), rhosh(NL), qbsh(NL)
        real bsh, rhosh, qbsh

        integer mmax

        integer iunit, iiso, iflsph, idimen, icnvel, ierr
        character title*80

        real v(NL), h(NL), qi(NL)

        real*8 c, s, t, x, p, tint, dxdp, vel, pnew, pupper
        real*8 ts
        real*8 sumx, sumt
        logical ext

        real tds, tdr
        common/earth/radius
        real radius

c-----
c       first read in the model and determine the medium parameters at the
c       source and receiver depths
c-----
c       get the earth model
c-----
        inquire(file=mname,exist=ext)
        if(.not. ext) call usage('Model file does not exist')
        l = lgstr(mname)

                call getmod(1,mname,mmax,title,iunit,iiso,iflsph,
     1          idimen,icnvel,ierr,.false.)
        mmmax = mmax
        if(ierr .lt. 0)return
                call adomod()
c-----
c       insert the source and receiver depths into the model
c       placing the source and receiver on a layer boundary
c-----
        call insert(hs+refdep)
        call insert(hr+refdep)
        call insert(   refdep)

c-----
c       get the layer in which the source lies
c-----
        call srclyr(hs+refdep, lmaxs, dphs)
        call srclyr(hr+refdep, lmaxr, dphr)
        call srclyr(   refdep, lmaxref, dphref)
c-----
c       get the medium parameters at the source and reciever depths
c-----
        varec = a(lmaxr)
        vbrec = b(lmaxr)
        rhorec = rho(lmaxr)
        vasrc = a(lmaxs)
        vbsrc = b(lmaxs)
        rhosrc = rho(lmaxs)
c-----
c       prepare for the computations
c-----
        depths = hs + refdep
        depthr = hr + refdep

c-----
c       set up default
c-----
        tfirst = 1.0e+30
c-----
c       special case for locked mode
c-----
        if(dolock)then
            mmax = mmmax -1
        else
            mmax = mmmax
        endif

c-----
c       get specifics about upward and downward distances
c       with a layer. We need his to define ray paths
c       We will also use the fact that the source/receiver are
c       on layer boundaries
c
c       lmn = layer number of shallowest of source/receiver
c       lmx = layer number of deepest    of source/receiver
c-----
        lmn = min(lmaxs,lmaxr)
        lmx = max(lmaxs,lmaxr)

c-----
c       perform spherical -> flat earth model transformation
c-----
        if(iflsph.ne.0)then
            call adosph()
            tds = radius*alog(radius/(radius-hs))
            tdr = radius*alog(radius/(radius-hr))
        else
            tds = depths
            tdr = depthr
        endif
c-----
c       now fill in velocity array according to desired first arrival
c       for SH there can be no water layer
c       for SV can be a water layer
c       Also define the Q for the T* analysis. Note we define
c        eventually q = 1/Q based on whether the given Q > or < 1
c-----
        do 100 i=1,mmax
            if(ipsvsh.eq.1)then
                v(i) = a(i)
                qi(i) = qa(i)
            else if(ipsvsh.eq.2)then
                v(i) = b(i)
                qi(i) = qb(i)
                if(b(i).le.0.001)then
                    v(i) = a(i)
                    qi(i) = qa(i)
                endif
            else if(ipsvsh.eq.3)then
                v(i) = bsh(i)
                qi(i) = qbsh(i)
            else if(ipsvsh.eq.4)then
                v(i) = a(i)
                qi(i) = qa(i)
            else if(ipsvsh.eq.5)then
                v(i) = a(i)
                qi(i) = qa(i)
            endif
            if(qi(i) .gt. 1.0)then
                qi(i) = 1.0 / qi(i)
            endif
            h(i) = d(i)
 100    continue
c-----
c       For the computations we look at four cases
c       1) direct path between source and receiver 
c          a) source and receiver in the same layer
c          b) source and receiver in different layers
c       2) refracted arrivals       
c          a) path is downward from source and then up to
c             receiver
c          b) path is upward from the source and then down to
c             receiver
c          This recognized the possibility that velocity does
c          not increase uniformly with depth
c-----
                    
c-----
c       direct arrival source/receiver at same layer
c-----
        if(v(lmaxs).eq.0.0)return
        if(v(lmaxr).eq.0.0)return
        if(lmaxs .eq. lmaxr)then
            tfirst = sqrt(dist**2 + abs(tds - tdr)**2)/
     1          v(lmaxs)
            rayp = (dist/sqrt(dist**2 + abs(tds - tdr)**2))/
     1          v(lmaxs)
            tstar = tfirst*qi(lmaxs)
        else
c-----
c       direct arrival source/receiver in different layers
c-----
c       Newton Iteration for direct arrival source/receiver at
c           different depths
c           
c           x = SUM h  tan theta
c                    i          i
c
c           t = SUM h  / v  cos theta
c                    i    i          i
c                                                          2 2
c       where sin theta  = p V  , cos theta  = sqrt ( 1 - p V )
c                      i      i                              i
c       and p is the ray parameter bounded by [0, 1/V  ] where V
c                                                    sr         sr
c       is the wave velocity at the starting point of the ray. 
c       Since the ray must also reach the receiver, we consider
c       that possibility too. The upper bound is MIN ( 1/Vs, 1/Vr)
c       Also we test for a real ray path, between source and receiver
c
c       Because source/receiver at top of a layer boundary, we have
c
c           -----------X----------
c           h(lmn)      \
c           ----------------------
c                      ....
c           ----------------------
c           h(lmx-1)        \
c                            \
c           ------------------X---
c            
c-----
            ps = 1.0/v(lmaxs)
            pr = 1.0/v(lmaxr)
            if(ps.lt.pr)then
                pupper = ps
            else
                pupper = pr
            endif
            do 1000 l=lmn,lmx
                if(v(l).eq.0.0)return
                p = 1.0/v(l)
                if(p.lt.pupper)pupper = p
 1000       continue
            p = 0.5d+00  * pupper
            do 1111 iter=1,20
                x = 0.0d+00
                t = 0.0d+00
                ts = 0.0d+00
                tint = 0.0d+00
                dxdp = 0.0d+00
                do 1500 l=lmn,lmx - 1
                    vel = dble(v(l))
                    s = p*vel
                    c = dsqrt(1.0d+00 - s*s)
                    t = t + dble(h(l)) /(vel*c)
                    x = x + dble(h(l)) * s / c
                    dxdp  = dxdp + dble(h(l)) *
     1                  vel/(c*c*c)
                    tint = tint + dble(h(l)) * c / vel
                    ts = ts + qi(l) * dble(h(l))/(c*vel)
 1500           continue
                pnew = p - (x-dble(dist))/dxdp
c-----
c       safety - we must have a real ray, with upper bound
c       of  min[ 1/v(src), 1/v(rec)]
c-----  
                if(pnew .gt. pupper)then
                    if(iter.lt.20)then
                        pnew = 0.99d+00 * pupper
                    else
c-----
c       this is propably working like a refraction, so stop iterations
c-----  
                        t = tint + p * (dist)
                        go to 1112
                    endif
                endif
                p = pnew
 1111       continue
 1112       continue
            tfirst = t
            rayp = p
            tstar = ts
        endif
c-----
c       now proceed through the possible refracted arrivals
c       considering first upward rays from the source
c-----  
        if(lmn.gt.1)then
        do 3020 m=1,lmn-1
c-----
c       m is the refracting layer
c
c       get velocity of refractor
c-----
            vel = v(m)
            if(v(m).eq.0.0)return
            p = 1.0/vel
c-----
c
c           --------------------------------
c           h(1)
c           --------------------------------
c                      ....
c           --------------------------------
c           h(m)
c           ----------------...-------------
c           h(m+1)         /   \
c           --------------------------------
c                         /     \
c                      ....
c           --------------------------------
c           h(lmn-1)              \
c           -----------------------X--------
c               
c           h(lmn)     /    
c           --------------------------------
c                      ....
c           --------------------------------
c           h(lmx-1) /
c           --------X-----------------------
c
c       safety check, velocity at source or receiver must be less than
c       refraction velocity
c-----
        if(v(lmn).ge.vel)go to 3020
        if(v(lmx).ge.vel)go to 3020
c-----
c       single leg
c-----
        sumt = 0.0
        sumx = 0.0
        ts = 0.0
            do 3021 l=1,lmx-1,lmn
                if(v(l).gt.vel)go to 3020
                cs = sqrt(abs(1.0 - p*p*v(l)*v(l)))
                sumt = sumt + h(l)*cs/v(l)
                sumx = sumx + h(l)*p/cs
                ts = ts + qi(l)*h(l)/(cs * v(l))
 3021       continue
            do 3022 l=m+1,lmn-1
                if(v(l).gt.vel)go to 3020
                cs = sqrt(abs(1.0 - p*p*v(l)*v(l)))
                sumt = sumt + 2.0*h(l)*cs/v(l)
                sumx = sumx + 2.0*h(l)*p/cs
                ts = ts + 2.0*qi(l)*h(l)/(cs * v(l))
 3022       continue
            tint = sumt
            tt = tint + dist / vel
            ts = ts + qi(m)*(dist-sumx)/v(m)
            if(tt .lt. tfirst .and. dist.ge.sumx)then
                  tfirst = tt
                  rayp = p
                 tstar = ts
            endif
 3020       continue
        endif
c-----
c       For the special case of the depth phases, ignore previous
c       first arrival times
c-----
        if(ipsvsh.eq.4 .or. ipsvsh.eq.5)then
             tfirst = 1.0e+30
        endif
c-----
c       now proceed through the possible refracted arrivals
c       considering first downward rays from the source
c
c       We start considering the deepest point since we place
c       a source/receiver position just below a layer boundary
c       and thus should consider a horizontal ray
c
c       The refraction is accepted only if the desired distance >
c       first refraction from the source - this puts physics in the problem
c           
c           x = SUM h  tan theta
c                    i          i
c
c           t = SUM h  cos theta / V
c                    i          i   i
c                                                          2 2
c       where sin theta  = p V  , cos theta  = sqrt ( 1 - p V )
c                      i      i                              i
c       For the T* computation we need to follow the path, e.g.,
c       SUM h qi / ( cos theta  / V ) + qi (dist -  SUM h tan theta / V )/V
c            i  i             i    i      i              i         i   i   r
c-----  
        do 2020 m=lmx+1, mmax
c-----
c       m is the refracting layer
c
c       get velocity of refractor
c-----
            vel = v(m)
            if(v(m).eq.0.0)return
            p = 1.0/vel
c-----
c
c           -----------X--------------------
c           h(lmn)      \
c           --------------------------------
c                      ....
c           --------------------------------
c           h(lmx-1)        \             
c                            \           
c           ------------------X--------X----
c           h(lmx)             \       /
c           --------------------\-----/-----
c                      ....      \   /
c           ----------------------...-------
c           h(m)
c
c-----
c       safety check, velocity at source or receiver must be less than
c       refraction velocity
c-----
        if(v(lmn).ge.vel)go to 2020
        if(v(lmx).ge.vel)go to 2020
c-----
c       single leg
c-----
        sumx = 0.0
        sumt = 0.0
        ts = 0.0
c-----
c       special case for depth phases
c-----
            if(ipsvsh.eq.4)then
c-----
c               pP
c-----
                  do  l=lmaxref,lmaxs - 1
                      if(a(l).gt.vel)go to 2020
                      cs = sqrt(abs(1.0 - p*p*a(l)*a(l)))
                      sumt = sumt + 2.*h(l)*cs/a(l)
                      sumx = sumx + 2.*h(l)*p*a(l)/cs
                      if(qa(l).gt.1.0)qa(l) = 1.0/qa(l)
                      ts = ts + 2.*qa(l)*h(l)/(cs * a(l))
                  enddo
            else if(ipsvsh.eq.5)then
c-----
c               sP
c-----
                  do  l=lmaxref,lmaxs - 1
                      if(a(l).gt.vel)go to 2020
                      if(b(l).gt.vel)go to 2020
                      csa = sqrt(abs(1.0 - p*p*a(l)*a(l)))
                      csb = sqrt(abs(1.0 - p*p*b(l)*b(l)))
                      sumt = sumt + h(l)*csa/a(l)
     1                        +h(l)*csb/b(l)
                      sumx = sumx + 2.*h(l)*p*a(l)/csa
                      if(qa(l).gt.1.0)qa(l) = 1.0/qa(l)
                      if(qb(l).gt.1.0)qb(l) = 1.0/qb(l)
                      ts = ts + qa(l)*h(l)/(csa * a(l))
     1                        + qb(l)*h(l)/(csb * b(l))
                  enddo
            endif
c-----
c       continue
c-----
            do 2021 l=lmn,lmx - 1
                if(v(l).gt.vel)go to 2020
                if(v(l).eq.0.0)return
                cs = sqrt(abs(1.0 - p*p*v(l)*v(l)))
                sumt = sumt + h(l)*cs/v(l)
                sumx = sumx + h(l)*p*v(l)/cs
                ts = ts + qi(l)*h(l)/(cs * v(l))
 2021       continue
c-----
c       double leg
c-----
            do 2022 l=lmx,m-1
                if(v(l).gt.vel)go to 2020
                if(v(l).eq.0.0)return
                cs = sqrt(abs(1.0 - p*p*v(l)*v(l)))
                sumt = sumt + 2.0*h(l)*cs/v(l)
                sumx = sumx + 2.0*h(l)*p*v(l)/cs
                ts = ts + 2.*qi(l)*h(l)/(cs * v(l))
 2022       continue
            tint = sumt
            tt = tint + dist / vel
            ts = ts + qi(m)*(dist-sumx)/vel
            if(tt .lt. tfirst .and. dist.ge.sumx)then
                 tfirst = tt
                 rayp = p
                 tstar = ts
            endif
 2020       continue
             if(tfirst .eq. 1.0e+30)then
                tfirst = -12345.
                rayp   = -12345.
                tstar  = -12345.
             endif
        return
        end

        subroutine adosph()
c-----
c       Transform spherical earth to flat earth
c
c       Schwab, F. A., and L. Knopoff (1972). 
c           Fast surface wave and free
c       mode computations, in  
c           Methods in Computational Physics, Volume 11,
c       Seismology: Surface Waves and Earth Oscillations,  
c           B. A. Bolt (ed),
c       Academic Press, New York
c
c       Love Wave Equations  44, 45 , 41 pp 112-113
c       Rayleigh Wave Equations 102, 108, 109 pp 142, 144
c
c
c-----
c       mmax    I*4 number of layers
c       ipsvsh  I*4     1 - get P time
c                       2 - get SV time
c                       3 - get SH time
c-----
        integer NL
        parameter (NL=200)
        common/isomod/d(NL),a(NL),b(NL),rho(NL),
     1      qa(NL),qb(NL),etap(NL),etas(NL), 
     2      frefp(NL), frefs(NL)
        common/modlly/mmax
        integer mmax
        common/depref/refdep
        real refdep
        common/shwave/bsh(NL), rhosh(NL), qbsh(NL)
        real bsh, rhosh, qbsh

        double precision z0,z1,r0,r1,dr,ar,tmp
        integer ifunc

        common/earth/radius
        real radius

        ar=radius
        dr=0.0d0
        r0=ar + refdep
        d(mmax)=1.0
        do 10 i=1,mmax
            r1=r0-dble(d(i))
            z0=ar*dlog(ar/r0)
            z1=ar*dlog(ar/r1)
            d(i)=z1-z0
c-----
c        attempt 7 15 2007 - use standard rule but at mid layer depth as per DGH
c-----
            TMP=(ar+ar)/(r0+r1)

            a(i)=a(i)*tmp
            btmp = b(i)
            b(i)=btmp*tmp
            bsh(i)=btmp*tmp
            qbtmp = qb(i)
            qbsh(i)=qbtmp
            rhotmp=rho(i)
            rhosh(i) = rhotmp * tmp **(-5.0)
            rho(i) = rhotmp * tmp **(-2.275)
            r0 = r1
   10   continue
        d(mmax)=0.0
        return
        end

        subroutine adomod()
c-----
c       just fill the rhosh, bsh and qbsh arrays 
c-----
        integer NL
        parameter (NL=200)
        common/isomod/d(NL),a(NL),b(NL),rho(NL),
     1      qa(NL),qb(NL),etap(NL),etas(NL), 
     2      frefp(NL), frefs(NL)
        common/modlly/mmax
        integer mmax
        common/depref/refdep
        real refdep
        common/shwave/bsh(NL), rhosh(NL), qbsh(NL)
        real bsh, rhosh, qbsh

        do  i=1,mmax
            bsh(i)=b(i)
            qbsh(i)=qb(i)
            rhosh(i) = rho(i) 
        enddo
        return
        end

        subroutine srclyr(depth,lmax,dph)
        implicit none
        real depth, dph
        integer lmax
        integer LER, LIN, LOT
        parameter (LER=0, LIN=5, LOT=6)
        integer NL
        parameter(NL=200)
        common/isomod/d(NL),a(NL),b(NL),rho(NL),
     1      qa(NL),qb(NL),etap(NL),etas(NL),
     2      frefp(NL), frefs(NL)
        real d, a, b, rho, qa, qb, etap, etas, frefp, frefs
        common/modlly/mmax
        integer mmax
        common/shwave/bsh(NL), rhosh(NL), qbsh(NL)
        real bsh, rhosh, qbsh

        integer m
        real dep
c-----
c       Find source/receiver boundary. It is assumed that
c       it will lie upon a boundary
c
c       lmax = source layer 
c            = 0 is the free surface 
c       depth = source depth 
c       dph = height of  source above lmax + 1 interface 
c       lmax = 0 is the free surface 
c-----
        if(depth.le.0.0)then
            lmax = 1
            dph = 0.0
        else
            dep = 0.0 
            do 100 m = 2,mmax
                dep = dep + d(m-1) 
                dph = dep - depth 
                lmax = m 
                if(abs(dph).lt. 0.0001*d(m-1) .or.
     1              abs(dph).lt.1.0e-6)go to 101
  100       continue 
  101   continue 
        endif
        return 
        end 

