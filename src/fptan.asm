format elf64
define AVX2 1

macro polevl p1,p2,p3 {
	local .L0
	; %1 = ymm value,%2 = addr coef array , %3 = N
	mov rbx,p2
	lea rcx,[rbx+8*p3]
	vbroadcastsd ymm15,[rbx]
.L0:
	add rbx,8
if AVX2
	vbroadcastsd ymm14,[rbx]
	vfmadd213pd ymm15,p1,ymm14
else
	vmulpd ymm15,ymm15,p1
	vbroadcastsd ymm14,[rbx]
	vaddpd ymm15,ymm15,ymm14
end if
	cmp rbx,rcx
	jl .L0
}

macro p1evl p1,p2,p3 {
	local .L0
	; %1 = ymm value,%2 = addr coef array , %3 = N
	mov rbx,p2
	lea rcx,[rbx+8*(p3-1)]
	vbroadcastsd ymm15,[rbx]
	vaddpd ymm15,ymm15,p1
.L0:
	add rbx,8
if AVX2
	vbroadcastsd ymm14,[rbx]
	vfmadd213pd ymm15,p1,ymm14
else
	vmulpd ymm15,ymm15,p1
	vbroadcastsd ymm14,[rbx]
	vaddpd ymm15,ymm15,ymm14
end if
	cmp rbx,rcx
	jl .L0
}

section '.text' executable

public tangent
public sine
public cosine
public sin_pd
public cos_pd
public tan_pd
public x87sincos
public sincos_pd

tangent:
	sub rsp,8
	vmovsd [rsp],xmm0
	fld qword[rsp]
	fptan
	fstp st0
	fstp qword[rsp]
	vmovsd xmm0,[rsp]
	add rsp,8
	ret

sine:
	sub rsp,8
	vmovsd [rsp],xmm0
	fld qword[rsp]
	fsin
	fstp qword[rsp]
	vmovsd xmm0,[rsp]
	add rsp,8
	ret
cosine:
	sub rsp,8
	vmovsd [rsp],xmm0
	fld qword[rsp]
	fcos
	fstp qword[rsp]
	vmovsd xmm0,[rsp]
	add rsp,8
	ret
x87sincos:
	sub rsp,8
	vmovsd [rsp],xmm0
	fld qword[rsp]
	fsincos
	fstp qword[rsi]
	fstp qword[rdi]
	add rsp,8
	ret
; ymm0 -> x
sin_pd:
	push rbx
	vmovapd ymm1,ymm0
	vmovapd ymm2,[sign_mask]
	vandnpd ymm0,ymm2,ymm0 ; make positive x
	vandpd ymm1,ymm1,[sign_mask] ; save sign bit
	
	vbroadcastsd ymm2,[O4PI]
	vmulpd ymm3,ymm0,ymm2 ; 
	vroundpd ymm3,ymm3,3 ; truncate y

	vmulpd ymm2,ymm3,[OD16]
	vroundpd ymm2,ymm2,3
	
;	vmulpd ymm2,ymm2,[S16]
;	vsubpd ymm2,ymm3,ymm2

	vfnmadd132pd ymm2,ymm3,[S16]
	
	vcvttpd2dq xmm2,ymm2 ; j

	vpand xmm4,xmm2,[mask_1]
	vpaddd xmm2,xmm2,xmm4 ; j += 1
	vcvtdq2pd ymm4,xmm4
	vaddpd ymm3,ymm3,ymm4 ; y += 1.0
	
	vpand xmm4,xmm2,[mask_4]
	vpslld xmm4,xmm4,29 ; move mask to highest position
if AVX2 ; just example, too lazy to repeat for other functions ;)
	vpmovzxdq ymm4,xmm4
	vpsllq ymm4,ymm4,32
else
	vpmovzxdq xmm5,xmm4
	vpsllq xmm5,xmm5,32
	vpsrldq xmm4,xmm4,8
	vpmovzxdq xmm6,xmm4
	vpsllq xmm6,xmm6,32
	vmovapd xmm4,xmm5
	vinsertf128 ymm4,ymm4,xmm6,1
end if
	vxorpd ymm1,ymm1,ymm4 ; invert sign

	vpand xmm4,xmm2,[mask_3]
	vpcmpeqd xmm4,xmm4,[mask_0] 
if AVX2
	vpmovsxdq ymm4,xmm4
