pro fball_sumimg,list
;+
;	sum images in list
;-
readcol,list,flist,form='a'
nfile = n_elements(flist)
;
; read in first image
hdr = headfits(flist[0])
nax = sxpar(hdr,'NAXIS')
if nax ne 2 then begin
	print,'This works for two-D images only'
	return
endif

nx = sxpar(hdr,'NAXIS1')
ny = sxpar(hdr,'NAXIS2')
outimg = fltarr(nx,ny)
nadd = 0

; loop over images
for i=0,nfile-1 do begin
	print,string(13B),i+1,'/',nfile,flist[i],format='($,a1,i3,a1,i3,2x,a)'
	data = mrdfits(flist[i],0,h,/silent)
	nnx = sxpar(h,'NAXIS1')
	nny = sxpar(h,'NAXIS2')
	if nnx ne nx or nny ne ny then begin
		print,'Error - not correct size: ',flist[i]
	endif else begin
		outimg[*,*] += data
		nadd += 1
	endelse
endfor
print,''
;
outimg /= float(nadd)
;
tmp = list
rute = gettok(tmp,'.')
ofil = rute+'.fits'
;
; use first image header for output fits file
mwrfits,outimg,ofil,hdr,/create
;
return
end
