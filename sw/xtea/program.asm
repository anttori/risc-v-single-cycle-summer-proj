
program.elf:     file format elf32-littleriscv


Disassembly of section .text:

00000000 <_start>:
   0:	00001137          	lui	sp,0x1
   4:	15c000ef          	jal	160 <main>

00000008 <halt>:
   8:	0000006f          	j	8 <halt>

0000000c <xtea_encrypt>:
   c:	0005a303          	lw	t1,0(a1)
  10:	0045a883          	lw	a7,4(a1)
  14:	06050c63          	beqz	a0,8c <xtea_encrypt+0x80>
  18:	9e378eb7          	lui	t4,0x9e378
  1c:	00000e13          	li	t3,0
  20:	00000793          	li	a5,0
  24:	9b9e8e93          	addi	t4,t4,-1607 # 9e3779b9 <data+0x9e377815>
  28:	0037f713          	andi	a4,a5,3
  2c:	00271713          	slli	a4,a4,0x2
  30:	00e60733          	add	a4,a2,a4
  34:	00072683          	lw	a3,0(a4)
  38:	00489813          	slli	a6,a7,0x4
  3c:	0058d713          	srli	a4,a7,0x5
  40:	00d786b3          	add	a3,a5,a3
  44:	01d787b3          	add	a5,a5,t4
  48:	00e84833          	xor	a6,a6,a4
  4c:	0097d713          	srli	a4,a5,0x9
  50:	01180833          	add	a6,a6,a7
  54:	00c77713          	andi	a4,a4,12
  58:	0106c6b3          	xor	a3,a3,a6
  5c:	00e60733          	add	a4,a2,a4
  60:	00d30333          	add	t1,t1,a3
  64:	00072703          	lw	a4,0(a4)
  68:	00431693          	slli	a3,t1,0x4
  6c:	00535813          	srli	a6,t1,0x5
  70:	0106c6b3          	xor	a3,a3,a6
  74:	00e78733          	add	a4,a5,a4
  78:	006686b3          	add	a3,a3,t1
  7c:	00d74733          	xor	a4,a4,a3
  80:	001e0e13          	addi	t3,t3,1
  84:	00e888b3          	add	a7,a7,a4
  88:	fbc510e3          	bne	a0,t3,28 <xtea_encrypt+0x1c>
  8c:	0065a023          	sw	t1,0(a1)
  90:	0115a223          	sw	a7,4(a1)
  94:	00008067          	ret

00000098 <xtea_decrypt>:
  98:	00151713          	slli	a4,a0,0x1
  9c:	00a70733          	add	a4,a4,a0
  a0:	00571793          	slli	a5,a4,0x5
  a4:	40e787b3          	sub	a5,a5,a4
  a8:	00579793          	slli	a5,a5,0x5
  ac:	00a787b3          	add	a5,a5,a0
  b0:	00779713          	slli	a4,a5,0x7
  b4:	00e787b3          	add	a5,a5,a4
  b8:	00479793          	slli	a5,a5,0x4
  bc:	40a787b3          	sub	a5,a5,a0
  c0:	00279793          	slli	a5,a5,0x2
  c4:	00a787b3          	add	a5,a5,a0
  c8:	00379713          	slli	a4,a5,0x3
  cc:	00e787b3          	add	a5,a5,a4
  d0:	00279793          	slli	a5,a5,0x2
  d4:	40a78733          	sub	a4,a5,a0
  d8:	0005a883          	lw	a7,0(a1)
  dc:	0045a803          	lw	a6,4(a1)
  e0:	00271793          	slli	a5,a4,0x2
  e4:	40e787b3          	sub	a5,a5,a4
  e8:	06050663          	beqz	a0,154 <xtea_decrypt+0xbc>
  ec:	61c88337          	lui	t1,0x61c88
  f0:	64730313          	addi	t1,t1,1607 # 61c88647 <data+0x61c884a3>
  f4:	0097d713          	srli	a4,a5,0x9
  f8:	00c77713          	andi	a4,a4,12
  fc:	00e60733          	add	a4,a2,a4
 100:	00072683          	lw	a3,0(a4)
 104:	00489513          	slli	a0,a7,0x4
 108:	0058d713          	srli	a4,a7,0x5
 10c:	00d786b3          	add	a3,a5,a3
 110:	006787b3          	add	a5,a5,t1
 114:	00e54533          	xor	a0,a0,a4
 118:	0037f713          	andi	a4,a5,3
 11c:	01150533          	add	a0,a0,a7
 120:	00271713          	slli	a4,a4,0x2
 124:	00a6c6b3          	xor	a3,a3,a0
 128:	00e60733          	add	a4,a2,a4
 12c:	40d80833          	sub	a6,a6,a3
 130:	00072703          	lw	a4,0(a4)
 134:	00481693          	slli	a3,a6,0x4
 138:	00585513          	srli	a0,a6,0x5
 13c:	00a6c6b3          	xor	a3,a3,a0
 140:	00e78733          	add	a4,a5,a4
 144:	010686b3          	add	a3,a3,a6
 148:	00d74733          	xor	a4,a4,a3
 14c:	40e888b3          	sub	a7,a7,a4
 150:	fa0792e3          	bnez	a5,f4 <xtea_decrypt+0x5c>
 154:	0115a023          	sw	a7,0(a1)
 158:	0105a223          	sw	a6,4(a1)
 15c:	00008067          	ret

00000160 <main>:
 160:	ff010113          	addi	sp,sp,-16 # ff0 <data+0xe4c>
 164:	00812423          	sw	s0,8(sp)
 168:	00912223          	sw	s1,4(sp)
 16c:	19400613          	li	a2,404
 170:	1a400593          	li	a1,420
 174:	02000513          	li	a0,32
 178:	00112623          	sw	ra,12(sp)
 17c:	e91ff0ef          	jal	c <xtea_encrypt>
 180:	19400613          	li	a2,404
 184:	1a400593          	li	a1,420
 188:	02000513          	li	a0,32
 18c:	f0dff0ef          	jal	98 <xtea_decrypt>
 190:	0000006f          	j	190 <main+0x30>