else
	vpmovsxdq xmm5,xmm4
	vpsrldq xmm4,xmm4,8
	vpmovsxdq xmm6,xmm4
	vmovapd xmm4,xmm5
	vinsertf128 ymm4,ymm4,xmm6,1 ; selection mask 
end if

; Extended precision modular arithmetic	
;	vmulpd ymm5,ymm3,[DP1]
;	vmulpd ymm6,ymm3,[DP2]
;	vmulpd ymm7,ymm3,[DP3]
;	vsubpd ymm0,ymm0,ymm5
;	vsubpd ymm0,ymm0,ymm6
;	vsubpd ymm0,ymm0,ymm7

	vfnmadd231pd ymm0,ymm3,[DP1]
	vfnmadd231pd ymm0,ymm3,[DP2]
	vfnmadd231pd ymm0,ymm3,[DP3]

	vmulpd ymm5,ymm0,ymm0 ; x^2

	; first	
	polevl ymm5,sincof,5
	vmulpd ymm15,ymm15,ymm5
;	vmulpd ymm15,ymm15,ymm0
;	vaddpd ymm6,ymm15,ymm0 ; y1
	
	vfmadd132pd ymm15,ymm0,ymm0
	vmovapd ymm6,ymm15

	; second
	polevl ymm5,coscof,5
	vmulpd ymm15,ymm15,ymm5
	vmulpd ymm15,ymm15,ymm5
;	vmulpd ymm7,ymm5,[OD2]
;	vsubpd ymm7,ymm15,ymm7

	vfnmadd231pd ymm15,ymm5,[OD2]
	vmovapd ymm7,ymm15

	vaddpd ymm7,ymm7,[one]; y2

	; combine
	vandpd ymm6,ymm4,ymm6
	vandnpd ymm7,ymm4,ymm7
	vaddpd ymm0,ymm6,ymm7

	vxorpd ymm0,ymm0,ymm1
	pop rbx
	ret
; ymm0 -> x
cos_pd:
	push rbx
	vmovapd ymm1,ymm0
	vmovapd ymm2,[sign_mask]
	vandnpd ymm0,ymm2,ymm0 ; make positive x
	vandpd ymm1,ymm1,[mask_0] ; positive
	
	vbroadcastsd ymm2,[O4PI]
	vmulpd ymm3,ymm0,ymm2 ; 
	vroundpd ymm3,ymm3,3 ; truncate y

	vmulpd ymm2,ymm3,[OD16]
	vroundpd ymm2,ymm2,3
	vmulpd ymm2,ymm2,[S16]
	vsubpd ymm2,ymm3,ymm2
	vcvttpd2dq xmm2,ymm2 ; j

	vpand xmm4,xmm2,[mask_1]
	vpaddd xmm2,xmm2,xmm4 ; j += 1
	vcvtdq2pd ymm4,xmm4
	vaddpd ymm3,ymm3,ymm4 ; y += 1.0
	
    vpand xmm2,xmm2,[mask_7]

	vpand xmm4,xmm2,[mask_4]
	vpslld xmm4,xmm4,29 ; move mask to highest position
	vpmovzxdq xmm5,xmm4
	vpsllq xmm5,xmm5,32
	vpsrldq xmm4,xmm4,8
	vpmovzxdq xmm6,xmm4
	vpsllq xmm6,xmm6,32
	vmovapd xmm4,xmm5
	vinsertf128 ymm4,ymm4,xmm6,1
	vxorpd ymm1,ymm1,ymm4 ; invert sign

    vpand xmm4,xmm2,[mask_2]
	vpslld xmm4,xmm4,30; move mask to highest position
	vpmovzxdq xmm5,xmm4
	vpsllq xmm5,xmm5,32
	vpsrldq xmm4,xmm4,8
	vpmovzxdq xmm6,xmm4
	vpsllq xmm6,xmm6,32
	vmovapd xmm4,xmm5
	vinsertf128 ymm4,ymm4,xmm6,1
    vxorpd ymm1,ymm1,ymm4 ; invert sign

    vpand xmm4,xmm2,[mask_3]
	vpcmpeqd xmm4,xmm4,[mask_0] 
	vpmovsxdq xmm5,xmm4
	vpsrldq xmm4,xmm4,8
	vpmovsxdq xmm6,xmm4
	vmovapd xmm4,xmm5
	vinsertf128 ymm4,ymm4,xmm6,1 ; selection mask 


