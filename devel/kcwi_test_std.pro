; $Id: kcwi_test_std.pro,v 1.16 2015/02/21 00:18:39 neill Exp $
;
; Copyright (c) 2014, California Institute of Technology. All rights
;	reserved.
;+
; NAME:
;	KCWI_TEST_STD
;
; PURPOSE:
;	Tests a standard star reduced with it's own inverse sensitivity.
;
; CATEGORY:
;	Data reduction for the Keck Cosmic Web Imager (KCWI).
;
; CALLING SEQUENCE:
;	KCWI_TEST_STD, Imno
;
; INPUTS:
;	Imno	- Image number of calibrated standard star observation
;
; OUTPUTS:
;	None
;
; SIDE EFFECTS:
;	None
;
; KEYWORDS:
;	None
;
; PROCEDURE:
;
; EXAMPLE:
;
; MODIFICATION HISTORY:
;	Written by:	Don Neill (neill@caltech.edu)
;	2014-APR-22	Initial Revision
;-
pro kcwi_test_std,imno,ps=ps,verbose=verbose,display=display
	;
	; setup
	pre = 'KCWI_TEST_STD'
	version = repstr('$Revision: 1.16 $ $Date: 2015/02/21 00:18:39 $','$','')
	q=''
	;
	; check input
	if n_params(0) lt 1 then begin
		print,pre+': Info - Usage: '+pre+', Imno'
		return
	endif
	;
	; get inputs
	kcfg = kcwi_read_cfgs('./redux',filespec='image'+strn(imno)+'_icubes.fits')
	ppar = kcwi_read_ppar('./redux/kcwi.ppar')
	;
	; check keyword overrides
	if keyword_set(verbose) then $
		ppar.verbose = verbose
	if keyword_set(display) then $
		ppar.display = display
	;
	; log
	kcwi_print_info,ppar,pre,version
	;
	; is this a standard star object observation?
	if strmatch(strtrim(kcfg.imgtype,2),'object') eq 0 then begin
		kcwi_print_info,ppar,pre,'not a std obs',/warning
	endif
	;
	; directories
	if kcwi_verify_dirs(ppar,rawdir,reddir,cdir,ddir) ne 0 then begin
		kcwi_print_info,ppar,pre,'Directory error, returning',/error
		return
	endif
	;
	; read in image (already extinction corrected)
	icub = kcwi_read_image(kcfg.imgnum,ppar,'_icubes',hdr,/calib,status=stat)
	if stat ne 0 then begin
		kcwi_print_info,ppar,pre,'could not read input file',/error
		return
	endif
	;
	; check standard
	sname = strlowcase(strtrim(sxpar(hdr,'object'),2))
	;
	; is standard file available?
	spath = !KCWI_DATA + '/stds/'+sname+'.fits'
	if not file_test(spath) then begin
		kcwi_print_info,ppar,pre,'standard star data file not found for: '+sname,/error
		return
	endif
	kcwi_print_info,ppar,pre,'testing inverse sensitivity curve for '+sname
	;
	; get size
	sz = size(icub,/dim)
	;
	; default pixel ranges
	y = findgen(sz[2])
	y0 = 175
	y1 = sz[2] - 175
	;
	; get wavelength scale
	w0 = sxpar(hdr,'CRVAL3')
	dw = sxpar(hdr,'CD3_3')
	;
	; get all good wavelength range
	wgoo0 = sxpar(hdr,'WAVGOOD0')
	wgoo1 = sxpar(hdr,'WAVGOOD1')
	;
	; get all inclusive wavelength range
	wall0 = sxpar(hdr,'WAVALL0')
	wall1 = sxpar(hdr,'WAVALL1')
	;
	; compute good y pixel ranges
	if w0 gt 0. and dw gt 0. and wgoo0 gt 0. and wgoo1 gt 0. then begin
		y0 = fix( (wgoo0 - w0) / dw ) + 10
		y1 = fix( (wgoo1 - w0) / dw ) - 10
	endif
	gy = where(y ge y0 and y le y1)
	;
	; wavelength scale
	w = w0 + y*dw
	;
	; good spatial range
	gx0 = ppar.slicex0
	gx1 = ppar.slicex1
	x = indgen(sz[0])
	;
	; log results
	kcwi_print_info,ppar,pre,'Invsens. Pars: X0, X1, Y0, Y1, Wav0, Wav1', $
		gx0,gx1,y0,y1,w[y0],w[y1],format='(a,4i6,2f9.3)'
	;
	; display status
	doplots = (ppar.display ge 2)
	;
	; find standard
	tot = total(icub[gx0:gx1,*,y0:y1],3)
	xx = findgen(gx1-gx0)+gx0
	mxsl = -1
	mxsg = 0.
	for i=0,23 do begin
		mo = moment(tot[*,i])
		if sqrt(mo[1]) gt mxsg then begin
			mxsg = sqrt(mo[1])
			mxsl = i
		endif
	endfor
	mxsl = 11
	;
	; relevant slices
	sl0 = (mxsl-3)>0
	sl1 = (mxsl+3)<23
	;
	; get x position of std
	cx = cntrd1d(xx,tot[*,mxsl])
	;
	; log results
	kcwi_print_info,ppar,pre,'Std slices; max, sl0, sl1, spatial cntrd', $
		mxsl,sl0,sl1,cx,format='(a,3i4,f9.2)'
	;
	; do sky subtraction
	scub = icub
	deepcolor
	!p.background=colordex('white')
	!p.color=colordex('black')
	for i=sl0,sl1 do begin
		skyspec = fltarr(sz[2])
		for j = 0,sz[2]-1 do begin
			skyv = reform(icub[gx0:gx1,i,j])
			good = where(xx le (cx-15) or xx ge (cx+15))
			sky = median(skyv[good])
			skyspec[j] = sky
			scub[*,i,j] = icub[*,i,j] - sky
		endfor
		if doplots then begin
			yrng = get_plotlims(skyspec[gy])
			plot,w,skyspec,title='Slice '+strn(i), $
				xtitle='Wave (A)', xran=[wall0,wall1], /xs, $
				ytitle='DN', yran=yrng, /ys
				oplot,[wgoo0,wgoo0],!y.crange,color=colordex('green')
				oplot,[wgoo1,wgoo1],!y.crange,color=colordex('green')
			read,'Next? (Q-quit plotting, <cr> - next): ',q
			if strupcase(strmid(strtrim(q,2),0,1)) eq 'Q' then $
				doplots = 0
		endif
	endfor
	;
	; get slice spectra
	slspec = total(scub[gx0:gx1,*,*],1)
	;
	; standard spectra
	stdspec = total(slspec[sl0:sl1,*],1)
	;
	; read in standard
	sdat = mrdfits(spath,1,shdr)
	swl = sdat.wavelength
	sflx = sdat.flux
	sfw = sdat.fwhm
	;
	; get region of interest
	sroi = where(swl ge wall0 and swl le wall1, nsroi)
	if nsroi le 0 then begin
		kcwi_print_info,ppar,pre,'no standard wavelengths in common',/error
		return
	;
	; very sparsely sampled w.r.t. object
	endif else if nsroi eq 1 then begin
		;
		; up against an edge, no good
		if sroi[0] le 0 or sroi[0] ge n_elements(swl)-1L then begin
			kcwi_print_info,ppar,pre, $
				'standard wavelengths not a good match',/error
			return
		;
		; manually expand sroi to allow linterp to work
		endif else begin
			sroi = [ sroi[0]-1, sroi[0], sroi[0]+1 ]
		endelse
	endif
	swl = swl[sroi]
	sflx = sflx[sroi]
	sfw = sfw[sroi]
	fwhm = max(sfw)
	kcwi_print_info,ppar,pre,'reference spectrum FWHM used',fwhm, $
		format='(a,f5.1)'
	;
	; resample onto our wavelength grid
	linterp,swl,sflx,w,rsflx
	;
	; get a smoothed version
	stdsmoo = gaussfold(w,stdspec,fwhm,lammin=wgoo0,lammax=wgoo1)
	;
	; make a hardcopy if requested
	if keyword_set(ps) then begin
		font_store=!p.font
		psfile,sname+'_'+strn(imno)
		deepcolor
		!p.background=colordex('white')
		!p.color=colordex('black')
		!p.font=0
	endif
	;
	; over plot standard
	yrng = get_plotlims(stdspec[gy])
	plot,w,stdspec,title=sname+' Img #: '+strn(imno), $
		xran=[wall0,wall1], /xs,xtickformat='(a1)', $
		ytitle='!3Flam (erg s!U-1!N cm!U-2!N A!U-1!N)',yran=yrng,/ys, $
		pos=[0.15,0.30,0.95,0.95]
	oplot,w,stdsmoo,color=colordex('blue'),thick=2
	oplot,swl,sflx,color=colordex('red')
	oplot,[wgoo0,wgoo0],!y.crange,color=colordex('green')
	oplot,[wgoo1,wgoo1],!y.crange,color=colordex('green')
	legend,['Cal. Flux','Obs. Flux','Smoothed'],linesty=[0,0,0], $
		color=[colordex('red'),colordex('black'),colordex('blue')], $
		/clear,clr_color=!p.background,/bottom,/right
	;
	; get residuals
	rsd = stdspec - rsflx
	frsd = 100.d0*(rsd/rsflx)
	srsd = stdsmoo - rsflx
	mo = moment(rsd[gy],/nan)
	fmo = moment(frsd[gy],/nan)
	;
	; annotate residuals on main plot
	legend,['<Resid> = '+strtrim(string(mo[0],format='(g13.3)'),2) + $
		' +- '+strtrim(string(sqrt(mo[1]),format='(g13.3)'),2)+' Flam', $
		'<Resid> = '+strtrim(string(fmo[0],format='(f8.2)'),2) + $
		' +- '+strtrim(string(sqrt(fmo[1]),format='(f8.2)'),2)+' %'], $
		/clear,clr_color=!p.background,/bottom;,/right
	;
	; plot residuals
	yrng = get_plotlims(rsd[gy])
	plot,w,rsd,xtitle='Wave (A)',xran=[wall0,wall1], /xs, $
		ytitle='!3Obs-Cal',yran=yrng,/ys,pos=[0.15,0.05,0.95,0.30], $
		/noerase
	oplot,!x.crange,[0,0]
	oplot,w,srsd,color=colordex('blue')
	oplot,[wgoo0,wgoo0],!y.crange,color=colordex('green')
	oplot,[wgoo1,wgoo1],!y.crange,color=colordex('green')
	;
	; check for effective area curve
	eafil = ppar.reddir + ppar.froot + $
		string(kcfg.imgnum,format='(i0'+strn(ppar.fdigits)+')') + $
		'_ea.fits'
	if file_test(eafil) then begin
		rdfits1dspec,eafil,wea,ea,hdr
		;
		; get reference area
		tel = strtrim(sxpar(hdr,'telescop'),2)
		;
		; average extinction correction (atmosphere)
		atm = 1./( sxpar(hdr,'avexcor')>1. )
		;
		; defaults
		area = -1.0
		refl = 1.0
		;
		; ea file starts the title
		fdecomp,eafil,disk,dir,eaf,ext
		if strpos(tel,'5m') ge 0 then begin
			area = 194165.d0	; Hale 5m area in cm^2
			refl = 0.90		; reflectivity (2-bounce)
		endif
		area = area * refl * atm
		tlab = eaf + '  ' + tel + ' * ' + $
			string(refl*100.,form='(i2)')+ '% refl. * ' + $
			string(atm*100.,form='(i2)')+ '% atmos.'
		if not keyword_set(ps) then $
			read,'next: ',q
		yrng = get_plotlims(ea)
		maxea = max(ea)
		mo = moment(ea)
		if area gt 0 then begin
			plot,wea,ea,xtitle='Wave (A)',xran=[wall0,wall1],/xs, $
				ytitle='!3EA (cm!U2!N)',title=tlab,ys=9, $
				yran=yrng,xmargin=[11,8]
			oplot,[wgoo0,wgoo0],!y.crange,color=colordex('green')
			oplot,[wgoo1,wgoo1],!y.crange,color=colordex('green')
			oplot,!x.crange,[maxea,maxea],linesty=2
			oplot,!x.crange,[mo[0],mo[0]],linesty=3
			axis,yaxis=1,yrange=100.*(!y.crange/area),ys=1, $
				ytitle='Efficiency (%)'
		endif else begin
			plot,wea,ea,xtitle='Wave (A)',xran=[wall0,wall1],/xs, $
				ytitle='!3EA (cm!U2!N)', yran=yrng, /ys, $
				title=tlab
			oplot,[wgoo0,wgoo0],!y.crange,color=colordex('green')
			oplot,[wgoo1,wgoo1],!y.crange,color=colordex('green')
			oplot,!x.crange,[maxea,maxea],linesty=2
			oplot,!x.crange,[mo[0],mo[0]],linesty=3
		endelse
	endif else $
		kcwi_print_info,ppar,pre,'EA file not found',eafil,/warning
	;
	; check if we are making hardcopy
	if keyword_set(ps) then begin
		!p.font=font_store
		psclose
	endif
	;
	return
end
