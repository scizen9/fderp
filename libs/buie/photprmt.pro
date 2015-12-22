;+
; NAME:
;  photprmt
; PURPOSE:
;  Promote version of a photometry log file to highest version.
; DESCRIPTION:
;
; CATEGORY:
;  File I/O
; CALLING SEQUENCE:
;  photprmt,photfile
; INPUTS:
;
;  photfile - File with photometry data.
;
; OPTIONAL INPUT PARAMETERS:
;
; KEYWORD INPUT PARAMETERS:
;  NEEDBADFLG    - Flag, if set, requires that the bad flag be present in 
;                     the photometry file. Ordinarily, a default value of 0
;                     or other value is adopted via a user prompt if the flag
;                     is not already there. Note that this ONLY applies when 
;                     promoting 0.0.
;  DEFBADFLAG    - Default to set the bad flag in the photometry file if it is
;                     not present. It pre-empts the prompting of the user for
;                     the value, and operates silently. This keyword  ignored if
;                     NEEDBADFLG is set.  Note that this ONLY applies when 
;                     promoting 0.0.
;                
; OUTPUTS:
;
;  The photfile is updated to the most recent version.  Not changed if already
;    current, or an error is encountered in processing. Prior to overwriting
;    the original, a backup copy of the original photfile is made, named
;    photfile + '.bak'  so something.log becomes something.log.bak
;
;   The following formats are supported:
;   v0.0  The base format with no version line (aka anonymous)
;         The version generated by BASPHOTE when /altlog is not specified.
;   v1.0  Version line at the start:   PHOTFILE v1.0
;         adds sky signal and sky error fields right after maxcnt
;   v1.1  Version line at the start:   PHOTFILE v1.1
;         adds read noise field right after the gain
;         The version now generated by BASPHOTE when /altlog is specified.
;
; KEYWORD OUTPUT PARAMETERS:
;
; COMMON BLOCKS:
;
; SIDE EFFECTS:
;
; RESTRICTIONS:
;
; PROCEDURE:
;
; MODIFICATION HISTORY:
;  2000/06/02, Written by Marc W. Buie, Lowell Observatory
;  2002/09/03, MWB, changed Str_sep call to strsplit
;  2006/04/28, Peter L. Collins, Lowell Observatory
;                created PHOTFILE v1.1 for carrying read noise,
;                which is effectively defaulted as 0.00.
;  2006/5/23,  PLC, added a registration test to prevent invalid
;                   promotion of faux 0.0 files
;  2006/5/26,  PLC, allow 0.0 to be promoted without a bad flag
;                   an option that is suppressed by /NEEDBADFLG
;                   and a default supplied by DEFBADFLG (or 0).
;  2006/7/14,  PLC, add creation of .bak copy of the original.
;
;-
pro photprmt,photfile,NEEDBADFLG=needbadflg,DEFBADFLG=defbadflg

   self='photprmt: '
   if badpar(photfile,7,0,caller=self +  '(photfile) ') then return
   if badpar(needbadflg,[0,1,2,3],0,CALLER=self + ' (needbadflg) ', $
                                    default=-1) then return
   if badpar(defbadflg,[0,1,2,3],0,CALLER=self + ' (defbadflg) ', $
                                    default=0) then return

   ; If not present, don't do anything.
   IF not exists(photfile) THEN return

   ; Check the file version by reading the first line of the file.
   version=''
   openr,lun,photfile,/get_lun
   readf,lun,version,format='(a)'

   v1pt1='PHOTFILE v1.1'
   v1pt0='PHOTFILE v1.0'
   v0pt0='PHOTFILE v0.0'

   latest=v1pt1
   anonymous=v0pt0

   ; If it's current, do nothing.
   if version eq latest then begin
      free_lun,lun
      return
   endif

   ; upgrade from anonymous file to version tagged file.
   if version ne v1pt0 then begin
      ; compress out the whitespace
      version=strtrim(strcompress(version),2)
      ; get rid of the object name in single quotes
      words=strsplit(version,"'",/extract)
      ; words[0] is left of the quote, words[2] to the right.
      ; unless- the quoted string is empty
      if strmatch(version, "*''*") then begin
         if n_elements(words) eq 2 then begin
            leftwords=strsplit(words[0],' ',/extract)
            rightwords=strsplit(words[1],' ',/extract)
            nwords=n_elements(leftwords)+n_elements(rightwords)
         endif else begin
            nwords=0 ; just to throw an error (there were other than 2 quotes)
         endelse
      endif else begin
         if n_elements(words) eq 3 then begin
            leftwords=strsplit(words[0],' ',/extract)
            rightwords=strsplit(words[2],' ',/extract)
            nwords=n_elements(leftwords)+n_elements(rightwords)
         endif else begin
            nwords=0 ; just to throw an error (there were other than 2 quotes)
         endelse
      endelse
      if nwords lt 15 or nwords ge 17 then begin
            print,photfile,' is of an unrecognized format, --aborting.'
            print,'version tag seen: [',version,']'
            free_lun,lun
            return
      endif
      version=anonymous
   endif
   free_lun,lun

   print,'PHOTPRMT: Upgrading file from ',version,' to ',latest


      ; Read the file
   openr,lun,photfile,/get_lun

   ;Read through and count the number of lines.
   line=''
   nobs=0
   while(not eof(lun)) do begin
      readf,lun,line,format='(a1)'
      nobs=nobs+1
   endwhile

   ;don't count the version line
   if version ne anonymous then nobs=nobs-1

   ;Rewind file.
   point_lun,lun,0

   ;Create the output data vectors
   filename = strarr(nobs)
   obj      = strarr(nobs)
   fil      = strarr(nobs)
   jd       = dblarr(nobs)
   exptime  = fltarr(nobs)
   gain     = fltarr(nobs)
   rdnoise  = fltarr(nobs)
   rad      = fltarr(nobs)
   sky1     = fltarr(nobs)
   sky2     = fltarr(nobs)
   serial   = intarr(nobs)
   xpos     = fltarr(nobs)
   ypos     = fltarr(nobs)
   fwhm     = fltarr(nobs)
   maxcnt   = fltarr(nobs)
   sky      = fltarr(nobs)
   skyerr   = fltarr(nobs)
   mag      = fltarr(nobs)
   err      = fltarr(nobs)
   bad      = intarr(nobs)
   jd0 = 0.0d0


   ; skip the version line if there is a version line.
   if version ne anonymous then readf,lun,line,format='(a)'

   ; supported input formats- initial 3 fields filename, obj and fil are
   ; not included. The 0pt0 format string also does not cover the bad flag,
   ; at end., which is processed separately.
   ; in tabular form:
   ;  Version 0.0 IS
   ; jd  1-13  decimal pt 8
   ; exptime 14-22 decimal pt 19
   ; gain    23-29 decimal pt 27
   ; radius  30-37 decimal pt 35
   ; inner annulus 38-45 decimal pt 42
   ; outer annulus 46-53 decimal pt 50
   ; serial #      54-58 integer
   ; x position    59-67 decimal pt 64
   ; y position    68-76 decimal pt 73
   ; fwhm          77-82 decimal pt 80
   ; max count     83-90 decimal pt 89
   ; mag           91-99 decimal pt 95
   ; error         100-107 decimal pt 103
   ; bad flag      108-109    (not guaranteed contents)
   ; Ordinarily the first position of each field (save jd) is blank but that
   ; is not to be assumed.
   ;  Version 1.0 IS
   ; jd  1-13  decimal pt 8
   ; exptime 14-22 decimal pt 19
   ; gain    23-29 decimal pt 27
   ; radius  30-37 decimal pt 34
   ; inner annulus 38-45 decimal pt 42
   ; outer annulus 46-53 decimal pt 50
   ; serial #      54-58 integer
   ; x position    59-67 decimal pt 64
   ; y position    68-76 decimal pt 73
   ; fwhm          77-82 decimal pt 80
   ; max count     83-90 decimal pt 89
   ; sky signal    91-99 decimal pt 97
   ; sky signal error 100-106 decimal pt 104
   ; mag           107-115 decimal pt 111   (COULD BE A BAD VERSION 107-114!!!)
   ; error         116-123 decimal pt 119
   ; bad flag      124-125 ( integer)
   ; Ordinarily the first position of each field (save jd) is blank but that
   ; is not to be  assumed.
   ;  Version 1.1 IS
   ; jd  1-13  decimal pt 8
   ; exptime 14-22 decimal pt 19
   ; gain    23-29 decimal pt 27
   ; rdnoise    30-36 decimal pt 34
   ; radius  37-44 decimal pt 41
   ; inner annulus 45-52 decimal pt 49
   ; outer annulus 53-60 decimal pt 57
   ; serial #      61-65 integer
   ; x position    66-74 decimal pt 71
   ; y position    75-83 decimal pt 80
   ; fwhm          84-89 decimal pt 87
   ; max count     90-97 decimal pt 96
   ; sky signal    98-106 decimal pt 104
   ; sky signal error 107-113 decimal pt 111
   ; mag           114-122 decimal pt 118
   ; error         123-130 decimal pt 126
   ; bad flag      131-132 ( integer)
   ; Ordinarily the first position of each field (save jd) is blank but that
   ; is not to be assumed (on input) but will be guaranteed on output.
   ; we do however test the assumption with the registration mask format.
   ; This is done because promotion is a dangerous operation especially
   ; given the existence of the anonymous (0.0) version.
   fmt0pt0 = '(d13.5,f9.3,f7.2,3f8.3,i5,2f9.3,f6.2,f8.1,f9.4,f8.4)'
   reg0pt0 = '(13x,a1,8x,a1,6x,a1,7x,a1,7x,a1,7x,a1,4x,a1,8x,a1,8x,a1,5x,' + $
             'a1,7x,a1,8x,a1)'
   fmt1pt0 = '(d13.5,f9.3,f7.2,3f8.3,i5,2f9.3,f6.2,f8.1,f9.2,f7.2,f9.4,f8.4,i2)'
   reg1pt0 = '(13x,a1,8x,a1,6x,a1,7x,a1,7x,a1,7x,a1,4x,a1,8x,a1,8x,a1,5x,' + $
             'a1,7x,a1,8x,a1,6x,a1,8x,a1,7x,a1)'
   regm    =  make_array(15,/string,value=' ')

   reg0=''
   reg1=''
   reg2=''
   reg3=''
   reg4=''
   reg5=''
   reg6=''
   reg7=''
   reg8=''
   reg9=''
   reg10=''
   reg11=''
   reg12=''
   reg13=''
   reg14=''

   askbadflg=1
   badflgdefault=0
   if defbadflg ge 0 then begin
      askbadflg = 0
      badflgdefault = defbadflg
   endif

   for i=0,nobs-1 do begin

      ; Get the next input line.
      readf,lun,line,format='(a)'

      ; Read the filename, object name, and filter code as string bits.
      filename[i] = gettok(line,' ')
      obj[i]      = gettok(line,"'") ; This is a dummy read to drop 1st quote
      obj[i]      = gettok(line,"'")
      fil[i]      = gettok(line,' ')

         ; Read the rest of the data which is all numeric.
      if version eq anonymous then begin 
         reads,line,format=fmt0pt0, jd0,exptime0,gain0,rad0,sky1_0,sky2_0, $
                    serial0,xpos0,ypos0,fwhm0,maxcnt0,mag0,err0

         if strlen(line) lt 109  then begin
            if needbadflg lt 0 then begin
               ; following code is not currently used 
               if askbadflg eq 1 then begin
                  print, 'there are "badflag" values  missing from ',photfile
                  read, badflgdefault, $
                  PROMPT='type a numerical default, 0, or -1 to abort'
                  if badflgdefault lt 0 then return
                  askbadflg = 0
               endif
               bad0 = badflgdefault
            endif else  begin
               print, 'there are "badflag" values  missing from ',photfile, $
                       ' --aborting.'
               return
            endelse
            if strlen(line) eq 108 then begin
               reg12 = strmid(line,107)
               if reg12 ne ' ' then begin
                  print, 'stray character before bad flag field, line ', i+1, $
                         ' --aborting.'
                  return
               endif
            endif
         endif else begin
            bad0      = string(strmid(line,108,1))
         endelse

         ; reread the line with a registration mask- each value read
         ; is the single character at the leftmost of each field (save jd)
         ; which ought to be blank
         reads, line,format=reg0pt0, reg0, reg1, reg2, reg3, $
                 reg4, reg5, reg6, reg7, reg8, reg9, $
                 reg10, reg11
         regm = [ reg0,reg1,reg2,reg3,reg4,reg5, $
                   reg6,reg7,reg8,reg9,reg10,reg11]
         idx = where( regm ne ' ',count)
         if count ne 0 then begin

            ; note that line numbers are offset by 1 to allow for
            ; 0 indexing and the PHOTFILE header line.
            idx=idx+1  ;to offset the field numbering properly.
            print, self + 'bad format in fields', idx,  ', of line ', $
                   i+1, ', --aborting.'
            print,  $
            'Indicated fields are out of left registry, where jdn is field 0' 
            free_lun, lun
            return
         endif

         ; as an additional check against format confusion, make sure there
         ; is nothing, or clean whitespace, beyond the last field.
         if strlen(line) ge 109 then begin
            oflo = strmid( line, 109)
            if  strmatch ( oflo, '*[! ]*') ne 0 then begin
               print, self + 'trailing characters in input: [', oflo, $
                      '], line ', i+1,', --aborting'
               free_lun, lun
               return
            endif
         endif
      endif else begin
         reads,line,format=fmt1pt0, jd0,exptime0,gain0,rad0,sky1_0,sky2_0, $
                    serial0,xpos0,ypos0,fwhm0,maxcnt0,skysig,skyerr0,mag0, $
                    err0, bad0

         ; reread the line with a registration mask- each value read
         ; is the single character at the leftmost of each field (save jd)
         ; which ought to be blank
         reads, line,format=reg1pt0, reg0, reg1, reg2, reg3, $
                reg4, reg5, reg6, reg7, reg8, reg9, $
                reg10, reg11, reg12, reg13, reg14
         regm = [ reg0,reg1,reg2,reg3,reg4,reg5, $
                  reg6,reg7,reg8,reg9,reg10,reg11,reg12, reg13, reg14]
         idx = where( regm ne ' ',count)
         if count ne 0 then begin

            ; note that line numbers are offset by 2 to allow for
            ; 0 indexing and the PHOTFILE header line.
            idx=idx+1  ;to offset the field numbering properly.
            print, self + 'bad format in fields', idx,  ', of line ', $
                   i+2, ', --aborting.'
            print,  $
            'Indicated fields are out of left registry, where jdn is field 0' 
            free_lun, lun
            return
         endif

         ; as an additional check against format confusion, make sure there
         ; is nothing, or clean whitespace, beyond the last field.
         if strlen(line) gt 125 then begin
            oflo = strmid( line, 125)
            if  strmatch ( oflo, '*[! ]*') ne 0 then begin
               print, self + 'trailing characters in input: [', oflo, $
                      '], line ', i+2,', --aborting'
               free_lun, lun
               return
             endif
         endif

         sky[i]   = skysig
         skyerr[i]= skyerr0
      endelse

      jd[i]       = jd0
      exptime[i]  = exptime0
      gain[i]     = gain0
      rad[i]      = rad0
      sky1[i]     = sky1_0
      sky2[i]     = sky2_0
      serial[i]   = serial0
      xpos[i]     = xpos0
      ypos[i]     = ypos0
      fwhm[i]     = fwhm0
      maxcnt[i]   = maxcnt0
      mag[i]      = mag0
      err[i]      = err0
      bad[i]      = bad0

   endfor

   free_lun,lun

   fmt1pt1 ='(a,1x,"''",a,"''",1x,a,1x,f13.5,1x,f8.3,1x,f6.2,1x,' + $
          'f6.2,1x,f7.3,1x,f7.3,' + $
          '1x,f7.3,1x,i4.4,1x,f8.3,1x,f8.3,1x,f5.2,1x,f7.1,1x,f8.2,1x,f6.2,' + $
          '1x,f8.4,1x,f7.4,1x,i1)'

   ; move the current photfile to the .bak location
   backup=photfile+'.bak'
   print, 'PHOTPRMT: copying previous contents of ', photfile, ' to ', backup
   file_move, photfile, backup, /NOEXPAND_PATH,/OVERWRITE
   if not exists(backup) then begin
      print, backup, ' was not written,  system failure, aborting.'
      return
   endif

   ; Now write out the new file
   openw,lun,photfile,/get_lun
   printf,lun,latest
   for i=0,nobs-1 do begin
      printf, lun, format=fmt1pt1, $
            filename[i], obj[i], fil[i], jd[i], exptime[i], gain[i], $
            rdnoise[i],rad[i], $
            sky1[i], sky2[i], serial[i], xpos[i], ypos[i], fwhm[i], $
            maxcnt[i], sky[i], skyerr[i], mag[i], err[i], bad[i]
   endfor
   free_lun,lun

end