; Extended precision modular arithmetic	
	vmulpd ymm5,ymm3,[DP1]
	vmulpd ymm6,ymm3,[DP2]
	vmulpd ymm7,ymm3,[DP3]
	vsubpd ymm0,ymm0,ymm5
	vsubpd ymm0,ymm0,ymm6
	vsubpd ymm0,ymm0,ymm7

	vmulpd ymm5,ymm0,ymm0 ; x^2

	; first	
	polevl ymm5,sincof,5
	vmulpd ymm15,ymm15,ymm5
	vmulpd ymm15,ymm15,ymm0
	vaddpd ymm6,ymm15,ymm0 ; y1
	
	; second
	polevl ymm5,coscof,5
	vmulpd ymm15,ymm15,ymm5
	vmulpd ymm15,ymm15,ymm5
	vmulpd ymm7,ymm5,[OD2]
	vsubpd ymm7,ymm15,ymm7
	vaddpd ymm7,ymm7,[one]; y2

	; combine
	vandnpd ymm6,ymm4,ymm6
	vandpd ymm7,ymm4,ymm7
	vaddpd ymm0,ymm6,ymm7

	vxorpd ymm0,ymm0,ymm1
	pop rbx
	ret
	
; ymm0 -> x
sincos_pd:
	push rbx
	vmovapd ymm1,ymm0
	vmovapd ymm2,[sign_mask]
	vandnpd ymm0,ymm2,ymm0 ; make positive x
	vandpd ymm1,ymm1,[sign_mask] ; save sign bit
	
	vbroadcastsd ymm2,[O4PI]
	vmulpd ymm3,ymm0,ymm2 ; 
	vroundpd ymm3,ymm3,3 ; truncate y

	vmulpd ymm2,ymm3,[OD16]
	vroundpd ymm2,ymm2,3
	vmulpd ymm2,ymm2,[S16]
	vsubpd ymm2,ymm3,ymm2
	vcvttpd2dq xmm2,ymm2 ; j

	vpand xmm4,xmm2,[mask_1]
	vpaddd xmm2,xmm2,xmm4 ; j += 1
	vcvtdq2pd ymm4,xmm4
	vaddpd ymm3,ymm3,ymm4 ; y += 1.0
	
	vpand xmm4,xmm2,[mask_4]
	vpslld xmm4,xmm4,29 ; move mask to highest position
	vpmovzxdq xmm5,xmm4
	vpsllq xmm5,xmm5,32
	vpsrldq xmm4,xmm4,8
	vpmovzxdq xmm6,xmm4
	vpsllq xmm6,xmm6,32
	vmovapd xmm4,xmm5
	vinsertf128 ymm4,ymm4,xmm6,1
	vxorpd ymm1,ymm1,ymm4 ; invert sign

	vpand xmm4,xmm2,[mask_3]
	vpcmpeqd xmm4,xmm4,[mask_0] 
	vpmovsxdq xmm5,xmm4
	vpsrldq xmm4,xmm4,8
	vpmovsxdq xmm6,xmm4
	vmovapd xmm4,xmm5
	vinsertf128 ymm4,ymm4,xmm6,1 ; selection mask 

	; Extended precision modular arithmetic	
	vmulpd ymm5,ymm3,[DP1]
	vmulpd ymm6,ymm3,[DP2]
	vmulpd ymm7,ymm3,[DP3]
	vsubpd ymm0,ymm0,ymm5
	vsubpd ymm0,ymm0,ymm6
	vsubpd ymm0,ymm0,ymm7

	vmulpd ymm5,ymm0,ymm0 ; x^2

	; first	
	polevl ymm5,sincof,5
	vmulpd ymm15,ymm15,ymm5
	vmulpd ymm15,ymm15,ymm0
	vaddpd ymm6,ymm15,ymm0 ; y1
	
	; second
	polevl ymm5,coscof,5
	vmulpd ymm15,ymm15,ymm5
	vmulpd ymm15,ymm15,ymm5
	vmulpd ymm7,ymm5,[OD2]
	vsubpd ymm7,ymm15,ymm7
	vaddpd ymm7,ymm7,[one]; y2

	; combine sin
	vandpd ymm8,ymm4,ymm6
	vandnpd ymm9,ymm4,ymm7
	vaddpd ymm0,ymm8,ymm9

	vxorpd ymm0,ymm0,ymm1
	vmovupd [rdi],ymm0

	; combine cos
	vandnpd ymm6,ymm4,ymm6
	vandpd ymm7,ymm4,ymm7
	vaddpd ymm0,ymm6,ymm7

	vxorpd ymm0,ymm0,ymm1
	vmovupd [rsi],ymm0
	
	pop rbx
	ret
