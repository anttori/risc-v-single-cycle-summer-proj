//#include <stdio.h>

void xtea_encrypt(unsigned int num_rounds, volatile unsigned int v[2], unsigned int const key[4]);

void xtea_decrypt(unsigned int num_rounds, volatile unsigned int v[2], unsigned int const key[4]);

// Make variables volatile or global so compiler doesn't optimize them away
volatile unsigned int data[2] = { 0x00C0FFEE, 0xFEE1600D };
const unsigned int key[4]     = { 0x20261021, 0x524F4D41, 0x33334444, 0x55556666 };

int main(void) {
	
	// temp windows-enviroment test command
	//printf("Initial data: data[0]: 0x%08X, data[1]: 0x%08X\n", data[0], data[1]);
	
	xtea_encrypt(32, data, key);
	
	// temp windows-enviroment test command
	//printf("Ecryption: data[0]: 0x%08X, data[1]: 0x%08X\n", data[0], data[1]);
	
	xtea_decrypt(32, data, key);
	
	// temp windows-enviroment test command
	//printf("Decryption: data[0]: 0x%08X, data[1]: 0x%08X\n", data[0], data[1]);
	
	while(1);
		
	return 0;
}


void xtea_encrypt(unsigned int num_rounds, volatile unsigned int v[2], unsigned int const key[4]) {
	unsigned int v0 = v[0], v1 = v[1], sum = 0, delta = 0x9E3779B9;
	for(unsigned int i = 0; i < num_rounds; i++) {
		v0 += (((v1 << 4) ^ (v1 >> 5)) + v1) ^ (sum + key[sum & 3]);
		sum += delta;
		v1 += (((v0 << 4) ^ (v0 >> 5)) + v0) ^ (sum + key[(sum >> 11) & 3]);
	}
	v[0] = v0;
	v[1] = v1;
}


void xtea_decrypt(unsigned int num_rounds, volatile unsigned int v[2], unsigned int const key[4]) {
	unsigned int v0 = v[0], v1 = v[1], delta = 0x9E3779B9, sum = delta * num_rounds;
	for (unsigned int i = 0; i < num_rounds; i++) {
		v1 -= (((v0 << 4) ^ (v0 >> 5)) + v0) ^ (sum + key[(sum >> 11) & 3]);
        sum -= delta;
        v0 -= (((v1 << 4) ^ (v1 >> 5)) + v1) ^ (sum + key[sum & 3]);
	}
	v[0] = v0;
	v[1] = v1;
}