tan_pd:
	push rbx
	vmovapd ymm1,ymm0
	vmovapd ymm2,[sign_mask]
	vandnpd ymm0,ymm2,ymm0 ; make positive x
	vandpd ymm1,ymm1,[sign_mask] ; save sign bit
	
	vbroadcastsd ymm2,[O4PI]
	vmulpd ymm3,ymm0,ymm2 ; 
	vroundpd ymm3,ymm3,3 ; truncate y

	vmulpd ymm2,ymm3,[OD16]
	vroundpd ymm2,ymm2,3
	vmulpd ymm2,ymm2,[S16]
	vsubpd ymm2,ymm3,ymm2
	vcvttpd2dq xmm2,ymm2 ; j

	vpand xmm4,xmm2,[mask_1]
	vpaddd xmm2,xmm2,xmm4 ; j += 1
	vcvtdq2pd ymm4,xmm4
	vaddpd ymm3,ymm3,ymm4 ; y += 1.0
	
	vpand xmm4,xmm2,[mask_2]
	vpcmpeqd xmm4,xmm4,[mask_0] 
	vpmovsxdq xmm5,xmm4
	vpsrldq xmm4,xmm4,8
	vpmovsxdq xmm6,xmm4
	vmovapd xmm4,xmm5
	vinsertf128 ymm4,ymm4,xmm6,1 ; selection mask 2

	; Extended precision modular arithmetic	
	vmulpd ymm5,ymm3,[DP1]
	vmulpd ymm6,ymm3,[DP2]
	vmulpd ymm7,ymm3,[DP3]
	vsubpd ymm0,ymm0,ymm5
	vsubpd ymm0,ymm0,ymm6
	vsubpd ymm0,ymm0,ymm7

	vmulpd ymm5,ymm0,ymm0 ; x^2

	vcmpnlepd ymm6,ymm5,[prec] ; selection mask 1
	
	;calculate polynom
	polevl ymm5,P,2
	vmovapd ymm13,ymm15
	p1evl ymm5,Q,4
	vdivpd ymm13,ymm13,ymm15
	vmulpd ymm13,ymm13,ymm5
	vmulpd ymm13,ymm13,ymm0
	vaddpd ymm13,ymm13,ymm0
	
	vandpd ymm13,ymm6,ymm13
	vandnpd ymm0,ymm6,ymm0 ; select according to mask 1
	vaddpd ymm0,ymm13,ymm0
	
	vmovapd ymm6,[mone]
	vdivpd ymm7,ymm6,ymm0
	
	vandpd ymm0,ymm4,ymm0
	vandnpd ymm7,ymm4,ymm7 ; select according to mask 2
	vaddpd ymm0,ymm0,ymm7
	
	vxorpd ymm0,ymm0,ymm1 ; invert sign
	pop rbx
	ret

section '.data' writeable align 32
sincof dq \
	1.58962301576546568060E-10,\
	-2.50507477628578072866E-8,\
	2.75573136213857245213E-6,\
	-1.98412698295895385996E-4,\
	8.33333333332211858878E-3,\
	-1.66666666666666307295E-1
coscof dq \
	-1.13585365213876817300E-11,\
	2.08757008419747316778E-9,\
	-2.75573141792967388112E-7,\
	2.48015872888517045348E-5,\
	-1.38888888888730564116E-3,\
	4.16666666666665929218E-2
P dq \
-1.30936939181383777646E4, \
 1.15351664838587416140E6, \
 -1.79565251976484877988E7 
Q dq \
 1.36812963470692954678E4, \
 -1.32089234440210967447E6,\
  2.50083801823357915839E7,\
  -5.38695755929454629881E7 
O4PI dq 1.273239544735162
align 32
DP1: times 4 dq   7.85398125648498535156E-1;
DP2: times 4 dq   3.77489470793079817668E-8;
DP3: times 4 dq   2.69515142907905952645E-15;
sign_mask: times 4 dq 0x8000000000000000
prec: times 4 dq 1.0e-14
one: times 4 dq 1.0
mone: times 4 dq -1.0
OD16: times 4 dq 0.0625
S16: times 4 dq 16.0
OD2: times 4 dq 0.5
mask_0: times 4 dd 0
mask_1: times 4 dd 1
mask_2: times 4 dd 2
mask_3: times 4 dd 3
mask_4: times 4 dd 4
mask_7: dd 4 dup(7)
